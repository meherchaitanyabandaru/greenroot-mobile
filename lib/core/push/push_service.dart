import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../utilities/logger.dart';

/// Firebase settings, passed at build time so no google-services.json or
/// GoogleService-Info.plist lives in the repository:
///
///   flutter build appbundle --dart-define=FCM_PROJECT_ID=... \
///     --dart-define=FCM_SENDER_ID=... --dart-define=FCM_API_KEY=... \
///     --dart-define=FCM_APP_ID_ANDROID=... --dart-define=FCM_APP_ID_IOS=...
///
/// Without them push is off (local builds); everything else works and
/// notifications stay in the in-app inbox.
class PushConfig {
  const PushConfig({
    required this.projectId,
    required this.senderId,
    required this.apiKey,
    required this.androidAppId,
    required this.iosAppId,
  });

  factory PushConfig.fromEnvironment() => const PushConfig(
        projectId: String.fromEnvironment('FCM_PROJECT_ID'),
        senderId: String.fromEnvironment('FCM_SENDER_ID'),
        apiKey: String.fromEnvironment('FCM_API_KEY'),
        androidAppId: String.fromEnvironment('FCM_APP_ID_ANDROID'),
        iosAppId: String.fromEnvironment('FCM_APP_ID_IOS'),
      );

  final String projectId;
  final String senderId;
  final String apiKey;
  final String androidAppId;
  final String iosAppId;

  /// The app id for this platform, or '' when push is not configured for it.
  String appIdFor(TargetPlatform platform) => switch (platform) {
        TargetPlatform.android => androidAppId,
        TargetPlatform.iOS => iosAppId,
        _ => '',
      };

  bool enabledFor(TargetPlatform platform) =>
      projectId.isNotEmpty && senderId.isNotEmpty && apiKey.isNotEmpty && appIdFor(platform).isNotEmpty;
}

/// The device side of push (Firebase), behind an interface for tests.
/// A push that arrived while the app was open.
class PushMessage {
  final String? title;
  final String? body;
  const PushMessage({this.title, this.body});
}

abstract class PushPlatform {
  /// Starts the SDK and asks for permission; false = push unavailable.
  Future<bool> start();
  Future<String?> token();
  Stream<String> get onTokenRefresh;
  Future<void> deleteToken();

  /// Pushes that arrive while the app is in the foreground (the system shows
  /// nothing for these on Android).
  Stream<PushMessage> get onForegroundMessage;
}

class FirebasePushPlatform implements PushPlatform {
  FirebasePushPlatform(this.config);
  final PushConfig config;

  @override
  Future<bool> start() async {
    final platform = defaultTargetPlatform;
    if (kIsWeb || !config.enabledFor(platform)) return false;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: config.apiKey,
          appId: config.appIdFor(platform),
          messagingSenderId: config.senderId,
          projectId: config.projectId,
        ),
      );
    }
    final settings = await FirebaseMessaging.instance.requestPermission();
    // iOS: show the banner with its sound even while the app is open.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // Registration tokens, as the API's FCM HTTP v1 sender targets them
  // (message.token). firebase_messaging 17 deprecates them for the new
  // FID-based register()/onRegistered; move both sides together when the API
  // sender is switched to FID targets.

  @override
  // ignore: deprecated_member_use
  Future<String?> token() => FirebaseMessaging.instance.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;

  @override
  // ignore: deprecated_member_use
  Future<void> deleteToken() => FirebaseMessaging.instance.deleteToken();

  @override
  Stream<PushMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map((m) => PushMessage(
            title: m.notification?.title,
            body: m.notification?.body,
          ),);
}

/// The API side: POST/DELETE /notifications/devices.
abstract class DeviceRegistry {
  Future<int?> register(String token);
  Future<void> unregister(int deviceId);
}

class ApiDeviceRegistry implements DeviceRegistry {
  @override
  Future<int?> register(String token) async {
    final version = (await PackageInfo.fromPlatform()).version;
    final out = await ApiClient.instance.post<Map<String, dynamic>>(
      ApiConstants.notificationDevices,
      data: {
        'fcm_token': token,
        'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
        'device_type': 'MOBILE',
        'app_version': version,
      },
    );
    final device = out['device'];
    return device is Map ? (device['id'] as num?)?.toInt() : null;
  }

  @override
  Future<void> unregister(int deviceId) =>
      ApiClient.instance.delete<dynamic>('${ApiConstants.notificationDevices}/$deviceId');
}

/// Keeps this phone registered for push while someone is signed in.
///
/// [register] after every successful sign-in or session restore (idempotent:
/// the API upserts by token); [unregister] on logout, before the session is
/// cleared, so a shared phone stops receiving the previous user's pushes.
/// Failures never block sign-in or logout: push is best-effort.
class PushService {
  PushService({PushPlatform? platform, DeviceRegistry? registry})
      : _platform = platform ?? FirebasePushPlatform(PushConfig.fromEnvironment()),
        _registry = registry ?? ApiDeviceRegistry();

  static final PushService instance = PushService();

  final PushPlatform _platform;
  final DeviceRegistry _registry;
  bool? _available;
  String? _token;
  int? _deviceId;
  StreamSubscription<String>? _refresh;

  StreamSubscription<PushMessage>? _foreground;

  /// Called for each push that arrives while the app is open; the app shows
  /// it as an in-app banner (with a haptic) and refreshes its lists.
  void Function(PushMessage message)? onForeground;

  int? get deviceId => _deviceId;

  Future<void> register() async {
    try {
      _available ??= await _platform.start();
      if (_available != true) return;
      final token = await _platform.token();
      if (token == null || token.isEmpty) return;
      if (token != _token || _deviceId == null) {
        _deviceId = await _registry.register(token);
        _token = token;
      }
      _foreground ??= _platform.onForegroundMessage
          .listen((m) => onForeground?.call(m));
      _refresh ??= _platform.onTokenRefresh.listen((t) async {
        try {
          _deviceId = await _registry.register(t);
          _token = t;
        } catch (e) {
          AppLogger.w('push: token refresh registration failed: $e');
        }
      });
    } catch (e) {
      AppLogger.w('push: registration skipped: $e');
    }
  }

  Future<void> unregister() async {
    final id = _deviceId;
    _deviceId = null;
    _token = null;
    await _refresh?.cancel();
    _refresh = null;
    await _foreground?.cancel();
    _foreground = null;
    if (_available != true) return;
    try {
      if (id != null) await _registry.unregister(id);
    } catch (e) {
      AppLogger.w('push: device unregister failed: $e');
    }
    try {
      await _platform.deleteToken(); // the next user gets a fresh token
    } catch (e) {
      AppLogger.w('push: token delete failed: $e');
    }
  }
}

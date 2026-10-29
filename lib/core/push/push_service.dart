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
        projectId: String.fromEnvironment('FCM_PROJECT_ID', defaultValue: 'them87-greenroot'),
        senderId: String.fromEnvironment('FCM_SENDER_ID', defaultValue: '1001020207670'),
        apiKey: String.fromEnvironment('FCM_API_KEY', defaultValue: 'AIzaSyAkWGcLDSuE1D3qwWfYOROAGM0AeBsk1-U'),
        androidAppId: String.fromEnvironment('FCM_APP_ID_ANDROID', defaultValue: '1:1001020207670:android:6bc79096a7e4fee90dde97'),
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
/// A push notification received by the app.
class PushMessage {
  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  const PushMessage({
    this.title,
    this.body,
    this.data = const {},
  });
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

  /// Pushes tapped in the system tray while the app was in the background.
  Stream<PushMessage> get onMessageOpenedApp;

  /// The push tapped to launch the app from a terminated (killed) state.
  Future<PushMessage?> getInitialMessage();
}

class FirebasePushPlatform implements PushPlatform {
  FirebasePushPlatform(this.config);
  final PushConfig config;

  static PushMessage _fromRemoteMessage(RemoteMessage m) => PushMessage(
        title: m.notification?.title ?? m.data['title']?.toString(),
        body: m.notification?.body ??
            m.data['body']?.toString() ??
            m.data['message']?.toString(),
        data: m.data,
      );

  @override
  Future<bool> start() async {
    final platform = defaultTargetPlatform;
    if (kIsWeb) return false;
    final isAndroid = platform == TargetPlatform.android;
    if (!config.enabledFor(platform) && !isAndroid) return false;
    try {
      if (Firebase.apps.isEmpty) {
        if (config.enabledFor(platform)) {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: config.apiKey,
              appId: config.appIdFor(platform),
              messagingSenderId: config.senderId,
              projectId: config.projectId,
            ),
          );
        } else {
          await Firebase.initializeApp();
        }
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
    } catch (e) {
      AppLogger.w('push: Firebase start failed: $e');
      return false;
    }
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
      FirebaseMessaging.onMessage.map(_fromRemoteMessage);

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(_fromRemoteMessage);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final m = await FirebaseMessaging.instance.getInitialMessage();
    return m != null ? _fromRemoteMessage(m) : null;
  }
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
  StreamSubscription<PushMessage>? _openedApp;

  /// Called for each push that arrives while the app is open; the app shows
  /// it as an in-app banner (with a haptic) and refreshes its lists.
  void Function(PushMessage message)? onForeground;

  /// Called when a push notification is tapped in system tray (background or cold start).
  void Function(PushMessage message)? onNotificationTap;

  PushMessage? _initialMessage;
  PushMessage? get initialMessage => _initialMessage;
  PushMessage? takeInitialMessage() {
    final m = _initialMessage;
    _initialMessage = null;
    return m;
  }

  int? get deviceId => _deviceId;

  /// Checks if the app was launched by tapping a push notification from terminated state.
  Future<void> checkInitialMessage() async {
    try {
      _available ??= await _platform.start();
      if (_available != true) return;
      final initial = await _platform.getInitialMessage();
      if (initial != null) {
        _initialMessage = initial;
        onNotificationTap?.call(initial);
      }
    } catch (e) {
      AppLogger.w('push: checkInitialMessage failed: $e');
    }
  }

  Future<void> register() async {
    try {
      _available ??= await _platform.start();
      if (_available != true) {
        AppLogger.i('push: platform not available');
        return;
      }
      final token = await _platform.token();
      final preview = token != null && token.length > 10
          ? '${token.substring(0, 10)}...'
          : '$token';
      AppLogger.i('push: token=$preview');
      if (token == null || token.isEmpty) return;
      if (token != _token || _deviceId == null) {
        _deviceId = await _registry.register(token);
        _token = token;
        AppLogger.i('push: registered device id=$_deviceId');
      }
      _foreground ??= _platform.onForegroundMessage
          .listen((m) => onForeground?.call(m));
      _openedApp ??= _platform.onMessageOpenedApp
          .listen((m) => onNotificationTap?.call(m));
      await checkInitialMessage();
      _refresh ??= _platform.onTokenRefresh.listen((t) async {
        try {
          _deviceId = await _registry.register(t);
          _token = t;
          AppLogger.i('push: token refreshed, device id=$_deviceId');
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
    await _openedApp?.cancel();
    _openedApp = null;
    _initialMessage = null;
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

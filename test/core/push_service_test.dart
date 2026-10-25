import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/config/app_config.dart';
import 'package:greenroot_mobile/core/config/environment.dart';
import 'package:greenroot_mobile/core/push/push_service.dart';
import 'package:greenroot_mobile/core/utilities/logger.dart';

class FakePlatform implements PushPlatform {
  FakePlatform({this.available = true, this.currentToken = 'tok-1'});
  bool available;
  String? currentToken;
  int starts = 0;
  int deletes = 0;
  final refresh = StreamController<String>.broadcast();

  @override
  Future<bool> start() async {
    starts++;
    return available;
  }

  @override
  Future<String?> token() async => currentToken;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Future<void> deleteToken() async => deletes++;
}

class FakeRegistry implements DeviceRegistry {
  final registered = <String>[];
  final removed = <int>[];
  bool fail = false;

  @override
  Future<int?> register(String token) async {
    if (fail) throw Exception('network down');
    registered.add(token);
    return registered.length;
  }

  @override
  Future<void> unregister(int deviceId) async {
    if (fail) throw Exception('network down');
    removed.add(deviceId);
  }
}

void main() {
  setUpAll(() {
    AppConfig.init(EnvConfig.dev);
    AppLogger.init();
  });

  test('registers once per token, follows token refreshes, cleans up on logout', () async {
    final platform = FakePlatform();
    final registry = FakeRegistry();
    final push = PushService(platform: platform, registry: registry);

    await push.register();
    await push.register(); // bootstrap runs often: no duplicate registration
    expect(registry.registered, ['tok-1']);
    expect(platform.starts, 1);

    platform.refresh.add('tok-2');
    await Future<void>.delayed(Duration.zero);
    expect(registry.registered, ['tok-1', 'tok-2']);

    await push.unregister();
    expect(registry.removed, [2]);
    expect(platform.deletes, 1, reason: 'the next user on this phone gets a fresh token');
    expect(push.deviceId, isNull);

    platform.refresh.add('tok-3'); // no longer listening after logout
    await Future<void>.delayed(Duration.zero);
    expect(registry.registered, ['tok-1', 'tok-2']);
  });

  test('push unavailable (no permission or not configured): nothing is sent', () async {
    final registry = FakeRegistry();
    final push = PushService(platform: FakePlatform(available: false), registry: registry);
    await push.register();
    await push.unregister();
    expect(registry.registered, isEmpty);
    expect(registry.removed, isEmpty);
  });

  test('network failures never throw into sign-in or logout', () async {
    final registry = FakeRegistry()..fail = true;
    final push = PushService(platform: FakePlatform(), registry: registry);
    await push.register();
    await push.unregister();
    expect(push.deviceId, isNull);
  });

  test('build-time config enables push only with every value for the platform', () {
    const none = PushConfig(projectId: '', senderId: '', apiKey: '', androidAppId: '', iosAppId: '');
    const android = PushConfig(projectId: 'p', senderId: '1', apiKey: 'k', androidAppId: '1:1:android:a', iosAppId: '');
    expect(none.enabledFor(TargetPlatform.android), isFalse);
    expect(android.enabledFor(TargetPlatform.android), isTrue);
    expect(android.enabledFor(TargetPlatform.iOS), isFalse);
    expect(PushConfig.fromEnvironment().enabledFor(TargetPlatform.android), isFalse,
        reason: 'tests build without FCM_* defines',);
  });
}

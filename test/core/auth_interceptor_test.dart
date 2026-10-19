import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/config/app_config.dart';
import 'package:greenroot_mobile/core/config/environment.dart';
import 'package:greenroot_mobile/core/constants/api_constants.dart';
import 'package:greenroot_mobile/core/network/auth_interceptor.dart';
import 'package:greenroot_mobile/core/storage/secure_storage_service.dart';
import 'package:greenroot_mobile/core/utilities/logger.dart';

/// Fake server: protected calls need "Bearer new"; the refresh token rotates,
/// so a second refresh with "r1" is refused — exactly like the real API.
class _FakeServer implements HttpClientAdapter {
  int refreshCalls = 0;
  bool refuseRefresh = false;
  bool suspendOnRefresh = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path == ApiConstants.refreshToken) {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      if (suspendOnRefresh) {
        return _json(403, {
          'error': {
            'code': 'USER_SUSPENDED',
            'reason': 'KYC documents expired',
            'suspended_at': '2026-10-19T09:00:00Z',
          },
        });
      }
      if (refuseRefresh || refreshCalls > 1) return _json(401, {'error': {'code': 'invalid_refresh_token'}});
      return _json(200, {'access_token': 'new', 'refresh_token': 'r2'});
    }
    final ok = options.headers['Authorization'] == 'Bearer new';
    return ok ? _json(200, {'ok': true}) : _json(401, {'error': {'code': 'invalid_token'}});
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late _FakeServer server;
  late AuthInterceptor interceptor;

  setUpAll(() {
    AppConfig.init(EnvConfig.dev);
    AppLogger.init();
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await SecureStorageService.saveAccessToken('expired');
    await SecureStorageService.saveRefreshToken('r1');
    server = _FakeServer();
    dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = server;
    interceptor = AuthInterceptor(dio);
    dio.interceptors.add(interceptor);
  });

  test('parallel 401s share one refresh and all succeed', () async {
    final results = await Future.wait([
      dio.get<dynamic>('/api/v1/orders'),
      dio.get<dynamic>('/api/v1/quotations'),
      dio.get<dynamic>('/api/v1/me/workspaces'),
    ]);
    expect(results.map((r) => r.statusCode), everyElement(200));
    expect(server.refreshCalls, 1, reason: 'a second refresh with the rotated token would be refused');
    expect(await SecureStorageService.getRefreshToken(), 'r2');
  });

  test('a refused refresh clears the session and signals the app', () async {
    server.refuseRefresh = true;
    var expired = 0;
    interceptor.onSessionExpired = () => expired++;
    await expectLater(dio.get<dynamic>('/api/v1/orders'), throwsA(isA<DioException>()));
    expect(expired, 1);
    expect(await SecureStorageService.getAccessToken(), isNull);
  });

  test('a suspended refresh preserves its reason and signals suspension', () async {
    server.suspendOnRefresh = true;
    String? capturedReason;
    DateTime? capturedSuspendedAt;
    var expired = 0;
    interceptor.onAccountSuspended = ({String? reason, DateTime? suspendedAt}) {
      capturedReason = reason;
      capturedSuspendedAt = suspendedAt;
    };
    interceptor.onSessionExpired = () => expired++;

    await expectLater(
      dio.get<dynamic>('/api/v1/orders'),
      throwsA(isA<DioException>()),
    );

    expect(capturedReason, 'KYC documents expired');
    expect(capturedSuspendedAt, DateTime.utc(2026, 10, 19, 9).toLocal());
    expect(expired, 0);
    expect(await SecureStorageService.getAccessToken(), isNull);
  });
}

import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import '../utilities/logger.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;

  // Set by SessionNotifier after ApiClient.init() so the interceptor can trigger
  // an immediate logout when the server tells us the user's membership was revoked.
  void Function()? onMembershipRevoked;

  AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorageService.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;

    // 403 with not_member means the server revoked the user's membership between
    // JWT issuance and this request. Clear local storage and signal the session
    // notifier so the router redirects to login without waiting for the JWT to expire.
    if (statusCode == 403) {
      final body = err.response?.data;
      final code = (body is Map) ? (body['error']?['code'] as String?) : null;
      if (code == 'not_member') {
        AppLogger.w('403 not_member — membership revoked mid-session, clearing storage');
        await SecureStorageService.clearSession();
        onMembershipRevoked?.call();
      }
      return handler.next(err);
    }

    if (statusCode != 401) {
      return handler.next(err);
    }

    // Skip refresh for auth endpoints to avoid loops
    if (err.requestOptions.path.contains('/auth/')) {
      return handler.next(err);
    }

    AppLogger.w('401 detected — attempting token refresh');

    try {
      final refreshToken = await SecureStorageService.getRefreshToken();
      if (refreshToken == null) {
        await _handleLogout(handler, err);
        return;
      }

      // Refresh using a separate Dio to avoid interceptor loop
      final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      final response = await refreshDio.post(
        ApiConstants.refreshToken,
        data: {'refresh_token': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      final newAccess  = data['access_token']  as String;
      final newRefresh = data['refresh_token'] as String;

      await SecureStorageService.saveAccessToken(newAccess);
      await SecureStorageService.saveRefreshToken(newRefresh);

      AppLogger.i('Token refreshed — retrying original request');

      // Retry with new token
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccess';

      final retryResponse = await _dio.fetch(retryOptions);
      return handler.resolve(retryResponse);
    } catch (e) {
      AppLogger.e('Token refresh failed', e);
      await _handleLogout(handler, err);
    }
  }

  Future<void> _handleLogout(ErrorInterceptorHandler handler, DioException err) async {
    await SecureStorageService.clearSession();
    AppLogger.w('Session cleared — navigating to login');
    handler.next(err);
  }
}

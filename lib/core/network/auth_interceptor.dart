import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import '../utilities/logger.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;

  void Function()? onMembershipRevoked;
  void Function({String? reason, DateTime? suspendedAt})? onAccountSuspended;

  /// Called when the refresh token is gone or refused: the user must sign in again.
  void Function()? onSessionExpired;

  // Refresh tokens rotate: a second refresh with the same token is refused.
  // Every request that hits 401 at the same moment waits on this one refresh.
  Future<String>? _refreshing;

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
      final errorObj = (body is Map) ? body['error'] : null;
      final code = (errorObj is Map) ? (errorObj['code'] as String?) : null;
      if (code == 'not_member') {
        AppLogger.w('403 not_member — membership revoked mid-session, clearing storage');
        await SecureStorageService.clearSession();
        onMembershipRevoked?.call();
      } else if (code == 'USER_SUSPENDED' || code == 'NURSERY_SUSPENDED' ||
          code == 'account_suspended' || code == 'nursery_suspended') {
        AppLogger.w('403 $code — account suspended mid-session');
        String? reason;
        DateTime? suspendedAt;
        if (errorObj is Map) {
          reason = errorObj['reason'] as String?;
          final rawDate = errorObj['suspended_at'];
          if (rawDate != null) {
            suspendedAt = DateTime.tryParse(rawDate.toString())?.toLocal();
          }
        }
        onAccountSuspended?.call(reason: reason, suspendedAt: suspendedAt);
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
      // Another request may already have refreshed while this one was in flight.
      final sentWith = (err.requestOptions.headers['Authorization'] as String?)?.replaceFirst('Bearer ', '');
      final current = await SecureStorageService.getAccessToken();
      final newAccess = current != null && current != sentWith ? current : await (_refreshing ??= _refresh());

      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _dio.fetch(retryOptions);
      return handler.resolve(retryResponse);
    } on DioException catch (e) {
      // The retry itself failed (not the refresh): pass that error on.
      if (e.requestOptions.path != ApiConstants.refreshToken) return handler.next(e);
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final errorObj = body is Map ? body['error'] : null;
      final code = errorObj is Map ? errorObj['code'] as String? : null;

      // Keep the refresh response: it can contain the suspension details,
      // while the original request only has a generic 401.
      if (status == 403 &&
          (code == 'USER_SUSPENDED' ||
              code == 'NURSERY_SUSPENDED' ||
              code == 'account_suspended' ||
              code == 'nursery_suspended')) {
        String? reason;
        DateTime? suspendedAt;
        if (errorObj is Map) {
          reason = errorObj['reason'] as String?;
          final rawDate = errorObj['suspended_at'];
          if (rawDate != null) {
            suspendedAt = DateTime.tryParse(rawDate.toString())?.toLocal();
          }
        }
        await SecureStorageService.clearSession();
        onAccountSuspended?.call(reason: reason, suspendedAt: suspendedAt);
        return handler.next(e);
      }

      // A connection failure says nothing about whether the refresh token is
      // still valid. Surface it so startup can offer Retry and keep the session.
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          (status != null && status >= 500)) {
        return handler.next(e);
      }
      AppLogger.e('Token refresh failed', e);
      await _handleLogout(handler, err);
    } catch (e) {
      AppLogger.e('Token refresh failed', e);
      await _handleLogout(handler, err);
    }
  }

  /// Exchanges the refresh token once and stores the new pair.
  Future<String> _refresh() async {
    try {
      final refreshToken = await SecureStorageService.getRefreshToken();
      if (refreshToken == null) throw StateError('no refresh token');
      // A separate Dio avoids running this interceptor on the refresh call.
      final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl))..httpClientAdapter = _dio.httpClientAdapter;
      final response = await refreshDio.post(ApiConstants.refreshToken, data: {'refresh_token': refreshToken});
      final data = response.data as Map<String, dynamic>;
      final newAccess = data['access_token'] as String;
      await SecureStorageService.saveAccessToken(newAccess);
      await SecureStorageService.saveRefreshToken(data['refresh_token'] as String);
      AppLogger.i('Token refreshed — retrying waiting requests');
      return newAccess;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _handleLogout(ErrorInterceptorHandler handler, DioException err) async {
    await SecureStorageService.clearSession();
    AppLogger.w('Session cleared — navigating to login');
    onSessionExpired?.call();
    handler.next(err);
  }
}

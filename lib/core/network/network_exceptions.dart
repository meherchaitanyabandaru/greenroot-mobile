import 'package:dio/dio.dart';
import '../errors/app_error.dart';
import '../utilities/logger.dart';

class NetworkExceptions {
  static AppError fromDioException(DioException e) {
    AppLogger.e('DioException [${e.type}]', e, e.stackTrace);

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutError();

      case DioExceptionType.connectionError:
        return const NetworkError();

      case DioExceptionType.badResponse:
        return _fromResponse(e.response);

      case DioExceptionType.cancel:
        return const UnknownError('Request was cancelled.');

      default:
        return const UnknownError();
    }
  }

  static AppError _fromResponse(Response? response) {
    if (response == null) return const UnknownError();

    final statusCode = response.statusCode ?? 0;
    final message = _extractMessage(response.data);

    switch (statusCode) {
      case 400:
        return ValidationError(message ?? 'Invalid request.');
      case 401:
        return const UnauthorizedError();
      case 403:
        final code = _extractCode(response.data);
        if (code == 'USER_SUSPENDED' || code == 'NURSERY_SUSPENDED' ||
            code == 'account_suspended' || code == 'nursery_suspended') {
          final errorObj = _extractErrorObj(response.data);
          String? reason;
          DateTime? suspendedAt;
          if (errorObj != null) {
            reason = errorObj['reason'] as String?;
            final rawDate = errorObj['suspended_at'];
            if (rawDate != null) {
              suspendedAt = DateTime.tryParse(rawDate.toString())?.toLocal();
            }
          }
          return AccountSuspendedError(reason: reason, suspendedAt: suspendedAt);
        }
        if (code == 'wrong_target') return const WrongTargetInviteError();
        return ForbiddenError(message ?? 'You do not have permission to perform this action.');
      case 404:
        return NotFoundError(message ?? 'Not found.');
      case 422:
        return ValidationError(
          message ?? 'Validation failed.',
          fieldErrors: _extractFieldErrors(response.data),
        );
      case >= 500:
        return ServerError(statusCode, message ?? 'Server error occurred.');
      default:
        return ServerError(statusCode, message ?? 'An error occurred.');
    }
  }

  static String? _extractCode(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      return error['code'] as String?;
    }
    return null;
  }

  static Map<String, dynamic>? _extractErrorObj(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final error = data['error'];
    return error is Map<String, dynamic> ? error : null;
  }

  static String? _extractMessage(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    // Top-level message field
    final top = data['message'] as String? ?? data['msg'] as String?;
    if (top != null) return top;
    // Nested {"error": {"message": "..."}} — format used by the Go API
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      return error['message'] as String? ?? error['msg'] as String?;
    }
    if (error is String) return error;
    return null;
  }

  static Map<String, String>? _extractFieldErrors(dynamic data) {
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map<String, dynamic>) {
        return errors.map((k, v) => MapEntry(k, v.toString()));
      }
    }
    return null;
  }
}

// ignore_for_file: invalid_use_of_protected_member

import 'package:dio/dio.dart';
import 'package:greenroot_mobile/core/config/app_config.dart';
import 'package:greenroot_mobile/core/config/environment.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/core/utilities/logger.dart';

/// The type of fake response to enqueue for a given call.
enum FakeResponseType {
  /// HTTP 200 with [responseData].
  success,

  /// HTTP 422 — maps to [ValidationError].
  validationError,

  /// HTTP 401 — maps to [UnauthorizedError].
  unauthorized,

  /// HTTP 403 — maps to [ForbiddenError].
  forbidden,

  /// HTTP 500 — maps to [ServerError].
  serverError,

  /// [DioExceptionType.connectionError] — maps to [NetworkError].
  networkError,

  /// HTTP 404 — maps to [NotFoundError].
  notFound,
}

class _QueuedResponse {
  final dynamic responseData;
  final FakeResponseType type;
  const _QueuedResponse({required this.type, this.responseData});
}

/// Captured call record — usable in test assertions.
class FakeCall {
  final String method;
  final String path;
  final FakeResponseType type;
  const FakeCall({required this.method, required this.path, required this.type});

  @override
  String toString() => '$method $path [$type]';
}

/// A thin wrapper around [ApiClient] that intercepts all HTTP via a Dio
/// [Interceptor]. No real HTTP calls are ever made.
///
/// Enqueue responses before each operation:
/// ```dart
/// fake.enqueue(response: {'orders': [], 'pagination': {'page':1,'per_page':20,'total':0,'total_pages':1}});
/// fake.enqueue(type: FakeResponseType.serverError);
/// ```
class FakeApiClient {
  late final ApiClient apiClient;
  late final _FakeInterceptor _interceptor;
  final List<FakeCall> calls = [];

  FakeApiClient() {
    _ensureInit();
    _interceptor = _FakeInterceptor(calls);
    // Overwrite the interceptors on the singleton's Dio so no network is hit.
    ApiClient.instance.dio.interceptors.clear();
    ApiClient.instance.dio.interceptors.add(_interceptor);
    apiClient = ApiClient.instance;
  }

  static void _ensureInit() {
    try {
      AppConfig.init(EnvConfig.dev);
      AppLogger.init();
      ApiClient.init();
    } catch (_) {
      // Already initialised — ignore.
    }
  }

  /// Queue a successful response with [response] as the decoded data.
  void enqueue({dynamic response, FakeResponseType type = FakeResponseType.success}) {
    _interceptor.queue.add(_QueuedResponse(type: type, responseData: response));
  }

  /// Replace queue with a single success response.
  void setResponse(dynamic response) {
    _interceptor.queue
      ..clear()
      ..add(_QueuedResponse(type: FakeResponseType.success, responseData: response));
  }

  /// Replace queue with a single error response.
  void setError(FakeResponseType type) {
    _interceptor.queue
      ..clear()
      ..add(_QueuedResponse(type: type));
  }

  /// Clear all queued responses and captured calls.
  void reset() {
    _interceptor.queue.clear();
    calls.clear();
  }
}

class _FakeInterceptor extends Interceptor {
  final List<FakeCall> _calls;
  final List<_QueuedResponse> queue = [];

  _FakeInterceptor(this._calls);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final queued = queue.isNotEmpty
        ? queue.removeAt(0)
        : const _QueuedResponse(type: FakeResponseType.success);

    _calls.add(FakeCall(method: options.method, path: options.path, type: queued.type));

    if (queued.type == FakeResponseType.networkError) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Simulated network error',
        ),
        true,
      );
      return;
    }

    if (queued.type != FakeResponseType.success) {
      final statusCode = _statusFor(queued.type);
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: statusCode,
            data: {'error': {'message': 'Simulated ${queued.type.name}'}},
          ),
          message: 'Simulated ${queued.type.name}',
        ),
        true,
      );
      return;
    }

    handler.resolve(
      Response(
        requestOptions: options,
        statusCode: 200,
        data: queued.responseData,
      ),
      true,
    );
  }

  int _statusFor(FakeResponseType type) => switch (type) {
        FakeResponseType.validationError => 422,
        FakeResponseType.unauthorized => 401,
        FakeResponseType.forbidden => 403,
        FakeResponseType.serverError => 500,
        FakeResponseType.notFound => 404,
        _ => 500,
      };
}

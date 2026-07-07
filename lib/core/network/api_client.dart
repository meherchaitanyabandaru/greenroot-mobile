import 'dart:io';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../errors/app_error.dart';
import '../utilities/logger.dart';
import 'auth_interceptor.dart';
import 'network_exceptions.dart';

class ApiClient {
  static late Dio _dio;
  static late ApiClient _instance;

  final Dio dio;

  ApiClient._(this.dio);

  static ApiClient get instance => _instance;

  static void init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeoutMs),
        sendTimeout: const Duration(milliseconds: AppConstants.sendTimeoutMs),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Interceptors (order matters)
    _dio.interceptors.addAll([
      AuthInterceptor(_dio),
      if (AppConfig.enableLogging) _LoggingInterceptor(),
    ]);

    _instance = ApiClient._(_dio);
  }

  // ── Typed request wrappers ───────────────────────────────────────────────
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await dio.get(path, queryParameters: queryParameters);
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on DioException catch (e) {
      throw NetworkExceptions.fromDioException(e);
    } catch (e) {
      AppLogger.e('Unexpected error on GET $path', e);
      throw const UnknownError();
    }
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await dio.post(path, data: data);
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on DioException catch (e) {
      throw NetworkExceptions.fromDioException(e);
    } catch (e) {
      AppLogger.e('Unexpected error on POST $path', e);
      throw const UnknownError();
    }
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await dio.put(path, data: data);
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on DioException catch (e) {
      throw NetworkExceptions.fromDioException(e);
    } catch (e) {
      AppLogger.e('Unexpected error on PUT $path', e);
      throw const UnknownError();
    }
  }

  Future<T> delete<T>(
    String path, {
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await dio.delete(path);
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on DioException catch (e) {
      throw NetworkExceptions.fromDioException(e);
    } catch (e) {
      AppLogger.e('Unexpected error on DELETE $path', e);
      throw const UnknownError();
    }
  }

  Future<T> patch<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await dio.patch(path, data: data);
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on DioException catch (e) {
      throw NetworkExceptions.fromDioException(e);
    } catch (e) {
      AppLogger.e('Unexpected error on PATCH $path', e);
      throw const UnknownError();
    }
  }

  Future<dynamic> uploadFile(
    String path, {
    required File file,
    Map<String, String> extraFields = const {},
  }) async {
    try {
      final formData = FormData.fromMap({
        ...extraFields,
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });
      final response = await dio.post(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data;
    } on DioException catch (e) {
      throw NetworkExceptions.fromDioException(e);
    } catch (e) {
      AppLogger.e('Unexpected error on file upload $path', e);
      throw const UnknownError();
    }
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.api(options.method, options.path);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    AppLogger.api(
      response.requestOptions.method,
      response.requestOptions.path,
      status: response.statusCode,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.api(
      err.requestOptions.method,
      err.requestOptions.path,
      status: err.response?.statusCode,
      body: err.message,
    );
    handler.next(err);
  }
}

import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../network/api_client.dart';

class PresignResult {
  final String uploadUrl;
  final String fileUrl;
  const PresignResult({required this.uploadUrl, required this.fileUrl});
}

class StorageService {
  final ApiClient _api;

  // Raw Dio — no auth interceptors, used only for presigned PUT to MinIO/S3.
  static final _rawDio = Dio(
    BaseOptions(validateStatus: (s) => s != null && s < 400),
  );

  StorageService(this._api);

  Future<PresignResult> presign(
    String bucket,
    String fileName,
    String contentType,
  ) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/api/v1/storage/presign',
      data: {
        'bucket': bucket,
        'file_name': fileName,
        'content_type': contentType,
      },
    );
    return PresignResult(
      uploadUrl: data['upload_url'] as String,
      fileUrl: data['file_url'] as String,
    );
  }

  /// PUT bytes directly to the presigned URL.
  /// MinIO/S3 presigned PUTs must NOT include extra headers.
  Future<void> uploadBytes(
    String uploadUrl,
    Uint8List bytes,
    String contentType,
  ) async {
    await _rawDio.put<void>(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': bytes.length,
        },
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
  }
}

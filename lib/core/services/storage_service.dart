import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../../features/auth/data/models/user_models.dart';

class StorageService {
  final ApiClient _api;

  StorageService(this._api);

  /// POST /api/v1/users/me/avatar — multipart upload.
  /// Uploads the image bytes to the API, which puts them in MinIO and
  /// updates profile_image_url in one step. Returns the updated UserProfile.
  Future<UserProfile> uploadAvatar(
    Uint8List bytes,
    String fileName,
    String contentType,
  ) async {
    final formData = FormData.fromMap({
      'avatar': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: DioMediaType.parse(contentType),
      ),
    });

    final data = await _api.post<Map<String, dynamic>>(
      '/api/v1/users/me/avatar',
      data: formData,
    );
    return UserProfile.fromJson(data);
  }

  /// Uploads a nursery logo to MinIO via presigned URL.
  /// Returns the permanent file_url to persist on the nursery.
  Future<String> uploadNurseryLogo(
    Uint8List bytes,
    String fileName,
    String contentType,
  ) async {
    // 1. Get presigned upload URL from API
    final presignData = await _api.post<Map<String, dynamic>>(
      ApiConstants.storagePresign,
      data: {
        'bucket': 'nursery-logos',
        'file_name': fileName,
        'content_type': contentType,
      },
    );
    final uploadUrl = presignData['upload_url'] as String;
    final fileUrl = presignData['file_url'] as String;

    // 2. PUT bytes directly to MinIO (no auth header needed on presigned URL)
    final rawDio = Dio();
    await rawDio.put(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': bytes.length,
        },
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    return fileUrl;
  }
}

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(ref.watch(apiClientProvider)),
);

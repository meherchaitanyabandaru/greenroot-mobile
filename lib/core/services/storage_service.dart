import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(ref.watch(apiClientProvider)),
);

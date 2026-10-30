import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../errors/app_error.dart';
import '../media/image_policy.dart';
import '../media/photos.dart';
import '../../features/auth/data/models/user_models.dart';

class StorageService {
  final ApiClient _api;
  final void Function()? _onRefused;

  StorageService(this._api, [this._onRefused]);

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

  /// DELETE /api/v1/users/me/avatar — removes the photo and its stored file.
  Future<UserProfile> deleteAvatar() async {
    final data =
        await _api.delete<Map<String, dynamic>>('/api/v1/users/me/avatar');
    return UserProfile.fromJson(data);
  }

  /// POST /api/v1/storage/images: the API checks [photo] against
  /// [category]'s image policy and stores it; returns the file_url to save on
  /// the record. A refusal is a [ValidationError] with what to do, and makes
  /// the app reload the policies (an admin may have changed them).
  Future<String> uploadImage(
    ImageCategory category,
    PreparedPhoto photo,
    String fileName,
  ) async {
    final formData = FormData.fromMap({
      'category': category.code, // before the file: its policy limits the read
      'file': MultipartFile.fromBytes(
        photo.bytes,
        filename: fileName,
        contentType: DioMediaType.parse(photo.mimeType),
      ),
    });
    try {
      final data = await _api.post<Map<String, dynamic>>(
        ApiConstants.storageImages,
        data: formData,
      );
      return data['file_url'] as String;
    } on ValidationError {
      _onRefused?.call();
      rethrow;
    }
  }
}

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(
    ref.watch(apiClientProvider),
    () => ref.invalidate(imagePoliciesProvider),
  ),
);

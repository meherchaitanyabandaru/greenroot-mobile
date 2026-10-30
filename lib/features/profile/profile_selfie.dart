import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/app_error.dart';
import '../../core/media/image_policy.dart';
import '../../core/media/photos.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../auth/presentation/providers/session_provider.dart';

/// Why we ask for the photo, shown wherever we ask for it.
const selfiePrivacyNote =
    'Other nurseries see this photo on your market ads and chats, so they '
    'know who they are dealing with. $selfieHandlingNote';

/// For people without the market (customers, drivers): only how it is handled.
const selfieHandlingNote = 'It is taken with the camera, never used for face '
    'recognition, and you can retake or delete it any time.';

/// Takes the profile photo with the front camera (never the gallery: it is
/// the face other nurseries see on your ads) and uploads it. True on success.
Future<bool> takeProfileSelfie(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  void fail(String message) => messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.red600),
      );
  final policy = await ref.read(imagePolicyProvider(ImageCategory.selfie).future);
  if (!context.mounted) return false;
  final shot = await pickPhoto(
    context,
    ImageSource.camera,
    camera: CameraDevice.front,
    policy: policy,
  );
  if (shot == null) return false;
  try {
    final photo = await preparePhoto(shot, policy);
    final updated = await ref.read(storageServiceProvider).uploadAvatar(
          photo.bytes,
          'selfie-${DateTime.now().millisecondsSinceEpoch}${photo.extension}',
          photo.mimeType,
        );
    ref.read(sessionProvider.notifier).updateUser(updated);
    return true;
  } on AppError catch (e) {
    fail(e.message);
  } catch (_) {
    fail('Upload failed. Please try again.');
  }
  return false;
}

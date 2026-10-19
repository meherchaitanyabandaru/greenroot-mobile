import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/app_error.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';

/// Why we ask for the photo, shown wherever we ask for it.
const selfiePrivacyNote =
    'Other nurseries see this photo on your ads and chats, so they know who '
    'they are dealing with. Only a live camera photo is accepted. It is never '
    'used for face recognition, and you can retake or delete it any time in '
    'Edit Profile.';

/// Takes the profile photo with the front camera (never the gallery: it is
/// the face other nurseries see on your ads) and uploads it. True on success.
Future<bool> takeProfileSelfie(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  void fail(String message) => messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.red600),
      );
  XFile? shot;
  try {
    shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
  } catch (_) {
    fail('Could not open the camera.');
    return false;
  }
  if (shot == null) return false;
  try {
    final bytes = await shot.readAsBytes();
    final updated = await ref.read(storageServiceProvider).uploadAvatar(
          bytes,
          'selfie-${DateTime.now().millisecondsSinceEpoch}.jpg',
          'image/jpeg',
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

/// The market gate: posting an ad or starting a chat needs a profile selfie.
/// Explains why, takes one, and returns whether the user can go on.
Future<bool> ensureMarketSelfie(BuildContext context, WidgetRef ref) async {
  final url = ref.read(sessionProvider).user?.profileImageUrl;
  if (url != null && url.isNotEmpty) return true;
  final go = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.face_retouching_natural,
                size: 40, color: AppColors.primaryMain,),
            const SizedBox(height: 12),
            const Text('Add a selfie to sell and chat', style: AppTypography.h3),
            const SizedBox(height: 8),
            Text(selfiePrivacyNote,
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary),),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Take selfie'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (go != true || !context.mounted) return false;
  return takeProfileSelfie(context, ref);
}

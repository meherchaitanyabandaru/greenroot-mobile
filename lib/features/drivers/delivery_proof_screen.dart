import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/constants/api_constants.dart';

/// Driver-only: capture and upload delivery proof photos.
/// Requires at least 1 photo. Uploaded via POST /api/v1/attachments.
class DeliveryProofScreen extends ConsumerStatefulWidget {
  final int dispatchId;
  const DeliveryProofScreen({super.key, required this.dispatchId});

  @override
  ConsumerState<DeliveryProofScreen> createState() =>
      _DeliveryProofScreenState();
}

class _DeliveryProofScreenState extends ConsumerState<DeliveryProofScreen> {
  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  bool _uploading = false;
  String? _uploadError;
  int _uploadedCount = 0;

  Future<void> _pickImage(ImageSource source) async {
    if (_photos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 photos allowed')),
      );
      return;
    }
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (file != null && mounted) {
      setState(() => _photos.add(file));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _upload() async {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one proof photo'),
          backgroundColor: AppColors.red600,
        ),
      );
      return;
    }

    setState(() {
      _uploading = true;
      _uploadError = null;
      _uploadedCount = 0;
    });

    try {
      final client = ApiClient.instance;
      for (int i = 0; i < _photos.length; i++) {
        await client.uploadXFile(
          ApiConstants.attachments,
          file: _photos[i],
          extraFields: {
            'entity_type': 'dispatch',
            'entity_id': widget.dispatchId.toString(),
            'attachment_type': 'delivery_proof',
          },
        );
        if (mounted) setState(() => _uploadedCount = i + 1);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_photos.length} proof photo${_photos.length > 1 ? 's' : ''} uploaded successfully'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on AppError catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadError = 'Upload failed. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Delivery Proof'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                // Instructions
                Container(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: AppRadius.cardRadius,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.primaryMain, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Take clear photos of the delivered items at the drop-off location. At least 1 photo is required.',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.primaryMain),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x2l),

                // Photo grid
                if (_photos.isNotEmpty) ...[
                  Text(
                    'Photos (${_photos.length}/5)',
                    style: AppTypography.h4,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1,
                    ),
                    itemCount: _photos.length,
                    itemBuilder: (_, i) => _PhotoThumbnail(
                      file: _photos[i],
                      onRemove: _uploading ? null : () => _removePhoto(i),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Upload progress
                if (_uploading) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Uploading $_uploadedCount / ${_photos.length}…',
                    style: AppTypography.label,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LinearProgressIndicator(
                    value: _photos.isNotEmpty
                        ? _uploadedCount / _photos.length
                        : null,
                    color: AppColors.primaryMain,
                    backgroundColor: AppColors.border,
                    borderRadius: AppRadius.inputRadius,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Error
                if (_uploadError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    decoration: BoxDecoration(
                      color: AppColors.red600.withValues(alpha: 0.08),
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(
                          color: AppColors.red600.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.red600),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _uploadError!,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.red600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Add photo buttons
                if (_photos.length < 5 && !_uploading) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _PickButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Take Photo',
                          onTap: () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _PickButton(
                          icon: Icons.photo_library_outlined,
                          label: 'From Gallery',
                          onTap: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Bottom action
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.md,
              AppSpacing.screenPadding,
              MediaQuery.of(context).padding.bottom + AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: FilledButton.icon(
                onPressed: (_photos.isEmpty || _uploading) ? null : _upload,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryMain),
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _uploading
                      ? 'Uploading…'
                      : 'Upload Proof (${_photos.length})',
                  style: AppTypography.label,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final XFile file;
  final VoidCallback? onRemove;

  const _PhotoThumbnail({required this.file, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: AppRadius.cardRadius,
          child: FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _BrokenPhoto(),
                );
              }
              if (snapshot.hasError) return const _BrokenPhoto();
              return Container(
                color: AppColors.border,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }
}

class _BrokenPhoto extends StatelessWidget {
  const _BrokenPhoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.border,
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2l),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryMain, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(label,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

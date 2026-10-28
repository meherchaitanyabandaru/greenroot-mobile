import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/media/photos.dart';
import '../../core/network/api_client.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'orders.dart';

const maxLoadingPhotos = 3;

/// What the seller declares when loading is done. The API refuses
/// complete-loading without it and keeps it in the audit log.
const loadingDeclaration =
    'I confirm this vehicle carries only the items of this order — no drugs, '
    'alcohol, weapons or any illegal or unauthorised goods. I take '
    'responsibility for what was loaded.';

/// Completes loading: up to [maxLoadingPhotos] optional photos of the loaded
/// vehicle, then the declaration. Returns the updated order, or null when
/// the seller backs out.
Future<Order?> showLoadingDoneSheet(BuildContext context, Order order) {
  return showModalBottomSheet<Order>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LoadingDoneSheet(order: order),
  );
}

class _LoadingDoneSheet extends ConsumerStatefulWidget {
  final Order order;
  const _LoadingDoneSheet({required this.order});

  @override
  ConsumerState<_LoadingDoneSheet> createState() => _LoadingDoneSheetState();
}

class _LoadingDoneSheetState extends ConsumerState<_LoadingDoneSheet> {
  final List<PreparedPhoto> _photos = [];
  int _uploaded = 0; // photos already attached; a retry doesn't send them again
  bool _busy = false;
  String? _error;

  Future<void> _add(ImageSource source) async {
    final file = await pickPhoto(context, source);
    if (file == null || !mounted) return;
    try {
      final photo = await preparePhoto(file);
      if (mounted) setState(() => _photos.add(photo));
    } on PhotoRejected catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final storage = ref.read(storageServiceProvider);
      for (; _uploaded < _photos.length; _uploaded++) {
        final p = _photos[_uploaded];
        final name =
            'loading-${widget.order.orderCode}-${_uploaded + 1}${p.extension}';
        final url = await storage.uploadPresigned(
          'delivery-photos',
          p.bytes,
          name,
          p.mimeType,
        );
        await ApiClient.instance.post<Map<String, dynamic>>(
          ApiConstants.attachments,
          data: {
            'entity_type': 'ORDER_LOADING',
            'entity_id': widget.order.id,
            'file_name': name,
            'file_url': url,
            'file_type': p.mimeType,
            'file_size': p.bytes.length,
          },
        );
      }
      final updated = await ref
          .read(orderRepositoryProvider)
          .completeLoading(widget.order.id, declaredNoProhibitedItems: true);
      if (mounted) Navigator.of(context).pop(updated);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Upload failed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = !_busy && _photos.length < maxLoadingPhotos;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Loading done', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Order ${widget.order.orderCode}',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('Photos of the loaded vehicle', style: AppTypography.h4),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Optional · up to $maxLoadingPhotos · ${_photos.length}/$maxLoadingPhotos added',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (var i = 0; i < maxLoadingPhotos; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: i < _photos.length
                          ? _Thumb(
                              photo: _photos[i],
                              // Attached photos stay; they're already on the order.
                              onRemove: _busy || i < _uploaded
                                  ? null
                                  : () => setState(() => _photos.removeAt(i)),
                            )
                          : _EmptySlot(
                              onCamera: canAdd
                                  ? () => _add(ImageSource.camera)
                                  : null,
                              onGallery: canAdd
                                  ? () => _add(ImageSource.gallery)
                                  : null,
                            ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Material(
              color: AppColors.amber50,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.cardRadius,
                side: BorderSide(color: AppColors.amber100),
              ),
              clipBehavior: Clip.antiAlias,
              // Tapping "I confirm" below is the declaration (one tap, not tick + button).
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  loadingDeclaration,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textPrimary, height: 1.45),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style:
                    AppTypography.bodySmall.copyWith(color: AppColors.red600),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                _busy && _uploaded < _photos.length
                    ? 'Uploading photo ${_uploaded + 1} of ${_photos.length}…'
                    : 'I confirm · Complete Loading',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final PreparedPhoto photo;
  final VoidCallback? onRemove;
  const _Thumb({required this.photo, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: AppRadius.cardRadius,
          child: Image.memory(
            photo.bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.border,
              child: const Icon(
                Icons.image_outlined,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: Semantics(
              button: true,
              label: 'Remove photo',
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final VoidCallback? onCamera;
  final VoidCallback? onGallery;
  const _EmptySlot({this.onCamera, this.onGallery});

  @override
  Widget build(BuildContext context) {
    final color =
        onCamera == null ? AppColors.textMuted : AppColors.primaryMain;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: 'Take photo',
            child: IconButton(
              onPressed: onCamera,
              icon: Icon(Icons.photo_camera_outlined, color: color),
            ),
          ),
          Semantics(
            label: 'Choose from gallery',
            child: IconButton(
              onPressed: onGallery,
              icon: Icon(Icons.photo_library_outlined, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

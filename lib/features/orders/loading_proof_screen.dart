import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/error_state.dart';
import 'loading_done_sheet.dart' show loadingDeclaration;
import 'orders.dart' show Order;

class LoadingProof {
  final List<({int id, String url})> photos;
  final bool declared;
  final DateTime? completedAt;
  final String? completedByName;
  final LoadingTruck? truck;

  const LoadingProof({
    required this.photos,
    required this.declared,
    this.completedAt,
    this.completedByName,
    this.truck,
  });

  factory LoadingProof.fromJson(Map<String, dynamic> j) => LoadingProof(
        photos: [
          for (final p in (j['photos'] as List? ?? const []))
            (id: (p as Map)['id'] as int, url: p['url'] as String),
        ],
        declared: j['declared_no_prohibited_items'] == true,
        completedAt: DateTime.tryParse(j['completed_at'] as String? ?? '')
            ?.toLocal(),
        completedByName: j['completed_by_name'] as String?,
        truck: j['truck'] is Map<String, dynamic>
            ? LoadingTruck.fromJson(j['truck'] as Map<String, dynamic>)
            : null,
      );
}

class LoadingTruck {
  final String? vehicleNumber;
  final String? vehicleType;
  final String? driverName;
  final String? driverMobile;
  final bool outsideTransport;

  const LoadingTruck({
    this.vehicleNumber,
    this.vehicleType,
    this.driverName,
    this.driverMobile,
    this.outsideTransport = false,
  });

  factory LoadingTruck.fromJson(Map<String, dynamic> j) => LoadingTruck(
        vehicleNumber: j['vehicle_number'] as String?,
        vehicleType: j['vehicle_type'] as String?,
        driverName: j['driver_name'] as String?,
        driverMobile: j['driver_mobile'] as String?,
        outsideTransport: j['outside_transport'] == true,
      );
}

/// Photo links are signed for an hour, so this is fetched fresh each time.
final loadingProofProvider =
    FutureProvider.autoDispose.family<LoadingProof, int>((ref, orderId) {
  return ApiClient.instance.get(
    ApiConstants.orderLoadingProof(orderId),
    fromJson: (d) => LoadingProof.fromJson(
      (d as Map<String, dynamic>)['loading_proof'] as Map<String, dynamic>,
    ),
  );
});

void openLoadingProof(BuildContext context, int orderId, String orderCode) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LoadingProofScreen(orderId: orderId, orderCode: orderCode),
    ),
  );
}

/// The buyer's way in (buyers don't see the operational timeline).
class LoadingProofTile extends StatelessWidget {
  final Order order;
  const LoadingProofTile({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => openLoadingProof(context, order.id, order.orderCode),
        leading: const Icon(Icons.photo_library_outlined,
            color: AppColors.primaryMain,),
        title: const Text('Loading photos & truck', style: AppTypography.label),
        subtitle: Text(
          'See how your order was loaded and which truck carries it',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

/// What was loaded and on which truck: for the buyer's confidence and the
/// seller's record. The API decides who may see it (anyone who sees the order).
class LoadingProofScreen extends ConsumerWidget {
  final int orderId;
  final String orderCode;
  const LoadingProofScreen({
    super.key,
    required this.orderId,
    required this.orderCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proof = ref.watch(loadingProofProvider(orderId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Loading · $orderCode')),
      body: proof.when(
        loading: () => const Center(child: AppLoader()),
        error: (e, _) => ErrorState(
          error: e is AppError ? e : null,
          onRetry: () => ref.invalidate(loadingProofProvider(orderId)),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(loadingProofProvider(orderId).future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              _Card(
                icon: Icons.photo_library_outlined,
                title: 'Photos of the loaded vehicle',
                child: p.photos.isEmpty
                    ? Text(
                        'No photos were added when loading was done.',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      )
                    : Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: i < p.photos.length
                                  ? _Photo(
                                      url: p.photos[i].url,
                                      onTap: () =>
                                          _showPhoto(context, p.photos[i].url),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              _Card(
                icon: p.declared
                    ? Icons.verified_user_outlined
                    : Icons.info_outline_rounded,
                iconColor: p.declared ? AppColors.primaryMain : null,
                title: p.declared
                    ? 'Declared: no prohibited items'
                    : 'No declaration on record',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.declared)
                      Text(
                        '“$loadingDeclaration”',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                          height: 1.45,
                        ),
                      ),
                    if (p.completedAt != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        [
                          'Loaded ${DateFormat('d MMM y, h:mm a').format(p.completedAt!)}',
                          if (p.completedByName?.isNotEmpty == true)
                            'by ${p.completedByName}',
                        ].join(' '),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _Card(
                icon: Icons.local_shipping_outlined,
                title: 'Truck',
                child: p.truck == null
                    ? Text(
                        'No truck assigned yet. Details show here once the trip is created.',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      )
                    : Column(
                        children: [
                          _Row(
                            'Vehicle',
                            [
                              p.truck!.vehicleNumber,
                              p.truck!.vehicleType,
                            ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                          ),
                          _Row('Driver', p.truck!.driverName),
                          _Row('Driver mobile', p.truck!.driverMobile),
                          if (p.truck!.outsideTransport)
                            const _Row('Transport', 'Outside transport'),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Widget child;
  const _Card({
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTypography.h4)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  const _Photo({required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open photo',
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: AppRadius.cardRadius,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(color: AppColors.border),
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.border,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

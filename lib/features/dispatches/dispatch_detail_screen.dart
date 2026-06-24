import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_badge.dart';
import 'dispatches.dart';

class DispatchDetailScreen extends ConsumerWidget {
  final int dispatchId;
  const DispatchDetailScreen({super.key, required this.dispatchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dispatchDetailProvider(dispatchId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dispatch Details'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryMain)),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              Text(err.toString(), style: AppTypography.body),
              TextButton(
                onPressed: () => ref.refresh(dispatchDetailProvider(dispatchId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (dispatch) => _DetailView(dispatch: dispatch),
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  final Dispatch dispatch;
  const _DetailView({required this.dispatch});

  @override
  Widget build(BuildContext context) {
    final dispDate = dispatch.dispatchDate != null
        ? DateTime.tryParse(dispatch.dispatchDate!)
        : null;
    final delDate = dispatch.deliveryDate != null
        ? DateTime.tryParse(dispatch.deliveryDate!)
        : null;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
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
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.amber100,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.local_shipping_rounded,
                        color: AppColors.amber600, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dispatch.dispatchCode, style: AppTypography.h3),
                        if (dispatch.orderNumber != null)
                          Text('Order: ${dispatch.orderNumber}',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: dispatch.status.replaceAll('_', ' '),
                    variant: badgeVariantFromStatus(dispatch.status),
                    dot: true,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.x2l),

        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              if (dispatch.driverName != null)
                _Row(
                    icon: Icons.person_outline_rounded,
                    label: 'Driver',
                    value: dispatch.driverName!),
              if (dispatch.vehicleNumber != null) ...[
                if (dispatch.driverName != null)
                  const Divider(height: 1, indent: 56),
                _Row(
                    icon: Icons.directions_car_outlined,
                    label: 'Vehicle',
                    value: dispatch.vehicleNumber!),
              ],
              if (dispatch.destinationAddress != null) ...[
                const Divider(height: 1, indent: 56),
                _Row(
                    icon: Icons.location_on_outlined,
                    label: 'Destination',
                    value: dispatch.destinationAddress!),
              ],
              if (dispDate != null) ...[
                const Divider(height: 1, indent: 56),
                _Row(
                    icon: Icons.calendar_today_outlined,
                    label: 'Dispatch Date',
                    value: DateFormat('dd MMM yyyy').format(dispDate.toLocal())),
              ],
              if (delDate != null) ...[
                const Divider(height: 1, indent: 56),
                _Row(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Delivery Date',
                    value: DateFormat('dd MMM yyyy').format(delDate.toLocal())),
              ],
            ],
          ),
        ),

        if (dispatch.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x2l),
          Text('Items (${dispatch.items.length})', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: dispatch.items
                  .asMap()
                  .entries
                  .map((e) => Column(
                        children: [
                          if (e.key > 0) const Divider(height: 1, indent: 16),
                          Padding(
                            padding:
                                const EdgeInsets.all(AppSpacing.cardPadding),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    e.value.plantName ?? 'Item ${e.key + 1}',
                                    style: AppTypography.body,
                                  ),
                                ),
                                Text(
                                  'Qty: ${e.value.quantity.toInt()}',
                                  style: AppTypography.label,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ],

        if (dispatch.notes != null) ...[
          const SizedBox(height: AppSpacing.x2l),
          const Text('Notes', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(dispatch.notes!,
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary, height: 1.5)),
          ),
        ],

        const SizedBox(height: AppSpacing.x3l),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: AppColors.forest100, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: AppColors.primaryMain),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
                Text(value, style: AppTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_badge.dart';
import 'inventory.dart';

class InventoryDetailScreen extends ConsumerWidget {
  final int itemId;
  final bool canEdit;

  const InventoryDetailScreen(
      {super.key, required this.itemId, this.canEdit = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inventoryDetailProvider(itemId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory Detail'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: canEdit
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {}, // TODO: navigate to edit form
                ),
              ]
            : null,
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
                onPressed: () => ref.refresh(inventoryDetailProvider(itemId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (item) => _InventoryDetailView(item: item),
      ),
    );
  }
}

class _InventoryDetailView extends StatelessWidget {
  final InventoryItem item;
  const _InventoryDetailView({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusVariant = _statusVariant(item.status);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // Main card
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
                      color: AppColors.forest100,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.local_florist_rounded,
                        color: AppColors.primaryMain, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.scientificName, style: AppTypography.h3),
                        if (item.commonName != null) ...[
                          const SizedBox(height: 2),
                          Text(item.commonName!,
                              style: AppTypography.body
                                  .copyWith(color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              StatusBadge(
                label: _capitalize(item.status.replaceAll('_', ' ')),
                variant: statusVariant,
                dot: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.x2l),

        // Stats
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Available Qty',
                value: '${item.availableQuantity}',
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                label: 'Size',
                value: item.sizeName,
                icon: Icons.straighten_outlined,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.x2l),

        // Details list
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _DetailRow(label: 'Nursery', value: item.nurseryName),
              const Divider(height: 1, indent: 16),
              _DetailRow(label: 'Size Code', value: item.sizeCode),
              const Divider(height: 1, indent: 16),
              _DetailRow(label: 'Inventory Code', value: item.inventoryCode),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.x3l),
      ],
    );
  }

  BadgeVariant _statusVariant(String status) => switch (status.toLowerCase()) {
        'available' => BadgeVariant.success,
        'low_stock' => BadgeVariant.warning,
        'out_of_stock' => BadgeVariant.error,
        _ => BadgeVariant.neutral,
      };

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value,
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary)),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding, vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTypography.label),
        ],
      ),
    );
  }
}

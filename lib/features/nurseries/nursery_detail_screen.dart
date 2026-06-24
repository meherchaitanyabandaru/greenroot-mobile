import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_badge.dart';
import 'nurseries.dart';

class NurseryDetailScreen extends ConsumerWidget {
  final int nurseryId;
  const NurseryDetailScreen({super.key, required this.nurseryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nurseryDetailProvider(nurseryId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nursery Details'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primaryMain)),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              Text(err.toString(), style: AppTypography.body),
              TextButton(
                onPressed: () => ref.refresh(nurseryDetailProvider(nurseryId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (nursery) => _NurseryDetailView(nursery: nursery),
      ),
    );
  }
}

class _NurseryDetailView extends StatelessWidget {
  final Nursery nursery;
  const _NurseryDetailView({required this.nursery});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // Header card
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
                    child: const Icon(Icons.store_rounded,
                        color: AppColors.primaryMain, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nursery.name, style: AppTypography.h3),
                        if (nursery.nurseryCode != null) ...[
                          const SizedBox(height: 2),
                          Text(nursery.nurseryCode!,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: _capitalize(nursery.status),
                    variant: badgeVariantFromStatus(nursery.status),
                    dot: true,
                  ),
                ],
              ),
              if (nursery.description != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(nursery.description!,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary, height: 1.5)),
              ],
            ],
          ),
        ),

        // Contact info
        if (nursery.mobile != null || nursery.email != null) ...[
          const SizedBox(height: AppSpacing.x2l),
          const Text('Contact', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                if (nursery.mobile != null)
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Mobile',
                    value: nursery.mobile!,
                  ),
                if (nursery.email != null) ...[
                  if (nursery.mobile != null)
                    const Divider(height: 1, indent: 56),
                  _InfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: nursery.email!,
                  ),
                ],
                if (nursery.website != null) ...[
                  const Divider(height: 1, indent: 56),
                  _InfoRow(
                    icon: Icons.language_outlined,
                    label: 'Website',
                    value: nursery.website!,
                  ),
                ],
              ],
            ),
          ),
        ],

        // Addresses
        if (nursery.addresses.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x2l),
          const Text('Addresses', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          for (final addr in nursery.addresses)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _AddressCard(address: addr),
            ),
        ],

        // Staff
        if (nursery.users.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x2l),
          Text('Staff (${nursery.users.length})', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: nursery.users
                  .asMap()
                  .entries
                  .map((entry) => Column(
                        children: [
                          if (entry.key > 0)
                            const Divider(height: 1, indent: 56),
                          _StaffRow(user: entry.value),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.x3l),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.forest100,
              shape: BoxShape.circle,
            ),
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

class _AddressCard extends StatelessWidget {
  final NurseryAddress address;
  const _AddressCard({required this.address});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
            color: address.isPrimary ? AppColors.primaryMain : AppColors.border,
            width: address.isPrimary ? 1.5 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.forest100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded,
                size: 18, color: AppColors.primaryMain),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (address.addressType != null)
                      Text(_capitalize(address.addressType!),
                          style: AppTypography.label),
                    if (address.isPrimary) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const StatusBadge(
                          label: 'Primary', variant: BadgeVariant.success),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(address.fullAddress,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _StaffRow extends StatelessWidget {
  final NurseryUserLink user;
  const _StaffRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.slate100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                style: AppTypography.label.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.firstName, style: AppTypography.body),
                Text(user.mobile,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          StatusBadge(
            label: user.roleName,
            variant: BadgeVariant.neutral,
          ),
        ],
      ),
    );
  }
}

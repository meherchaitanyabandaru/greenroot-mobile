import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_badge.dart';
import 'requests.dart';

class RequestDetailScreen extends ConsumerWidget {
  final int requestId;

  const RequestDetailScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(requestDetailProvider(requestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Request Details'),
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
                onPressed: () => ref.refresh(requestDetailProvider(requestId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (req) => _RequestDetailView(request: req),
      ),
    );
  }
}

class _RequestDetailView extends StatelessWidget {
  final PlantRequest request;
  const _RequestDetailView({required this.request});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(request.createdAt);
    final dateStr = date != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal())
        : '';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // Header
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.forest100,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.assignment_rounded,
                        color: AppColors.primaryMain, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.displayName, style: AppTypography.h3),
                        Text(request.requestCode,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: request.status,
                    variant: badgeVariantFromStatus(request.status),
                    dot: true,
                  ),
                ],
              ),
              if (request.notes != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  request.notes!,
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.x2l),

        // Stats row
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Quantity',
                value: '${request.quantityRequired}',
                icon: Icons.format_list_numbered_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                label: 'Radius',
                value: '${request.radiusKm} km',
                icon: Icons.radar_rounded,
              ),
            ),
            if (request.responses.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatCard(
                  label: 'Responses',
                  value: '${request.responses.length}',
                  icon: Icons.reply_rounded,
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: AppSpacing.x2l),

        // Details
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _DetailRow(label: 'Nursery', value: request.requestingNursery),
              const Divider(height: 1, indent: 16),
              _DetailRow(label: 'Requested by', value: request.requestedByName),
              if (request.sizeName != null) ...[
                const Divider(height: 1, indent: 16),
                _DetailRow(label: 'Size', value: request.sizeName!),
              ],
              if (dateStr.isNotEmpty) ...[
                const Divider(height: 1, indent: 16),
                _DetailRow(label: 'Created', value: dateStr),
              ],
            ],
          ),
        ),

        // Responses
        if (request.responses.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x2l),
          Text('Responses (${request.responses.length})',
              style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          for (final resp in request.responses)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _ResponseCard(response: resp),
            ),
        ],

        const SizedBox(height: AppSpacing.x3l),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryMain),
          const SizedBox(height: AppSpacing.sm),
          Text(value,
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary)),
          Text(label,
              style:
                  AppTypography.caption.copyWith(color: AppColors.textSecondary)),
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
        children: [
          Text(label,
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: AppTypography.label,
                textAlign: TextAlign.right,
                maxLines: 2),
          ),
        ],
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  final RequestResponse response;
  const _ResponseCard({required this.response});

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
          Row(
            children: [
              Expanded(
                child: Text(response.supplierNursery, style: AppTypography.h4),
              ),
              StatusBadge(
                label: response.status,
                variant: badgeVariantFromStatus(response.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Available: ${response.availableQuantity}',
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary)),
          if (response.remarks != null) ...[
            const SizedBox(height: 4),
            Text(response.remarks!,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 4),
          Text('By: ${response.respondedByName}',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

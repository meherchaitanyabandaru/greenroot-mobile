import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class CompletionItem {
  final String label;
  final bool done;
  final VoidCallback? onTap;

  const CompletionItem({
    required this.label,
    required this.done,
    this.onTap,
  });
}

/// Displays a profile completion card with a progress bar and checklist.
/// Hides itself when all items are complete.
class ProfileCompletionCard extends StatelessWidget {
  final List<CompletionItem> items;

  const ProfileCompletionCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final done = items.where((i) => i.done).length;
    if (done == items.length) return const SizedBox.shrink();

    final pct = done / items.length;
    final pctLabel = '${(pct * 100).round()}%';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardPadding, AppSpacing.cardPadding,
                AppSpacing.cardPadding, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Complete your profile',
                          style: AppTypography.label),
                      const SizedBox(height: 2),
                      Text(
                        '$done of ${items.length} steps done',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 4),
                  decoration: BoxDecoration(
                    color: _progressColor(pct).withAlpha(26),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    pctLabel,
                    style: AppTypography.label.copyWith(
                      color: _progressColor(pct),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_progressColor(pct)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Checklist
          ...items.map((item) => _CheckRow(item: item)),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  static Color _progressColor(double pct) {
    if (pct >= 0.8) return AppColors.primaryMain;
    if (pct >= 0.5) return AppColors.amber600;
    return AppColors.red500;
  }
}

class _CheckRow extends StatelessWidget {
  final CompletionItem item;
  const _CheckRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.done ? null : item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              item.done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: item.done ? AppColors.primaryMain : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                item.label,
                style: AppTypography.body.copyWith(
                  color: item.done
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  decoration:
                      item.done ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textMuted,
                ),
              ),
            ),
            if (!item.done && item.onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

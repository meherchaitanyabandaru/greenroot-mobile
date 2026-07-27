import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum BadgeVariant { success, warning, error, info, neutral, accent }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final bool dot;

  const StatusBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _colors;

    // Keyed by label+variant so a status transition (e.g. CONFIRMED ->
    // LOADING) swaps to a distinct AnimatedSwitcher child -- a brief
    // fade+scale "pulse" that gives the user visual confirmation the status
    // actually changed, rather than the badge silently relabeling itself.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey('$label-$variant'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: colors.text,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _BadgeColors get _colors => switch (variant) {
        BadgeVariant.success => const _BadgeColors(
            bg: AppColors.successBg,
            text: AppColors.successText,
          ),
        BadgeVariant.warning => const _BadgeColors(
            bg: AppColors.warningBg,
            text: AppColors.warningText,
          ),
        BadgeVariant.error => const _BadgeColors(
            bg: AppColors.errorBg,
            text: AppColors.errorText,
          ),
        BadgeVariant.info => const _BadgeColors(
            bg: AppColors.infoBg,
            text: AppColors.infoText,
          ),
        BadgeVariant.accent => const _BadgeColors(
            bg: AppColors.accentLight,
            text: AppColors.accentHover,
          ),
        BadgeVariant.neutral => const _BadgeColors(
            bg: AppColors.slate100,
            text: AppColors.textSecondary,
          ),
      };
}

class _BadgeColors {
  final Color bg;
  final Color text;
  const _BadgeColors({required this.bg, required this.text});
}

BadgeVariant badgeVariantFromStatus(String status) {
  return switch (status.toUpperCase()) {
    'ACTIVE' || 'DELIVERED' || 'SUCCESS' || 'COMPLETED' || 'LOADED' => BadgeVariant.success,
    'PENDING' || 'IN_PROGRESS' || 'IN_TRANSIT' || 'LOADING' => BadgeVariant.warning,
    'CANCELLED' || 'FAILED' || 'REJECTED' || 'EXPIRED' => BadgeVariant.error,
    'DISPATCHED' || 'PROCESSING' || 'CONFIRMED' => BadgeVariant.info,
    'PARTIALLY_FULFILLED' => BadgeVariant.accent,
    _ => BadgeVariant.neutral,
  };
}

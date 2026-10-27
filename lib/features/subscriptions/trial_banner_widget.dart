import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'subscription_provider.dart';

class TrialExpiryBanner extends ConsumerWidget {
  const TrialExpiryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(
      sessionProvider.select((s) => s.capabilities.isNurseryOwner),
    );
    if (!isOwner) return const SizedBox.shrink();

    final subAsync = ref.watch(subscriptionProvider);
    return subAsync.when(
      data: (sub) {
        if (sub == null || sub.isCancelled) return const SizedBox.shrink();
        final days = sub.daysRemaining ?? 999;
        // Warn only in the last week: a monthly plan would otherwise show
        // "expires" all month. A trial is shown throughout, calmly at first.
        final soon = days <= 7;
        if (sub.isActive && !sub.isTrial && !soon) {
          return const SizedBox.shrink();
        }

        final isExpired = sub.isExpired || days < 0;
        final calm = sub.isTrial && !soon && !isExpired;
        final bg = isExpired
            ? const Color(0xFFFCE4EC)
            : calm
                ? AppColors.forest100
                : const Color(0xFFFFF8E1);
        final iconColor = isExpired
            ? AppColors.red600
            : calm
                ? AppColors.primaryMain
                : AppColors.amber600;
        final icon = isExpired
            ? Icons.error_outline_rounded
            : calm
                ? Icons.card_giftcard_rounded
                : Icons.access_time_rounded;
        final left =
            days == 0 ? 'today' : 'in $days day${days == 1 ? '' : 's'}';
        final message = isExpired
            ? 'Your subscription has ended. Choose a plan to keep selling.'
            : calm
                ? 'Free trial: $days days left. Unlimited orders and quotations, on us.'
                : sub.isTrial
                    ? 'Your free trial ends $left. Choose a plan to keep selling.'
                    : 'Your ${sub.planName} plan ends $left.';
        final action = isExpired || !sub.isTrial
            ? 'Renew'
            : calm
                ? 'See plans'
                : 'Choose plan';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push(
                  '/subscription/payment?subId=${sub.id}',
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  action,
                  style: AppTypography.bodySmall.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

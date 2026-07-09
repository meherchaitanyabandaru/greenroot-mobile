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
        sessionProvider.select((s) => s?.capabilities.isNurseryOwner ?? false));
    if (!isOwner) return const SizedBox.shrink();

    final subAsync = ref.watch(subscriptionProvider);
    return subAsync.when(
      data: (sub) {
        if (sub == null || sub.isCancelled) return const SizedBox.shrink();
        final days = sub.daysRemaining ?? 999;
        if (sub.isActive && days > 30) return const SizedBox.shrink();

        final isExpired = sub.isExpired || days == 0;
        final bg = isExpired ? const Color(0xFFFCE4EC) : const Color(0xFFFFF8E1);
        final iconColor = isExpired ? AppColors.red600 : AppColors.amber600;
        final icon = isExpired
            ? Icons.error_outline_rounded
            : Icons.access_time_rounded;
        final message = isExpired
            ? 'Your subscription has expired. Renew now to keep access.'
            : sub.isTrial
                ? 'Free trial expires in $days day${days == 1 ? '' : 's'}. Upgrade to continue.'
                : 'Subscription expires in $days day${days == 1 ? '' : 's'}.';

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
                    '/subscription/payment?subId=${sub.id}'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  isExpired ? 'Renew' : 'Upgrade',
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

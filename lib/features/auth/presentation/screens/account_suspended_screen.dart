import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../presentation/providers/session_provider.dart';

class AccountSuspendedScreen extends ConsumerWidget {
  const AccountSuspendedScreen({super.key});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suspension = ref.watch(sessionProvider).suspensionInfo;
    final hasReason = suspension?.reason?.isNotEmpty == true;
    final hasDate = suspension?.suspendedAt != null;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.amber600.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.amber600,
                    size: 40,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2l),
                const Text(
                  'Account Suspended',
                  style: AppTypography.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your account has been suspended by GreenRoot. Please contact our support team to resolve this.',
                  style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),

                // Suspension metadata card — shown when reason/date are available
                if (hasReason || hasDate) ...[
                  const SizedBox(height: AppSpacing.x2l),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.amber50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.amber600.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppColors.amber700, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Suspension details',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.amber700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (hasDate) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Suspended on ${_formatDate(suspension!.suspendedAt!)}',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.amber700),
                          ),
                        ],
                        if (hasReason) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            suspension!.reason!,
                            style: AppTypography.body
                                .copyWith(color: AppColors.amber700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.x2l),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          color: AppColors.primaryMain, size: 20),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'support@greenroot.in',
                        style: AppTypography.body
                            .copyWith(color: AppColors.primaryMain),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // Tapping "Login Again" clears session and re-enters OTP flow.
                // If the account is still suspended the auth response returns 403
                // USER_SUSPENDED and the user is redirected here again with the reason.
                AppButton(
                  label: 'Login Again',
                  onPressed: () async {
                    await ref.read(sessionProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

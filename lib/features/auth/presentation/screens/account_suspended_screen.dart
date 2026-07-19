import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../presentation/providers/session_provider.dart';

class AccountSuspendedScreen extends ConsumerWidget {
  const AccountSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
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
                'Your account has been suspended. Please contact our support team to resolve this.',
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
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
              TextButton(
                onPressed: () async {
                  await ref.read(sessionProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                child: Text(
                  'Sign Out',
                  style:
                      AppTypography.body.copyWith(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/session_provider.dart';

class AccountReadyScreen extends ConsumerWidget {
  const AccountReadyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = ref.watch(sessionProvider.select((s) => s.user?.firstName));
    final hasName = first != null && first.trim().isNotEmpty;
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
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.primaryMain,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),
              // The account exists; how they'll use GreenRoot is still to pick,
              // so this is a welcome, not "all set".
              Text(
                hasName ? 'Welcome, ${first.trim()}!' : 'Welcome to GreenRoot!',
                style: AppTypography.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your account is ready. One more step: tell us how you will '
                'use GreenRoot.',
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              AppButton(
                label: 'Continue',
                onPressed: () => context.go('/select-activity'),
                trailingIcon: Icons.arrow_forward_rounded,
              ),
              const SizedBox(height: AppSpacing.x2l),
            ],
          ),
        ),
      ),
    );
  }
}

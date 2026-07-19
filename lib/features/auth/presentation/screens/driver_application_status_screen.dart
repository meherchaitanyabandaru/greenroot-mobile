import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/session_provider.dart';

class DriverApplicationStatusScreen extends ConsumerWidget {
  const DriverApplicationStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(sessionProvider).driverApplication?.approvalStatus ??
            'PENDING';
    final rejected = status == 'REJECTED';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Driver Application'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: rejected ? AppColors.red100 : AppColors.amber100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  rejected
                      ? Icons.error_outline_rounded
                      : Icons.hourglass_empty_rounded,
                  color: rejected ? AppColors.red600 : AppColors.amber600,
                  size: 44,
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),
              Text(
                rejected
                    ? 'Application Needs Attention'
                    : 'Application Under Review',
                style: AppTypography.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                rejected
                    ? 'Your driver application was not approved. You can update your details and submit again, or continue using GreenRoot as a customer.'
                    : 'Your driver application is being reviewed. You can continue using GreenRoot as a customer while you wait.',
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (rejected) ...[
                AppButton(
                  label: 'Update Driver Details',
                  onPressed: () => context.go('/register/driver'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              OutlinedButton(
                onPressed: () => context.go('/home'),
                style: OutlinedButton.styleFrom(
                  minimumSize:
                      const Size(double.infinity, AppSpacing.buttonHeight),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text('Continue as Customer'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () async {
                  await ref.read(sessionProvider.notifier).bootstrap();
                  if (context.mounted) context.go('/');
                },
                child: const Text('Refresh Status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

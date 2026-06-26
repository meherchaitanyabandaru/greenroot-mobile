import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/session_provider.dart';

class NurseryRejectedScreen extends ConsumerWidget {
  const NurseryRejectedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    Future<void> logout() async {
      await ref.read(sessionProvider.notifier).logout();
      if (!context.mounted) return;
      context.go('/login');
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Application Status', style: AppTypography.h3),
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded, color: AppColors.red600),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              const Spacer(),

              // Status icon
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.red100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: AppColors.red600,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),
              const Text(
                'Application Not Approved',
                style: AppTypography.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Unfortunately, your nursery registration was not approved at this time. You may resubmit with updated information.',
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),

              if (session.capabilities.ownedNurseryName != null) ...[
                const SizedBox(height: AppSpacing.x2l),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          color: AppColors.textMuted, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nursery',
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary)),
                            Text(
                              session.capabilities.ownedNurseryName!,
                              style: AppTypography.body
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.red100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Rejected',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.red600,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.x3l),

              // What to do next info
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.amber50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.amber600.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            color: AppColors.amber700, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Text('What you can do',
                            style: AppTypography.body.copyWith(
                                color: AppColors.amber700,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Tip('Update your nursery information and resubmit.'),
                    _Tip('Contact GreenRoot support for more details.'),
                    _Tip('Ensure your contact details are accurate.'),
                  ],
                ),
              ),

              const Spacer(),

              AppButton(
                label: 'Resubmit Application',
                onPressed: () => context.go('/register/nursery'),
                trailingIcon: Icons.arrow_forward_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: logout,
                child: Text(
                  'Sign Out',
                  style: AppTypography.button
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;
  const _Tip(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.amber700)),
          Expanded(
            child: Text(text,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.amber700)),
          ),
        ],
      ),
    );
  }
}

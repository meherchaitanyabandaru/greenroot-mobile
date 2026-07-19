import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';

class ActivitySelectScreen extends ConsumerWidget {
  const ActivitySelectScreen({super.key});

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    String activity,
    String route,
  ) async {
    try {
      final user =
          await ref.read(authRepositoryProvider).completeOnboarding(activity);
      ref.read(sessionProvider.notifier).updateUser(user);
      if (context.mounted) context.go(route);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not save your selection. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('GreenRoot', style: AppTypography.h3),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              const Text('How would you like to use GreenRoot?',
                  style: AppTypography.h1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Choose your primary role. You can add more roles later from your profile.',
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.x3l),
              _ActivityCard(
                icon: Icons.local_florist_rounded,
                iconBg: AppColors.forest100,
                iconColor: AppColors.primaryMain,
                title: 'I own a nursery',
                subtitle:
                    'Register your nursery and get selling access after approval.',
                onTap: () =>
                    _select(context, ref, 'OWNER', '/register/nursery'),
              ),
              const SizedBox(height: AppSpacing.md),
              _ActivityCard(
                icon: Icons.manage_accounts_rounded,
                iconBg: AppColors.amber100,
                iconColor: AppColors.amber700,
                title: 'I work in a nursery',
                subtitle:
                    'Join as a manager using an invite code from the nursery owner.',
                onTap: () => _select(context, ref, 'MANAGER', '/invite/accept'),
              ),
              const SizedBox(height: AppSpacing.md),
              _ActivityCard(
                icon: Icons.shopping_bag_outlined,
                iconBg: const Color(0xFFE8F5E9),
                iconColor: const Color(0xFF2E7D32),
                title: 'I am a customer / buyer',
                subtitle:
                    'Browse nurseries, request quotations and place orders.',
                onTap: () => _select(context, ref, 'CUSTOMER', '/home'),
              ),
              const SizedBox(height: AppSpacing.md),
              _ActivityCard(
                icon: Icons.local_shipping_outlined,
                iconBg: const Color(0xFFE3F2FD),
                iconColor: const Color(0xFF1565C0),
                title: 'I am a driver',
                subtitle:
                    'Register your vehicle and join delivery trips using a trip code.',
                onTap: () =>
                    _select(context, ref, 'DRIVER', '/register/driver'),
              ),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: () => _select(context, ref, 'CUSTOMER', '/home'),
                  child: Text(
                    'Continue as Customer →',
                    style: AppTypography.button
                        .copyWith(color: AppColors.primaryMain),
                  ),
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

class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.label),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

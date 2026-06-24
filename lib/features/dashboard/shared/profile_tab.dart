import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/domain/rbac/roles.dart';
import '../../auth/presentation/providers/session_provider.dart';

class ProfileTabContent extends ConsumerWidget {
  final AppRole role;

  const ProfileTabContent({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryMain, width: 2),
            ),
            child: Center(
              child: Text(
                user?.initials ?? '?',
                style: AppTypography.h2.copyWith(color: AppColors.primaryMain),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            user?.name ?? 'GreenRoot User',
            style: AppTypography.h3,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              role.displayName,
              style: AppTypography.label.copyWith(color: AppColors.primaryMain),
            ),
          ),
        ),
        if (user?.mobile != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              user!.mobile!,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
        if (user?.email != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              user!.email!,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.x3l),
        ProfileTile(
          icon: Icons.person_outline_rounded,
          title: 'Edit Profile',
          onTap: () => context.go('/create-profile'),
        ),
        ProfileTile(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          onTap: () {},
        ),
        ProfileTile(
          icon: Icons.help_outline_rounded,
          title: 'Help & Support',
          onTap: () {},
        ),
        ProfileTile(
          icon: Icons.info_outline_rounded,
          title: 'About GreenRoot',
          onTap: () {},
        ),
        const SizedBox(height: AppSpacing.x2l),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(sessionProvider.notifier).logout().then((_) {
              if (context.mounted) context.go('/login');
            });
          },
          icon: const Icon(Icons.logout_rounded, color: AppColors.red600),
          label: const Text(
            'Sign Out',
            style: TextStyle(color: AppColors.red600),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.red600),
            minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          ),
        ),
        const SizedBox(height: AppSpacing.x2l),
      ],
    );
  }
}

class ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;

  const ProfileTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.forest100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primaryMain),
        ),
        title: Text(title, style: AppTypography.body),
        subtitle: subtitle != null ? Text(subtitle!, style: AppTypography.caption) : null,
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textMuted,
        ),
        onTap: onTap,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
    );
  }
}

class EmptyActivity extends StatelessWidget {
  final String message;
  const EmptyActivity({super.key, this.message = 'No recent activity'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x2l),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 36, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

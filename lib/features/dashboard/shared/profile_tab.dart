import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/profile_completion_service.dart';
import '../../../core/widgets/profile_completion_card.dart';
import '../../auth/domain/rbac/roles.dart';
import '../../auth/presentation/providers/session_provider.dart';
import '../../nurseries/nurseries.dart' show Nursery, nurseryDetailProvider;

class ProfileTabContent extends ConsumerWidget {
  final AppRole role;

  const ProfileTabContent({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final caps = session.capabilities;

    // For owners, try to load nursery branding to include in completion.
    final nurseryAsync = caps.primaryNurseryId != null
        ? ref.watch(nurseryDetailProvider(caps.primaryNurseryId!))
        : const AsyncValue<Nursery>.loading();

    final completionItems = buildCompletionItems(
      role: role,
      user: user,
      caps: caps,
      nursery: nurseryAsync.valueOrNull,
      onEditProfile: () => context.push('/create-profile'),
      onRegisterDriver: () => context.push('/register/driver'),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        if (completionItems.isNotEmpty) ...[
          ProfileCompletionCard(items: completionItems),
          const SizedBox(height: AppSpacing.x2l),
        ],
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
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
        if (user?.email != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              user!.email!,
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
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

        // Leave Nursery — only for managers (not owners)
        if (role == AppRole.manager) ...[
          OutlinedButton.icon(
            onPressed: () => _confirmLeaveNursery(context, ref),
            icon: const Icon(Icons.exit_to_app_rounded,
                color: AppColors.amber600),
            label: const Text(
              'Leave Nursery',
              style: TextStyle(color: AppColors.amber600),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.amber600),
              minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Disconnect from Nursery — only for drivers who have a connected nursery
        if (role == AppRole.driver && caps.driverNurseryId != null) ...[
          OutlinedButton.icon(
            onPressed: () => _confirmDisconnectFromNursery(
                context, ref, caps.driverNurseryId!),
            icon: const Icon(Icons.link_off_rounded, color: AppColors.amber600),
            label: const Text(
              'Disconnect from Nursery',
              style: TextStyle(color: AppColors.amber600),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.amber600),
              minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

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
        const SizedBox(height: AppSpacing.md),

        // Delete Account — available for all roles, intentionally low emphasis.
        TextButton.icon(
          onPressed: () => _confirmDeleteAccount(context, ref),
          icon: const Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
          label: const Text(
            'Delete Account',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        const SizedBox(height: AppSpacing.x2l),
      ],
    );
  }

  Future<void> _confirmLeaveNursery(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Nursery'),
        content: const Text(
          'You will lose access to this nursery immediately. You can rejoin by accepting a new invite from the owner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.amber600),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ApiClient.instance.delete(ApiConstants.leaveNursery);
      await ref.read(sessionProvider.notifier).bootstrap();
      if (context.mounted) context.go('/home');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to leave nursery. Please try again.')),
        );
      }
    }
  }

  Future<void> _confirmDisconnectFromNursery(
      BuildContext context, WidgetRef ref, int nurseryId) async {
    final session = ref.read(sessionProvider);
    final userId = session.user?.id;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disconnect from Nursery'),
        content: const Text(
          'You will be disconnected from this nursery immediately. The nursery owner can reconnect you by sending a new invite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.amber600),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ApiClient.instance
          .delete(ApiConstants.disconnectDriver(nurseryId, userId));
      await ref.read(sessionProvider.notifier).bootstrap();
      if (context.mounted) context.go('/home');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to disconnect. Please try again.')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Your profile and personal data will be permanently removed. Business records such as orders and quotations are kept for legal compliance.\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red600),
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ApiClient.instance.delete(ApiConstants.deleteAccount);
      await ref.read(sessionProvider.notifier).logout();
      if (context.mounted) {
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted. Goodbye.')),
        );
      }
    } on DioException catch (e) {
      if (!context.mounted) return;
      final body = e.response?.data;
      final code = (body is Map && body['error'] is Map)
          ? (body['error'] as Map)['code'] as String?
          : null;
      final message = code == 'account_deletion_blocked'
          ? 'Close or cancel your active orders, quotations, and nursery before deleting your account.'
          : 'Failed to delete account. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to delete account. Please try again.')),
        );
      }
    }
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
        subtitle: subtitle != null
            ? Text(subtitle!, style: AppTypography.caption)
            : null,
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
          const Icon(Icons.inbox_outlined,
              size: 36, color: AppColors.textMuted),
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

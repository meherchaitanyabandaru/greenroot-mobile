import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/services/profile_completion_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/domain/rbac/roles.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../nurseries/nurseries.dart' show nurseryDetailProvider;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final caps = session.capabilities;
    final role = _roleFor(caps);
    final nursery = caps.primaryNurseryId == null
        ? null
        : ref.watch(nurseryDetailProvider(caps.primaryNurseryId!)).valueOrNull;
    final completionItems = buildCompletionItems(
      role: role,
      user: user,
      caps: caps,
      nursery: nursery,
      onEditProfile: () => context.push('/edit-profile'),
      onEditAddress: () => context.push('/my-addresses'),
      onEditNurseryProfile: caps.primaryNurseryId != null
          ? () => context.push('/nursery/profile', extra: caps.primaryNurseryId)
          : null,
      onRegisterDriver: () => context.push('/register/driver'),
    );
    final completionPct = completionPercent(completionItems);
    final pctLabel = '${(completionPct * 100).round()}%';
    final roleLabel = _roleLabel(caps);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Profile', style: AppTypography.h3),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          _ProfileHeaderCard(
            name: user?.name ?? 'GreenRoot User',
            roleLabel: roleLabel,
            userCode: user?.userCode,
          ),
          const SizedBox(height: AppSpacing.md),
          _ProfileCompletionCard(
            percent: completionPct,
            pctLabel: pctLabel,
            done: completionItems.where((i) => i.done).length,
            total: completionItems.length,
            onContinue: () => context.push('/complete-profile'),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Account', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          _SettingsSection(
            items: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                label: 'Personal Information',
                subtitle: 'Name, email, phone, gender',
                onTap: () => context.push('/edit-profile'),
              ),
              if (caps.canSell)
                _SettingsTile(
                  icon: Icons.storefront_outlined,
                  label: 'Nursery Profile',
                  subtitle: 'Business, branding, details',
                  onTap: () {
                    final id = caps.primaryNurseryId;
                    if (id == null) return;
                    if (caps.isNurseryOwner) {
                      context.push('/nursery/profile', extra: id);
                    } else {
                      context.push('/nurseries/$id');
                    }
                  },
                ),
              if (!caps.isDriverOnly)
                _SettingsTile(
                  icon: Icons.location_on_outlined,
                  label: 'Addresses',
                  subtitle: 'Nursery, billing, delivery',
                  onTap: () => context.push('/my-addresses'),
                ),
              _SettingsTile(
                icon: Icons.workspace_premium_rounded,
                label: 'Subscription',
                subtitle: 'Plan, status, billing',
                onTap: () => context.push('/subscription'),
              ),
              if (caps.isDriverOnly)
                _SettingsTile(
                  icon: Icons.route_outlined,
                  label: 'My Trips',
                  onTap: () => context.push('/driver/trips'),
                )
              else if (!caps.canSell)
                _SettingsTile(
                  icon: Icons.payments_outlined,
                  label: 'Payment History',
                  onTap: () => context.push('/my-payments'),
                ),
              _SettingsTile(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                subtitle: 'Preferences, channels',
                onTap: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Support', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          _SettingsSection(
            items: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                onTap: () => context.push('/help-support'),
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => context.push('/privacy-policy'),
              ),
              _SettingsTile(
                icon: Icons.gavel_rounded,
                label: 'Terms & Conditions',
                onTap: () => context.push('/terms-of-service'),
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                label: 'About GreenRoot',
                onTap: () => context.push('/about-greenroot'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
          _SettingsSection(
            items: [
              if (caps.isManager)
                _SettingsTile(
                  icon: Icons.exit_to_app_rounded,
                  iconColor: AppColors.amber600,
                  label: 'Leave Nursery',
                  onTap: () => _confirmLeaveNursery(context, ref),
                ),
              if (caps.isDriverOnly && caps.driverNurseryId != null)
                _SettingsTile(
                  icon: Icons.link_off_rounded,
                  iconColor: AppColors.amber600,
                  label: 'Disconnect from Nursery',
                  onTap: () => _confirmDisconnectFromNursery(
                      context, ref, caps.driverNurseryId!),
                ),
              _SettingsTile(
                icon: Icons.logout_rounded,
                iconColor: AppColors.red600,
                label: 'Sign Out',
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(color: AppColors.red600),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await ref.read(sessionProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: () => _confirmDeleteAccount(context, ref),
              child: const Text(
                'Delete Account',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
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
      if (context.mounted) context.go('/select-activity');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to leave nursery. Please try again.')),
        );
      }
    }
  }

  Future<void> _confirmDisconnectFromNursery(
      BuildContext context, WidgetRef ref, int nurseryId) async {
    final userId = ref.read(sessionProvider).user?.id;
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
      if (context.mounted) context.go('/select-activity');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to disconnect. Please try again.')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
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
          const SnackBar(content: Text('Failed to delete account. Please try again.')),
        );
      }
    }
  }

  static AppRole _roleFor(caps) {
    if (caps.canSell) {
      return caps.isNurseryOwner ? AppRole.nurseryOwner : AppRole.manager;
    }
    if (caps.hasDriverProfile) return AppRole.driver;
    return AppRole.buyer;
  }

  static String _roleLabel(caps) {
    if (caps.isNurseryOwner) return 'Owner';
    if (caps.isManager) return 'Manager';
    if (caps.isDriverOnly) return 'Driver';
    return 'Customer';
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String roleLabel;
  final String? userCode;

  const _ProfileHeaderCard({
    required this.name,
    required this.roleLabel,
    required this.userCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const UserAvatar(size: 68, borderWidth: 0),
          const SizedBox(height: AppSpacing.md),
          Text(name, style: AppTypography.h3, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              roleLabel,
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryHover,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (userCode != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              userCode!,
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryMain,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileCompletionCard extends StatelessWidget {
  final double percent;
  final String pctLabel;
  final int done;
  final int total;
  final VoidCallback onContinue;

  const _ProfileCompletionCard({
    required this.percent,
    required this.pctLabel,
    required this.done,
    required this.total,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final complete = percent >= 1;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profile Completion', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _ProgressBadge(percent: percent, size: 74, strokeWidth: 6),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$pctLabel Complete', style: AppTypography.h3),
                    const SizedBox(height: 4),
                    Text(
                      complete
                          ? '$done of $total steps completed'
                          : 'Keep going! You are almost there.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: complete ? 'View Profile' : 'Continue Profile',
            onPressed: onContinue,
            trailingIcon: Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  final double percent;
  final double size;
  final double strokeWidth;

  const _ProgressBadge({
    required this.percent,
    this.size = 58,
    this.strokeWidth = 4,
  });

  @override
  Widget build(BuildContext context) {
    final pctLabel = '${(percent * 100).round()}%';
    final color = percent >= 0.9
        ? AppColors.primaryMain
        : percent >= 0.5
            ? AppColors.amber600
            : AppColors.red500;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size - 4,
            height: size - 4,
            child: CircularProgressIndicator(
              value: percent.clamp(0, 1),
              strokeWidth: strokeWidth,
              backgroundColor: AppColors.border,
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            pctLabel,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final List<_SettingsTile> items;

  const _SettingsSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primaryMain;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: AppTypography.body),
      subtitle: subtitle == null || subtitle!.isEmpty
          ? null
          : Text(
              subtitle!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

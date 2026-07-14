import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/services/profile_completion_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/domain/rbac/roles.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../nurseries/nurseries.dart' show nurseryDetailProvider;

const _appVersion = '1.0.0';

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
    final roleLabel = _roleLabel(caps);
    final isComplete = completionPct >= 1.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      // No notification bell here — accessible via the Account section below.
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Profile', style: AppTypography.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          _ProfileHeaderCard(
            name: user?.name ?? 'GreenRoot User',
            roleLabel: roleLabel,
            userCode: user?.userCode,
            mobile: user?.mobile,
            onEdit: () => context.push('/edit-profile'),
          ),
          const SizedBox(height: AppSpacing.md),

          // Profile completion — hidden once 100% done.
          if (!isComplete) ...[
            _ProfileCompletionCard(
              percent: completionPct,
              pctLabel: '${(completionPct * 100).round()}%',
              done: completionItems.where((i) => i.done).length,
              total: completionItems.length,
              onContinue: () => context.push('/complete-profile'),
            ),
            const SizedBox(height: AppSpacing.x2l),
          ] else
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
              // Subscription is only relevant for nursery roles.
              if (caps.canSell)
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
                icon: Icons.star_rounded,
                label: 'Rate the App',
                subtitle: 'Share your feedback with us',
                onTap: () => context.push('/ratings/app'),
              ),
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
                subtitle: 'Version $_appVersion',
                onTap: () => context.push('/about-greenroot'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Manage Account', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.x2l),
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
          const SnackBar(
              content: Text('Failed to leave nursery. Please try again.')),
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

// ── Profile header card ───────────────────────────────────────────────────────

class _ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String roleLabel;
  final String? userCode;
  final String? mobile;
  final VoidCallback onEdit;

  const _ProfileHeaderCard({
    required this.name,
    required this.roleLabel,
    required this.userCode,
    required this.mobile,
    required this.onEdit,
  });

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User code copied'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
          Stack(
            children: [
              const UserAvatar(size: 72, borderWidth: 0),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.primaryMain,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 13),
                  ),
                ),
              ),
            ],
          ),
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
          if (mobile != null && mobile!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              mobile!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (userCode != null) ...[
            const SizedBox(height: AppSpacing.xs),
            GestureDetector(
              onTap: () => _copyCode(context, userCode!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userCode!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryMain,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded,
                      size: 12, color: AppColors.primaryMain),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Profile completion card ───────────────────────────────────────────────────

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
                      '$done of $total steps completed',
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
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Complete Profile',
                  style: AppTypography.button.copyWith(color: Colors.white)),
            ),
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

// ── Settings section + tile ───────────────────────────────────────────────────

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

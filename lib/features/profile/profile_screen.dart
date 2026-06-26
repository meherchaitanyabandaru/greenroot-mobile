import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/data/models/capabilities_model.dart';
import '../auth/presentation/providers/session_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final caps = session.capabilities;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Profile', style: AppTypography.h3),
        actions: [
          IconButton(
            onPressed: () => context.push('/create-profile'),
            icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
            tooltip: 'Edit Profile',
          ),
          IconButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Sign Out',
                            style: TextStyle(color: AppColors.red600))),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref.read(sessionProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.red600),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryMain, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      user?.initials ?? '?',
                      style: AppTypography.h2
                          .copyWith(color: AppColors.primaryMain),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  user?.name ?? 'GreenRoot User',
                  style: AppTypography.h3,
                ),
                if (user?.mobile != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    user!.mobile!,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
                if (user?.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user!.email!,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // My Roles / Access
          const Text('My Roles & Access', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          _RolesSection(caps: caps),
          const SizedBox(height: AppSpacing.x2l),

          // Account settings
          const Text('Account', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          _SettingsSection(
            items: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                label: 'Edit Profile',
                onTap: () => context.push('/create-profile'),
              ),
              _SettingsTile(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                onTap: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),

          // App info
          const Text('Support', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          _SettingsSection(
            items: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                label: 'About GreenRoot',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Sign out
          OutlinedButton.icon(
            onPressed: () {
              ref.read(sessionProvider.notifier).logout().then((_) {
                if (context.mounted) context.go('/login');
              });
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.red600),
            label:
                const Text('Sign Out', style: TextStyle(color: AppColors.red600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.red600),
              minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
            ),
          ),
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Roles section — shows each workspace as a card
// ──────────────────────────────────────────────────────────────────────────────

class _RolesSection extends StatelessWidget {
  final UserCapabilities caps;

  const _RolesSection({required this.caps});

  @override
  Widget build(BuildContext context) {
    final hasRoles = caps.isNurseryOwner || caps.isManager || caps.hasDriverProfile;

    if (!hasRoles) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.shopping_bag_outlined,
                size: 32, color: AppColors.primaryMain),
            const SizedBox(height: AppSpacing.sm),
            const Text('Customer', style: AppTypography.label),
            const SizedBox(height: 3),
            Text(
              'Standard buying access — quotations, orders, tracking',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Always show customer card
        _RoleCard(
          icon: Icons.shopping_bag_outlined,
          iconColor: const Color(0xFF2E7D32),
          iconBg: const Color(0xFFE8F5E9),
          title: 'Customer',
          subtitle: 'Buying access — quotations, orders, tracking',
        ),
        const SizedBox(height: AppSpacing.sm),
        if (caps.isNurseryOwner) ...[
          _RoleCard(
            icon: Icons.local_florist_rounded,
            iconColor: AppColors.primaryMain,
            iconBg: AppColors.primaryLight,
            title: caps.ownedNurseryName ?? 'My Nursery',
            subtitle: 'Nursery Owner — full selling access',
            action: _RoleAction(
              label: 'Manage',
              onTap: () {},
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (caps.isManager) ...[
          for (final w in caps.managedNurseries) ...[
            _RoleCard(
              icon: Icons.manage_accounts_rounded,
              iconColor: AppColors.amber700,
              iconBg: AppColors.amber100,
              title: w.nurseryName ?? 'Nursery',
              subtitle: 'Manager / Gumastha',
              action: _RoleAction(
                label: 'Open',
                onTap: () {},
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
        if (caps.hasDriverProfile) ...[
          _RoleCard(
            icon: Icons.local_shipping_outlined,
            iconColor: const Color(0xFF1565C0),
            iconBg: const Color(0xFFE3F2FD),
            title: 'Delivery Driver',
            subtitle: 'Trips, vehicle details, documents',
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final _RoleAction? action;

  const _RoleCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.action,
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.label),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: action!.onTap,
              child: Text(action!.label),
            ),
        ],
      ),
    );
  }
}

class _RoleAction {
  final String label;
  final VoidCallback onTap;

  const _RoleAction({required this.label, required this.onTap});
}

// ──────────────────────────────────────────────────────────────────────────────
// Settings section
// ──────────────────────────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final List<_SettingsTile> items;

  const _SettingsSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
  final String label;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.forest100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryMain, size: 20),
      ),
      title: Text(label, style: AppTypography.body),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

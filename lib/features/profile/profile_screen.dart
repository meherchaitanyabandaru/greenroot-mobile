import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/data/models/user_models.dart';
import '../auth/presentation/providers/session_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final caps = session.capabilities;
    final accountItems = [
      _SettingsTile(
        icon: Icons.person_outline_rounded,
        label: 'Edit Profile',
        onTap: () => context.push('/edit-profile'),
      ),
      if (caps.isNurseryOwner)
        _SettingsTile(
          icon: Icons.workspace_premium_rounded,
          label: 'Subscription',
          onTap: () => context.push('/subscription'),
        ),
      if (caps.isDriverOnly)
        _SettingsTile(
          icon: Icons.route_outlined,
          label: 'My Trips',
          onTap: () => context.push('/driver/trips'),
        )
      else ...[
        _SettingsTile(
          icon: Icons.location_on_outlined,
          label: 'My Addresses',
          onTap: () => context.push('/my-addresses'),
        ),
        if (!caps.canSell)
          _SettingsTile(
            icon: Icons.payments_outlined,
            label: 'Payment History',
            onTap: () => context.push('/my-payments'),
          ),
      ],
      _SettingsTile(
        icon: Icons.notifications_none_rounded,
        label: 'Notifications',
        onTap: () => context.push('/notifications'),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Profile', style: AppTypography.h3),
        actions: [
          IconButton(
            onPressed: () => context.push('/edit-profile'),
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
            icon: const Icon(Icons.logout_rounded, color: AppColors.red600),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // ── Avatar + identity ─────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                UserAvatar(
                  size: 88,
                  borderWidth: 2,
                  onTap: () => context.push('/edit-profile'),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  user?.name ?? 'GreenRoot User',
                  style: AppTypography.h3,
                ),
                const SizedBox(height: AppSpacing.xs),
                // Member ID badge
                if (user?.userCode != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryMain.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined, size: 13, color: AppColors.primaryMain),
                        const SizedBox(width: 4),
                        Text(
                          user!.userCode!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primaryMain,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // ── Account info card ─────────────────────────────────────────────
          _ProfileInfoCard(user: user),
          const SizedBox(height: AppSpacing.x2l),

          // Account settings
          const Text('Account', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          _SettingsSection(items: accountItems),
          const SizedBox(height: AppSpacing.x2l),

          // Support
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
                onTap: () async {
                  final uri = Uri.parse('https://www.greenroot.in/privacy');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _SettingsTile(
                icon: Icons.gavel_rounded,
                label: 'Terms & Conditions',
                onTap: () async {
                  final uri = Uri.parse('https://www.greenroot.in/terms');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                label: 'About GreenRoot',
                onTap: () => context.push('/about-greenroot'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Profile info card — contact details + account metadata
// ──────────────────────────────────────────────────────────────────────────────

class _ProfileInfoCard extends StatelessWidget {
  final UserProfile? user;
  const _ProfileInfoCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final rows = <_InfoRow>[
      _InfoRow(
        icon: Icons.phone_outlined,
        label: 'Mobile',
        value: user?.mobile ?? '—',
        badge: user?.mobileVerified == true ? 'Verified' : null,
      ),
      if (user?.email != null)
        _InfoRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: user!.email!,
          badge: user?.emailVerified == true ? 'Verified' : null,
        ),
      if (user?.gender != null)
        _InfoRow(
          icon: _genderIcon(user!.gender!),
          label: 'Gender',
          value: _genderLabel(user!.gender!),
        ),
      _InfoRow(
        icon: Icons.calendar_today_outlined,
        label: 'Member since',
        value: user?.createdAt != null ? _memberSince(user!.createdAt!) : '—',
      ),
      if (user?.lastLoginAt != null)
        _InfoRow(
          icon: Icons.access_time_rounded,
          label: 'Last login',
          value: _relativeTime(user!.lastLoginAt!),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const Divider(height: 1, indent: 52, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  static IconData _genderIcon(String g) {
    switch (g) {
      case 'MALE': return Icons.male_rounded;
      case 'FEMALE': return Icons.female_rounded;
      default: return Icons.visibility_off_outlined;
    }
  }

  static String _genderLabel(String g) {
    switch (g) {
      case 'MALE': return 'Male';
      case 'FEMALE': return 'Female';
      default: return 'Prefer not to say';
    }
  }

  static String _memberSince(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month - 1]} ${dt.year}';
  }

  static String _relativeTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDay = DateTime(local.year, local.month, local.day);
    final daysDiff = today.difference(itemDay).inDays;
    final timeStr = DateFormat('h:mm a').format(local);
    if (daysDiff == 0) return 'Today, $timeStr';
    if (daysDiff == 1) return 'Yesterday, $timeStr';
    if (daysDiff < 30) return '${daysDiff}d ago';
    if (daysDiff < 365) return '${(daysDiff / 30).floor()}mo ago';
    return '${(daysDiff / 365).floor()}y ago';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? badge;

  const _InfoRow({required this.icon, required this.label, required this.value, this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.forest100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryMain),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(value, style: AppTypography.body),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: AppTypography.caption.copyWith(
                  color: const Color(0xFF2E7D32),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Settings section
// ──────────────────────────────────────────────────────────────────────────────

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

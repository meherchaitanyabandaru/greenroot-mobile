import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/domain/rbac/roles.dart';
import '../../auth/presentation/providers/session_provider.dart';
import '../../dispatches/dispatch_list_screen.dart';
import '../../orders/order_list_screen.dart';
import '../shared/profile_tab.dart';
import '../shared/role_shell.dart';

class BuyerDashboard extends StatelessWidget {
  const BuyerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      role: AppRole.buyer,
      navItems: [
        RoleNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
          screen: _CustomerHomeTab(),
        ),
        RoleNavItem(
          icon: Icons.shopping_bag_outlined,
          activeIcon: Icons.shopping_bag_rounded,
          label: 'Orders',
          screen: OrderListScreen(),
        ),
        RoleNavItem(
          icon: Icons.location_on_outlined,
          activeIcon: Icons.location_on_rounded,
          label: 'Track',
          screen: DispatchListScreen(),
        ),
        RoleNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
          screen: _CustomerProfileTab(),
        ),
      ],
    );
  }
}

class _CustomerHomeTab extends ConsumerWidget {
  const _CustomerHomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;

    return RefreshIndicator(
      onRefresh: () async {},
      color: AppColors.primaryMain,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Hello, ${user?.firstName ?? 'there'}',
            style: AppTypography.h2,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Track your orders and deliveries.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Quick-access cards
          _SectionTitle('My Activity'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ActivityCard(
                  icon: Icons.shopping_bag_outlined,
                  label: 'My Orders',
                  iconColor: AppColors.blue600,
                  iconBg: AppColors.blue100,
                  onTap: () => ref
                      .read(roleTabIndexProvider(AppRole.buyer).notifier)
                      .state = 1,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ActivityCard(
                  icon: Icons.local_shipping_outlined,
                  label: 'Track Delivery',
                  iconColor: AppColors.teal700,
                  iconBg: AppColors.teal100,
                  onTap: () => ref
                      .read(roleTabIndexProvider(AppRole.buyer).notifier)
                      .state = 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Join as section
          _SectionTitle('Join GreenRoot'),
          const SizedBox(height: AppSpacing.md),
          _JoinCard(
            icon: Icons.local_florist_rounded,
            title: 'Register as Nursery Owner',
            subtitle: 'List your nursery and manage operations',
            iconColor: AppColors.primaryMain,
            iconBg: AppColors.forest100,
            onTap: () => context.push('/register/nursery'),
          ),
          const SizedBox(height: AppSpacing.md),
          _JoinCard(
            icon: Icons.local_shipping_rounded,
            title: 'Register as Driver',
            subtitle: 'Join delivery operations and earn',
            iconColor: AppColors.amber600,
            iconBg: AppColors.amber100,
            onTap: () => context.push('/register/driver'),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Invite acceptance
          _SectionTitle('Got an Invite?'),
          const SizedBox(height: AppSpacing.md),
          _JoinCard(
            icon: Icons.mail_outline_rounded,
            title: 'Accept Invite',
            subtitle: 'Enter your invite code to join a nursery',
            iconColor: AppColors.blue600,
            iconBg: AppColors.blue100,
            onTap: () => context.push('/invite/accept'),
          ),
          const SizedBox(height: AppSpacing.x2l),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) =>
      Text(title, style: AppTypography.h4);
}

class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.label,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _JoinCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
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
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CustomerProfileTab extends StatelessWidget {
  const _CustomerProfileTab();

  @override
  Widget build(BuildContext context) =>
      const ProfileTabContent(role: AppRole.buyer);
}

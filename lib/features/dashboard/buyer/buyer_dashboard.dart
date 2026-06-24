import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/domain/rbac/roles.dart';
import '../../auth/presentation/providers/session_provider.dart';
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
          screen: _BuyerHomeTab(),
        ),
        RoleNavItem(
          icon: Icons.shopping_bag_outlined,
          activeIcon: Icons.shopping_bag_rounded,
          label: 'My Orders',
          screen: OrderListScreen(),
        ),
        RoleNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
          screen: _BuyerProfileTab(),
        ),
      ],
    );
  }
}

class _BuyerHomeTab extends ConsumerWidget {
  const _BuyerHomeTab();

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
            'Check your orders and delivery status below.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x3l),
          Center(
            child: Column(
              children: [
                Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.primaryMain.withValues(alpha: 0.4)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your orders will appear here',
                  style: AppTypography.body.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Contact your nursery to place an order.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyerProfileTab extends StatelessWidget {
  const _BuyerProfileTab();

  @override
  Widget build(BuildContext context) =>
      const ProfileTabContent(role: AppRole.buyer);
}

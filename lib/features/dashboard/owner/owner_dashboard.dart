import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/domain/rbac/roles.dart';
import '../../auth/presentation/providers/session_provider.dart';
import '../../inventory/inventory_list_screen.dart';
import '../../orders/order_list_screen.dart';
import '../../requests/request_list_screen.dart';
import '../shared/dashboard_card.dart';
import '../shared/profile_tab.dart';
import '../shared/role_shell.dart';

class OwnerDashboard extends ConsumerWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nurseryId = ref.watch(sessionProvider).nurseryId;
    return RoleShell(
      role: AppRole.nurseryOwner,
      navItems: [
        const RoleNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
          screen: _OwnerHomeTab(),
        ),
        const RoleNavItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          label: 'Requests',
          screen: RequestListScreen(),
        ),
        RoleNavItem(
          icon: Icons.shopping_bag_outlined,
          activeIcon: Icons.shopping_bag_rounded,
          label: 'Orders',
          screen: OrderListScreen(nurseryId: nurseryId),
        ),
        const RoleNavItem(
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2_rounded,
          label: 'Inventory',
          screen: InventoryListScreen(canEdit: true),
        ),
        const RoleNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
          screen: _OwnerProfileTab(),
        ),
      ],
    );
  }
}

class _OwnerHomeTab extends ConsumerWidget {
  const _OwnerHomeTab();

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
          Text('Hello, ${user?.firstName ?? 'Owner'} 👋',
              style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Manage your nursery operations.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Overview', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.15,
            children: [
              DashboardCard(
                title: 'Open Requests',
                value: '—',
                icon: Icons.assignment_outlined,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
                onTap: () => ref
                    .read(roleTabIndexProvider(AppRole.nurseryOwner).notifier)
                    .state = 1,
              ),
              DashboardCard(
                title: 'Active Orders',
                value: '—',
                icon: Icons.shopping_bag_outlined,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
                onTap: () => ref
                    .read(roleTabIndexProvider(AppRole.nurseryOwner).notifier)
                    .state = 2,
              ),
              DashboardCard(
                title: 'Inventory Items',
                value: '—',
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.teal700,
                iconBg: AppColors.teal100,
                onTap: () => ref
                    .read(roleTabIndexProvider(AppRole.nurseryOwner).notifier)
                    .state = 3,
              ),
              DashboardCard(
                title: 'Active Dispatches',
                value: '—',
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
                onTap: () => context.push('/dispatches'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Quick Actions', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.9,
            children: [
              QuickActionCard(
                label: 'Add Inventory',
                icon: Icons.add_circle_outline_rounded,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
                onTap: () => context.push('/inventory/add'),
              ),
              QuickActionCard(
                label: 'View Requests',
                icon: Icons.assignment_outlined,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
                onTap: () => ref
                    .read(roleTabIndexProvider(AppRole.nurseryOwner).notifier)
                    .state = 1,
              ),
              QuickActionCard(
                label: 'Orders',
                icon: Icons.shopping_bag_rounded,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
                onTap: () => ref
                    .read(roleTabIndexProvider(AppRole.nurseryOwner).notifier)
                    .state = 2,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Recent Activity', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          const EmptyActivity(),
          const SizedBox(height: AppSpacing.x2l),
        ],
      ),
    );
  }
}

class _OwnerProfileTab extends StatelessWidget {
  const _OwnerProfileTab();

  @override
  Widget build(BuildContext context) =>
      const ProfileTabContent(role: AppRole.nurseryOwner);
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/domain/rbac/roles.dart';
import '../../auth/presentation/providers/session_provider.dart';
import '../../dispatches/dispatch_list_screen.dart';
import '../../inventory/inventory_list_screen.dart';
import '../../orders/order_list_screen.dart';
import '../shared/dashboard_card.dart';
import '../shared/profile_tab.dart';
import '../shared/role_shell.dart';

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      role: AppRole.manager,
      navItems: [
        RoleNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
          screen: _ManagerHomeTab(),
        ),
        RoleNavItem(
          icon: Icons.shopping_bag_outlined,
          activeIcon: Icons.shopping_bag_rounded,
          label: 'Orders',
          screen: _ManagerOrdersTab(),
        ),
        RoleNavItem(
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2_rounded,
          label: 'Inventory',
          screen: InventoryListScreen(canEdit: true),
        ),
        RoleNavItem(
          icon: Icons.local_shipping_outlined,
          activeIcon: Icons.local_shipping_rounded,
          label: 'Dispatches',
          screen: DispatchListScreen(),
        ),
        RoleNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
          screen: _ManagerProfileTab(),
        ),
      ],
    );
  }
}

class _ManagerHomeTab extends ConsumerWidget {
  const _ManagerHomeTab();

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
          Text('Hello, ${user?.firstName ?? 'Manager'}', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Today's operations at a glance.",
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
                title: 'Orders Today',
                value: '—',
                icon: Icons.shopping_bag_outlined,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
                onTap: () => ref.read(roleTabIndexProvider(AppRole.manager).notifier).state = 1,
              ),
              DashboardCard(
                title: 'Active Dispatches',
                value: '—',
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
                onTap: () => ref.read(roleTabIndexProvider(AppRole.manager).notifier).state = 3,
              ),
              DashboardCard(
                title: 'Inventory Items',
                value: '—',
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.teal700,
                iconBg: AppColors.teal100,
                onTap: () => ref.read(roleTabIndexProvider(AppRole.manager).notifier).state = 2,
              ),
              DashboardCard(
                title: 'Pending Orders',
                value: '—',
                icon: Icons.hourglass_bottom_outlined,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
                onTap: () => ref.read(roleTabIndexProvider(AppRole.manager).notifier).state = 1,
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
                label: 'New Order',
                icon: Icons.add_shopping_cart_rounded,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
                onTap: () => context.push('/orders/create'),
              ),
              QuickActionCard(
                label: 'Inventory',
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.teal700,
                iconBg: AppColors.teal100,
                onTap: () => ref.read(roleTabIndexProvider(AppRole.manager).notifier).state = 2,
              ),
              QuickActionCard(
                label: 'Dispatches',
                icon: Icons.local_shipping_rounded,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
                onTap: () => ref.read(roleTabIndexProvider(AppRole.manager).notifier).state = 3,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
        ],
      ),
    );
  }
}

class _ManagerOrdersTab extends ConsumerWidget {
  const _ManagerOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nurseryId = ref.watch(sessionProvider).nurseryId;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: OrderListScreen(nurseryId: nurseryId),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/orders/create'),
        backgroundColor: AppColors.primaryMain,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _ManagerProfileTab extends StatelessWidget {
  const _ManagerProfileTab();

  @override
  Widget build(BuildContext context) =>
      const ProfileTabContent(role: AppRole.manager);
}

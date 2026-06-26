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
import '../../quotations/quotation_list_screen.dart';
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
        // ── Bottom nav (4 items) ──────────────────────────────────────────
        const RoleNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
          screen: _OwnerHomeTab(),
        ),
        RoleNavItem(
          icon: Icons.shopping_bag_outlined,
          activeIcon: Icons.shopping_bag_rounded,
          label: 'Orders',
          screen: _OwnerOrdersTab(),
        ),
        const RoleNavItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          label: 'Requests',
          screen: RequestListScreen(canCreate: true),
        ),
        const RoleNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
          screen: _OwnerProfileTab(),
        ),
        // ── Drawer-only ───────────────────────────────────────────────────
        const RoleNavItem(
          icon: Icons.description_outlined,
          activeIcon: Icons.description_rounded,
          label: 'Quotations',
          screen: QuotationListScreen(),
          inBottomNav: false,
        ),
        RoleNavItem(
          icon: Icons.local_shipping_outlined,
          activeIcon: Icons.local_shipping_rounded,
          label: 'Dispatches',
          screen: DispatchListScreen(nurseryId: nurseryId),
          inBottomNav: false,
        ),
        const RoleNavItem(
          icon: Icons.manage_accounts_outlined,
          activeIcon: Icons.manage_accounts_rounded,
          label: 'Managers',
          screen: PlaceholderFeatureScreen(
            title: 'Managers',
            icon: Icons.manage_accounts_outlined,
            subtitle:
                'Invite and manage your nursery managers (Gumasthas).',
          ),
          inBottomNav: false,
        ),
        const RoleNavItem(
          icon: Icons.local_shipping_outlined,
          activeIcon: Icons.local_shipping_rounded,
          label: 'Drivers',
          screen: PlaceholderFeatureScreen(
            title: 'Drivers',
            icon: Icons.local_shipping_outlined,
            subtitle: 'Invite and manage connected delivery drivers.',
          ),
          inBottomNav: false,
        ),
        RoleNavItem(
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2_rounded,
          label: 'Inventory',
          screen: const InventoryListScreen(canEdit: true),
          inBottomNav: false,
        ),
        const RoleNavItem(
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront_rounded,
          label: 'Nursery Profile',
          screen: PlaceholderFeatureScreen(
            title: 'Nursery Profile',
            icon: Icons.storefront_outlined,
            subtitle: 'Update your nursery details, location and contact info.',
          ),
          inBottomNav: false,
        ),
      ],
    );
  }
}

// ── Orders tab with FAB ────────────────────────────────────────────────────────

class _OwnerOrdersTab extends ConsumerWidget {
  const _OwnerOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nurseryId = ref.watch(sessionProvider).nurseryId;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: OrderListScreen(nurseryId: nurseryId),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/orders/create'),
        backgroundColor: AppColors.primaryMain,
        tooltip: 'New Order',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ── Home tab ───────────────────────────────────────────────────────────────────

class _OwnerHomeTab extends ConsumerWidget {
  const _OwnerHomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;

    // Tab-index aliases for clarity
    void gotoOrders()      => ref.read(roleTabIndexProvider(AppRole.nurseryOwner).notifier).state = 1;
    void gotoRequests()    => ref.read(roleTabIndexProvider(AppRole.nurseryOwner).notifier).state = 2;
    void gotoQuotations()  => ref.read(roleTabIndexProvider(AppRole.nurseryOwner).notifier).state = 4;
    void gotoDispatches()  => ref.read(roleTabIndexProvider(AppRole.nurseryOwner).notifier).state = 5;
    void gotoManagers()    => ref.read(roleTabIndexProvider(AppRole.nurseryOwner).notifier).state = 6;
    void gotoDrivers()     => ref.read(roleTabIndexProvider(AppRole.nurseryOwner).notifier).state = 7;

    return RefreshIndicator(
      onRefresh: () async {},
      color: AppColors.primaryMain,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text('Hello, ${user?.firstName ?? 'Owner'}',
              style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Manage your nursery operations.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // ── Overview stats ────────────────────────────────────────────
          const Text('Overview', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.05,
            children: [
              DashboardCard(
                title: 'Active Orders',
                value: '—',
                icon: Icons.shopping_bag_outlined,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
                onTap: gotoOrders,
              ),
              DashboardCard(
                title: 'Pending Quotations',
                value: '—',
                icon: Icons.description_outlined,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
                onTap: gotoQuotations,
              ),
              DashboardCard(
                title: 'Open Requests',
                value: '—',
                icon: Icons.assignment_outlined,
                iconColor: AppColors.teal700,
                iconBg: AppColors.teal100,
                onTap: gotoRequests,
              ),
              DashboardCard(
                title: 'Active Dispatches',
                value: '—',
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
                onTap: gotoDispatches,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),

          // ── Quick actions ─────────────────────────────────────────────
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
                label: 'New Quotation',
                icon: Icons.add_comment_outlined,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
                onTap: () => context.push('/quotations/create'),
              ),
              QuickActionCard(
                label: 'New Order',
                icon: Icons.add_shopping_cart_rounded,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
                onTap: () => context.push('/orders/create'),
              ),
              QuickActionCard(
                label: 'Invite Manager',
                icon: Icons.person_add_alt_1_rounded,
                iconColor: AppColors.teal700,
                iconBg: AppColors.teal100,
                onTap: gotoManagers,
              ),
              QuickActionCard(
                label: 'Invite Driver',
                icon: Icons.local_shipping_rounded,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
                onTap: gotoDrivers,
              ),
              QuickActionCard(
                label: 'Inventory',
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
                onTap: () => context.push('/inventory/add'),
              ),
              QuickActionCard(
                label: 'Dispatches',
                icon: Icons.route_rounded,
                iconColor: AppColors.teal700,
                iconBg: AppColors.teal100,
                onTap: gotoDispatches,
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

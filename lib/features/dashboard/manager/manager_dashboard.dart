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
import '../../quotations/quotation_list_screen.dart';
import '../../plant_requests/request_list_screen.dart';
import '../shared/dashboard_card.dart';
import '../shared/profile_tab.dart';
import '../shared/role_shell.dart';

class ManagerDashboard extends ConsumerWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nurseryId = ref.watch(sessionProvider).nurseryId;
    return RoleShell(
      role: AppRole.manager,
      navItems: [
        // ── Bottom nav (4 items) ─────────────────────────────────────────
        const RoleNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
          screen: _ManagerHomeTab(),
        ),
        RoleNavItem(
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2_rounded,
          label: 'Loading',
          screen: _ManagerLoadingTab(),
        ),
        RoleNavItem(
          icon: Icons.local_shipping_outlined,
          activeIcon: Icons.local_shipping_rounded,
          label: 'Dispatches',
          screen: DispatchListScreen(nurseryId: nurseryId),
        ),
        const RoleNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
          screen: _ManagerProfileTab(),
        ),
        // ── Drawer-only ──────────────────────────────────────────────────
        const RoleNavItem(
          icon: Icons.description_outlined,
          activeIcon: Icons.description_rounded,
          label: 'My Quotations',
          screen: QuotationListScreen(),
          inBottomNav: false,
        ),
        RoleNavItem(
          icon: Icons.shopping_bag_outlined,
          activeIcon: Icons.shopping_bag_rounded,
          label: 'My Orders',
          screen: _ManagerAllOrdersTab(),
          inBottomNav: false,
        ),
        const RoleNavItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          label: 'Plant Requests',
          screen: RequestListScreen(canCreate: true),
          inBottomNav: false,
        ),
      ],
    );
  }
}

// ── Loading tab: orders in LOADING or CONFIRMED status ─────────────────────────

class _ManagerLoadingTab extends ConsumerStatefulWidget {
  const _ManagerLoadingTab();

  @override
  ConsumerState<_ManagerLoadingTab> createState() => _ManagerLoadingTabState();
}

class _ManagerLoadingTabState extends ConsumerState<_ManagerLoadingTab> {
  @override
  Widget build(BuildContext context) {
    final nurseryId = ref.watch(sessionProvider).nurseryId;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Loading Queue'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Chip(
              label: const Text(
                'LOADING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.amber700,
                ),
              ),
              backgroundColor: AppColors.amber100,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
      body: OrderListScreen(nurseryId: nurseryId, statusFilter: 'LOADING'),
    );
  }
}

// ── All assigned orders (drawer) ───────────────────────────────────────────────

class _ManagerAllOrdersTab extends ConsumerWidget {
  const _ManagerAllOrdersTab();

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

class _ManagerHomeTab extends ConsumerWidget {
  const _ManagerHomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;

    void gotoLoading()     => ref.read(roleTabIndexProvider(AppRole.manager).notifier).state = 1;
    void gotoDispatches()  => ref.read(roleTabIndexProvider(AppRole.manager).notifier).state = 2;
    void gotoQuotations()  => ref.read(roleTabIndexProvider(AppRole.manager).notifier).state = 4;
    void gotoOrders()      => ref.read(roleTabIndexProvider(AppRole.manager).notifier).state = 5;

    return RefreshIndicator(
      onRefresh: () async {},
      color: AppColors.primaryMain,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text('Hello, ${user?.firstName ?? 'Manager'}',
              style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Today's operations at a glance.",
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // ── Loading banner ────────────────────────────────────────────
          GestureDetector(
            onTap: gotoLoading,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.amber600, AppColors.forest600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded,
                      color: Colors.white, size: 38),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Loading Queue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'View orders ready for loading',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 22),
                ],
              ),
            ),
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
            childAspectRatio: 1.05,
            children: [
              DashboardCard(
                title: 'Assigned Orders',
                value: '—',
                icon: Icons.shopping_bag_outlined,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
                onTap: gotoOrders,
              ),
              DashboardCard(
                title: 'Active Dispatches',
                value: '—',
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
                onTap: gotoDispatches,
              ),
              DashboardCard(
                title: 'Quotations',
                value: '—',
                icon: Icons.description_outlined,
                iconColor: AppColors.teal700,
                iconBg: AppColors.teal100,
                onTap: gotoQuotations,
              ),
              DashboardCard(
                title: 'Loading Today',
                value: '—',
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
                onTap: gotoLoading,
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
                label: 'Loading',
                icon: Icons.inventory_2_rounded,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
                onTap: gotoLoading,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
        ],
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

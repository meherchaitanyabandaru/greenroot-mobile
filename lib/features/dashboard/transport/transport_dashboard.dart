import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/domain/rbac/roles.dart';
import '../../auth/presentation/providers/session_provider.dart';
import '../../dispatches/dispatch_list_screen.dart';
import '../shared/dashboard_card.dart';
import '../shared/profile_tab.dart';
import '../shared/role_shell.dart';

class TransportDashboard extends StatelessWidget {
  const TransportDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      role: AppRole.transportProvider,
      navItems: [
        RoleNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
          screen: _TransportHomeTab(),
        ),
        RoleNavItem(
          icon: Icons.directions_bus_outlined,
          activeIcon: Icons.directions_bus_rounded,
          label: 'Vehicles',
          screen: PlaceholderFeatureScreen(
            title: 'Vehicles',
            icon: Icons.directions_bus_outlined,
            subtitle: 'Manage your fleet of vehicles.',
          ),
        ),
        RoleNavItem(
          icon: Icons.person_pin_outlined,
          activeIcon: Icons.person_pin_rounded,
          label: 'Drivers',
          screen: PlaceholderFeatureScreen(
            title: 'Drivers',
            icon: Icons.person_pin_outlined,
            subtitle: 'Manage drivers and assignments.',
          ),
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
          screen: _TransportProfileTab(),
        ),
      ],
    );
  }
}

class _TransportHomeTab extends ConsumerWidget {
  const _TransportHomeTab();

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
          Text('Hello, ${user?.firstName ?? 'Provider'} 👋', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Manage your transport fleet.',
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
            children: const [
              DashboardCard(
                title: 'Active Vehicles',
                value: '—',
                icon: Icons.directions_bus_outlined,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
              ),
              DashboardCard(
                title: 'Available Drivers',
                value: '—',
                icon: Icons.person_pin_outlined,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
              ),
              DashboardCard(
                title: 'Assigned Dispatches',
                value: '—',
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
              ),
              DashboardCard(
                title: 'Completed Deliveries',
                value: '—',
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.teal700,
                iconBg: AppColors.teal100,
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
            children: const [
              QuickActionCard(
                label: 'Add Vehicle',
                icon: Icons.add_circle_outline_rounded,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
              ),
              QuickActionCard(
                label: 'Assign Driver',
                icon: Icons.person_add_outlined,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
              ),
              QuickActionCard(
                label: 'View Dispatches',
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
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

class _TransportProfileTab extends StatelessWidget {
  const _TransportProfileTab();

  @override
  Widget build(BuildContext context) {
    return const ProfileTabContent(role: AppRole.transportProvider);
  }
}

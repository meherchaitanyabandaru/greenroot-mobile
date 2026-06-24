import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/domain/rbac/roles.dart';
import '../../auth/presentation/providers/session_provider.dart';
import '../shared/dashboard_card.dart';
import '../shared/profile_tab.dart';
import '../shared/role_shell.dart';

class AdminDashboard extends StatelessWidget {
  final AppRole role;
  const AdminDashboard({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      role: role,
      navItems: [
        const RoleNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
          screen: _AdminHomeTab(),
        ),
        const RoleNavItem(
          icon: Icons.store_outlined,
          activeIcon: Icons.store_rounded,
          label: 'Nurseries',
          screen: PlaceholderFeatureScreen(
            title: 'Nurseries',
            icon: Icons.store_outlined,
            subtitle: 'View and manage all nurseries.',
          ),
        ),
        const RoleNavItem(
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart_rounded,
          label: 'Reports',
          screen: PlaceholderFeatureScreen(
            title: 'Reports',
            icon: Icons.bar_chart_outlined,
            subtitle: 'Platform analytics and reports.',
          ),
        ),
        RoleNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
          screen: _AdminProfileTab(role: role),
        ),
      ],
    );
  }
}

class _AdminHomeTab extends ConsumerWidget {
  const _AdminHomeTab();

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
            'Hello, ${user?.firstName ?? 'Admin'} 👋',
            style: AppTypography.h2,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Platform overview at a glance.',
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
                title: 'Active Users',
                value: '—',
                icon: Icons.people_outline_rounded,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
              ),
              DashboardCard(
                title: 'Active Nurseries',
                value: '—',
                icon: Icons.store_outlined,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
              ),
              DashboardCard(
                title: 'Open Requests',
                value: '—',
                icon: Icons.assignment_outlined,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
              ),
              DashboardCard(
                title: 'Active Dispatches',
                value: '—',
                icon: Icons.local_shipping_outlined,
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
                label: 'Users',
                icon: Icons.people_outlined,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
              ),
              QuickActionCard(
                label: 'Nurseries',
                icon: Icons.store_outlined,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
              ),
              QuickActionCard(
                label: 'Reports',
                icon: Icons.bar_chart_outlined,
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

class _AdminProfileTab extends StatelessWidget {
  final AppRole role;
  const _AdminProfileTab({required this.role});

  @override
  Widget build(BuildContext context) {
    return ProfileTabContent(role: role);
  }
}

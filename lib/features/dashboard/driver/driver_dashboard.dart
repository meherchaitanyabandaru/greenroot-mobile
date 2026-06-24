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

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      role: AppRole.driver,
      navItems: [
        RoleNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
          screen: _DriverHomeTab(),
        ),
        RoleNavItem(
          icon: Icons.route_outlined,
          activeIcon: Icons.route_rounded,
          label: 'My Trips',
          screen: DispatchListScreen(),
        ),
        RoleNavItem(
          icon: Icons.delivery_dining_outlined,
          activeIcon: Icons.delivery_dining_rounded,
          label: 'Active Trip',
          screen: PlaceholderFeatureScreen(
            title: 'Active Trip',
            icon: Icons.delivery_dining_outlined,
            subtitle: 'GPS tracking requires location permissions. Coming soon.',
          ),
        ),
        RoleNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
          screen: _DriverProfileTab(),
        ),
      ],
    );
  }
}

class _DriverHomeTab extends ConsumerWidget {
  const _DriverHomeTab();

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
          Text("Hello, ${user?.firstName ?? 'Driver'} 👋", style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Ready for today's deliveries?",
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Active trip CTA
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryMain, AppColors.forest600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.delivery_dining_rounded,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No Active Trip',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Waiting for dispatch assignment.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
            childAspectRatio: 1.15,
            children: const [
              DashboardCard(
                title: 'Assigned Trips',
                value: '—',
                icon: Icons.route_outlined,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
              ),
              DashboardCard(
                title: 'Active Dispatch',
                value: '—',
                icon: Icons.delivery_dining_outlined,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
              ),
              DashboardCard(
                title: 'Completed Trips',
                value: '—',
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.teal700,
                iconBg: AppColors.teal100,
              ),
              DashboardCard(
                title: 'Pending Delivery',
                value: '—',
                icon: Icons.pending_outlined,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Recent Activity', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          const EmptyActivity(message: 'No trips yet today'),
          const SizedBox(height: AppSpacing.x2l),
        ],
      ),
    );
  }
}

class _DriverProfileTab extends StatelessWidget {
  const _DriverProfileTab();

  @override
  Widget build(BuildContext context) {
    return const ProfileTabContent(role: AppRole.driver);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/domain/rbac/roles.dart';
import '../../auth/presentation/providers/session_provider.dart';
import '../../dispatches/dispatches.dart';
import '../../drivers/driver_trips_screen.dart';
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
        // ── Bottom nav (3 items) ──────────────────────────────────────────
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
          screen: DriverTripsScreen(),
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

// ── Home tab ───────────────────────────────────────────────────────────────────

class _DriverHomeTab extends ConsumerStatefulWidget {
  const _DriverHomeTab();

  @override
  ConsumerState<_DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends ConsumerState<_DriverHomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dispatchListProvider.notifier).load(statusFilter: 'IN_TRANSIT');
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final user = ref.watch(sessionProvider).user;
    final dispState = ref.watch(dispatchListProvider);
    final paged = dispState.paged;
    final inTransit = paged.items
        .where((d) => d.status == 'IN_TRANSIT' || d.status == 'ASSIGNED')
        .toList();
    final hasActive = inTransit.isNotEmpty;

    void gotoTrips() =>
        ref.read(roleTabIndexProvider(AppRole.driver).notifier).state = 1;

    return RefreshIndicator(
      onRefresh: () async {
        ref
            .read(dispatchListProvider.notifier)
            .load(statusFilter: 'IN_TRANSIT');
      },
      color: AppColors.primaryMain,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text("Hello, ${user?.firstName ?? 'Driver'}",
              style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Ready for today's deliveries?",
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // ── Active trip banner ────────────────────────────────────────
          if (hasActive) ...[
            _ActiveTripBanner(dispatch: inTransit.first),
          ] else ...[
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
                  const Icon(Icons.delivery_dining_rounded,
                      color: Colors.white, size: 40),
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
          ],
          const SizedBox(height: AppSpacing.x2l),

          const Text('Overview', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.1,
            children: [
              DashboardCard(
                title: 'Assigned Trips',
                value: '—',
                icon: Icons.route_outlined,
                iconColor: AppColors.primaryMain,
                iconBg: AppColors.forest100,
                onTap: gotoTrips,
              ),
              DashboardCard(
                title: 'Active Trip',
                value: hasActive ? '${inTransit.length}' : '0',
                icon: Icons.delivery_dining_outlined,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
                onTap: gotoTrips,
              ),
              const DashboardCard(
                title: 'Completed',
                value: '—',
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.teal700,
                iconBg: AppColors.teal100,
              ),
              const DashboardCard(
                title: 'Pending',
                value: '—',
                icon: Icons.pending_outlined,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Recent Trips', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          const EmptyActivity(message: 'No trips yet today'),
          const SizedBox(height: AppSpacing.x2l),
        ],
      ),
    );
  }
}

class _ActiveTripBanner extends StatelessWidget {
  final Dispatch dispatch;
  const _ActiveTripBanner({required this.dispatch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.amber600, AppColors.forest600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.delivery_dining_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  dispatch.dispatchCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dispatch.status.replaceAll('_', ' '),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (dispatch.destinationAddress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dispatch.destinationAddress!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push(
                '/dispatches/${dispatch.id}/track?driver=true',
                extra: dispatch,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.amber600,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('Open Active Trip'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverProfileTab extends ConsumerWidget {
  const _DriverProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        children: [
          const ProfileTabContent(role: AppRole.driver),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Driver Documents', style: AppTypography.h4),
                const SizedBox(height: AppSpacing.md),
                ProfileTile(
                  icon: Icons.badge_outlined,
                  title: 'Driving Licence',
                  subtitle: 'Upload or update your licence photo',
                  onTap: () {},
                ),
                ProfileTile(
                  icon: Icons.directions_car_outlined,
                  title: 'Vehicle Details',
                  subtitle: 'Update vehicle number and type',
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.x2l),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

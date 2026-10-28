import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/next_action_pulse.dart';
import '../../core/domain/lifecycle_presenter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/green_root_app_bar.dart';
import '../../core/widgets/universal_qr_screen.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dispatches/dispatches.dart';
import '../notifications/notifications.dart';
import '../tracking/tracking.dart';
import 'trip_tracker.dart';

part 'driver_home_active_trip.dart';
part 'driver_home_trip_cards.dart';

// ── Exported: whether the driver currently has an active trip ──────────────────
// Used by the bottom nav to gate the QR scan button without an extra API call.
// Returns false when the dashboard hasn't loaded yet (safe default: allow UI).
final driverHasActiveTripProvider = Provider.autoDispose<bool>(
  (ref) =>
      ref.watch(_driverDashboardProvider).valueOrNull?.tripState.trip != null,
);

// ── Dashboard data model ───────────────────────────────────────────────────────

class _DashboardData {
  final ActiveTripState tripState;
  final int pendingCount;
  final int deliveredCount;
  final AppNotification? latestNotification;

  const _DashboardData({
    required this.tripState,
    required this.pendingCount,
    required this.deliveredCount,
    required this.latestNotification,
  });
}

// ── Dashboard provider — 2 parallel API calls ──────────────────────────────────

final _driverDashboardProvider =
    FutureProvider.autoDispose<_DashboardData>((ref) async {
  // Rebuild whenever trip screens refresh the active trip (accept, start,
  // deliver...); otherwise home kept showing "No Active Trip" after accepting.
  ref.watch(activeDriverTripProvider);
  final dispatchRepo = ref.read(dispatchRepositoryProvider);
  final notifRepo = ref.read(notificationRepositoryProvider);

  final results = await Future.wait([
    dispatchRepo.listDispatches(page: 1, perPage: 50),
    notifRepo.listNotifications(page: 1, perPage: 1),
  ]);

  final dispatches = (results[0] as (List<Dispatch>, dynamic)).$1;
  final notifications = (results[1] as (List<AppNotification>, dynamic, int)).$1;

  const activeStatuses = {'ACCEPTED', 'DISPATCHED', 'IN_TRANSIT'};
  final active =
      dispatches.where((d) => activeStatuses.contains(d.status)).toList();

  // The tracked trip left the active list (delivered or cancelled): stop now.
  // A trip only just started is still active here, so it is not stopped.
  final tracked = TripTracker.instance.dispatchId;
  if (tracked != null && !active.any((d) => d.id == tracked)) {
    unawaited(TripTracker.instance.end(tracked));
  }

  ActiveTripState tripState;
  if (active.length > 1) {
    tripState = const ActiveTripState(
        trip: null, result: ActiveTripResult.integrityError,);
  } else if (active.isNotEmpty) {
    tripState =
        ActiveTripState(trip: active.first, result: ActiveTripResult.found);
    // App reopened mid-trip: keep sharing the location.
    if (active.first.status == 'IN_TRANSIT') {
      unawaited(TripTracker.instance
          .start(active.first.id, ref.read(trackingRepositoryProvider)),);
    }
  } else {
    tripState =
        const ActiveTripState(trip: null, result: ActiveTripResult.none);
  }

  return _DashboardData(
    tripState: tripState,
    pendingCount: dispatches.where((d) => d.status == 'PENDING').length,
    deliveredCount: dispatches.where((d) => d.status == 'DELIVERED').length,
    latestNotification: notifications.firstOrNull,
  );
});

// ── Root screen ────────────────────────────────────────────────────────────────

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(_driverDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GreenRootAppBar(),
      body: RefreshIndicator(
        color: AppColors.primaryMain,
        displacement: 20,
        onRefresh: () async {
          ref.invalidate(_driverDashboardProvider);
          await ref.read(notificationListProvider.notifier).load();
        },
        child: dashAsync.when(
          loading: () => const _DashboardSkeleton(),
          error: (_, __) => _OfflineState(
              onRetry: () => ref.invalidate(_driverDashboardProvider),),
          data: (data) => _DashboardBody(data: data),
        ),
      ),
    );
  }
}

// ── Dashboard body ─────────────────────────────────────────────────────────────

class _DashboardBody extends ConsumerWidget {
  final _DashboardData data;
  const _DashboardBody({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = data.tripState.trip;
    final session = ref.watch(sessionProvider);
    final firstName = session.user?.name?.split(' ').first ?? 'Driver';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + 100,
      ),
      children: [
        Text(
          greeting,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        Text(firstName, style: AppTypography.h2),
        const SizedBox(height: AppSpacing.md),
        // Active trip always takes priority.
        if (trip != null) ...[
          if (trip.status == 'ACCEPTED' || trip.status == 'DISPATCHED') ...[
            _ReadyToDepartCard(trip: trip),
            const SizedBox(height: AppSpacing.md),
            const _DepartTip(),
          ] else ...[
            _ActiveTripCard(trip: trip),
            const SizedBox(height: AppSpacing.md),
            _ActiveTripActions(trip: trip),
            const SizedBox(height: AppSpacing.md),
            const _ActiveTripTip(),
          ],
        ] else ...[
          const _NoTripCard(),
          const SizedBox(height: AppSpacing.md),
          const _HowItWorksCard(),
        ],
      ],
    );
  }
}

// ── No active trip card — unified join card ────────────────────────────────────

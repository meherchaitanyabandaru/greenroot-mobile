import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/domain/lifecycle_presenter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/green_root_app_bar.dart';
import '../../core/widgets/status_badge.dart';
import '../dispatches/dispatches.dart';
import 'driver_trip_map_screen.dart';

// ── Screen ─────────────────────────────────────────────────────────────────────

class DriverTripsScreen extends ConsumerStatefulWidget {
  const DriverTripsScreen({super.key});

  @override
  ConsumerState<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends ConsumerState<DriverTripsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch history count for the badge
    final historyAsync = ref.watch(_historyProvider);
    final historyCount = historyAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GreenRootAppBar(
        title: 'My Trips',
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryMain,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryMain,
          indicatorWeight: 2.5,
          tabs: [
            const Tab(text: 'Active'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('History'),
                  if (historyCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$historyCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // Disable swiping so map gestures don't conflict with tab swipes
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _ActiveTab(),
          _HistoryTab(),
        ],
      ),
    );
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────

// Separate provider for history list (DELIVERED + CANCELLED)
final _historyProvider =
    FutureProvider.autoDispose<List<Dispatch>>((ref) async {
  final repo = ref.watch(dispatchRepositoryProvider);
  final (dispatches, _) = await repo.listDispatches(page: 1, perPage: 100);
  return dispatches
      .where((d) => d.status == 'DELIVERED' || d.status == 'CANCELLED')
      .toList()
    ..sort((a, b) =>
        (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));
});

// ── Active tab ─────────────────────────────────────────────────────────────────

class _ActiveTab extends ConsumerWidget {
  const _ActiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeDriverTripProvider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryMain),
      ),
      error: (err, _) => _centred(
        icon: Icons.error_outline_rounded,
        title: 'Could not load trip',
        subtitle: err.toString(),
        action: FilledButton.icon(
          onPressed: () => ref.invalidate(activeDriverTripProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryMain),
        ),
      ),
      data: (state) {
        switch (state.result) {
          case ActiveTripResult.integrityError:
            return _centred(
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.amber600,
              title: 'Multiple active trips',
              subtitle:
                  'More than one active trip was found. Please contact support.',
            );

          case ActiveTripResult.none:
            return _centred(
              icon: Icons.local_shipping_outlined,
              title: 'No active trip',
              subtitle: 'You have no active trip at the moment.',
            );

          case ActiveTripResult.found:
            final trip = state.trip!;
            // Embed the full trip map body directly — no navigation needed
            return DriverTripMapBody(
              key: ValueKey('active-${trip.id}-${trip.status}'),
              dispatch: trip,
              dispatchId: trip.id,
            );
        }
      },
    );
  }

  Widget _centred({
    required IconData icon,
    required String title,
    required String subtitle,
    Color iconColor = AppColors.textMuted,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: iconColor),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTypography.h4, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

// ── History tab ────────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_historyProvider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryMain),
      ),
      error: (err, _) => _RetryView(
        message: err.toString(),
        onRetry: () => ref.invalidate(_historyProvider),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              const SizedBox(height: 120),
              const Icon(Icons.history_rounded,
                  size: 52, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              const Text('No trip history',
                  style: AppTypography.h4, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Completed and cancelled trips will appear here.',
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          );
        }

        // Group by month for better scannability
        return RefreshIndicator(
          color: AppColors.primaryMain,
          onRefresh: () async => ref.invalidate(_historyProvider),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.md,
              AppSpacing.screenPadding,
              AppSpacing.x2l,
            ),
            itemCount: trips.length,
            itemBuilder: (context, i) {
              final trip = trips[i];
              final showHeader = i == 0 ||
                  _monthOf(trips[i].createdAt) !=
                      _monthOf(trips[i - 1].createdAt);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader) ...[
                    if (i != 0) const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
                      child: Text(
                        _monthOf(trip.createdAt),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                  _HistoryTripCard(trip: trip),
                  const SizedBox(height: AppSpacing.sm),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _monthOf(String isoDate) {
    try {
      return DateFormat('MMMM yyyy').format(DateTime.parse(isoDate).toLocal());
    } catch (_) {
      return '';
    }
  }
}

// ── History trip card ──────────────────────────────────────────────────────────

class _HistoryTripCard extends StatelessWidget {
  final Dispatch trip;
  const _HistoryTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final display = LifecyclePresenter.forDispatch(
      dispatch: trip,
      role: LifecycleRole.driver,
    );
    final dateStr = _formatDate(trip.updatedAt ?? trip.createdAt);
    final isDelivered = trip.status == 'DELIVERED';

    return InkWell(
      onTap: () => context.push('/driver/trip/${trip.id}'),
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDelivered ? AppColors.forest100 : AppColors.border,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDelivered
                    ? Icons.check_circle_rounded
                    : Icons.cancel_outlined,
                color:
                    isDelivered ? AppColors.primaryMain : AppColors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Trip info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.dispatchCode,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                  if (trip.destinationAddress?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            trip.destinationAddress!,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Status badge + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(
                  label: display.label,
                  variant: display.variant,
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      return DateFormat('dd MMM yyyy')
          .format(DateTime.parse(isoDate).toLocal());
    } catch (_) {
      return '';
    }
  }
}

// ── Retry view ─────────────────────────────────────────────────────────────────

class _RetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _RetryView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                style: AppTypography.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryMain),
            ),
          ],
        ),
      ),
    );
  }
}

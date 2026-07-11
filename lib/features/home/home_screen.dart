import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/main_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/green_root_app_bar.dart';
import '../../core/widgets/qr_scanner_screen.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../buyer/buyer_home.dart';
import '../dashboard/owner/owner_dashboard_data.dart';
import '../dispatches/dispatches.dart';
import '../manager/manager_home.dart';
import '../owner/owner_home.dart';
import '../drivers/trip_preview_screen.dart';
import '../notifications/notifications.dart';
import '../orders/orders.dart';
import '../quotations/quotations.dart';
import '../plant_requests/requests.dart';
import '../subscriptions/trial_banner_widget.dart';

final _operationsHomeProvider =
    FutureProvider.autoDispose<_OperationsHomeData>((ref) async {
  final session = ref.watch(sessionProvider);
  final caps = session.capabilities;
  final nurseryId = session.nurseryId ?? caps.primaryNurseryId;
  final orderRepo = ref.watch(orderRepositoryProvider);
  final dispatchRepo = ref.watch(dispatchRepositoryProvider);
  final requestRepo = ref.watch(requestRepositoryProvider);
  final dashboardRepo = ref.watch(ownerDashboardRepositoryProvider);

  var dashboard = OwnerDashboardData.empty;
  var orders = <Order>[];
  var dispatches = <Dispatch>[];
  var requests = <PlantRequest>[];

  if (caps.isNurseryOwner) {
    try {
      dashboard = await dashboardRepo.fetch();
    } catch (_) {}
  }
  try {
    final (items, _) = await orderRepo.listOrders(
      page: 1,
      perPage: 30,
      nurseryId: nurseryId,
    );
    orders = items;
  } catch (_) {}
  try {
    final (items, _) = await dispatchRepo.listDispatches(
      page: 1,
      perPage: 30,
      nurseryId: nurseryId,
    );
    dispatches = items;
  } catch (_) {}
  try {
    final (items, _) = await requestRepo.listRequests(page: 1, perPage: 30);
    requests = items;
  } catch (_) {}

  return _OperationsHomeData(
    nurseryId: nurseryId,
    dashboard: dashboard,
    orders: orders,
    dispatches: dispatches,
    requests: requests,
  );
});

final _driverHomeProvider =
    FutureProvider.autoDispose<_DriverHomeData>((ref) async {
  final repo = ref.watch(dispatchRepositoryProvider);
  try {
    final (items, _) = await repo.listDispatches(page: 1, perPage: 50);
    return _DriverHomeData(items);
  } catch (_) {
    return const _DriverHomeData([]);
  }
});


class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final caps = session.capabilities;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const GreenRootAppBar(),
      body: RefreshIndicator(
        color: AppColors.primaryMain,
        onRefresh: () async {
          await ref.read(sessionProvider.notifier).bootstrap();
          ref.invalidate(_operationsHomeProvider);
          ref.invalidate(_driverHomeProvider);
          ref.invalidate(buyerHomeProvider);
          ref.invalidate(notificationListProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          children: [
            _GreetingBlock(caps: caps, firstName: session.user?.firstName),
              const SizedBox(height: 20),
              const TrialExpiryBanner(),
              if (caps.isDriverOnly)
                const _DriverHome()
              else if (caps.isNurseryOwner)
                const OwnerHome()
              else if (caps.isManager)
                const ManagerHome()
              else
                const BuyerHome(),
            ],
          ),
        ),
    );
  }
}

class _DriverHome extends ConsumerWidget {
  const _DriverHome();

  Future<void> _openQrScanner(BuildContext context) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(title: 'Scan Trip QR'),
        fullscreenDialog: true,
      ),
    );
    if (code != null && code.isNotEmpty && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TripPreviewScreen(code: code),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data =
        ref.watch(_driverHomeProvider).valueOrNull ?? const _DriverHomeData([]);
    final trips = data.dispatches;
    final active = data.activeTrip;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryCard(
          items: [
            _SummaryItem(
              icon: Icons.local_shipping_outlined,
              value: '${data.upcoming + data.active}',
              label: 'Assigned',
              sub: 'view',
              color: AppColors.primaryMain,
              onTap: () => ref.read(mainTabIndexProvider.notifier).state = 1,
            ),
            _SummaryItem(
              icon: Icons.my_location_outlined,
              value: '${data.active}',
              label: 'In Progress',
              sub: 'view',
              color: AppColors.blue600,
              onTap: () => ref.read(mainTabIndexProvider.notifier).state = 1,
            ),
            _SummaryItem(
              icon: Icons.inventory_2_outlined,
              value: '${data.completed}',
              label: 'Delivered',
              sub: 'view',
              color: AppColors.amber600,
              onTap: () => ref.read(mainTabIndexProvider.notifier).state = 1,
            ),
            _SummaryItem(
              icon: Icons.cancel_outlined,
              value: '${data.cancelled}',
              label: 'Cancelled',
              sub: 'view',
              color: AppColors.purple700,
              onTap: () => ref.read(mainTabIndexProvider.notifier).state = 1,
            ),
          ],
        ),
        const SizedBox(height: 22),
        _CurrentTripCard(dispatch: active),
        const SizedBox(height: 22),
        _DriverActionGrid(
          onTrips: () => ref.read(mainTabIndexProvider.notifier).state = 1,
          onJoin: () => _openQrScanner(context),
          onTrack: active == null
              ? null
              : () => context.push(
                    '/dispatches/${active.id}/track?driver=true',
                    extra: active,
                  ),
        ),
        const SizedBox(height: 22),
        _SectionHeader(
          title: 'My Trips Today',
          actionLabel: 'View All',
          onAction: () => ref.read(mainTabIndexProvider.notifier).state = 1,
        ),
        const SizedBox(height: 12),
        _TripPanel(trips: trips.take(3).toList()),
        const SizedBox(height: 18),
        const _SafetyBanner(),
      ],
    );
  }
}


class _GreetingBlock extends StatelessWidget {
  final dynamic caps;
  final String? firstName;

  const _GreetingBlock({required this.caps, this.firstName});

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    final name = firstName?.isNotEmpty == true ? firstName! : 'there';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_timeGreeting, $name 👋',
          style: AppTypography.h2.copyWith(fontSize: 20, height: 1.2),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          _roleSubtitle(caps),
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RolePill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _RolePill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.primaryMain.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryMain, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.primaryMain,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleDashboardHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String primaryLabel;
  final String primaryValue;
  final String secondaryLabel;
  final String secondaryValue;
  final VoidCallback onTap;

  const _RoleDashboardHero({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryLabel,
    required this.primaryValue,
    required this.secondaryLabel,
    required this.secondaryValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(bg: AppColors.forest50),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.h3.copyWith(
                      color: AppColors.primaryMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _HeroMetric(label: primaryLabel, value: primaryValue),
                      const SizedBox(width: 14),
                      _HeroMetric(label: secondaryLabel, value: secondaryValue),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: AppColors.primaryMain, size: 38),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.forest100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTypography.h2.copyWith(height: 1)),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTypography.h3)),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: AppColors.primaryMain,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: AppColors.primaryMain,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<_SummaryItem> items;

  const _SummaryCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              items[i],
              if (i != items.length - 1)
                const SizedBox(
                  height: 116,
                  child: VerticalDivider(width: 1, color: AppColors.border),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 112,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(height: 9),
              Text(value, style: AppTypography.h2.copyWith(height: 1)),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Text(
                sub,
                style: AppTypography.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskStrip extends StatelessWidget {
  final List<_TaskItem> tasks;

  const _TaskStrip({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(bg: AppColors.forest50),
      child: Row(
        children: [
          for (var i = 0; i < tasks.length; i++) ...[
            Expanded(child: tasks[i]),
            if (i != tasks.length - 1)
              const SizedBox(
                height: 92,
                child: VerticalDivider(width: 1, color: AppColors.border),
              ),
          ],
        ],
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final VoidCallback onTap;

  const _TaskItem(this.title, this.count, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Badge.count(
              count: count,
              isLabelVisible: count > 0,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.forest100,
                child: Icon(icon, color: AppColors.primaryMain),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              title,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              'Tap to view',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconActionRow extends StatelessWidget {
  final List<_IconAction> actions;

  const _IconActionRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions
          .map(
            (a) => Expanded(
              child: InkWell(
                onTap: a.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.forest100,
                        child: Icon(a.icon, color: AppColors.primaryMain),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.label,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _IconAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _IconAction(this.label, this.icon, this.onTap);
}

class _OrderPanel extends StatelessWidget {
  final List<Order> orders;

  const _OrderPanel({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.shopping_bag_outlined,
        title: 'No active orders',
      );
    }
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < orders.length; i++) ...[
            _OrderRow(order: orders[i]),
            if (i != orders.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Order order;

  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final firstItem = order.items.firstOrNull;
    final itemName = firstItem?.displayName ?? 'Plant order';
    final qty = firstItem == null
        ? ''
        : ' - ${firstItem.quantity.toStringAsFixed(0)} Nos';

    return InkWell(
      onTap: () => context.push('/orders/${order.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.forest50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_florist_rounded,
                color: AppColors.primaryMain,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(order.orderNumber, style: AppTypography.h4),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: _prettyStatus(order.status),
                        variant: badgeVariantFromStatus(order.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$itemName$qty',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (order.buyerName?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            order.buyerName!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _LiveDispatchCard extends StatelessWidget {
  final Dispatch? dispatch;

  const _LiveDispatchCard({required this.dispatch});

  @override
  Widget build(BuildContext context) {
    if (dispatch == null) return const SizedBox.shrink();
    final d = dispatch!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(bg: AppColors.forest50),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.primaryMain,
                    ),
                    const SizedBox(width: 8),
                    Text('Live Dispatch', style: AppTypography.h4),
                    const SizedBox(width: 8),
                    const StatusBadge(
                        label: 'In Transit', variant: BadgeVariant.success),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Trip ID: ${d.dispatchCode}',
                    style: AppTypography.bodySmall),
                const SizedBox(height: 5),
                Text(
                  d.destinationAddress ?? 'Destination pending',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push('/dispatches/${d.id}/track'),
                  icon: const Icon(Icons.location_on_outlined, size: 18),
                  label: const Text('View Live Location'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _MapPreview(width: 150, height: 112),
        ],
      ),
    );
  }
}

class _CurrentTripCard extends StatelessWidget {
  final Dispatch? dispatch;

  const _CurrentTripCard({required this.dispatch});

  @override
  Widget build(BuildContext context) {
    if (dispatch == null) {
      return const _EmptyPanel(
        icon: Icons.route_outlined,
        title: 'No current trip',
        subtitle: 'Join a trip with QR or code when assigned.',
      );
    }
    final d = dispatch!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(bg: AppColors.forest50),
      child: Column(
        children: [
          Row(
            children: [
              Text('Current Trip', style: AppTypography.h3),
              const SizedBox(width: 10),
              StatusBadge(
                label: _prettyStatus(d.status),
                variant: badgeVariantFromStatus(d.status),
              ),
              const Spacer(),
              Text(
                'Trip ID: ${d.dispatchCode}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _TripPoint(
                      icon: Icons.circle,
                      color: AppColors.primaryMain,
                      title: 'Loading Point',
                      subtitle: d.orderNumber ?? 'Order assigned',
                    ),
                    _TripPoint(
                      icon: Icons.local_shipping_rounded,
                      color: AppColors.primaryMain,
                      title: 'En Route',
                      subtitle: 'On the way to delivery point',
                    ),
                    _TripPoint(
                      icon: Icons.location_on,
                      color: AppColors.red600,
                      title: 'Delivery Point',
                      subtitle: d.destinationAddress ?? 'Destination pending',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  const _MapPreview(width: 140, height: 132),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/dispatches/${d.id}/track?driver=true',
                      extra: d,
                    ),
                    icon: const Icon(Icons.location_on_outlined, size: 16),
                    label: const Text('Live Location'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripPoint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _TripPoint({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.bodySmall
                        .copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverActionGrid extends StatelessWidget {
  final VoidCallback onTrips;
  final VoidCallback onJoin;
  final VoidCallback? onTrack;

  const _DriverActionGrid({
    required this.onTrips,
    required this.onJoin,
    this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DriverActionCard(
            title: 'Start Trip',
            subtitle: 'QR / OTP',
            icon: Icons.play_arrow_rounded,
            onTap: onJoin,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DriverActionCard(
            title: 'Update Status',
            subtitle: 'Trip actions',
            icon: Icons.list_alt_rounded,
            onTap: onTrips,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DriverActionCard(
            title: 'Track',
            subtitle: 'Live route',
            icon: Icons.my_location_rounded,
            onTap: onTrack ?? onTrips,
          ),
        ),
      ],
    );
  }
}

class _DriverActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _DriverActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: AppColors.forest100,
                child: Icon(icon, color: AppColors.primaryMain),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripPanel extends StatelessWidget {
  final List<Dispatch> trips;

  const _TripPanel({required this.trips});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return const _EmptyPanel(
          icon: Icons.route_outlined, title: 'No trips yet');
    }
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < trips.length; i++) ...[
            _TripRow(index: i + 1, dispatch: trips[i]),
            if (i != trips.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final int index;
  final Dispatch dispatch;

  const _TripRow({required this.index, required this.dispatch});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/dispatches/${dispatch.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: AppTypography.h4.copyWith(
                    color: AppColors.primaryMain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(dispatch.dispatchCode,
                            style: AppTypography.h4),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: _prettyStatus(dispatch.status),
                        variant: badgeVariantFromStatus(dispatch.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dispatch.destinationAddress ??
                        dispatch.orderNumber ??
                        'Delivery trip',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amber50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.health_and_safety_outlined,
              color: AppColors.amber600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Drive Safe!', style: AppTypography.h4),
                const SizedBox(height: 4),
                Text(
                  'Your safety is important. Follow traffic rules.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.local_shipping_rounded,
              color: AppColors.primaryMain),
        ],
      ),
    );
  }
}

class _CustomerLifecycleHero extends StatelessWidget {
  final List<Quotation> quotations;
  final List<Order> orders;
  final Order? activeOrder;
  final VoidCallback onQuotes;
  final VoidCallback onOrders;
  final VoidCallback onTracking;

  const _CustomerLifecycleHero({
    required this.quotations,
    required this.orders,
    required this.activeOrder,
    required this.onQuotes,
    required this.onOrders,
    required this.onTracking,
  });

  @override
  Widget build(BuildContext context) {
    final awaitingQuotes = quotations.where(_isCustomerQuoteAwaiting).length;
    final activeOrders = orders.where(_isActiveOrder).length;
    final trackableOrders = orders.where(_isTrackableOrder).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(bg: AppColors.forest50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Dashboard',
                      style: AppTypography.h3.copyWith(
                        color: AppColors.primaryMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activeOrder == null
                          ? 'Review quotes and follow your order lifecycle.'
                          : 'Your active order is ${_prettyStatus(activeOrder!.status).toLowerCase()}.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: AppColors.primaryMain,
                  size: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroActionMetric(
                  label: 'Quotes',
                  value: '$awaitingQuotes',
                  icon: Icons.request_quote_outlined,
                  onTap: onQuotes,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroActionMetric(
                  label: 'Orders',
                  value: '$activeOrders',
                  icon: Icons.receipt_long_outlined,
                  onTap: onOrders,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroActionMetric(
                  label: 'Track',
                  value: '$trackableOrders',
                  icon: Icons.map_outlined,
                  onTap: onTracking,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroActionMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _HeroActionMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.forest100),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryMain, size: 22),
            const SizedBox(height: 8),
            Text(value, style: AppTypography.h2.copyWith(height: 1)),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

bool _isCustomerQuoteAwaiting(Quotation quotation) {
  return {'SENT', 'CUSTOMER_SENT'}.contains(quotation.status);
}

bool _isActiveOrder(Order order) {
  return !{'DELIVERED', 'COMPLETED', 'CANCELLED'}.contains(order.status);
}

bool _isTrackableOrder(Order order) {
  return {
    'LOADING',
    'LOADED',
    'PARTIALLY_FULFILLED',
    'COMPLETED',
    'DELIVERED',
  }.contains(order.status);
}

class _QuoteCards extends StatelessWidget {
  final List<Quotation> quotations;

  const _QuoteCards({required this.quotations});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniMetricCard(
            icon: Icons.schedule_rounded,
            value: '${quotations.where(_isCustomerQuoteAwaiting).length}',
            label: 'Awaiting Response',
            color: AppColors.amber600,
            onTap: () => context.push('/quotations'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniMetricCard(
            icon: Icons.check_circle_outline_rounded,
            value: '${quotations.where((q) => q.status == 'APPROVED').length}',
            label: 'Approved',
            color: AppColors.primaryMain,
            onTap: () => context.push('/quotations'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniMetricCard(
            icon: Icons.cancel_outlined,
            value: '${quotations.where((q) => q.status == 'REJECTED').length}',
            label: 'Rejected',
            color: AppColors.red600,
            onTap: () => context.push('/quotations'),
          ),
        ),
      ],
    );
  }
}

class _OrderStatsGrid extends StatelessWidget {
  final List<Order> orders;

  const _OrderStatsGrid({required this.orders});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniMetricCard(
            icon: Icons.inventory_2_outlined,
            value: '${orders.where(_isActiveOrder).length}',
            label: 'Active',
            color: AppColors.blue600,
            onTap: () => context.push('/orders?status=LOADING'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniMetricCard(
            icon: Icons.local_shipping_outlined,
            value: '${orders.where((o) => {
                  'LOADED',
                  'PARTIALLY_FULFILLED'
                }.contains(o.status)).length}',
            label: 'Ready',
            color: AppColors.amber600,
            onTap: () => context.push('/orders?status=LOADED'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniMetricCard(
            icon: Icons.location_on_outlined,
            value: '${orders.where((o) => {
                  'COMPLETED',
                  'DELIVERED'
                }.contains(o.status)).length}',
            label: 'Completed',
            color: AppColors.primaryMain,
            onTap: () => context.push('/orders?status=COMPLETED'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniMetricCard(
            icon: Icons.receipt_long_outlined,
            value: '${orders.length}',
            label: 'All Orders',
            color: AppColors.purple700,
            onTap: () => context.push('/orders'),
          ),
        ),
      ],
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MiniMetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 9),
            Text(value, style: AppTypography.h2.copyWith(height: 1)),
            const SizedBox(height: 5),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackOrderCard extends StatelessWidget {
  final Order order;

  const _TrackOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final item = order.items.firstOrNull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.primaryMain,
                    ),
                    const SizedBox(width: 9),
                    Text('Track Delivery', style: AppTypography.h3),
                  ],
                ),
                const SizedBox(height: 14),
                Text(order.orderNumber, style: AppTypography.h4),
                const SizedBox(height: 5),
                Text(
                  item == null
                      ? 'Plant order'
                      : '${item.displayName} - ${item.quantity.toStringAsFixed(0)} Nos',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _prettyStatus(order.status),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primaryMain,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              const _MapPreview(width: 150, height: 96),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push('/orders/${order.id}'),
                icon: const Icon(Icons.location_on_outlined, size: 17),
                label: const Text('Track'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerActionCards extends StatelessWidget {
  final VoidCallback onOrders;
  final VoidCallback onBuyPlants;
  final VoidCallback onNursery;
  final VoidCallback onInvite;

  const _CustomerActionCards({
    required this.onOrders,
    required this.onBuyPlants,
    required this.onNursery,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Primary CTA — view quotations from nurseries
        InkWell(
          onTap: onBuyPlants,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryMain,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined,
                    color: Colors.white, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Quotations',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        'Review and accept quotations from nurseries',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Explore row — browse nurseries and plants
        Row(
          children: [
            Expanded(
              child: _SmallLinkCard(
                title: 'Browse Nurseries',
                subtitle: 'Find a nursery near you',
                icon: Icons.storefront_outlined,
                onTap: () => context.push('/nurseries'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallLinkCard(
                title: 'Plant Catalog',
                subtitle: 'Explore available plants',
                icon: Icons.eco_outlined,
                onTap: () => context.push('/plants'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SmallLinkCard(
                title: 'My Orders',
                subtitle: 'View past orders',
                icon: Icons.receipt_long_outlined,
                onTap: onOrders,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallLinkCard(
                title: 'Register Nursery',
                subtitle: 'Become an owner',
                icon: Icons.local_florist_outlined,
                onTap: onNursery,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallLinkCard(
                title: 'Accept Invite',
                subtitle: 'UUID or QR',
                icon: Icons.qr_code_scanner_rounded,
                onTap: onInvite,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SmallLinkCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SmallLinkCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaryMain),
            const SizedBox(height: 12),
            Text(
              title,
              style:
                  AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  final double width;
  final double height;

  const _MapPreview({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: CustomPaint(painter: _RoutePainter()),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryMain
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.78)
      ..lineTo(size.width * 0.34, size.height * 0.58)
      ..lineTo(size.width * 0.52, size.height * 0.64)
      ..lineTo(size.width * 0.68, size.height * 0.38)
      ..lineTo(size.width * 0.86, size.height * 0.22);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = AppColors.primaryMain;
    for (final p in [
      Offset(size.width * 0.16, size.height * 0.78),
      Offset(size.width * 0.52, size.height * 0.64),
      Offset(size.width * 0.86, size.height * 0.22),
    ]) {
      canvas.drawCircle(p, 5, dotPaint);
      canvas.drawCircle(p, 2.5, Paint()..color = Colors.white);
    }
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.48),
      16,
      Paint()..color = AppColors.primaryMain,
    );
    final iconPainter = TextPainter(
      text: const TextSpan(
        text: '>',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(size.width * 0.62 - 6, size.height * 0.48 - 12),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _EmptyPanel({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 38),
          const SizedBox(height: 10),
          Text(title, style: AppTypography.h4),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _OperationsHomeData {
  final int? nurseryId;
  final OwnerDashboardData dashboard;
  final List<Order> orders;
  final List<Dispatch> dispatches;
  final List<PlantRequest> requests;

  const _OperationsHomeData({
    required this.nurseryId,
    required this.dashboard,
    required this.orders,
    required this.dispatches,
    required this.requests,
  });
}

class _DriverHomeData {
  final List<Dispatch> dispatches;
  const _DriverHomeData(this.dispatches);

  // PENDING = assigned but not accepted; ACCEPTED = driver accepted, not yet dispatched
  int get upcoming =>
      dispatches.where((d) => d.status == 'PENDING').length;
  // ACCEPTED + DISPATCHED + IN_TRANSIT all count as "in progress" for driver
  int get active => dispatches
      .where((d) => {'ACCEPTED', 'DISPATCHED', 'IN_TRANSIT'}.contains(d.status))
      .length;
  int get completed => dispatches.where((d) => d.status == 'DELIVERED').length;
  int get cancelled => dispatches.where((d) => d.status == 'CANCELLED').length;
  // Active trip = ACCEPTED (accepted not yet dispatched) or DISPATCHED or IN_TRANSIT
  Dispatch? get activeTrip => dispatches
      .where(
          (d) => {'ACCEPTED', 'DISPATCHED', 'IN_TRANSIT'}.contains(d.status))
      .firstOrNull;
}


BoxDecoration _cardDecoration({Color bg = AppColors.surface}) => BoxDecoration(
      color: bg,
      borderRadius: AppRadius.cardRadius,
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.slate900.withValues(alpha: 0.04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );

IconData _roleIcon(caps) {
  if (caps.isDriverOnly) return Icons.local_shipping_outlined;
  if (caps.isNurseryOwner) return Icons.storefront_outlined;
  if (caps.isManager) return Icons.manage_accounts_outlined;
  return Icons.person_outline_rounded;
}

String _roleSubtitle(caps) {
  if (caps.isDriverOnly) return 'Stay safe on the road. Check your trips below.';
  if (caps.isNurseryOwner)
    return 'Manage orders, team & deliveries for ${caps.ownedNurseryName ?? 'your nursery'}.';
  if (caps.isManager)
    return 'Here\'s what\'s happening at ${caps.primaryNurseryName ?? 'your nursery'} today.';
  return 'Here\'s what\'s happening with your orders today.';
}

String _prettyStatus(String status) => status
    .toLowerCase()
    .split('_')
    .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/main_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dashboard/owner/owner_dashboard_data.dart';
import '../dispatches/dispatches.dart';
import '../notifications/notifications.dart';
import '../orders/orders.dart';
import '../quotations/quotations.dart';
import '../requests/requests.dart';

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

final _buyerHomeProvider =
    FutureProvider.autoDispose<_BuyerHomeData>((ref) async {
  final orderRepo = ref.watch(orderRepositoryProvider);
  final quotationRepo = ref.watch(quotationRepositoryProvider);
  var orders = <Order>[];
  var quotations = <Quotation>[];

  try {
    final (items, _) = await quotationRepo.listBuyingQuotations(
      page: 1,
      perPage: 30,
    );
    quotations = items;
  } catch (_) {}
  try {
    final (items, _) = await orderRepo.listBuyingOrders(page: 1, perPage: 30);
    orders = items;
  } catch (_) {}

  return _BuyerHomeData(orders: orders, quotations: quotations);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final caps = session.capabilities;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryMain,
          onRefresh: () async {
            await ref.read(sessionProvider.notifier).bootstrap();
            ref.invalidate(_operationsHomeProvider);
            ref.invalidate(_driverHomeProvider);
            ref.invalidate(_buyerHomeProvider);
            ref.invalidate(notificationListProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            children: [
              _TopHeader(caps: caps),
              const SizedBox(height: 28),
              _GreetingBlock(caps: caps, firstName: session.user?.firstName),
              const SizedBox(height: 20),
              if (caps.isDriverOnly)
                const _DriverHome()
              else if (caps.isNurseryOwner)
                const _OwnerHome()
              else if (caps.isManager)
                const _ManagerHome()
              else
                const _CustomerHome(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerHome extends ConsumerWidget {
  const _OwnerHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_operationsHomeProvider).valueOrNull;
    final nurseryId = data?.nurseryId;
    final orders = data?.orders ?? const <Order>[];
    final dispatches = data?.dispatches ?? const <Dispatch>[];
    final requests = data?.requests ?? const <PlantRequest>[];
    final dashboard = data?.dashboard ?? OwnerDashboardData.empty;
    final activeOrders = orders
        .where((o) => !{'DELIVERED', 'CANCELLED'}.contains(o.status))
        .take(3)
        .toList();
    final inTransit = dispatches.where((d) => d.status == 'IN_TRANSIT').length;
    final loading = orders.where((o) => o.status == 'LOADING').length;
    final openRequests = requests.where((r) => r.status == 'OPEN').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OwnerPrimaryActions(nurseryId: nurseryId),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Today\'s Summary',
          actionLabel: 'View All',
          onAction: () => context.push(
            nurseryId != null ? '/orders?nursery=$nurseryId' : '/orders',
          ),
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          items: [
            _SummaryItem(
              icon: Icons.shopping_bag_outlined,
              value: '${dashboard.sellOrders.total}',
              label: 'Orders',
              sub: '${dashboard.sellOrders.pending} pending',
              color: AppColors.primaryMain,
              onTap: () => context.push(
                nurseryId != null ? '/orders?nursery=$nurseryId' : '/orders',
              ),
            ),
            _SummaryItem(
              icon: Icons.local_shipping_outlined,
              value: '${dispatches.length}',
              label: 'Dispatches',
              sub: '$inTransit in transit',
              color: AppColors.blue600,
              onTap: () => context.push('/dispatches'),
            ),
            _SummaryItem(
              icon: Icons.inventory_2_outlined,
              value: '$loading',
              label: 'Loading',
              sub: 'in progress',
              color: AppColors.amber600,
              onTap: () => context.push(
                nurseryId != null
                    ? '/orders/loading?nursery=$nurseryId'
                    : '/orders/loading',
              ),
            ),
            _SummaryItem(
              icon: Icons.eco_outlined,
              value: '$openRequests',
              label: 'Requests',
              sub: 'open',
              color: AppColors.teal700,
              onTap: () => context.push('/requests/create'),
            ),
            _SummaryItem(
              icon: Icons.people_outline_rounded,
              value: '${dashboard.connections.total}',
              label: 'Contacts',
              sub:
                  '${dashboard.connections.managers}M ${dashboard.connections.drivers}D',
              color: AppColors.purple700,
              onTap: () => context.push('/connections'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _IconActionRow(
          actions: [
            _IconAction('My Nursery', Icons.storefront_outlined, () {
              if (nurseryId != null) context.push('/nurseries/$nurseryId');
            }),
            _IconAction('Managers', Icons.groups_outlined, () {
              if (nurseryId != null) {
                context.push('/nursery/members?id=$nurseryId&tab=0');
              }
            }),
            _IconAction('Availability', Icons.local_florist_outlined, () {
              context.push('/inventory/add');
            }),
            _IconAction('Customers', Icons.person_add_alt_outlined, () {
              context.push('/connections');
            }),
          ],
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Recent Orders',
          actionLabel: 'View All',
          onAction: () => context.push(
            nurseryId != null ? '/orders?nursery=$nurseryId' : '/orders',
          ),
        ),
        const SizedBox(height: 12),
        _OrderPanel(orders: activeOrders),
        const SizedBox(height: 18),
        _LiveDispatchCard(
            dispatch:
                dispatches.where((d) => d.status == 'IN_TRANSIT').firstOrNull),
      ],
    );
  }
}

class _ManagerHome extends ConsumerWidget {
  const _ManagerHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_operationsHomeProvider).valueOrNull;
    final nurseryId = data?.nurseryId;
    final orders = data?.orders ?? const <Order>[];
    final dispatches = data?.dispatches ?? const <Dispatch>[];
    final requests = data?.requests ?? const <PlantRequest>[];
    final activeOrders = orders
        .where((o) => !{'DELIVERED', 'CANCELLED'}.contains(o.status))
        .take(3)
        .toList();
    final loading = orders.where((o) => o.status == 'LOADING').length;
    final delivered = orders.where((o) => o.status == 'DELIVERED').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuickTiles(
          tiles: [
            _QuickTile('Create Order', 'New Order', Icons.post_add_rounded,
                AppColors.primaryMain, () => context.push('/orders/create')),
            _QuickTile('Plant Request', 'From Nurseries', Icons.eco_outlined,
                AppColors.teal700, () => context.push('/requests/create')),
            _QuickTile(
                'Create Dispatch',
                'New Trip',
                Icons.local_shipping_outlined,
                AppColors.blue600,
                () => context.push('/orders/loading')),
            _QuickTile('Sourcing', 'Network', Icons.travel_explore_outlined,
                AppColors.purple700, () => context.push('/sourcing')),
          ],
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Today\'s Summary',
          actionLabel: 'View All',
          onAction: () => context.push(
            nurseryId != null ? '/orders?nursery=$nurseryId' : '/orders',
          ),
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          items: [
            _SummaryItem(
              icon: Icons.shopping_bag_outlined,
              value: '${orders.length}',
              label: 'Orders',
              sub:
                  '${orders.where((o) => o.status == 'CONFIRMED').length} ready',
              color: AppColors.primaryMain,
              onTap: () => context.push(
                nurseryId != null ? '/orders?nursery=$nurseryId' : '/orders',
              ),
            ),
            _SummaryItem(
              icon: Icons.local_shipping_outlined,
              value: '${dispatches.length}',
              label: 'Dispatches',
              sub:
                  '${dispatches.where((d) => d.status == 'IN_TRANSIT').length} in transit',
              color: AppColors.blue600,
              onTap: () => context.push('/dispatches'),
            ),
            _SummaryItem(
              icon: Icons.inventory_2_outlined,
              value: '$loading',
              label: 'Loading',
              sub: 'in progress',
              color: AppColors.amber600,
              onTap: () => context.push(
                nurseryId != null
                    ? '/orders/loading?nursery=$nurseryId'
                    : '/orders/loading',
              ),
            ),
            _SummaryItem(
              icon: Icons.check_circle_outline_rounded,
              value: '$delivered',
              label: 'Delivered',
              sub: 'completed',
              color: AppColors.teal700,
              onTap: () => context.push('/orders?status=DELIVERED'),
            ),
            _SummaryItem(
              icon: Icons.eco_outlined,
              value: '${requests.where((r) => r.status == 'OPEN').length}',
              label: 'Requests',
              sub: 'open',
              color: AppColors.purple700,
              onTap: () => context.push('/requests/create'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _TaskStrip(
          tasks: [
            _TaskItem(
                'Orders to Confirm',
                orders.where((o) => o.status == 'PENDING').length,
                Icons.inventory_2_outlined,
                () => context.push('/orders?status=PENDING')),
            _TaskItem(
                'Dispatch to Create',
                orders.where((o) => o.status == 'COMPLETED').length,
                Icons.local_shipping_outlined,
                () => context.push('/orders?status=COMPLETED')),
            _TaskItem(
                'Need Posts',
                requests.where((r) => r.status == 'OPEN').length,
                Icons.eco_outlined,
                () => context.push('/requests/create')),
          ],
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Active Orders',
          actionLabel: 'View All',
          onAction: () => context.push('/orders'),
        ),
        const SizedBox(height: 12),
        _OrderPanel(orders: activeOrders),
        const SizedBox(height: 18),
        _LiveDispatchCard(
            dispatch:
                dispatches.where((d) => d.status == 'IN_TRANSIT').firstOrNull),
      ],
    );
  }
}

class _DriverHome extends ConsumerWidget {
  const _DriverHome();

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
          onJoin: () => ref.read(mainTabIndexProvider.notifier).state = 2,
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

class _CustomerHome extends ConsumerWidget {
  const _CustomerHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_buyerHomeProvider).valueOrNull ??
        const _BuyerHomeData(orders: [], quotations: []);
    final activeOrder = data.orders
        .where((o) => !{'DELIVERED', 'CANCELLED'}.contains(o.status))
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CustomerHero(
            onTap: () => ref.read(mainTabIndexProvider.notifier).state = 1),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'My Quotations',
          actionLabel: 'View All',
          onAction: () => ref.read(mainTabIndexProvider.notifier).state = 1,
        ),
        const SizedBox(height: 12),
        _QuoteCards(quotations: data.quotations),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'My Orders',
          actionLabel: 'View All',
          onAction: () => ref.read(mainTabIndexProvider.notifier).state = 2,
        ),
        const SizedBox(height: 12),
        _OrderStatsGrid(orders: data.orders),
        const SizedBox(height: 18),
        if (activeOrder != null) _TrackOrderCard(order: activeOrder),
        const SizedBox(height: 18),
        _CustomerActionCards(
          onOrders: () => ref.read(mainTabIndexProvider.notifier).state = 2,
          onNursery: () => context.push('/register/nursery'),
          onInvite: () => context.push('/invite/accept'),
        ),
      ],
    );
  }
}

class _TopHeader extends ConsumerWidget {
  final dynamic caps;

  const _TopHeader({required this.caps});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.push('/workspace-select'),
          icon: const Icon(Icons.menu_rounded, size: 30),
          color: AppColors.textPrimary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.eco_rounded, color: AppColors.primaryMain),
                  const SizedBox(width: 4),
                  Text(
                    'GreenRoot',
                    style: AppTypography.h2.copyWith(
                      color: AppColors.primaryMain,
                      height: 1,
                    ),
                  ),
                ],
              ),
              Text(
                _headerSubtitle(caps),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const _NotificationButton(),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => ref.read(mainTabIndexProvider.notifier).state = 99,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.forest100,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryMain, width: 1.5),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.primaryMain,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationButton extends ConsumerStatefulWidget {
  const _NotificationButton();

  @override
  ConsumerState<_NotificationButton> createState() =>
      _NotificationButtonState();
}

class _NotificationButtonState extends ConsumerState<_NotificationButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(notificationListProvider).unreadCount;

    return IconButton(
      onPressed: () => context.push('/notifications'),
      icon: Badge.count(
        count: unread,
        isLabelVisible: unread > 0,
        child: const Icon(Icons.notifications_none_rounded),
      ),
      color: AppColors.textPrimary,
    );
  }
}

class _GreetingBlock extends StatelessWidget {
  final dynamic caps;
  final String? firstName;

  const _GreetingBlock({required this.caps, this.firstName});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good Morning, ${firstName?.isNotEmpty == true ? firstName! : 'there'}!',
                style: AppTypography.h1.copyWith(fontSize: 25, height: 1.1),
              ),
              const SizedBox(height: 8),
              Text(
                _roleSubtitle(caps),
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        _RolePill(label: _roleLabel(caps), icon: _roleIcon(caps)),
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

class _OwnerPrimaryActions extends StatelessWidget {
  final int? nurseryId;

  const _OwnerPrimaryActions({required this.nurseryId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _WideActionCard(
            title: 'Create Order',
            subtitle: 'New customer order',
            icon: Icons.add_shopping_cart_rounded,
            color: AppColors.primaryMain,
            onTap: () => context.push('/orders/create'),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _WideActionCard(
            title: 'Plant Request',
            subtitle: 'Request from nurseries',
            icon: Icons.eco_outlined,
            color: AppColors.primaryMain,
            onTap: () => context.push('/requests/create'),
          ),
        ),
      ],
    );
  }
}

class _WideActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _WideActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forest50,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.forest100),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: AppTypography.h4.copyWith(height: 1.15),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.18,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: AppColors.primaryMain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickTiles extends StatelessWidget {
  final List<_QuickTile> tiles;

  const _QuickTiles({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final tile in tiles)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: tile,
            ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickTile(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.onTap,
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 116,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
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

class _CustomerHero extends StatelessWidget {
  final VoidCallback onTap;

  const _CustomerHero({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Best Quality Plants',
                  style: AppTypography.h3.copyWith(
                    color: AppColors.primaryMain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Straight from trusted nurseries',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onTap,
                  child: const Text('Browse Quotations'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 98,
            height: 98,
            decoration: BoxDecoration(
              color: AppColors.forest100,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.local_florist_rounded,
              color: AppColors.primaryMain,
              size: 52,
            ),
          ),
        ],
      ),
    );
  }
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
            value: '${quotations.where((q) => q.status == 'SENT').length}',
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
            value: '${orders.where((o) => o.status == 'LOADING').length}',
            label: 'Loading',
            color: AppColors.blue600,
            onTap: () => context.push('/orders?status=LOADING'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniMetricCard(
            icon: Icons.local_shipping_outlined,
            value: '${orders.where((o) => o.status == 'DISPATCHED').length}',
            label: 'Dispatched',
            color: AppColors.amber600,
            onTap: () => context.push('/orders?status=DISPATCHED'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniMetricCard(
            icon: Icons.location_on_outlined,
            value: '${orders.where((o) => o.status == 'DELIVERED').length}',
            label: 'Delivered',
            color: AppColors.primaryMain,
            onTap: () => context.push('/orders?status=DELIVERED'),
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
  final VoidCallback onNursery;
  final VoidCallback onInvite;

  const _CustomerActionCards({
    required this.onOrders,
    required this.onNursery,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SmallLinkCard(
            title: 'Previous Orders',
            subtitle: 'View your past orders',
            icon: Icons.receipt_long_outlined,
            onTap: onOrders,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SmallLinkCard(
            title: 'Register Nursery',
            subtitle: 'Become a nursery owner',
            icon: Icons.storefront_outlined,
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

  int get upcoming => dispatches
      .where((d) => d.status == 'PENDING' || d.status == 'DISPATCHED')
      .length;
  int get active => dispatches.where((d) => d.status == 'IN_TRANSIT').length;
  int get completed => dispatches.where((d) => d.status == 'DELIVERED').length;
  int get cancelled => dispatches.where((d) => d.status == 'CANCELLED').length;
  Dispatch? get activeTrip =>
      dispatches.where((d) => d.status == 'IN_TRANSIT').firstOrNull;
}

class _BuyerHomeData {
  final List<Order> orders;
  final List<Quotation> quotations;

  const _BuyerHomeData({required this.orders, required this.quotations});
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

String _headerSubtitle(caps) {
  if (caps.isDriverOnly) return 'Delivering Green, On Time';
  if (caps.isManager) return 'Manage. Deliver. Grow.';
  if (caps.isNurseryOwner) return 'Plant Supply Simplified';
  return 'Quality Plants. On Time.';
}

String _roleLabel(caps) {
  if (caps.isDriverOnly) return 'Driver';
  if (caps.isNurseryOwner) return 'Owner';
  if (caps.isManager) return 'Manager';
  return 'Customer';
}

IconData _roleIcon(caps) {
  if (caps.isDriverOnly) return Icons.local_shipping_outlined;
  if (caps.isNurseryOwner) return Icons.storefront_outlined;
  if (caps.isManager) return Icons.manage_accounts_outlined;
  return Icons.person_outline_rounded;
}

String _roleSubtitle(caps) {
  if (caps.isDriverOnly) return 'Stay safe and complete your trips.';
  if (caps.isNurseryOwner)
    return caps.ownedNurseryName ?? 'Manage your nursery.';
  if (caps.isManager)
    return caps.primaryNurseryName ?? 'Manage nursery operations.';
  return 'Let\'s find the perfect plants for you.';
}

String _prettyStatus(String status) => status
    .toLowerCase()
    .split('_')
    .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

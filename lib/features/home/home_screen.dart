import 'dart:async';

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
import '../subscriptions/trial_banner_widget.dart';

final _operationsHomeProvider =
    FutureProvider.autoDispose<_OperationsHomeData>((ref) async {
  final session = ref.watch(sessionProvider);
  final caps = session.capabilities;
  final nurseryId = session.nurseryId ?? caps.primaryNurseryId;
  final orderRepo = ref.watch(orderRepositoryProvider);
  final dispatchRepo = ref.watch(dispatchRepositoryProvider);
  final dashboardRepo = ref.watch(ownerDashboardRepositoryProvider);

  var dashboard = OwnerDashboardData.empty;
  var orders = <Order>[];
  var dispatches = <Dispatch>[];

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

  return _OperationsHomeData(
    nurseryId: nurseryId,
    dashboard: dashboard,
    orders: orders,
    dispatches: dispatches,
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
              if (caps.hasPendingNursery)
                _OwnerPendingCard(nurseryName: caps.ownedNurseryName)
              else if (caps.hasRejectedNursery)
                const _OwnerRejectedCard()
              else if (caps.isDriverOnly)
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

// ── Owner pending approval card ────────────────────────────────────────────────

class _OwnerPendingCard extends ConsumerStatefulWidget {
  final String? nurseryName;
  const _OwnerPendingCard({this.nurseryName});

  @override
  ConsumerState<_OwnerPendingCard> createState() => _OwnerPendingCardState();
}

class _OwnerPendingCardState extends ConsumerState<_OwnerPendingCard> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Silently re-check session every 30 s so user sees approval without pulling
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.read(sessionProvider.notifier).bootstrap();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryMain.withAlpha(51)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 36,
              color: AppColors.primaryMain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Application Under Review',
            style: AppTypography.h3.copyWith(color: AppColors.primaryMain),
            textAlign: TextAlign.center,
          ),
          if (widget.nurseryName != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.nurseryName!,
              style: AppTypography.body.copyWith(
                color: AppColors.primaryMain,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Our team is reviewing your nursery application. '
            'Approvals typically complete within 24–48 hours.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh and check your status.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Owner rejected card ────────────────────────────────────────────────────────

class _OwnerRejectedCard extends StatelessWidget {
  const _OwnerRejectedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red500.withAlpha(51)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.red500.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cancel_outlined,
              size: 36,
              color: AppColors.red500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Application Not Approved',
            style: AppTypography.h3.copyWith(color: AppColors.red500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your nursery application was not approved at this time. '
            'Please contact our support team to understand next steps.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.support_agent_rounded,
                color: AppColors.red500, size: 18,),
            label: const Text('Contact Support',
                style: TextStyle(color: AppColors.red500),),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.red500),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Greeting block ─────────────────────────────────────────────────────────────

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
              const Text('Current Trip', style: AppTypography.h3),
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
                    const _TripPoint(
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
                        .copyWith(fontWeight: FontWeight.w800),),
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
          icon: Icons.route_outlined, title: 'No trips yet',);
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
                            style: AppTypography.h4,),
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
              color: AppColors.amber600,),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Drive Safe!', style: AppTypography.h4),
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
              color: AppColors.primaryMain,),
        ],
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

  const _OperationsHomeData({
    required this.nurseryId,
    required this.dashboard,
    required this.orders,
    required this.dispatches,
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
          (d) => {'ACCEPTED', 'DISPATCHED', 'IN_TRANSIT'}.contains(d.status),)
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

String _roleSubtitle(caps) {
  if (caps.isDriverOnly) return 'Stay safe on the road. Check your trips below.';
  if (caps.isNurseryOwner) {
    return 'Manage orders, team & deliveries for ${caps.ownedNurseryName ?? 'your nursery'}.';
  }
  if (caps.isManager) {
    return 'Here\'s what\'s happening at ${caps.primaryNurseryName ?? 'your nursery'} today.';
  }
  return 'Here\'s what\'s happening with your orders today.';
}

String _prettyStatus(String status) => status
    .toLowerCase()
    .split('_')
    .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

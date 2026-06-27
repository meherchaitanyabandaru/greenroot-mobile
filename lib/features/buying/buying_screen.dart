import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dispatches/dispatches.dart';
import '../orders/orders.dart';
import '../quotations/quotations.dart';
import '../tracking/dispatch_tracking_screen.dart';

class BuyingScreen extends ConsumerStatefulWidget {
  const BuyingScreen({super.key});

  @override
  ConsumerState<BuyingScreen> createState() => _BuyingScreenState();
}

class _BuyingScreenState extends ConsumerState<BuyingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(buyingQuotationListProvider.notifier).load();
      ref.read(buyingOrderListProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Buying', style: AppTypography.h3),
            if (user?.firstName != null)
              Text(
                user!.firstName!,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryMain,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryMain,
          labelStyle: AppTypography.label,
          unselectedLabelStyle: AppTypography.bodySmall,
          tabs: const [
            Tab(text: 'Quotations'),
            Tab(text: 'Orders'),
            Tab(text: 'Tracking'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BuyingQuotationsTab(),
          _BuyingOrdersTab(),
          _TrackingTab(),
        ],
      ),
    );
  }
}

// ── Buying Quotations Tab ──────────────────────────────────────────────────────

class _BuyingQuotationsTab extends ConsumerWidget {
  const _BuyingQuotationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(buyingQuotationListProvider);
    final paged = state.paged;

    if (paged.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryMain));
    }
    if (paged.error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Failed to load',
              style: AppTypography.body.copyWith(color: AppColors.red600)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () =>
                ref.read(buyingQuotationListProvider.notifier).load(),
            child: const Text('Retry'),
          ),
        ]),
      );
    }
    if (paged.items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined,
              size: 64, color: AppColors.primaryMain.withValues(alpha: 0.3)),
          const SizedBox(height: AppSpacing.md),
          Text('No incoming quotations',
              style: AppTypography.body.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text('Quotations sent to you by other nurseries will appear here.',
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center),
        ]),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryMain,
      onRefresh: () => ref.read(buyingQuotationListProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
            AppSpacing.sm, AppSpacing.screenPadding, 80),
        itemCount: paged.items.length + (paged.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= paged.items.length) {
            ref.read(buyingQuotationListProvider.notifier).loadMore();
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryMain),
                ),
              ),
            );
          }
          final q = paged.items[i];
          return _BuyingQuotationCard(
            quotation: q,
            onTap: () => context.push('/quotations/${q.id}'),
          );
        },
      ),
    );
  }
}

class _BuyingQuotationCard extends ConsumerWidget {
  final Quotation quotation;
  final VoidCallback onTap;
  const _BuyingQuotationCard({required this.quotation, required this.onTap});

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    try {
      final updated = await ref
          .read(quotationRepositoryProvider)
          .acceptQuotation(quotation.id);
      ref.read(buyingQuotationListProvider.notifier).updateItem(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Quotation accepted'),
              backgroundColor: AppColors.primaryMain),
        );
      }
    } on AppError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red600),
        );
      }
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    String? reason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Quotation'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Reason (optional)'),
            onChanged: (v) => reason = v,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Reject', style: TextStyle(color: AppColors.red600)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final updated = await ref
          .read(quotationRepositoryProvider)
          .rejectQuotation(quotation.id, reason: reason);
      ref.read(buyingQuotationListProvider.notifier).updateItem(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Quotation rejected'),
              backgroundColor: AppColors.red600),
        );
      }
    } on AppError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red600),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dt = DateTime.tryParse(quotation.createdAt)?.toLocal();
    final dateStr = dt != null ? DateFormat('d MMM yyyy').format(dt) : '';
    final canAct = quotation.status == 'APPROVED' ||
        quotation.status == 'SENT' ||
        quotation.status == 'CUSTOMER_SENT';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.forest100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description_outlined,
                      color: AppColors.primaryMain, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(quotation.quotationCode,
                          style: AppTypography.bodySmall
                              .copyWith(fontWeight: FontWeight.w700)),
                      if (quotation.nurseryName != null)
                        Text('From: ${quotation.nurseryName}',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                _StatusChip(status: quotation.status),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text('₹${quotation.totalAmount.toStringAsFixed(2)}',
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primaryMain,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text(
                    '· ${quotation.items.length} item${quotation.items.length == 1 ? '' : 's'}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted)),
                const Spacer(),
                Text(dateStr,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted)),
              ]),
              if (canAct) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red600,
                        side: const BorderSide(color: AppColors.red600),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child:
                          const Text('Reject', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _accept(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMain,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child:
                          const Text('Accept', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Buying Orders Tab ──────────────────────────────────────────────────────────

class _BuyingOrdersTab extends ConsumerWidget {
  const _BuyingOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(buyingOrderListProvider);
    final paged = state.paged;

    if (paged.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryMain));
    }
    if (paged.error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Failed to load',
              style: AppTypography.body.copyWith(color: AppColors.red600)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.read(buyingOrderListProvider.notifier).load(),
            child: const Text('Retry'),
          ),
        ]),
      );
    }
    if (paged.items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: AppColors.primaryMain.withValues(alpha: 0.3)),
          const SizedBox(height: AppSpacing.md),
          Text('No buying orders',
              style: AppTypography.body.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text('Orders from other nurseries will appear here.',
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center),
        ]),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryMain,
      onRefresh: () => ref.read(buyingOrderListProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
            AppSpacing.sm, AppSpacing.screenPadding, 80),
        itemCount: paged.items.length + (paged.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= paged.items.length) {
            ref.read(buyingOrderListProvider.notifier).loadMore();
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryMain),
                ),
              ),
            );
          }
          final order = paged.items[i];
          return _BuyingOrderCard(
            order: order,
            onTap: () => context.push('/orders/${order.id}'),
          );
        },
      ),
    );
  }
}

class _BuyingOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const _BuyingOrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(order.orderDate)?.toLocal();
    final dateStr = dt != null ? DateFormat('d MMM yyyy').format(dt) : '';
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  color: AppColors.primaryMain, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(order.orderCode,
                          style: AppTypography.bodySmall
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
                    _OrderStatusChip(status: order.status),
                  ]),
                  if (order.sellerNursery != null)
                    Text('From: ${order.sellerNursery}',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary)),
                  Row(children: [
                    Text(fmt.format(order.totalAmount),
                        style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primaryMain,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(dateStr,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 18),
          ]),
        ),
      ),
    );
  }
}

// ── Tracking Tab ───────────────────────────────────────────────────────────────

class _TrackingTab extends ConsumerStatefulWidget {
  const _TrackingTab();

  @override
  ConsumerState<_TrackingTab> createState() => _TrackingTabState();
}

class _TrackingTabState extends ConsumerState<_TrackingTab> {
  List<Dispatch> _dispatches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(dispatchRepositoryProvider);
      final (items, _) = await repo.listDispatches(page: 1, perPage: 50);
      if (mounted) setState(() => _dispatches = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryMain));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Failed to load',
              style: AppTypography.body.copyWith(color: AppColors.red600)),
          const SizedBox(height: 8),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    final active = _dispatches
        .where((d) => d.status == 'DISPATCHED' || d.status == 'IN_TRANSIT')
        .toList();
    final recent = _dispatches
        .where((d) => d.status == 'DELIVERED')
        .toList();
    final pending = _dispatches
        .where((d) =>
            d.status == 'ACCEPTED' ||
            d.status == 'LOADING_STARTED' ||
            d.status == 'LOADING_COMPLETED')
        .toList();

    if (_dispatches.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.forest100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.local_shipping_outlined,
                size: 36, color: AppColors.primaryMain),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('No Deliveries Yet', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your incoming shipments will appear here once they are dispatched.',
            style:
                AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryMain,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
            AppSpacing.sm, AppSpacing.screenPadding, 80),
        children: [
          if (active.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.local_shipping_rounded,
              label: 'In Transit',
              color: AppColors.blue600,
              count: active.length,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...active.map((d) => _DispatchTrackCard(dispatch: d)),
            const SizedBox(height: AppSpacing.x2l),
          ],
          if (pending.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.inventory_rounded,
              label: 'Being Loaded',
              color: AppColors.amber600,
              count: pending.length,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...pending.map((d) => _DispatchTrackCard(dispatch: d)),
            const SizedBox(height: AppSpacing.x2l),
          ],
          if (recent.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.check_circle_rounded,
              label: 'Delivered',
              color: AppColors.primaryMain,
              count: recent.length,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...recent.map((d) => _DispatchTrackCard(dispatch: d)),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(label,
          style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$count',
          style: AppTypography.caption
              .copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    ]);
  }
}

class _DispatchTrackCard extends StatelessWidget {
  final Dispatch dispatch;

  const _DispatchTrackCard({required this.dispatch});

  @override
  Widget build(BuildContext context) {
    final isInTransit =
        dispatch.status == 'DISPATCHED' || dispatch.status == 'IN_TRANSIT';
    final isDelivered = dispatch.status == 'DELIVERED';

    Color statusBg, statusFg;
    String statusLabel;
    IconData statusIcon;
    switch (dispatch.status) {
      case 'DISPATCHED':
        statusBg = AppColors.blue100;
        statusFg = AppColors.blue600;
        statusLabel = 'Dispatched';
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'IN_TRANSIT':
        statusBg = AppColors.blue100;
        statusFg = AppColors.blue600;
        statusLabel = 'On The Way';
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'DELIVERED':
        statusBg = AppColors.forest100;
        statusFg = AppColors.primaryMain;
        statusLabel = 'Delivered';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'LOADING_STARTED':
        statusBg = AppColors.amber100;
        statusFg = AppColors.amber600;
        statusLabel = 'Loading';
        statusIcon = Icons.inventory_2_rounded;
        break;
      case 'LOADING_COMPLETED':
        statusBg = AppColors.amber100;
        statusFg = AppColors.amber600;
        statusLabel = 'Ready to Ship';
        statusIcon = Icons.inventory_2_rounded;
        break;
      default:
        statusBg = const Color(0xFFEEEEEE);
        statusFg = AppColors.textSecondary;
        statusLabel = dispatch.status.replaceAll('_', ' ');
        statusIcon = Icons.circle_outlined;
    }

    final dateStr = dispatch.dispatchDate != null
        ? DateFormat('d MMM yyyy').format(
            DateTime.tryParse(dispatch.dispatchDate!)?.toLocal() ??
                DateTime.now())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInTransit
              ? AppColors.blue600.withValues(alpha: 0.3)
              : AppColors.border,
        ),
        boxShadow: isInTransit
            ? [
                BoxShadow(
                  color: AppColors.blue600.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DispatchTrackingScreen(
            dispatchId: dispatch.id,
            title: dispatch.dispatchCode,
            isDriver: false,
          ),
        )),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusFg, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dispatch.dispatchCode,
                          style: AppTypography.bodySmall
                              .copyWith(fontWeight: FontWeight.w700)),
                      if (dispatch.orderNumber != null)
                        Text('Order ${dispatch.orderNumber}',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel,
                      style: AppTypography.caption.copyWith(
                          color: statusFg, fontWeight: FontWeight.w700)),
                ),
              ]),
              if (dispatch.destinationAddress != null) ...[
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(dispatch.destinationAddress!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
              const SizedBox(height: 8),
              Row(children: [
                if (dispatch.driverName != null) ...[
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(dispatch.driverName!,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(width: 10),
                ],
                if (dispatch.vehicleNumber != null) ...[
                  const Icon(Icons.directions_car_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(dispatch.vehicleNumber!,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
                const Spacer(),
                if (dateStr.isNotEmpty)
                  Text(dateStr,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted)),
              ]),
              if (isInTransit) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DispatchTrackingScreen(
                        dispatchId: dispatch.id,
                        title: 'Live Tracking',
                        isDriver: false,
                      ),
                    )),
                    icon: const Icon(Icons.location_on_rounded, size: 16),
                    label: const Text('Track Live'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
              if (isDelivered) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/dispatches/${dispatch.id}'),
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryMain,
                    side: const BorderSide(color: AppColors.primaryMain),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(double.infinity, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status chips ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status) {
      case 'DRAFT':
        bg = AppColors.amber100;
        fg = AppColors.amber600;
        break;
      case 'SENT':
      case 'APPROVED':
        bg = AppColors.blue100;
        fg = AppColors.blue600;
        break;
      case 'BUYER_ACCEPTED':
        bg = AppColors.forest100;
        fg = AppColors.primaryMain;
        break;
      case 'BUYER_REJECTED':
        bg = AppColors.red100;
        fg = AppColors.red600;
        break;
      default:
        bg = const Color(0xFFEEEEEE);
        fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(
        status.replaceAll('_', ' '),
        style: AppTypography.caption
            .copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 10),
      ),
    );
  }
}

class _OrderStatusChip extends StatelessWidget {
  final String status;
  const _OrderStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status) {
      case 'PENDING':
        bg = AppColors.amber100;
        fg = AppColors.amber600;
        break;
      case 'CONFIRMED':
        bg = AppColors.blue100;
        fg = AppColors.blue600;
        break;
      case 'LOADING':
      case 'COMPLETED':
        bg = const Color(0xFFE8F5E9);
        fg = AppColors.primaryMain;
        break;
      case 'DELIVERED':
        bg = AppColors.forest100;
        fg = AppColors.primaryMain;
        break;
      case 'CANCELLED':
        bg = AppColors.red100;
        fg = AppColors.red600;
        break;
      default:
        bg = const Color(0xFFEEEEEE);
        fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(
        status,
        style: AppTypography.caption
            .copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 10),
      ),
    );
  }
}

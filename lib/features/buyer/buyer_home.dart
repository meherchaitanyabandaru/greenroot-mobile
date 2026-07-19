// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — BUYER HOME SECTION                                              ║
// ║  Role:  BUYER (customer)                                                     ║
// ║  Guard: rendered only when !caps.canSell && !caps.isDriverOnly               ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// CONTEXT
// ───────
// Rendered inside HomeScreen as the main content block when the logged-in user
// is a BUYER — i.e. a GreenRoot user who is NOT a nursery owner, NOT a manager,
// and NOT a driver. This is the buyer's "dashboard" for the purchase lifecycle:
//
//   BROWSE  →  /plants, /nurseries
//   RECEIVE →  quotations sent by nurseries (buyer accepts / rejects)
//   TRACK   →  order status + dispatch live location
//
// Dispatch condition in home_screen.dart (HomeScreen.build):
//   else BuyerHome()   ← fallback when all other role checks are false
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  RBAC — WHAT A BUYER CAN DO                                                 │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ✅  Browse plant catalog              GET  /api/v1/plants                  │
// │  ✅  Browse nurseries (public)         GET  /api/v1/nurseries               │
// │  ✅  View nursery detail               GET  /api/v1/nurseries/:id           │
// │  ✅  Place own order                   POST /api/v1/orders                  │
// │  ✅  View own orders                   GET  /api/v1/orders                  │
// │  ✅  View order detail                 GET  /api/v1/orders/:id              │
// │  ✅  Cancel PENDING order (own only)   POST /api/v1/orders/:id/cancel       │
// │  ✅  View quotations (nursery→buyer)   GET  /api/v1/quotations              │
// │  ✅  View quotation detail             GET  /api/v1/quotations/:id          │
// │  ✅  Accept a quotation                POST /api/v1/quotations/:id/buyer-accept  │
// │  ✅  Reject a quotation                POST /api/v1/quotations/:id/buyer-reject  │
// │  ✅  Track own dispatches              GET  /api/v1/dispatches              │
// │  ✅  Live dispatch tracking            GET  /api/v1/dispatches/:id/track    │
// │  ✅  View own payment history          GET  /api/v1/payments                │
// │  ✅  Manage delivery addresses         GET/POST/PUT/DELETE                  │
// │                                         /api/v1/users/:id/addresses         │
// │  ✅  Register nursery application      POST /api/v1/nurseries               │
// │  ✅  Accept customer/team invite       POST /api/v1/invites/:uuid/accept    │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  RBAC — WHAT A BUYER CANNOT DO                                              │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ❌  Create quotations POST /api/v1/quotations                              │
// │  ❌  Approve / convert quotations                                           │
// │  ❌  Access inventory, plant requests, sourcing network                     │
// │  ❌  Create dispatches / assign drivers                                     │
// │  ❌  Cancel non-PENDING orders                                              │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// API CALLS — ON LOAD & PULL-TO-REFRESH
// ──────────────────────────────────────
//   1. GET /api/v1/orders?buying=true&page=1&per_page=30
//        → KPI counts + active orders list
//
// ORDER STATUS VALUES (state machine — API enforced)
// ───────────────────────────────────────────────────
//   PENDING → CONFIRMED → LOADING → LOADED | PARTIALLY_FULFILLED → COMPLETED
//                                                                 ↘ CANCELLED (only from PENDING)
//
// NAVIGATION FROM THIS WIDGET
// ────────────────────────────
//   context.push('/orders/:id')    — order detail + cancel button (PENDING only)
//   context.push('/plants')        — browse plant catalog
//   context.push('/nurseries')     — browse and explore nurseries
//   mainTabIndexProvider = 1       — jump to Buying tab
//
// BUSINESS RULES — MUST ENFORCE IN UI
// ─────────────────────────────────────
//   • Render buyer order creation as "Place Order", never seller "New Order"
//   • "Cancel Order" visible ONLY when order.status == 'PENDING'
//   • Empty state: show "Explore nurseries →" CTA, NOT "Create your first order"

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/main_shell.dart';
import '../../core/domain/lifecycle_presenter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/universal_qr_screen.dart';
import '../dispatches/dispatches.dart';
import '../orders/orders.dart';

/// Fetches buyer home data: orders scoped to the current buyer.
/// Public so that HomeScreen can invalidate it on pull-to-refresh.
final buyerHomeProvider =
    FutureProvider.autoDispose<_BuyerHomeData>((ref) async {
  final orderRepo = ref.watch(orderRepositoryProvider);
  final dispatchRepo = ref.watch(dispatchRepositoryProvider);
  var orders = <Order>[];
  var dispatches = <Dispatch>[];
  try {
    final (items, _) = await orderRepo.listBuyingOrders(page: 1, perPage: 30);
    orders = items;
  } catch (_) {}
  try {
    final (items, _) =
        await dispatchRepo.listBuyingDispatches(page: 1, perPage: 50);
    dispatches = items;
  } catch (_) {}
  return _BuyerHomeData(orders: orders, dispatches: dispatches);
});

class _BuyerHomeData {
  final List<Order> orders;
  final List<Dispatch> dispatches;

  const _BuyerHomeData({required this.orders, this.dispatches = const []});

  List<Order> get activeOrders => orders
      .where(
          (o) => !{'COMPLETED', 'CANCELLED'}.contains(o.status.toUpperCase()))
      .toList();

  int get completedCount =>
      orders.where((o) => o.status.toUpperCase() == 'COMPLETED').length;

  int get cancelledCount =>
      orders.where((o) => o.status.toUpperCase() == 'CANCELLED').length;

  Dispatch? dispatchForOrder(int orderId) =>
      LifecyclePresenter.activeDispatchForOrder(dispatches, orderId);
}

// ── Root widget ───────────────────────────────────────────────────────────────

/// Buyer home section rendered inside HomeScreen for buyer-only users.
class BuyerHome extends ConsumerWidget {
  const BuyerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(buyerHomeProvider).valueOrNull ??
        const _BuyerHomeData(orders: []);
    final active = data.activeOrders;
    final isEmpty = data.orders.isEmpty;

    void goToBuying() => ref.read(mainTabIndexProvider.notifier).state = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI summary row
        _BuyerSummaryRow(
          totalCount: data.orders.length,
          activeCount: active.length,
          completedCount: data.completedCount,
          onTap: goToBuying,
        ),
        const SizedBox(height: 22),
        // Quick actions
        _BuyerActionGrid(
          onBrowsePlants: () => context.push('/plants'),
          onBrowseNurseries: () => context.push('/nurseries'),
          onMyOrders: goToBuying,
          onTrackDeliveries: goToBuying,
        ),
        const SizedBox(height: 22),
        // Active orders list (up to 3)
        if (active.isNotEmpty) ...[
          _SectionHeader(
            title: 'Active Orders',
            actionLabel: 'View All',
            onAction: goToBuying,
          ),
          const SizedBox(height: 12),
          ...active.take(3).map(
                (o) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BuyerOrderCard(
                    order: o,
                    dispatch: data.dispatchForOrder(o.id),
                    onTap: () => context.push('/orders/${o.id}'),
                  ),
                ),
              ),
          const SizedBox(height: 12),
        ],
        // Empty state
        if (isEmpty)
          _EmptyBuyerState(onExplore: () => context.push('/nurseries')),
      ],
    );
  }
}

// ── KPI summary row ───────────────────────────────────────────────────────────

class _BuyerSummaryRow extends StatelessWidget {
  final int totalCount;
  final int activeCount;
  final int completedCount;
  final VoidCallback onTap;

  const _BuyerSummaryRow({
    required this.totalCount,
    required this.activeCount,
    required this.completedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _KpiCell(
            icon: Icons.shopping_bag_outlined,
            value: '$totalCount',
            label: 'Total',
            color: AppColors.primaryMain,
            onTap: onTap,
          ),
          const SizedBox(
            height: 80,
            child: VerticalDivider(width: 1, color: AppColors.border),
          ),
          _KpiCell(
            icon: Icons.pending_outlined,
            value: '$activeCount',
            label: 'Active',
            color: AppColors.blue600,
            onTap: onTap,
          ),
          const SizedBox(
            height: 80,
            child: VerticalDivider(width: 1, color: AppColors.border),
          ),
          _KpiCell(
            icon: Icons.check_circle_outline_rounded,
            value: '$completedCount',
            label: 'Done',
            color: const Color(0xFF2E7D32),
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _KpiCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _KpiCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(
                value,
                style: AppTypography.h2.copyWith(color: color, height: 1),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

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

// ── Order card ────────────────────────────────────────────────────────────────

class _BuyerOrderCard extends StatelessWidget {
  final Order order;
  final Dispatch? dispatch;
  final VoidCallback onTap;

  const _BuyerOrderCard({
    required this.order,
    required this.onTap,
    this.dispatch,
  });

  @override
  Widget build(BuildContext context) {
    final display = LifecyclePresenter.forOrder(
      order: order,
      dispatch: dispatch,
      role: LifecycleRole.buyer,
    );
    final fmt = NumberFormat('#,##0.00');

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primaryMain,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    order.sellerNursery ?? 'GreenRoot',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: display.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    display.label,
                    style: AppTypography.caption.copyWith(
                      color: display.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '₹${fmt.format(order.totalAmount)}',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick-action grid ─────────────────────────────────────────────────────────

class _BuyerActionGrid extends StatelessWidget {
  final VoidCallback onBrowsePlants;
  final VoidCallback onBrowseNurseries;
  final VoidCallback onMyOrders;
  final VoidCallback onTrackDeliveries;

  const _BuyerActionGrid({
    required this.onBrowsePlants,
    required this.onBrowseNurseries,
    required this.onMyOrders,
    required this.onTrackDeliveries,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: [
        _ActionCell(
          icon: Icons.eco_outlined,
          label: 'Browse Plants',
          color: AppColors.primaryMain,
          onTap: onBrowsePlants,
        ),
        _ActionCell(
          icon: Icons.storefront_outlined,
          label: 'Connected Nurseries',
          color: AppColors.blue600,
          onTap: () => context.push('/buyer/connections'),
        ),
        _ActionCell(
          icon: Icons.shopping_bag_outlined,
          label: 'My Orders',
          color: AppColors.purple700,
          onTap: onMyOrders,
        ),
        _ActionCell(
          icon: Icons.local_shipping_outlined,
          label: 'Track Delivery',
          color: AppColors.amber600,
          onTap: onTrackDeliveries,
        ),
      ],
    );
  }
}

class _ActionCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCell({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyBuyerState extends StatelessWidget {
  final VoidCallback onExplore;

  const _EmptyBuyerState({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: _cardDecoration(accent: AppColors.forest50),
      child: Column(
        children: [
          const Icon(Icons.eco_rounded, size: 54, color: AppColors.primaryMain),
          const SizedBox(height: 16),
          Text(
            'Your garden starts here',
            style: AppTypography.h3.copyWith(color: AppColors.primaryMain),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Browse nurseries and request plants. Your orders will appear here.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onExplore,
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('Explore Nurseries'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              minimumSize: const Size(double.infinity, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const UniversalQrScreen(),
                fullscreenDialog: true,
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded,
                size: 18, color: AppColors.primaryMain),
            label: const Text('Have an invite? Scan QR',
                style: TextStyle(color: AppColors.primaryMain)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryMain),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

BoxDecoration _cardDecoration({Color? accent}) => BoxDecoration(
      color: accent ?? AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );

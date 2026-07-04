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
// │         (becomes nursery owner on admin approval; normal buyer flow)        │
// │  ✅  Accept customer/team invite       POST /api/v1/invites/:uuid/accept    │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  RBAC — WHAT A BUYER CANNOT DO                                              │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ❌  Create orders     POST /api/v1/orders   — nursery staff creates orders │
// │  ❌  Create quotations POST /api/v1/quotations — nursery → buyer flow only  │
// │  ❌  Approve quotations     POST .../approve                                │
// │  ❌  Convert quotations     POST .../convert-to-order                       │
// │  ❌  Access inventory       ANY  /api/v1/nurseries/:id/inventory            │
// │  ❌  Access plant requests  ANY  /api/v1/nurseries/:id/requests             │
// │  ❌  Access sourcing network GET /api/v1/sourcing                           │
// │  ❌  Create dispatches      POST /api/v1/dispatches                         │
// │  ❌  Assign drivers         POST /api/v1/dispatches/:id/assign-driver       │
// │  ❌  Invite managers        POST /api/v1/invites  (MANAGER_INVITE type)     │
// │  ❌  Cancel non-PENDING orders — status must be exactly PENDING             │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// API CALLS — ON LOAD & PULL-TO-REFRESH
// ──────────────────────────────────────
//   1. GET /api/v1/quotations?page=1&per_page=5&status=APPROVED,SENT,CUSTOMER_SENT
//        → "X offers waiting" badge card at top of home
//        → Response: { data: [quotation...], pagination: { page, per_page, total, total_pages } }
//        → quotation fields: id, quotation_number, status, total_amount,
//                            nursery_name, created_at, items[]
//
//   2. GET /api/v1/orders?page=1&per_page=5
//        → Active order card (most recent non-COMPLETED / non-CANCELLED order)
//        → Response: { data: [order...], pagination: {...} }
//        → order fields: id, order_number, status, total_amount, nursery_name, created_at
//
//   3. GET /api/v1/dispatches?page=1&per_page=3
//        → Live delivery card when a dispatch is IN_TRANSIT
//        → Response: { data: [dispatch...], pagination: {...} }
//        → dispatch fields: id, dispatch_number, status, vehicle_number, driver_name,
//                           estimated_arrival, order_id
//
// ORDER STATUS VALUES (state machine — API enforced)
// ───────────────────────────────────────────────────
//   PENDING → CONFIRMED → LOADING → LOADED | PARTIALLY_FULFILLED → COMPLETED
//                                                                 ↘ CANCELLED (only from PENDING)
//
// QUOTATION STATUS VALUES
// ────────────────────────
//   DRAFT → APPROVED → SENT | CUSTOMER_SENT → CUSTOMER_ACCEPTED | CUSTOMER_REJECTED
//                                            → CONVERTED (when nursery converts to order)
//                                            → EXPIRED
//
// NAVIGATION FROM THIS WIDGET
// ────────────────────────────
//   context.push('/quotations/:id')        — quotation detail + accept/reject actions
//   context.push('/orders/:id')            — order detail + cancel button (PENDING only)
//   context.push('/dispatches/:id/track')  — live delivery map
//   context.push('/plants')               — browse plant catalog
//   context.push('/nurseries')            — browse and explore nurseries
//
// BUSINESS RULES — MUST ENFORCE IN UI
// ─────────────────────────────────────
//   • NEVER render "Create Order", "Place Order", "Buy Now" button or FAB
//   • "Accept / Reject" buttons visible ONLY when quotation.status ∈
//     { APPROVED, SENT, CUSTOMER_SENT }
//   • "Cancel Order" visible ONLY when order.status == 'PENDING'
//   • Orders in LOADING, LOADED, PARTIALLY_FULFILLED, COMPLETED are immutable;
//     show read-only status badge, no action buttons
//   • Empty state: show "Explore nurseries →" CTA, NOT "Create your first order"
//   • If pending_quotations > 0, show a prominent "You have N offers" banner
//     at the very top above the orders list
//   • Label incoming quotations as "Offers from nurseries" — buyer did not create them

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/main_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../orders/orders.dart';
import '../quotations/quotations.dart';

/// Fetches buyer home data: quotations and orders scoped to the current buyer.
/// Public so that HomeScreen can invalidate it on pull-to-refresh.
final buyerHomeProvider =
    FutureProvider.autoDispose<_BuyerHomeData>((ref) async {
  final orderRepo = ref.watch(orderRepositoryProvider);
  final quotationRepo = ref.watch(quotationRepositoryProvider);
  var orders = <Order>[];
  var quotations = <Quotation>[];
  try {
    final (items, _) =
        await quotationRepo.listBuyingQuotations(page: 1, perPage: 30);
    quotations = items;
  } catch (_) {}
  try {
    final (items, _) = await orderRepo.listBuyingOrders(page: 1, perPage: 30);
    orders = items;
  } catch (_) {}
  return _BuyerHomeData(orders: orders, quotations: quotations);
});

class _BuyerHomeData {
  final List<Order> orders;
  final List<Quotation> quotations;

  const _BuyerHomeData({required this.orders, required this.quotations});

  List<Quotation> get pendingOffers => quotations
      .where(
        (q) => {'APPROVED', 'SENT', 'CUSTOMER_SENT'}
            .contains(q.status.toUpperCase()),
      )
      .toList();

  List<Order> get activeOrders => orders
      .where(
          (o) => !{'COMPLETED', 'CANCELLED'}.contains(o.status.toUpperCase()))
      .toList();

  int get completedCount =>
      orders.where((o) => o.status.toUpperCase() == 'COMPLETED').length;
}

// ── Root widget ───────────────────────────────────────────────────────────────

/// Buyer home section rendered inside HomeScreen for buyer-only users.
class BuyerHome extends ConsumerWidget {
  const BuyerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(buyerHomeProvider).valueOrNull ??
        const _BuyerHomeData(orders: [], quotations: []);
    final pending = data.pendingOffers;
    final active = data.activeOrders;
    final isEmpty = data.orders.isEmpty && data.quotations.isEmpty;

    void goToBuying() => ref.read(mainTabIndexProvider.notifier).state = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prominent offers banner when nurseries have sent quotations
        if (pending.isNotEmpty) ...[
          _OffersBanner(count: pending.length, onTap: goToBuying),
          const SizedBox(height: 16),
        ],
        // KPI summary row
        _BuyerSummaryRow(
          pendingCount: pending.length,
          activeCount: active.length,
          completedCount: data.completedCount,
          onTap: goToBuying,
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
                    onTap: () => context.push('/orders/${o.id}'),
                  ),
                ),
              ),
          const SizedBox(height: 12),
        ],
        // Pending offers list (up to 3)
        if (pending.isNotEmpty) ...[
          _SectionHeader(
            title: 'Offers from Nurseries',
            actionLabel: 'View All',
            onAction: goToBuying,
          ),
          const SizedBox(height: 12),
          ...pending.take(3).map(
                (q) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BuyerQuotationCard(
                    quotation: q,
                    onTap: () => context.push('/quotations/${q.id}'),
                  ),
                ),
              ),
          const SizedBox(height: 12),
        ],
        // Quick actions
        _BuyerActionGrid(
          onBrowsePlants: () => context.push('/plants'),
          onBrowseNurseries: () => context.push('/nurseries'),
          onMyOrders: goToBuying,
          onTrackDeliveries: goToBuying,
        ),
        const SizedBox(height: 22),
        // Empty state
        if (isEmpty)
          _EmptyBuyerState(onExplore: () => context.push('/nurseries')),
      ],
    );
  }
}

// ── Offers banner ─────────────────────────────────────────────────────────────

class _OffersBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _OffersBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9800), Color(0xFFFFC107)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: AppRadius.cardRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_unread_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You have $count offer${count == 1 ? '' : 's'}',
                    style: AppTypography.h3.copyWith(color: Colors.white),
                  ),
                  Text(
                    'Nurseries are waiting for your response',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ── KPI summary row ───────────────────────────────────────────────────────────

class _BuyerSummaryRow extends StatelessWidget {
  final int pendingCount;
  final int activeCount;
  final int completedCount;
  final VoidCallback onTap;

  const _BuyerSummaryRow({
    required this.pendingCount,
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
            icon: Icons.request_quote_outlined,
            value: '$pendingCount',
            label: 'Offers',
            color: AppColors.amber600,
            onTap: onTap,
          ),
          const SizedBox(
            height: 80,
            child: VerticalDivider(width: 1, color: AppColors.border),
          ),
          _KpiCell(
            icon: Icons.shopping_bag_outlined,
            value: '$activeCount',
            label: 'Active',
            color: AppColors.primaryMain,
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
            color: AppColors.blue600,
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
  final VoidCallback onTap;

  const _BuyerOrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chip = _orderStatusChip(order.status);
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
                    color: chip.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    chip.label,
                    style: AppTypography.caption.copyWith(
                      color: chip.text,
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

// ── Quotation card ────────────────────────────────────────────────────────────

class _BuyerQuotationCard extends StatelessWidget {
  final Quotation quotation;
  final VoidCallback onTap;

  const _BuyerQuotationCard({required this.quotation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final itemCount = quotation.items.length;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(accent: const Color(0xFFFFF3E0)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.amber600.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.request_quote_outlined,
                color: AppColors.amber600,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quotation.nurseryName ?? 'Nursery',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$itemCount item${itemCount == 1 ? '' : 's'} · ${quotation.quotationCode}',
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
                    color: AppColors.amber600.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Awaiting You',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.amber600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '₹${fmt.format(quotation.totalAmount)}',
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
          label: 'Nurseries',
          color: AppColors.blue600,
          onTap: onBrowseNurseries,
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
            'Browse nurseries and request plants. Your orders and offers will appear here.',
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

({Color bg, Color text, String label}) _orderStatusChip(String status) =>
    switch (status.toUpperCase()) {
      'PENDING' => (
          bg: const Color(0xFFFFF3E0),
          text: AppColors.amber600,
          label: 'Pending',
        ),
      'CONFIRMED' => (
          bg: const Color(0xFFE3F2FD),
          text: AppColors.blue600,
          label: 'Confirmed',
        ),
      'LOADING' => (
          bg: const Color(0xFFE8F5E9),
          text: AppColors.primaryMain,
          label: 'Loading',
        ),
      'LOADED' || 'PARTIALLY_FULFILLED' => (
          bg: const Color(0xFFE8F5E9),
          text: AppColors.primaryMain,
          label: 'Loaded',
        ),
      'COMPLETED' => (
          bg: const Color(0xFFE8F5E9),
          text: const Color(0xFF2E7D32),
          label: 'Completed',
        ),
      'CANCELLED' => (
          bg: const Color(0xFFFCE4EC),
          text: const Color(0xFFB71C1C),
          label: 'Cancelled',
        ),
      _ => (
          bg: AppColors.border,
          text: AppColors.textSecondary,
          label: _prettyStatus(status),
        ),
    };

String _prettyStatus(String status) => status
    .toLowerCase()
    .split('_')
    .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — MANAGER HOME SECTION                                            ║
// ║  Role:  MANAGER (Gumastha)                                                   ║
// ║  Guard: rendered only when caps.isManager == true                            ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// CONTEXT
// ───────
// Rendered inside HomeScreen as the main content block for a MANAGER (Gumastha).
// The manager is a nursery employee assigned by a nursery owner. They have
// operational access to the nursery without ownership rights.
//
// Dispatch condition in home_screen.dart:
//   else if (caps.isManager) ManagerHome()
//
// CRITICAL BUSINESS RULE — MANAGER ≠ OWNER
// ─────────────────────────────────────────
//   A manager CANNOT be a nursery owner simultaneously.
//   If a user is already a manager and tries to register a nursery:
//     API returns 409 conflicting_role
//   This means caps.isManager and caps.isNurseryOwner are mutually exclusive.
//   Never show the "Register Nursery" CTA for managers.
//
// NURSERY CONTEXT
// ────────────────
// Manager is linked to a nursery through their membership:
//   caps.primaryNurseryId  — the nursery they manage (from session)
//   All nursery-scoped API calls use this ID
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  RBAC — WHAT A MANAGER CAN DO (home dashboard context)                     │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ✅  View assigned nursery orders      GET  /api/v1/orders                  │
// │  ✅  View order detail                 GET  /api/v1/orders/:id              │
// │  ✅  Create orders for buyers          POST /api/v1/orders                  │
// │  ✅  Confirm order                     POST /api/v1/orders/:id/confirm       │
// │  ✅  Cancel order (PENDING/CONFIRMED)  POST /api/v1/orders/:id/cancel        │
// │  ✅  Start loading (CONFIRMED→LOADING) POST /api/v1/orders/:id/start-loading │
// │  ✅  Set loaded quantity per item      PUT  /api/v1/orders/:id/items/:itemId/loaded-quantity│
// │  ✅  Complete loading (→LOADED)        POST /api/v1/orders/:id/complete-loading│
// │  ✅  Create quotations for buyers      POST /api/v1/quotations               │
// │  ✅  View quotations                   GET  /api/v1/quotations               │
// │  ✅  Approve quotation                 POST /api/v1/quotations/:id/approve   │
// │  ✅  Convert accepted quotation→order  POST /api/v1/quotations/:id/convert-to-order│
// │  ✅  View inventory (read-only)        GET  /api/v1/nurseries/:id/inventory  │
// │  ✅  Create dispatches                 POST /api/v1/dispatches               │
// │  ✅  View dispatches                   GET  /api/v1/dispatches               │
// │  ✅  Invite customers                  POST /api/v1/invites  (CUSTOMER_INVITE)│
// │  ✅  Invite drivers (if applicable)    POST /api/v1/invites  (DRIVER_INVITE) │
// │  ✅  Browse sourcing network           GET  /api/v1/sourcing                 │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  RBAC — WHAT A MANAGER CANNOT DO                                            │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ❌  Invite managers  POST /api/v1/invites (MANAGER_INVITE) — owner only    │
// │  ❌  View team list   GET /api/v1/nurseries/:id/managers     — owner only   │
// │  ❌  Delete orders    DELETE /api/v1/orders/:id               — owner only  │
// │  ❌  Delete quotations DELETE /api/v1/quotations/:id          — owner only  │
// │  ❌  Modify inventory  POST/PUT/DELETE /api/v1/inventory       — owner only │
// │  ❌  Update nursery settings PUT /api/v1/nurseries/:id         — owner only │
// │  ❌  Register nursery POST /api/v1/nurseries  (409 conflicting_role)        │
// │  ❌  Access /nursery/members route (blocked by _ownerGuard in router.dart)  │
// │  ❌  Access /inventory/add route (blocked by _ownerGuard in router.dart)    │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// API CALLS — ON LOAD & PULL-TO-REFRESH
// ──────────────────────────────────────
//   1. GET /api/v1/orders?page=1&per_page=30
//        → Work queue: orders awaiting confirmation, loading
//   2. GET /api/v1/quotations?page=1&per_page=10
//        → Quotations needing action: unsent drafts + accepted ones to convert
//   3. GET /api/v1/dispatches?page=1&per_page=50
//        → Outbound dispatches — surfaces drivers waiting to be dispatched
//
// ORDER STATUS MACHINE (same as owner — API-enforced)
// ──────────────────────────────────────────────────────
//   PENDING → CONFIRMED → LOADING → LOADED | PARTIALLY_FULFILLED → COMPLETED
//   PENDING or CONFIRMED → CANCELLED
//   Manager CAN cancel from PENDING or CONFIRMED, same as owner
//   Manager CANNOT delete orders at any stage
//
// NAVIGATION FROM THIS WIDGET
// ────────────────────────────
//   context.push('/orders/create')       — new order (canSell → seller flow)
//   context.push('/quotations/create')   — new quotation
//   context.push('/connections')         — invite a customer (canSell-guarded,
//                                           NOT /nursery/members, which is
//                                           owner-only)
//   context.push('/orders/:id')          — order detail + state-machine actions
//   context.push('/quotations/:id')      — quotation detail + approve/convert
//   context.push('/dispatches')          — dispatch overview
//
// BUSINESS RULES — MUST ENFORCE IN UI
// ─────────────────────────────────────
//   • Never show "Register Nursery" CTA — will always fail with 409 conflicting_role
//   • Never show "Invite Manager" option — MANAGER_INVITE is owner-only
//   • Never show "Delete Order" button — not permitted
//   • Never navigate to /nursery/members — _ownerGuard redirects to /home
//   • Show inventory in READ-ONLY mode (no add/edit/delete controls)
//   • Loading queue is the primary manager home card (loading is the core work)
//
// SEE ALSO
// ─────────
//   lib/features/manager/manager_work_tab.dart  — full work tab content
//   lib/features/buying/buying_screen.dart       — routes to ManagerWorkTab
//   lib/features/selling/selling_screen.dart     — routes to ManagerWorkTab
//   lib/features/owner/owner_home.dart           — the owner's equivalent
//                                                   Action Center, same visual
//                                                   language (this file
//                                                   duplicates rather than
//                                                   shares those private
//                                                   widgets, since Dart's
//                                                   library-privacy is
//                                                   per-file)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/main_shell.dart';
import '../../core/domain/lifecycle_presenter.dart';
import '../../core/services/recent_items.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/shimmer.dart';
import '../dispatches/dispatches.dart';
import '../orders/orders.dart';
import '../quotations/quotations.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

final managerHomeProvider =
    FutureProvider.autoDispose<_ManagerHomeData>((ref) async {
  final orderRepo = ref.watch(orderRepositoryProvider);
  final dispatchRepo = ref.watch(dispatchRepositoryProvider);
  final quotationRepo = ref.watch(quotationRepositoryProvider);
  var orders = <Order>[];
  var dispatches = <Dispatch>[];
  var pendingQuotations = <Quotation>[];
  try {
    final (items, _) = await orderRepo.listOrders(page: 1, perPage: 30);
    orders = items;
  } catch (_) {}
  try {
    final (items, _) = await dispatchRepo.listDispatches(page: 1, perPage: 50);
    dispatches = items;
  } catch (_) {}
  try {
    final (items, _) = await quotationRepo.listQuotations(page: 1, perPage: 10);
    pendingQuotations = items
        .where((q) => q.status == 'DRAFT' || q.status == 'CUSTOMER_ACCEPTED')
        .toList();
  } catch (_) {}
  return _ManagerHomeData(
    orders: orders,
    dispatches: dispatches,
    pendingQuotations: pendingQuotations,
  );
});

class _ManagerHomeData {
  final List<Order> orders;
  final List<Dispatch> dispatches;
  final List<Quotation> pendingQuotations;

  const _ManagerHomeData({
    required this.orders,
    this.dispatches = const [],
    required this.pendingQuotations,
  });

  // Work queue: orders that need the manager to move them forward.
  List<Order> get workQueue => orders
      .where((o) => {'PENDING', 'CONFIRMED', 'LOADING'}
          .contains(o.status.toUpperCase()))
      .toList();

  int get ordersAwaitingLoadingCount => orders
      .where((o) =>
          {'CONFIRMED', 'LOADING'}.contains(o.status.toUpperCase()))
      .length;

  int get driversWaitingToDispatchCount =>
      dispatches.where((d) => d.status.toUpperCase() == 'ACCEPTED').length;

  bool get hasAnything => orders.isNotEmpty || pendingQuotations.isNotEmpty;

  Dispatch? dispatchForOrder(int orderId) =>
      LifecyclePresenter.activeDispatchForOrder(dispatches, orderId);
}

// ── Root widget ───────────────────────────────────────────────────────────────

/// Manager home section rendered inside HomeScreen for managers (Gumastha).
/// Same "what should I do next" Action Center treatment as OwnerHome, minus
/// anything owner-only (no team/inventory management, no Invite Manager).
class ManagerHome extends ConsumerWidget {
  const ManagerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(managerHomeProvider);
    final recentItems = ref.watch(recentItemsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ManagerQuickActions(
          onNewOrder: () => context.push('/orders/create'),
          onNewQuotation: () => context.push('/quotations/create'),
          onInviteCustomer: () => context.push('/connections'),
        ),
        if (recentItems.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x2l),
          _ManagerContinueWorkingSection(items: recentItems),
        ],
        const SizedBox(height: AppSpacing.x2l),
        homeAsync.when(
          loading: () => const _ManagerHomeSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
          data: (data) {
            if (!data.hasAnything) {
              return _EmptyManagerState(
                onGoToWork: () =>
                    ref.read(mainTabIndexProvider.notifier).state = 1,
              );
            }
            final attentionRows = <_ManagerAttentionRow>[
              if (data.ordersAwaitingLoadingCount > 0)
                _ManagerAttentionRow(
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.blue600,
                  label: '${data.ordersAwaitingLoadingCount} order'
                      '${data.ordersAwaitingLoadingCount == 1 ? '' : 's'} '
                      'waiting for loading',
                  onTap: () => context.push('/orders?status=CONFIRMED'),
                ),
              if (data.pendingQuotations.isNotEmpty)
                _ManagerAttentionRow(
                  icon: Icons.description_outlined,
                  color: AppColors.amber600,
                  label: '${data.pendingQuotations.length} quotation'
                      '${data.pendingQuotations.length == 1 ? '' : 's'} '
                      'need${data.pendingQuotations.length == 1 ? 's' : ''} '
                      'your action',
                  onTap: () => context.push('/quotations'),
                ),
              if (data.driversWaitingToDispatchCount > 0)
                _ManagerAttentionRow(
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.teal700,
                  label: '${data.driversWaitingToDispatchCount} driver'
                      '${data.driversWaitingToDispatchCount == 1 ? '' : 's'} '
                      'waiting to dispatch',
                  onTap: () => context.push('/dispatches'),
                ),
            ];

            var sectionIndex = 0;
            Widget section(Widget child) => FadeSlideIn(
                  delay: Duration(milliseconds: 60 * sectionIndex++),
                  child: child,
                );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (attentionRows.isNotEmpty) ...[
                  section(_ManagerNeedsAttentionCard(rows: attentionRows)),
                  const SizedBox(height: AppSpacing.x2l),
                ],
                if (data.pendingQuotations.isNotEmpty) ...[
                  section(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ManagerSectionHeader(
                        title: 'Quotations Needing Action',
                        actionLabel: 'View All',
                        onAction: () => context.push('/quotations'),
                      ),
                      const SizedBox(height: 10),
                      for (final q in data.pendingQuotations.take(3)) ...[
                        _ManagerQuotationCard(
                          quotation: q,
                          onTap: () => context.push('/quotations/${q.id}'),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  )),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (data.workQueue.isNotEmpty) ...[
                  section(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ManagerSectionHeader(
                        title: 'Work Queue',
                        actionLabel: 'View All',
                        onAction: () =>
                            ref.read(mainTabIndexProvider.notifier).state = 1,
                      ),
                      const SizedBox(height: 10),
                      for (final o in data.workQueue.take(3)) ...[
                        _ManagerOrderCard(
                          order: o,
                          dispatch: data.dispatchForOrder(o.id),
                          onTap: () => context.push('/orders/${o.id}'),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  )),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _ManagerQuickActions extends StatelessWidget {
  final VoidCallback onNewOrder;
  final VoidCallback onNewQuotation;
  final VoidCallback onInviteCustomer;

  const _ManagerQuickActions({
    required this.onNewOrder,
    required this.onNewQuotation,
    required this.onInviteCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 2.6,
      children: [
        _ManagerActionCell(
          icon: Icons.add_shopping_cart_rounded,
          label: 'New Order',
          color: AppColors.blue600,
          onTap: onNewOrder,
        ),
        _ManagerActionCell(
          icon: Icons.add_comment_outlined,
          label: 'New Quotation',
          color: AppColors.primaryMain,
          onTap: onNewQuotation,
        ),
        _ManagerActionCell(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Invite Customer',
          color: AppColors.amber600,
          onTap: onInviteCustomer,
        ),
      ],
    );
  }
}

class _ManagerActionCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ManagerActionCell({
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

// ── Continue Working ──────────────────────────────────────────────────────────

class _ManagerContinueWorkingSection extends StatelessWidget {
  final List<RecentItem> items;

  const _ManagerContinueWorkingSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Continue Working', style: AppTypography.h4),
        const SizedBox(height: 10),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) =>
                _ManagerContinueWorkingCard(item: items[i]),
          ),
        ),
      ],
    );
  }
}

class _ManagerContinueWorkingCard extends StatelessWidget {
  final RecentItem item;

  const _ManagerContinueWorkingCard({required this.item});

  IconData get _icon => switch (item.type) {
        RecentItemType.order => Icons.receipt_long_outlined,
        RecentItemType.quotation => Icons.description_outlined,
        RecentItemType.dispatch => Icons.local_shipping_outlined,
      };

  String get _route => switch (item.type) {
        RecentItemType.order => '/orders/${item.id}',
        RecentItemType.quotation => '/quotations/${item.id}',
        RecentItemType.dispatch => '/dispatches/${item.id}',
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(_route),
      borderRadius: AppRadius.cardRadius,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, color: AppColors.primaryMain, size: 20),
            const SizedBox(height: 6),
            Text(
              item.title,
              style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.subtitle.isNotEmpty)
              Text(
                item.subtitle,
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _ManagerHomeSkeleton extends StatelessWidget {
  const _ManagerHomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 150, height: 16),
                SizedBox(height: 18),
                ShimmerBox(height: 16),
                SizedBox(height: 12),
                ShimmerBox(height: 16),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const ShimmerBox(width: 130, height: 18),
          const SizedBox(height: 10),
          Container(height: 76, decoration: _cardDecoration()),
          const SizedBox(height: 10),
          Container(height: 76, decoration: _cardDecoration()),
        ],
      ),
    );
  }
}

// ── Needs Attention ───────────────────────────────────────────────────────────

class _ManagerAttentionRow {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ManagerAttentionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
}

class _ManagerNeedsAttentionCard extends StatelessWidget {
  final List<_ManagerAttentionRow> rows;

  const _ManagerNeedsAttentionCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.red600,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Needs Attention (${rows.length})',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          for (final row in rows)
            InkWell(
              onTap: row.onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                child: Row(
                  children: [
                    Icon(row.icon, color: row.color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        row.label,
                        style: AppTypography.bodySmall
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _ManagerSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ManagerSectionHeader({
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

class _ManagerOrderCard extends StatelessWidget {
  final Order order;
  final Dispatch? dispatch;
  final VoidCallback onTap;

  const _ManagerOrderCard({
    required this.order,
    required this.onTap,
    this.dispatch,
  });

  @override
  Widget build(BuildContext context) {
    final display = LifecyclePresenter.forOrder(
      order: order,
      dispatch: dispatch,
      role: LifecycleRole.operator,
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
                    order.buyerName ?? 'Customer',
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Container(
                    key: ValueKey(display.label),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
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

// ── Quotation alert card ──────────────────────────────────────────────────────

class _ManagerQuotationCard extends StatelessWidget {
  final Quotation quotation;
  final VoidCallback onTap;

  const _ManagerQuotationCard({required this.quotation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDraft = quotation.status == 'DRAFT';
    final color = isDraft ? AppColors.amber600 : AppColors.blue600;
    final bg = isDraft ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD);
    final actionLabel = isDraft ? 'Approve & Send' : 'Convert to Order';

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(accent: bg.withValues(alpha: 0.4)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDraft ? Icons.description_outlined : Icons.task_alt_rounded,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quotation.quotationCode,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    quotation.recipientName ?? 'Customer',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                actionLabel,
                style: AppTypography.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyManagerState extends StatelessWidget {
  final VoidCallback onGoToWork;

  const _EmptyManagerState({required this.onGoToWork});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: _cardDecoration(accent: AppColors.forest50),
      child: Column(
        children: [
          const Icon(Icons.work_outline_rounded,
              size: 54, color: AppColors.primaryMain),
          const SizedBox(height: 16),
          Text(
            'Nothing needs your attention',
            style: AppTypography.h3.copyWith(color: AppColors.primaryMain),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'New orders and quotations will show up here as they come in.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onGoToWork,
            icon: const Icon(Icons.work_outline_rounded, size: 18),
            label: const Text('Go to Work'),
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

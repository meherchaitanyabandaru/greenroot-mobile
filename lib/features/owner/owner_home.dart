// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — OWNER HOME SECTION                                              ║
// ║  Role:  NURSERY_OWNER                                                        ║
// ║  Guard: rendered only when caps.isNurseryOwner == true                       ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

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
import '../auth/presentation/providers/session_provider.dart';
import '../dispatches/dispatches.dart';
import '../market/local_market_providers.dart' show receivedEnquiriesProvider;
import '../orders/orders.dart';
import '../quotations/quotations.dart';
import 'nursery_setup_prompt.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

final ownerHomeProvider =
    FutureProvider.autoDispose<_OwnerHomeData>((ref) async {
  final orderRepo = ref.watch(orderRepositoryProvider);
  final dispatchRepo = ref.watch(dispatchRepositoryProvider);
  final quotationRepo = ref.watch(quotationRepositoryProvider);
  var orders = <Order>[];
  var dispatches = <Dispatch>[];
  var pendingQuotations = <Quotation>[];
  var newEnquiriesCount = 0;
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
  try {
    // receivedEnquiriesProvider already handles its own request/JSON parsing
    // (see local_market_providers.dart) -- reused here rather than
    // duplicating a second Local Market repository call.
    final enquiries = await ref.read(receivedEnquiriesProvider.future);
    newEnquiriesCount =
        enquiries.where((e) => e.status.toUpperCase() == 'NEW').length;
  } catch (_) {}
  return _OwnerHomeData(
    orders: orders,
    dispatches: dispatches,
    pendingQuotations: pendingQuotations,
    newEnquiriesCount: newEnquiriesCount,
  );
});

class _OwnerHomeData {
  final List<Order> orders;
  final List<Dispatch> dispatches;
  final List<Quotation> pendingQuotations;
  final int newEnquiriesCount;

  const _OwnerHomeData({
    required this.orders,
    this.dispatches = const [],
    required this.pendingQuotations,
    this.newEnquiriesCount = 0,
  });

  List<Order> get activeOrders => orders
      .where(
          (o) => !{'COMPLETED', 'CANCELLED'}.contains(o.status.toUpperCase()))
      .toList();

  int get completedCount =>
      orders.where((o) => o.status.toUpperCase() == 'COMPLETED').length;

  int get pendingCount =>
      orders.where((o) => o.status.toUpperCase() == 'PENDING').length;

  // "Needs attention" counts -- each one is something the OWNER must act on
  // next, not just a status snapshot (see _NeedsAttentionCard).
  int get ordersAwaitingLoadingCount => orders
      .where((o) =>
          {'CONFIRMED', 'LOADING'}.contains(o.status.toUpperCase()))
      .length;

  int get driversWaitingToDispatchCount =>
      dispatches.where((d) => d.status.toUpperCase() == 'ACCEPTED').length;

  bool get hasAnything =>
      orders.isNotEmpty || pendingQuotations.isNotEmpty || newEnquiriesCount > 0;

  Dispatch? dispatchForOrder(int orderId) =>
      LifecyclePresenter.activeDispatchForOrder(dispatches, orderId);
}

// ── Root widget ───────────────────────────────────────────────────────────────

class OwnerHome extends ConsumerWidget {
  const OwnerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(ownerHomeProvider);
    final recentItems = ref.watch(recentItemsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NurserySetupPrompt(),
        const SizedBox(height: AppSpacing.lg),
        _OwnerQuickActions(
          onNewOrder: () => context.push('/orders/create'),
          onNewQuotation: () => context.push('/quotations/create'),
          onNewMarketAd: () =>
              ref.read(mainTabIndexProvider.notifier).state = 3,
          onInviteMember: () => context.push('/nursery/members'),
        ),
        if (recentItems.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x2l),
          _ContinueWorkingSection(items: recentItems),
        ],
        const SizedBox(height: AppSpacing.x2l),
        homeAsync.when(
          loading: () => const _OwnerHomeSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
          data: (data) {
            if (!data.hasAnything) {
              return _EmptyOwnerState(
                onAddOrder: () =>
                    ref.read(mainTabIndexProvider.notifier).state = 2,
              );
            }
            final attentionRows = <_AttentionRowData>[
              if (data.ordersAwaitingLoadingCount > 0)
                _AttentionRowData(
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.blue600,
                  label: '${data.ordersAwaitingLoadingCount} order'
                      '${data.ordersAwaitingLoadingCount == 1 ? '' : 's'} '
                      'waiting for loading',
                  onTap: () => context.push('/orders?status=CONFIRMED'),
                ),
              if (data.pendingQuotations.isNotEmpty)
                _AttentionRowData(
                  icon: Icons.description_outlined,
                  color: AppColors.amber600,
                  label: '${data.pendingQuotations.length} quotation'
                      '${data.pendingQuotations.length == 1 ? '' : 's'} '
                      'need${data.pendingQuotations.length == 1 ? 's' : ''} '
                      'your action',
                  onTap: () => context.push('/quotations'),
                ),
              if (data.driversWaitingToDispatchCount > 0)
                _AttentionRowData(
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.teal700,
                  label: '${data.driversWaitingToDispatchCount} driver'
                      '${data.driversWaitingToDispatchCount == 1 ? '' : 's'} '
                      'waiting to dispatch',
                  onTap: () => context.push('/dispatches'),
                ),
              if (data.newEnquiriesCount > 0)
                _AttentionRowData(
                  icon: Icons.storefront_outlined,
                  color: AppColors.primaryMain,
                  label: '${data.newEnquiriesCount} new market '
                      'enquir${data.newEnquiriesCount == 1 ? 'y' : 'ies'}',
                  onTap: () =>
                      ref.read(mainTabIndexProvider.notifier).state = 3,
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
                  section(_NeedsAttentionCard(rows: attentionRows)),
                  const SizedBox(height: AppSpacing.x2l),
                ],
                section(_OwnerSummaryRow(
                  totalCount: data.orders.length,
                  activeCount: data.activeOrders.length,
                  pendingCount: data.pendingCount,
                  onTap: () => ref.read(mainTabIndexProvider.notifier).state = 2,
                )),
                if (data.pendingQuotations.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x2l),
                  section(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: 'Quotations Needing Action',
                        actionLabel: 'View All',
                        onAction: () => context.push('/quotations'),
                      ),
                      const SizedBox(height: 10),
                      for (final q in data.pendingQuotations.take(3)) ...[
                        _QuotationAlertCard(
                          quotation: q,
                          onTap: () => context.push('/quotations/${q.id}'),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  )),
                ],
                if (data.activeOrders.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  section(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: 'Active Orders',
                        actionLabel: 'View All',
                        onAction: () =>
                            ref.read(mainTabIndexProvider.notifier).state = 2,
                      ),
                      const SizedBox(height: 10),
                      for (final o in data.activeOrders.take(3)) ...[
                        _OwnerOrderCard(
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

// ── Continue Working ──────────────────────────────────────────────────────────

/// Horizontal "resume where you left off" strip -- the last few order/
/// quotation/dispatch detail screens actually opened (see recent_items.dart
/// and the record() calls in each detail screen), not just recently
/// *created* records. Lets a user who got interrupted mid-task jump
/// straight back in instead of re-navigating or re-searching for it.
class _ContinueWorkingSection extends StatelessWidget {
  final List<RecentItem> items;

  const _ContinueWorkingSection({required this.items});

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
            itemBuilder: (context, i) => _ContinueWorkingCard(item: items[i]),
          ),
        ),
      ],
    );
  }
}

class _ContinueWorkingCard extends StatelessWidget {
  final RecentItem item;

  const _ContinueWorkingCard({required this.item});

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

/// Shape-matched shimmer placeholder for the Action Center's first paint --
/// a rough silhouette of the Needs Attention card, KPI row and one order
/// card, so the layout doesn't visibly jump once real data lands.
class _OwnerHomeSkeleton extends StatelessWidget {
  const _OwnerHomeSkeleton();

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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: _cardDecoration(),
            child: const Row(
              children: [
                Expanded(child: Center(child: ShimmerBox(width: 32, height: 32))),
                Expanded(child: Center(child: ShimmerBox(width: 32, height: 32))),
                Expanded(child: Center(child: ShimmerBox(width: 32, height: 32))),
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

class _AttentionRowData {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _AttentionRowData({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
}

/// "What should I do next?" -- the first thing the owner sees, above the
/// generic KPI counts. Each row is a specific, actionable item (not just a
/// status snapshot); the whole card is omitted when there's nothing to act
/// on rather than showing an empty "all clear" placeholder.
class _NeedsAttentionCard extends StatelessWidget {
  final List<_AttentionRowData> rows;

  const _NeedsAttentionCard({required this.rows});

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

// ── Quick actions ─────────────────────────────────────────────────────────────

class _OwnerQuickActions extends StatelessWidget {
  final VoidCallback onNewOrder;
  final VoidCallback onNewQuotation;
  final VoidCallback onNewMarketAd;
  final VoidCallback onInviteMember;

  const _OwnerQuickActions({
    required this.onNewOrder,
    required this.onNewQuotation,
    required this.onNewMarketAd,
    required this.onInviteMember,
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
        _ActionCell(
          icon: Icons.add_shopping_cart_rounded,
          label: 'New Order',
          color: AppColors.blue600,
          onTap: onNewOrder,
        ),
        _ActionCell(
          icon: Icons.add_comment_outlined,
          label: 'New Quotation',
          color: AppColors.primaryMain,
          onTap: onNewQuotation,
        ),
        _ActionCell(
          icon: Icons.storefront_outlined,
          label: 'New Market Ad',
          color: AppColors.teal700,
          onTap: onNewMarketAd,
        ),
        _ActionCell(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Invite Member',
          color: AppColors.amber600,
          onTap: onInviteMember,
        ),
      ],
    );
  }
}

// ── KPI summary row ───────────────────────────────────────────────────────────

class _OwnerSummaryRow extends StatelessWidget {
  final int totalCount;
  final int activeCount;
  final int pendingCount;
  final VoidCallback onTap;

  const _OwnerSummaryRow({
    required this.totalCount,
    required this.activeCount,
    required this.pendingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _KpiCell(
            icon: Icons.receipt_long_outlined,
            value: totalCount,
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
            value: activeCount,
            label: 'Active',
            color: AppColors.blue600,
            onTap: onTap,
          ),
          const SizedBox(
            height: 80,
            child: VerticalDivider(width: 1, color: AppColors.border),
          ),
          _KpiCell(
            icon: Icons.hourglass_top_rounded,
            value: pendingCount,
            label: 'Pending',
            color: AppColors.amber600,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _KpiCell extends StatelessWidget {
  final IconData icon;
  final int value;
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
              // Counts up from 0 on first load (and smoothly re-counts on
              // any later change, e.g. pull-to-refresh) rather than a
              // static number appearing instantly.
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: value),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, animatedValue, child) => Text(
                  '$animatedValue',
                  style: AppTypography.h2.copyWith(color: color, height: 1),
                ),
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

class _OwnerOrderCard extends StatelessWidget {
  final Order order;
  final Dispatch? dispatch;
  final VoidCallback onTap;

  const _OwnerOrderCard({
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
                    order.customerName ?? order.buyerName ?? 'Customer',
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

class _QuotationAlertCard extends StatelessWidget {
  final Quotation quotation;
  final VoidCallback onTap;

  const _QuotationAlertCard({required this.quotation, required this.onTap});

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

class _EmptyOwnerState extends StatelessWidget {
  final VoidCallback onAddOrder;

  const _EmptyOwnerState({required this.onAddOrder});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: _cardDecoration(accent: AppColors.forest50),
      child: Column(
        children: [
          const Icon(Icons.storefront_rounded,
              size: 54, color: AppColors.primaryMain),
          const SizedBox(height: 16),
          Text(
            'Ready to take orders',
            style: AppTypography.h3.copyWith(color: AppColors.primaryMain),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Invite customers or create a quotation to get started.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAddOrder,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Go to Selling'),
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

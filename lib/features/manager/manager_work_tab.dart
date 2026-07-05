// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — MANAGER WORK TAB                                               ║
// ║  Role:  MANAGER  |  Entry: SellingScreen → ManagerWorkTab                  ║
// ║  APIs:  GET /api/v1/orders                                                  ║
// ║         GET /api/v1/quotations                                              ║
// ║  Dispatch info is shown inside the Order Detail screen, not as a tab.       ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/providers/paged_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/seller_order_card_actions.dart';
import '../../core/widgets/trade_status_chip.dart';
import '../orders/orders.dart';
import '../quotations/quotations.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════════════════

class _MgrOrderNotifier extends PagedNotifier<Order> {
  _MgrOrderNotifier(OrderRepository repo)
      : super(
          fetch: (p, pp) => repo.listOrders(page: p, perPage: pp),
          idOf: (o) => o.id,
        );
}

final _mgrOrderProvider =
    StateNotifierProvider.autoDispose<_MgrOrderNotifier, PagedState<Order>>(
  (ref) => _MgrOrderNotifier(ref.watch(orderRepositoryProvider)),
);

class _MgrQuotationNotifier extends PagedNotifier<Quotation> {
  _MgrQuotationNotifier(QuotationRepository repo)
      : super(
          fetch: (p, pp) => repo.listQuotations(page: p, perPage: pp),
          idOf: (q) => q.id,
        );
}

final _mgrQuotationProvider = StateNotifierProvider.autoDispose<
    _MgrQuotationNotifier, PagedState<Quotation>>(
  (ref) => _MgrQuotationNotifier(ref.watch(quotationRepositoryProvider)),
);

// ══════════════════════════════════════════════════════════════════════════════
// MAIN WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class ManagerWorkTab extends ConsumerStatefulWidget {
  const ManagerWorkTab({super.key});

  @override
  ConsumerState<ManagerWorkTab> createState() => _ManagerWorkTabState();
}

class _ManagerWorkTabState extends ConsumerState<ManagerWorkTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(_mgrOrderProvider.notifier).load();
      ref.read(_mgrQuotationProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_mgrOrderProvider);
    ref.watch(_mgrQuotationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: AppSpacing.screenPadding,
        title: const Text('My Work', style: AppTypography.h2),
        bottom: TabBar(
          controller: _tabs,
          labelStyle: AppTypography.h4,
          unselectedLabelStyle:
              AppTypography.h4.copyWith(color: AppColors.textSecondary),
          labelColor: AppColors.primaryMain,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryMain,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'Orders'),
            Tab(text: 'Quotations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _MgrOrdersTab(),
          _MgrQuotationsTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — ORDERS (Dispatch info lives in Order Detail screen)
// ══════════════════════════════════════════════════════════════════════════════

class _MgrOrdersTab extends ConsumerWidget {
  const _MgrOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paged = ref.watch(_mgrOrderProvider);

    if (paged.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryMain));
    }
    if (paged.error != null && paged.items.isEmpty) {
      return ErrorState(
        error: paged.error,
        onRetry: () => ref.read(_mgrOrderProvider.notifier).load(),
      );
    }
    if (paged.items.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No orders yet',
        subtitle: 'Orders placed by customers will appear here.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryMain,
      onRefresh: () => ref.read(_mgrOrderProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding, vertical: AppSpacing.lg),
        itemCount: paged.items.length + (paged.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          if (i == paged.items.length) {
            ref.read(_mgrOrderProvider.notifier).loadMore();
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _MgrOrderCard(order: paged.items[i]);
        },
      ),
    );
  }
}

class _MgrOrderCard extends ConsumerWidget {
  final Order order;
  const _MgrOrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = order;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM');
    final date = DateTime.tryParse(o.orderDate)?.toLocal();

    return GestureDetector(
      onTap: () => context.push('/orders/${o.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(o.orderNumber,
                        style: AppTypography.h4,
                        overflow: TextOverflow.ellipsis)),
                TradeStatusChip(status: o.status, kind: TradeChipKind.order),
              ],
            ),
            if (o.buyerName?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(o.buyerName!,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (o.items.isNotEmpty) ...[
                  const Icon(Icons.eco_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                      '${o.items.length} item${o.items.length == 1 ? '' : 's'}',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(width: AppSpacing.lg),
                ],
                if (date != null) ...[
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.xs),
                  Text(dateFmt.format(date),
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
                const Spacer(),
                Text(fmt.format(o.totalAmount),
                    style:
                        AppTypography.h3.copyWith(color: AppColors.primaryMain)),
              ],
            ),
            SellerOrderCardActions(
              order: o,
              onUpdated: (updated) =>
                  ref.read(_mgrOrderProvider.notifier).updateItem(updated),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — QUOTATIONS
// ══════════════════════════════════════════════════════════════════════════════

class _MgrQuotationsTab extends ConsumerWidget {
  const _MgrQuotationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paged = ref.watch(_mgrQuotationProvider);

    if (paged.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryMain));
    }
    if (paged.error != null && paged.items.isEmpty) {
      return ErrorState(
        error: paged.error,
        onRetry: () => ref.read(_mgrQuotationProvider.notifier).load(),
      );
    }
    if (paged.items.isEmpty) {
      return const EmptyState(
        icon: Icons.request_quote_outlined,
        title: 'No quotations yet',
        subtitle: 'Quotations you create for buyers will appear here.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryMain,
      onRefresh: () => ref.read(_mgrQuotationProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding, vertical: AppSpacing.lg),
        itemCount: paged.items.length + (paged.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          if (i == paged.items.length) {
            ref.read(_mgrQuotationProvider.notifier).loadMore();
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _MgrQuotationCard(quotation: paged.items[i]);
        },
      ),
    );
  }
}

class _MgrQuotationCard extends ConsumerStatefulWidget {
  final Quotation quotation;
  const _MgrQuotationCard({required this.quotation});

  @override
  ConsumerState<_MgrQuotationCard> createState() => _MgrQuotationCardState();
}

class _MgrQuotationCardState extends ConsumerState<_MgrQuotationCard> {
  bool _acting = false;

  bool get _canApprove => widget.quotation.status == 'DRAFT';
  bool get _canConvert => widget.quotation.status == 'CUSTOMER_ACCEPTED';

  Future<void> _approve() async {
    setState(() => _acting = true);
    try {
      final updated = await ref
          .read(quotationRepositoryProvider)
          .approveQuotation(widget.quotation.id);
      ref.read(_mgrQuotationProvider.notifier).updateItem(updated);
      if (mounted) _snack('Quotation approved & sent to buyer', AppColors.primaryMain);
    } on AppError catch (e) {
      if (mounted) _snack(e.message, AppColors.red600);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _convert() async {
    setState(() => _acting = true);
    try {
      final order = await ref
          .read(quotationRepositoryProvider)
          .convertToOrder(widget.quotation.id);
      ref.read(_mgrQuotationProvider.notifier).load();
      if (mounted) {
        _snack('Converted to order ${order.orderNumber}', AppColors.primaryMain);
        context.push('/orders/${order.id}');
      }
    } on AppError catch (e) {
      if (mounted) _snack(e.message, AppColors.red600);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quotation;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM');
    final date = DateTime.tryParse(q.createdAt)?.toLocal();

    return GestureDetector(
      onTap: () => context.push('/quotations/${q.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(q.quotationCode,
                        style: AppTypography.h4,
                        overflow: TextOverflow.ellipsis)),
                TradeStatusChip(status: q.status, kind: TradeChipKind.quotation),
              ],
            ),
            if (q.recipientName?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(q.recipientName!,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (q.items.isNotEmpty) ...[
                  const Icon(Icons.eco_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                      '${q.items.length} item${q.items.length == 1 ? '' : 's'}',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(width: AppSpacing.lg),
                ],
                if (date != null) ...[
                  const Icon(Icons.schedule_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.xs),
                  Text(dateFmt.format(date),
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
                const Spacer(),
                Text(fmt.format(q.totalAmount),
                    style:
                        AppTypography.h3.copyWith(color: AppColors.primaryMain)),
              ],
            ),
            if (_canApprove || _canConvert) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
              _acting
                  ? const Center(
                      child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : Row(
                      children: [
                        if (_canApprove)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _approve,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryMain,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(
                                    AppSpacing.buttonHeightSm),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Approve & Send'),
                            ),
                          ),
                        if (_canConvert)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _convert,
                              icon: const Icon(Icons.swap_horiz_rounded,
                                  size: 16),
                              label: const Text('Convert to Order'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blue600,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(
                                    AppSpacing.buttonHeightSm),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                      ],
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

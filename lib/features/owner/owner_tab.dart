// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — OWNER TAB                                                      ║
// ║  Role:  NURSERY_OWNER  |  Entry: SellingScreen → OwnerTab                  ║
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
import '../quotations/quotation_create_screen.dart';
import '../quotations/quotations.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════════════════

class _SellerOrderNotifier extends PagedNotifier<Order> {
  _SellerOrderNotifier(OrderRepository repo)
      : super(
          fetch: (p, pp) => repo.listOrders(page: p, perPage: pp),
          idOf: (o) => o.id,
        );
}

final _sellerOrderProvider =
    StateNotifierProvider.autoDispose<_SellerOrderNotifier, PagedState<Order>>(
  (ref) => _SellerOrderNotifier(ref.watch(orderRepositoryProvider)),
);

class _SellerQuotationNotifier extends PagedNotifier<Quotation> {
  _SellerQuotationNotifier(QuotationRepository repo)
      : super(
          fetch: (p, pp) => repo.listQuotations(page: p, perPage: pp),
          idOf: (q) => q.id,
        );
}

final _sellerQuotationProvider = StateNotifierProvider.autoDispose<
    _SellerQuotationNotifier, PagedState<Quotation>>(
  (ref) => _SellerQuotationNotifier(ref.watch(quotationRepositoryProvider)),
);

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class OwnerTab extends ConsumerStatefulWidget {
  const OwnerTab({super.key});

  @override
  ConsumerState<OwnerTab> createState() => _OwnerTabState();
}

class _OwnerTabState extends ConsumerState<OwnerTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index != _tabIndex) setState(() => _tabIndex = _tabs.index);
    });
    Future.microtask(() {
      ref.read(_sellerOrderProvider.notifier).load();
      ref.read(_sellerQuotationProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _createQuotation() async {
    final choice = await showQuotationTypeDialog(context);
    if (choice == null || !mounted) return;
    final type = choice == QuotationTypeChoice.internal ? 'INTERNAL' : 'CUSTOMER';
    final created = await context.push<bool>('/quotations/create?type=$type');
    if (created == true) ref.read(_sellerQuotationProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_sellerOrderProvider);
    ref.watch(_sellerQuotationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _createQuotation,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Quotation'),
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              elevation: 2,
            )
          : null,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: AppSpacing.screenPadding,
        title: const Text('My Nursery', style: AppTypography.h2),
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
            Tab(text: 'Quotations'),
            Tab(text: 'Orders'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _SellerQuotationsTab(),
          _SellerOrdersTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — QUOTATIONS
// ══════════════════════════════════════════════════════════════════════════════

class _SellerQuotationsTab extends ConsumerWidget {
  const _SellerQuotationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paged = ref.watch(_sellerQuotationProvider);

    if (paged.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryMain));
    }

    if (paged.error != null && paged.items.isEmpty) {
      return ErrorState(
        error: paged.error,
        onRetry: () => ref.read(_sellerQuotationProvider.notifier).load(),
      );
    }

    if (paged.items.isEmpty) {
      return const EmptyState(
        icon: Icons.request_quote_outlined,
        title: 'No quotations yet',
        subtitle: 'Tap New Quotation to create your first one.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryMain,
      onRefresh: () => ref.read(_sellerQuotationProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding, vertical: AppSpacing.lg),
        itemCount: paged.items.length + (paged.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          if (i == paged.items.length) {
            ref.read(_sellerQuotationProvider.notifier).loadMore();
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _SellerQuotationCard(quotation: paged.items[i]);
        },
      ),
    );
  }
}

class _SellerQuotationCard extends ConsumerStatefulWidget {
  final Quotation quotation;
  const _SellerQuotationCard({required this.quotation});

  @override
  ConsumerState<_SellerQuotationCard> createState() =>
      _SellerQuotationCardState();
}

class _SellerQuotationCardState extends ConsumerState<_SellerQuotationCard> {
  bool _acting = false;

  bool get _canApprove => widget.quotation.status == 'DRAFT';
  bool get _canConvert => widget.quotation.status == 'CUSTOMER_ACCEPTED';
  bool get _canDelete => {'DRAFT', 'APPROVED', 'CUSTOMER_REJECTED', 'EXPIRED'}
      .contains(widget.quotation.status);

  Future<void> _approve() async {
    setState(() => _acting = true);
    try {
      final updated = await ref
          .read(quotationRepositoryProvider)
          .approveQuotation(widget.quotation.id);
      ref.read(_sellerQuotationProvider.notifier).updateItem(updated);
      if (mounted) _snack('Quotation approved & sent to buyer', AppColors.primaryMain);
    } on AppError catch (e) {
      if (mounted) _snack(e.message, AppColors.red600);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _convert() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to Order', style: AppTypography.h3),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Order ID'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Convert')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final orderId = int.tryParse(ctrl.text.trim());
    if (orderId == null) return;
    setState(() => _acting = true);
    try {
      final q = await ref
          .read(quotationRepositoryProvider)
          .convertToOrder(widget.quotation.id, orderId: orderId);
      ref.read(_sellerQuotationProvider.notifier).load();
      if (mounted) {
        _snack('Converted to order', AppColors.primaryMain);
        if (q.convertedOrderId != null) context.push('/orders/${q.convertedOrderId}');
      }
    } on AppError catch (e) {
      if (mounted) _snack(e.message, AppColors.red600);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quotation', style: AppTypography.h3),
        content: Text(
          'Delete ${widget.quotation.quotationCode}?',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.red600)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _acting = true);
    try {
      await ref
          .read(quotationRepositoryProvider)
          .deleteQuotation(widget.quotation.id);
      ref.read(_sellerQuotationProvider.notifier).removeItem(widget.quotation.id);
      if (mounted) _snack('Quotation deleted', AppColors.slate700);
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
                      overflow: TextOverflow.ellipsis),
                ),
                TradeStatusChip(status: q.status, kind: TradeChipKind.quotation),
                if (q.isExpired && q.status == 'CUSTOMER_SENT') ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.red100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Expired',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.red600,
                            fontWeight: FontWeight.w700,
                            fontSize: 10)),
                  ),
                ],
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
                        .copyWith(color: AppColors.textSecondary),
                  ),
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
            if (_canApprove || _canConvert || _canDelete) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
              _acting
                  ? const Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Row(
                      children: [
                        if (_canDelete)
                          IconButton(
                            onPressed: _delete,
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppColors.red600, size: 20),
                            tooltip: 'Delete',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        if (_canDelete && (_canApprove || _canConvert))
                          const SizedBox(width: AppSpacing.sm),
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

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — ORDERS (Dispatch info lives in Order Detail screen)
// ══════════════════════════════════════════════════════════════════════════════

class _SellerOrdersTab extends ConsumerWidget {
  const _SellerOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paged = ref.watch(_sellerOrderProvider);

    if (paged.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryMain));
    }

    if (paged.error != null && paged.items.isEmpty) {
      return ErrorState(
        error: paged.error,
        onRetry: () => ref.read(_sellerOrderProvider.notifier).load(),
      );
    }

    if (paged.items.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No orders yet',
        subtitle: 'Orders placed by your customers will appear here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryMain,
      onRefresh: () => ref.read(_sellerOrderProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding, vertical: AppSpacing.lg),
        itemCount: paged.items.length + (paged.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          if (i == paged.items.length) {
            ref.read(_sellerOrderProvider.notifier).loadMore();
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _SellerOrderCard(order: paged.items[i]);
        },
      ),
    );
  }
}

class _SellerOrderCard extends ConsumerWidget {
  final Order order;
  const _SellerOrderCard({required this.order});

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
                      overflow: TextOverflow.ellipsis),
                ),
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
                        .copyWith(color: AppColors.textSecondary),
                  ),
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
                  ref.read(_sellerOrderProvider.notifier).updateItem(updated),
            ),
          ],
        ),
      ),
    );
  }
}

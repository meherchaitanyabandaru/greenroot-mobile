// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — BUYER TAB  (Buying tab content for BUYER role)                 ║
// ║  Role:  BUYER only  |  Entry: BuyingScreen → BuyerTab                      ║
// ║  APIs:  GET /api/v1/quotations?buying=true                                  ║
// ║         GET /api/v1/orders?buying=true                                      ║
// ║         GET /api/v1/dispatches                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../dispatches/dispatches.dart';
import '../orders/orders.dart';
import '../quotations/quotations.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════════════════

// ── Buyer Quotations ──────────────────────────────────────────────────────────

class _BuyerQuotationState {
  final PagedState<Quotation> paged;
  const _BuyerQuotationState({required this.paged});
  _BuyerQuotationState copyWith({PagedState<Quotation>? paged}) =>
      _BuyerQuotationState(paged: paged ?? this.paged);
}

class _BuyerQuotationNotifier extends StateNotifier<_BuyerQuotationState> {
  final QuotationRepository _repo;
  int _page = 0;

  _BuyerQuotationNotifier(this._repo)
      : super(_BuyerQuotationState(paged: PagedState.initial()));

  Future<void> load() async {
    state = state.copyWith(
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) =
          await _repo.listBuyingQuotations(page: 1, perPage: 20);
      _page = 1;
      state = state.copyWith(
        paged: PagedState(
          items: items,
          isLoading: false,
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError catch (e) {
      state = state.copyWith(
        paged: state.paged.copyWith(isLoading: false, error: e),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.paged.isLoadingMore || !state.paged.hasMore) return;
    state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: true));
    try {
      final (items, pagination) =
          await _repo.listBuyingQuotations(page: _page + 1, perPage: 20);
      _page++;
      state = state.copyWith(
        paged: state.paged.copyWith(
          items: [...state.paged.items, ...items],
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError {
      state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: false));
    }
  }

  void updateItem(Quotation updated) {
    state = state.copyWith(
      paged: state.paged.copyWith(
        items: state.paged.items
            .map((q) => q.id == updated.id ? updated : q)
            .toList(),
      ),
    );
  }
}

final _buyerQuotationProvider = StateNotifierProvider.autoDispose<
    _BuyerQuotationNotifier, _BuyerQuotationState>(
  (ref) => _BuyerQuotationNotifier(ref.watch(quotationRepositoryProvider)),
);

// ── Buyer Orders ──────────────────────────────────────────────────────────────

class _BuyerOrderState {
  final PagedState<Order> paged;
  const _BuyerOrderState({required this.paged});
  _BuyerOrderState copyWith({PagedState<Order>? paged}) =>
      _BuyerOrderState(paged: paged ?? this.paged);
}

class _BuyerOrderNotifier extends StateNotifier<_BuyerOrderState> {
  final OrderRepository _repo;
  int _page = 0;

  _BuyerOrderNotifier(this._repo)
      : super(_BuyerOrderState(paged: PagedState.initial()));

  Future<void> load() async {
    state = state.copyWith(
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) =
          await _repo.listBuyingOrders(page: 1, perPage: 20);
      _page = 1;
      state = state.copyWith(
        paged: PagedState(
          items: items,
          isLoading: false,
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError catch (e) {
      state = state.copyWith(
        paged: state.paged.copyWith(isLoading: false, error: e),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.paged.isLoadingMore || !state.paged.hasMore) return;
    state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: true));
    try {
      final (items, pagination) =
          await _repo.listBuyingOrders(page: _page + 1, perPage: 20);
      _page++;
      state = state.copyWith(
        paged: state.paged.copyWith(
          items: [...state.paged.items, ...items],
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError {
      state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: false));
    }
  }

  void updateItem(Order updated) {
    state = state.copyWith(
      paged: state.paged.copyWith(
        items: state.paged.items
            .map((o) => o.id == updated.id ? updated : o)
            .toList(),
      ),
    );
  }
}

final _buyerOrderProvider =
    StateNotifierProvider.autoDispose<_BuyerOrderNotifier, _BuyerOrderState>(
  (ref) => _BuyerOrderNotifier(ref.watch(orderRepositoryProvider)),
);

// ── Buyer Dispatches ──────────────────────────────────────────────────────────

class _BuyerDispatchState {
  final PagedState<Dispatch> paged;
  const _BuyerDispatchState({required this.paged});
  _BuyerDispatchState copyWith({PagedState<Dispatch>? paged}) =>
      _BuyerDispatchState(paged: paged ?? this.paged);
}

class _BuyerDispatchNotifier extends StateNotifier<_BuyerDispatchState> {
  final DispatchRepository _repo;
  int _page = 0;

  _BuyerDispatchNotifier(this._repo)
      : super(_BuyerDispatchState(paged: PagedState.initial()));

  Future<void> load() async {
    state = state.copyWith(
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) =
          await _repo.listDispatches(page: 1, perPage: 20);
      _page = 1;
      state = state.copyWith(
        paged: PagedState(
          items: items,
          isLoading: false,
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError catch (e) {
      state = state.copyWith(
        paged: state.paged.copyWith(isLoading: false, error: e),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.paged.isLoadingMore || !state.paged.hasMore) return;
    state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: true));
    try {
      final (items, pagination) =
          await _repo.listDispatches(page: _page + 1, perPage: 20);
      _page++;
      state = state.copyWith(
        paged: state.paged.copyWith(
          items: [...state.paged.items, ...items],
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError {
      state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: false));
    }
  }
}

final _buyerDispatchProvider = StateNotifierProvider.autoDispose<
    _BuyerDispatchNotifier, _BuyerDispatchState>(
  (ref) => _BuyerDispatchNotifier(ref.watch(dispatchRepositoryProvider)),
);

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class BuyerTab extends ConsumerStatefulWidget {
  const BuyerTab({super.key});

  @override
  ConsumerState<BuyerTab> createState() => _BuyerTabState();
}

class _BuyerTabState extends ConsumerState<BuyerTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(_buyerQuotationProvider.notifier).load();
      ref.read(_buyerOrderProvider.notifier).load();
      ref.read(_buyerDispatchProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: AppSpacing.screenPadding,
        title: const Text('My Purchases', style: AppTypography.h2),
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
            Tab(text: 'Offers'),
            Tab(text: 'Orders'),
            Tab(text: 'Deliveries'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _OffersTab(),
          _OrdersTab(),
          _DeliveriesTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — OFFERS (Quotations sent to this buyer)
// ══════════════════════════════════════════════════════════════════════════════

class _OffersTab extends ConsumerWidget {
  const _OffersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_buyerQuotationProvider);
    final paged = state.paged;

    if (paged.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (paged.error != null && paged.items.isEmpty) {
      return _ErrorRetry(
        message: paged.error!.message,
        onRetry: () => ref.read(_buyerQuotationProvider.notifier).load(),
      );
    }

    if (paged.items.isEmpty) {
      return const _EmptyState(
        icon: Icons.request_quote_outlined,
        title: 'No offers yet',
        subtitle: 'When a nursery sends you an offer, it will appear here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryMain,
      onRefresh: () => ref.read(_buyerQuotationProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.lg,
        ),
        itemCount: paged.items.length + (paged.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          if (i == paged.items.length) {
            ref.read(_buyerQuotationProvider.notifier).loadMore();
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _QuotationCard(quotation: paged.items[i]);
        },
      ),
    );
  }
}

class _QuotationCard extends ConsumerStatefulWidget {
  final Quotation quotation;
  const _QuotationCard({required this.quotation});

  @override
  ConsumerState<_QuotationCard> createState() => _QuotationCardState();
}

class _QuotationCardState extends ConsumerState<_QuotationCard> {
  bool _acting = false;

  bool get _canRespond => const {
        'APPROVED',
        'SENT',
        'CUSTOMER_SENT',
      }.contains(widget.quotation.status);

  Future<void> _accept() async {
    setState(() => _acting = true);
    try {
      final updated = await ref
          .read(quotationRepositoryProvider)
          .acceptQuotation(widget.quotation.id);
      ref.read(_buyerQuotationProvider.notifier).updateItem(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer accepted'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.red600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const _RejectReasonSheet(),
    );
    if (reason == null || !mounted) return;
    setState(() => _acting = true);
    try {
      final updated = await ref
          .read(quotationRepositoryProvider)
          .rejectQuotation(widget.quotation.id, reason: reason);
      ref.read(_buyerQuotationProvider.notifier).updateItem(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer declined'),
            backgroundColor: AppColors.slate700,
          ),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.red600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quotation;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM yyyy');
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
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    q.quotationCode,
                    style: AppTypography.h4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(status: q.status, type: _ChipType.quotation),
              ],
            ),

            if (q.nurseryName?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      q.nurseryName!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.sm),

            // Items count + total
            Row(
              children: [
                if (q.items.isNotEmpty) ...[
                  const Icon(
                    Icons.eco_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${q.items.length} ${q.items.length == 1 ? 'item' : 'items'}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ],
                if (date != null) ...[
                  const Icon(
                    Icons.schedule_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    dateFmt.format(date),
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
                const Spacer(),
                Text(
                  fmt.format(q.totalAmount),
                  style:
                      AppTypography.h3.copyWith(color: AppColors.primaryMain),
                ),
              ],
            ),

            // Action buttons (only for actionable statuses)
            if (_canRespond) ...[
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
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _reject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.red600,
                              side: const BorderSide(color: AppColors.red600),
                              minimumSize: const Size.fromHeight(
                                AppSpacing.buttonHeightSm,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _accept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryMain,
                              foregroundColor: AppColors.textInverse,
                              minimumSize: const Size.fromHeight(
                                AppSpacing.buttonHeightSm,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Accept'),
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

class _RejectReasonSheet extends StatefulWidget {
  const _RejectReasonSheet();

  @override
  State<_RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends State<_RejectReasonSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.x2l,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.x2l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Decline Offer', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Optionally share a reason with the nursery.',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            maxLength: 200,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Price too high, out of budget…',
              hintStyle:
                  AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primaryMain, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.slate50,
              contentPadding: const EdgeInsets.all(AppSpacing.md),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red600,
                foregroundColor: AppColors.textInverse,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Decline Offer'),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — ORDERS
// ══════════════════════════════════════════════════════════════════════════════

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_buyerOrderProvider);
    final paged = state.paged;

    if (paged.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (paged.error != null && paged.items.isEmpty) {
      return _ErrorRetry(
        message: paged.error!.message,
        onRetry: () => ref.read(_buyerOrderProvider.notifier).load(),
      );
    }

    if (paged.items.isEmpty) {
      return const _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No orders yet',
        subtitle: 'Your orders from nurseries will appear here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryMain,
      onRefresh: () => ref.read(_buyerOrderProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.lg,
        ),
        itemCount: paged.items.length + (paged.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          if (i == paged.items.length) {
            ref.read(_buyerOrderProvider.notifier).loadMore();
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _OrderCard(order: paged.items[i]);
        },
      ),
    );
  }
}

class _OrderCard extends ConsumerStatefulWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _cancelling = false;

  bool get _canCancel => widget.order.status == 'PENDING';

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order', style: AppTypography.h3),
        content: Text(
          'Cancel ${widget.order.orderNumber}? This cannot be undone.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Keep Order',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancel Order',
              style: TextStyle(color: AppColors.red600),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final updated =
          await ref.read(orderRepositoryProvider).cancelOrder(widget.order.id);
      ref.read(_buyerOrderProvider.notifier).updateItem(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled'),
            backgroundColor: AppColors.slate700,
          ),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.red600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM yyyy');
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
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    o.orderNumber,
                    style: AppTypography.h4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(status: o.status, type: _ChipType.order),
              ],
            ),
            if (o.sellerNursery?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      o.sellerNursery!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (o.items.isNotEmpty) ...[
                  const Icon(
                    Icons.eco_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${o.items.length} ${o.items.length == 1 ? 'item' : 'items'}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ],
                if (date != null) ...[
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    dateFmt.format(date),
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
                const Spacer(),
                Text(
                  fmt.format(o.totalAmount),
                  style:
                      AppTypography.h3.copyWith(color: AppColors.primaryMain),
                ),
              ],
            ),
            if (_canCancel) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
              _cancelling
                  ? const Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _cancelOrder,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red600,
                          side: const BorderSide(color: AppColors.red600),
                          minimumSize:
                              const Size.fromHeight(AppSpacing.buttonHeightSm),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel Order'),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — DELIVERIES (Dispatches for buyer's orders)
// ══════════════════════════════════════════════════════════════════════════════

class _DeliveriesTab extends ConsumerWidget {
  const _DeliveriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_buyerDispatchProvider);
    final paged = state.paged;

    if (paged.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (paged.error != null && paged.items.isEmpty) {
      return _ErrorRetry(
        message: paged.error!.message,
        onRetry: () => ref.read(_buyerDispatchProvider.notifier).load(),
      );
    }

    if (paged.items.isEmpty) {
      return const _EmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'No deliveries yet',
        subtitle: 'Dispatches for your orders will appear here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryMain,
      onRefresh: () => ref.read(_buyerDispatchProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.lg,
        ),
        itemCount: paged.items.length + (paged.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          if (i == paged.items.length) {
            ref.read(_buyerDispatchProvider.notifier).loadMore();
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _DispatchCard(dispatch: paged.items[i]);
        },
      ),
    );
  }
}

class _DispatchCard extends StatelessWidget {
  final Dispatch dispatch;
  const _DispatchCard({required this.dispatch});

  @override
  Widget build(BuildContext context) {
    final d = dispatch;
    final dateFmt = DateFormat('d MMM yyyy');
    final date = DateTime.tryParse(d.dispatchDate ?? d.createdAt)?.toLocal();
    final isInTransit = d.status == 'DISPATCHED' || d.status == 'IN_TRANSIT';

    return GestureDetector(
      onTap: () => isInTransit
          ? context.push('/dispatches/${d.id}/track')
          : context.push('/dispatches/${d.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isInTransit ? AppColors.primaryMain : AppColors.border,
            width: isInTransit ? 1.5 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    d.dispatchNumber ?? d.dispatchCode,
                    style: AppTypography.h4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(status: d.status, type: _ChipType.dispatch),
              ],
            ),
            if (d.orderNumber?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Order ${d.orderNumber}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (d.vehicleNumber?.isNotEmpty == true) ...[
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    d.vehicleNumber!,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ],
                if (date != null) ...[
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    dateFmt.format(date),
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
                const Spacer(),
                if (isInTransit)
                  Row(
                    children: [
                      Text(
                        'Track',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppColors.primaryMain,
                      ),
                    ],
                  ),
              ],
            ),
            if (d.driverName?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    d.driverName!,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
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
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

enum _ChipType { quotation, order, dispatch }

class _StatusChip extends StatelessWidget {
  final String status;
  final _ChipType type;
  const _StatusChip({required this.status, required this.type});

  ({Color bg, Color text, String label}) _resolve() {
    switch (type) {
      case _ChipType.quotation:
        return switch (status) {
          'DRAFT' => (
              bg: AppColors.slate100,
              text: AppColors.slate600,
              label: 'Draft'
            ),
          'APPROVED' || 'SENT' || 'CUSTOMER_SENT' => (
              bg: AppColors.amber100,
              text: AppColors.amber700,
              label: 'Offer Sent'
            ),
          'CUSTOMER_ACCEPTED' => (
              bg: AppColors.primaryLight,
              text: AppColors.primaryMain,
              label: 'Accepted'
            ),
          'CUSTOMER_REJECTED' => (
              bg: AppColors.red100,
              text: AppColors.red600,
              label: 'Declined'
            ),
          'CONVERTED' => (
              bg: AppColors.primaryLight,
              text: AppColors.successText,
              label: 'Converted'
            ),
          'EXPIRED' => (
              bg: AppColors.slate100,
              text: AppColors.textMuted,
              label: 'Expired'
            ),
          _ => (
              bg: AppColors.slate100,
              text: AppColors.slate600,
              label: status
            ),
        };
      case _ChipType.order:
        return switch (status) {
          'PENDING' => (
              bg: AppColors.amber100,
              text: AppColors.amber700,
              label: 'Pending'
            ),
          'CONFIRMED' => (
              bg: AppColors.blue100,
              text: AppColors.blue600,
              label: 'Confirmed'
            ),
          'LOADING' => (
              bg: AppColors.orange100,
              text: AppColors.orange700,
              label: 'Loading'
            ),
          'LOADED' => (
              bg: AppColors.teal100,
              text: AppColors.teal700,
              label: 'Loaded'
            ),
          'PARTIALLY_FULFILLED' => (
              bg: AppColors.amber100,
              text: AppColors.amber700,
              label: 'Partial'
            ),
          'COMPLETED' => (
              bg: AppColors.primaryLight,
              text: AppColors.successText,
              label: 'Completed'
            ),
          'CANCELLED' => (
              bg: AppColors.red100,
              text: AppColors.red600,
              label: 'Cancelled'
            ),
          _ => (
              bg: AppColors.slate100,
              text: AppColors.slate600,
              label: status
            ),
        };
      case _ChipType.dispatch:
        return switch (status) {
          'PENDING' || 'PENDING_ACCEPTANCE' => (
              bg: AppColors.amber100,
              text: AppColors.amber700,
              label: 'Preparing'
            ),
          'ACCEPTED' => (
              bg: AppColors.blue100,
              text: AppColors.blue600,
              label: 'Accepted'
            ),
          'DISPATCHED' || 'IN_TRANSIT' => (
              bg: AppColors.teal100,
              text: AppColors.teal700,
              label: 'In Transit'
            ),
          'DELIVERED' => (
              bg: AppColors.primaryLight,
              text: AppColors.successText,
              label: 'Delivered'
            ),
          'CANCELLED' => (
              bg: AppColors.red100,
              text: AppColors.red600,
              label: 'Cancelled'
            ),
          _ => (
              bg: AppColors.slate100,
              text: AppColors.slate600,
              label: status
            ),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final (:bg, :text, :label) = _resolve();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.caption
            .copyWith(color: text, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(icon, size: 36, color: AppColors.primaryMain),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTypography.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Could not load',
              style: AppTypography.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

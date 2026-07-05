import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/trade_status_chip.dart';
import '../dispatches/dispatches.dart';
import '../orders/orders.dart';
import '../quotations/quotations.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════════════════

class _MgrOrderState {
  final PagedState<Order> paged;
  const _MgrOrderState({required this.paged});
  _MgrOrderState copyWith({PagedState<Order>? paged}) =>
      _MgrOrderState(paged: paged ?? this.paged);
}

class _MgrOrderNotifier extends StateNotifier<_MgrOrderState> {
  final OrderRepository _repo;
  int _page = 0;

  _MgrOrderNotifier(this._repo)
      : super(_MgrOrderState(paged: PagedState.initial()));

  Future<void> load() async {
    state = state.copyWith(
        paged: state.paged.copyWith(isLoading: true, clearError: true));
    try {
      final (items, pagination) = await _repo.listOrders(page: 1, perPage: 20);
      _page = 1;
      state = state.copyWith(
        paged: PagedState(
            items: items,
            isLoading: false,
            isLoadingMore: false,
            hasMore: pagination.hasMore),
      );
    } on AppError catch (e) {
      state = state.copyWith(
          paged: state.paged.copyWith(isLoading: false, error: e));
    }
  }

  Future<void> loadMore() async {
    if (state.paged.isLoadingMore || !state.paged.hasMore) return;
    state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: true));
    try {
      final (items, pagination) =
          await _repo.listOrders(page: _page + 1, perPage: 20);
      _page++;
      state = state.copyWith(
        paged: state.paged.copyWith(
          items: [...state.paged.items, ...items],
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError {
      state = state.copyWith(
          paged: state.paged.copyWith(isLoadingMore: false));
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

final _mgrOrderProvider =
    StateNotifierProvider.autoDispose<_MgrOrderNotifier, _MgrOrderState>(
  (ref) => _MgrOrderNotifier(ref.watch(orderRepositoryProvider)),
);

// ── Quotations ────────────────────────────────────────────────────────────────

class _MgrQuotationState {
  final PagedState<Quotation> paged;
  const _MgrQuotationState({required this.paged});
  _MgrQuotationState copyWith({PagedState<Quotation>? paged}) =>
      _MgrQuotationState(paged: paged ?? this.paged);
}

class _MgrQuotationNotifier extends StateNotifier<_MgrQuotationState> {
  final QuotationRepository _repo;
  int _page = 0;

  _MgrQuotationNotifier(this._repo)
      : super(_MgrQuotationState(paged: PagedState.initial()));

  Future<void> load() async {
    state = state.copyWith(
        paged: state.paged.copyWith(isLoading: true, clearError: true));
    try {
      final (items, pagination) =
          await _repo.listQuotations(page: 1, perPage: 20);
      _page = 1;
      state = state.copyWith(
        paged: PagedState(
            items: items,
            isLoading: false,
            isLoadingMore: false,
            hasMore: pagination.hasMore),
      );
    } on AppError catch (e) {
      state = state.copyWith(
          paged: state.paged.copyWith(isLoading: false, error: e));
    }
  }

  Future<void> loadMore() async {
    if (state.paged.isLoadingMore || !state.paged.hasMore) return;
    state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: true));
    try {
      final (items, pagination) =
          await _repo.listQuotations(page: _page + 1, perPage: 20);
      _page++;
      state = state.copyWith(
        paged: state.paged.copyWith(
          items: [...state.paged.items, ...items],
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError {
      state = state.copyWith(
          paged: state.paged.copyWith(isLoadingMore: false));
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

final _mgrQuotationProvider =
    StateNotifierProvider.autoDispose<_MgrQuotationNotifier, _MgrQuotationState>(
  (ref) => _MgrQuotationNotifier(ref.watch(quotationRepositoryProvider)),
);

// ── Dispatches ────────────────────────────────────────────────────────────────

class _MgrDispatchState {
  final PagedState<Dispatch> paged;
  const _MgrDispatchState({required this.paged});
  _MgrDispatchState copyWith({PagedState<Dispatch>? paged}) =>
      _MgrDispatchState(paged: paged ?? this.paged);
}

class _MgrDispatchNotifier extends StateNotifier<_MgrDispatchState> {
  final DispatchRepository _repo;
  int _page = 0;

  _MgrDispatchNotifier(this._repo)
      : super(_MgrDispatchState(paged: PagedState.initial()));

  Future<void> load() async {
    state = state.copyWith(
        paged: state.paged.copyWith(isLoading: true, clearError: true));
    try {
      final (items, pagination) =
          await _repo.listDispatches(page: 1, perPage: 20);
      _page = 1;
      state = state.copyWith(
        paged: PagedState(
            items: items,
            isLoading: false,
            isLoadingMore: false,
            hasMore: pagination.hasMore),
      );
    } on AppError catch (e) {
      state = state.copyWith(
          paged: state.paged.copyWith(isLoading: false, error: e));
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
      state = state.copyWith(
          paged: state.paged.copyWith(isLoadingMore: false));
    }
  }
}

final _mgrDispatchProvider =
    StateNotifierProvider.autoDispose<_MgrDispatchNotifier, _MgrDispatchState>(
  (ref) => _MgrDispatchNotifier(ref.watch(dispatchRepositoryProvider)),
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
    _tabs = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(_mgrOrderProvider.notifier).load();
      ref.read(_mgrQuotationProvider.notifier).load();
      ref.read(_mgrDispatchProvider.notifier).load();
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
    ref.watch(_mgrDispatchProvider);

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
            Tab(text: 'Dispatches'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _MgrOrdersTab(),
          _MgrQuotationsTab(),
          _MgrDispatchesTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — ORDERS
// ══════════════════════════════════════════════════════════════════════════════

class _MgrOrdersTab extends ConsumerWidget {
  const _MgrOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_mgrOrderProvider);
    final paged = state.paged;

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

class _MgrOrderCard extends ConsumerStatefulWidget {
  final Order order;
  const _MgrOrderCard({required this.order});

  @override
  ConsumerState<_MgrOrderCard> createState() => _MgrOrderCardState();
}

class _MgrOrderCardState extends ConsumerState<_MgrOrderCard> {
  bool _acting = false;

  bool get _canConfirm => widget.order.status == 'PENDING';
  bool get _canStartLoading => widget.order.status == 'CONFIRMED';
  bool get _canCancel =>
      {'PENDING', 'CONFIRMED'}.contains(widget.order.status);

  Future<void> _confirm() async {
    setState(() => _acting = true);
    try {
      final updated =
          await ref.read(orderRepositoryProvider).confirmOrder(widget.order.id);
      ref.read(_mgrOrderProvider.notifier).updateItem(updated);
      if (mounted) _snack('Order confirmed', AppColors.primaryMain);
    } on AppError catch (e) {
      if (mounted) _snack(e.message, AppColors.red600);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _startLoading() async {
    setState(() => _acting = true);
    try {
      final updated = await ref
          .read(orderRepositoryProvider)
          .startLoading(widget.order.id);
      ref.read(_mgrOrderProvider.notifier).updateItem(updated);
      if (mounted) {
        _snack('Loading started', AppColors.blue600);
        context.push('/orders/${widget.order.id}');
      }
    } on AppError catch (e) {
      if (mounted) _snack(e.message, AppColors.red600);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order', style: AppTypography.h3),
        content: Text(
            'Cancel ${widget.order.orderNumber}? This cannot be undone.',
            style: AppTypography.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Order',
                style: TextStyle(color: AppColors.red600)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _acting = true);
    try {
      final updated =
          await ref.read(orderRepositoryProvider).cancelOrder(widget.order.id);
      ref.read(_mgrOrderProvider.notifier).updateItem(updated);
      if (mounted) _snack('Order cancelled', AppColors.slate700);
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
    final o = widget.order;
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
            if (_canConfirm || _canStartLoading || _canCancel) ...[
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
                        if (_canCancel)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _cancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.red600,
                                side:
                                    const BorderSide(color: AppColors.red600),
                                minimumSize: const Size.fromHeight(
                                    AppSpacing.buttonHeightSm),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                        if (_canCancel && (_canConfirm || _canStartLoading))
                          const SizedBox(width: AppSpacing.sm),
                        if (_canConfirm)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _confirm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryMain,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(
                                    AppSpacing.buttonHeightSm),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Confirm'),
                            ),
                          ),
                        if (_canStartLoading)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _startLoading,
                              icon: const Icon(Icons.inventory_2_outlined,
                                  size: 16),
                              label: const Text('Start Loading'),
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
// TAB 2 — QUOTATIONS
// ══════════════════════════════════════════════════════════════════════════════

class _MgrQuotationsTab extends ConsumerWidget {
  const _MgrQuotationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_mgrQuotationProvider);
    final paged = state.paged;

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
                TradeStatusChip(
                    status: q.status, kind: TradeChipKind.quotation),
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

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — DISPATCHES
// ══════════════════════════════════════════════════════════════════════════════

class _MgrDispatchesTab extends ConsumerWidget {
  const _MgrDispatchesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_mgrDispatchProvider);
    final paged = state.paged;

    if (paged.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryMain));
    }
    if (paged.error != null && paged.items.isEmpty) {
      return ErrorState(
        error: paged.error,
        onRetry: () => ref.read(_mgrDispatchProvider.notifier).load(),
      );
    }
    if (paged.items.isEmpty) {
      return const EmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'No dispatches yet',
        subtitle: 'Create a dispatch from a loaded order to start delivery.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryMain,
      onRefresh: () => ref.read(_mgrDispatchProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding, vertical: AppSpacing.lg),
        itemCount: paged.items.length + (paged.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          if (i == paged.items.length) {
            ref.read(_mgrDispatchProvider.notifier).loadMore();
            return const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()));
          }
          return _MgrDispatchCard(dispatch: paged.items[i]);
        },
      ),
    );
  }
}

class _MgrDispatchCard extends StatelessWidget {
  final Dispatch dispatch;
  const _MgrDispatchCard({required this.dispatch});

  @override
  Widget build(BuildContext context) {
    final d = dispatch;
    final dateFmt = DateFormat('d MMM');
    final date = DateTime.tryParse(d.createdAt)?.toLocal();
    final chip = dispatchChipData(d.status);

    return GestureDetector(
      onTap: () => context.push('/dispatches/${d.id}'),
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
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: chip.bg, borderRadius: BorderRadius.circular(12)),
              child:
                  Icon(Icons.local_shipping_rounded, color: chip.text, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.dispatchNumber ?? d.dispatchCode,
                      style: AppTypography.h4),
                  const SizedBox(height: 2),
                  if (d.driverName?.isNotEmpty == true)
                    Text(d.driverName!,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  if (date != null)
                    Text(dateFmt.format(date),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: chip.bg, borderRadius: BorderRadius.circular(20)),
              child: Text(chip.label,
                  style: AppTypography.caption.copyWith(
                      color: chip.text, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

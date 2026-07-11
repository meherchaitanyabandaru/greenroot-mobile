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
import '../../core/widgets/green_root_app_bar.dart';
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

class _MgrQuotationNotifier extends StateNotifier<PagedState<Quotation>> {
  final QuotationRepository _repo;
  String _search = '';
  String? _status;
  int _page = 0;

  _MgrQuotationNotifier(this._repo) : super(PagedState.initial());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final (items, pagination) = await _repo.listQuotations(
        page: 1, perPage: 20, search: _search, status: _status,
      );
      _page = 1;
      state = PagedState(
        items: items,
        isLoading: false,
        isLoadingMore: false,
        hasMore: pagination.hasMore,
      );
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final (items, pagination) = await _repo.listQuotations(
        page: _page + 1, perPage: 20, search: _search, status: _status,
      );
      _page++;
      state = state.copyWith(
        items: [...state.items, ...items],
        isLoadingMore: false,
        hasMore: pagination.hasMore,
      );
    } on AppError {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setSearch(String q) {
    _search = q;
    load();
  }

  void setStatusFilter(String? status) {
    _status = status;
    load();
  }

  void removeItem(int id) {
    state = state.copyWith(items: state.items.where((q) => q.id != id).toList());
  }

  void updateItem(Quotation updated) {
    state = state.copyWith(
      items: state.items.map((q) => q.id == updated.id ? updated : q).toList(),
    );
  }
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
      appBar: GreenRootAppBar(
        title: 'My Work',
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
          _MgrQuotationsTab(),
          _MgrOrdersTab(),
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
      onTap: () async {
        await context.push('/orders/${o.id}');
        if (context.mounted) ref.read(_mgrOrderProvider.notifier).load();
      },
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

class _MgrQuotationsTab extends ConsumerStatefulWidget {
  const _MgrQuotationsTab();

  @override
  ConsumerState<_MgrQuotationsTab> createState() => _MgrQuotationsTabState();
}

class _MgrQuotationsTabState extends ConsumerState<_MgrQuotationsTab> {
  final _searchCtrl = TextEditingController();
  String? _activeStatus;

  static const _statusOptions = [
    (label: 'All', value: null),
    (label: 'Internal', value: 'INTERNAL_DRAFT'),
    (label: 'Draft', value: 'CUSTOMER_DRAFT'),
    (label: 'Sent', value: 'CUSTOMER_SENT'),
    (label: 'Accepted', value: 'CUSTOMER_ACCEPTED'),
    (label: 'Rejected', value: 'CUSTOMER_REJECTED'),
    (label: 'Converted', value: 'CONVERTED'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete(Quotation q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: Text('Delete ${q.quotationCode}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.red600)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref.read(quotationRepositoryProvider).deleteQuotation(q.id);
      ref.read(_mgrQuotationProvider.notifier).removeItem(q.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quotation deleted'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red600),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paged = ref.watch(_mgrQuotationProvider);

    if (paged.isLoading && paged.items.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryMain));
    }
    if (paged.error != null && paged.items.isEmpty) {
      return ErrorState(
        error: paged.error,
        onRetry: () => ref.read(_mgrQuotationProvider.notifier).load(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>('/quotations/create');
          if (created == true) ref.read(_mgrQuotationProvider.notifier).load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Quotation'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => ref.read(_mgrQuotationProvider.notifier).setSearch(v),
              decoration: InputDecoration(
                hintText: 'Search quotations…',
                hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(_mgrQuotationProvider.notifier).setSearch('');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primaryMain),
                ),
              ),
            ),
          ),
          // ── Status filter chips ─────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              itemCount: _statusOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final opt = _statusOptions[i];
                final isSelected = _activeStatus == opt.value;
                return GestureDetector(
                  onTap: () {
                    setState(() => _activeStatus = opt.value);
                    ref.read(_mgrQuotationProvider.notifier).setStatusFilter(opt.value);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryMain : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryMain : AppColors.border,
                      ),
                    ),
                    child: Text(
                      opt.label,
                      style: AppTypography.caption.copyWith(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: paged.items.isEmpty && !paged.isLoading
                ? const EmptyState(
                    icon: Icons.request_quote_outlined,
                    title: 'No quotations yet',
                    subtitle: 'Tap + to create your first quotation.',
                  )
                : RefreshIndicator(
                    color: AppColors.primaryMain,
                    onRefresh: () => ref.read(_mgrQuotationProvider.notifier).load(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPadding, AppSpacing.sm,
                          AppSpacing.screenPadding, 100),
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
                        final q = paged.items[i];
                        return Dismissible(
                          key: ValueKey(q.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.red600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_outline, color: Colors.white, size: 22),
                                SizedBox(height: 2),
                                Text('Delete',
                                    style: TextStyle(color: Colors.white, fontSize: 11)),
                              ],
                            ),
                          ),
                          confirmDismiss: (_) async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Quotation'),
                                content: Text(
                                    'Delete ${q.quotationCode}? This cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text('Delete',
                                        style: TextStyle(color: AppColors.red600)),
                                  ),
                                ],
                              ),
                            );
                            return confirm ?? false;
                          },
                          onDismissed: (_) => _delete(q),
                          child: _MgrQuotationCard(quotation: q),
                        );
                      },
                    ),
                  ),
          ),
        ],
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Convert to Order', style: AppTypography.h3),
        content: Text(
          'Create a new order from ${widget.quotation.quotationCode}?\nThe order will be created in PENDING status.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _acting = true);
    try {
      final q = await ref
          .read(quotationRepositoryProvider)
          .convertToOrder(widget.quotation.id);
      ref.read(_mgrQuotationProvider.notifier).load();
      if (mounted) {
        _snack('Order created successfully', AppColors.primaryMain);
        if (q.convertedOrderId != null) context.push('/orders/${q.convertedOrderId}');
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
      onTap: () async {
        final changed = await context.push<bool>('/quotations/${q.id}');
        if (changed == true && mounted) ref.read(_mgrQuotationProvider.notifier).load();
      },
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

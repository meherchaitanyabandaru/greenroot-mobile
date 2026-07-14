// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — BUYER TAB                                                      ║
// ║  Role:  BUYER only  |  Entry: BuyingScreen → BuyerTab                      ║
// ║  APIs:  GET /api/v1/quotations?buying=true                                  ║
// ║         GET /api/v1/orders?buying=true                                      ║
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
import '../../core/widgets/trade_status_chip.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dispatches/dispatches.dart';
import '../orders/orders.dart';
import '../profile/my_addresses_screen.dart';
import '../quotations/quotations.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════════════════

class _BuyerQuotationNotifier extends PagedNotifier<Quotation> {
  _BuyerQuotationNotifier(QuotationRepository repo)
      : super(
          fetch: (p, pp) => repo.listBuyingQuotations(page: p, perPage: pp),
          idOf: (q) => q.id,
        );
}

final _buyerQuotationProvider = StateNotifierProvider.autoDispose<
    _BuyerQuotationNotifier, PagedState<Quotation>>(
  (ref) => _BuyerQuotationNotifier(ref.watch(quotationRepositoryProvider)),
);

class _BuyerOrderNotifier extends PagedNotifier<Order> {
  _BuyerOrderNotifier(OrderRepository repo)
      : super(
          fetch: (p, pp) => repo.listBuyingOrders(page: p, perPage: pp),
          idOf: (o) => o.id,
        );
}

final _buyerOrderProvider =
    StateNotifierProvider.autoDispose<_BuyerOrderNotifier, PagedState<Order>>(
  (ref) => _BuyerOrderNotifier(ref.watch(orderRepositoryProvider)),
);

class _BuyerDispatchNotifier extends PagedNotifier<Dispatch> {
  _BuyerDispatchNotifier(DispatchRepository repo)
      : super(
          fetch: (p, pp) => repo.listDispatches(page: p, perPage: pp),
          idOf: (d) => d.id,
        );
}

final _buyerDispatchProvider = StateNotifierProvider.autoDispose<
    _BuyerDispatchNotifier, PagedState<Dispatch>>(
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
    ref.watch(_buyerQuotationProvider);
    ref.watch(_buyerOrderProvider);
    ref.watch(_buyerDispatchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GreenRootAppBar(
        title: 'My Purchases',
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
// TAB 1 — QUOTATIONS
// ══════════════════════════════════════════════════════════════════════════════

class _OffersTab extends ConsumerWidget {
  const _OffersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paged = ref.watch(_buyerQuotationProvider);

    if (paged.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (paged.error != null && paged.items.isEmpty) {
      return ErrorState(
        error: paged.error,
        onRetry: () => ref.read(_buyerQuotationProvider.notifier).load(),
      );
    }

    if (paged.items.isEmpty) {
      return const EmptyState(
        icon: Icons.request_quote_outlined,
        title: 'No quotations yet',
        subtitle: 'When a nursery sends you a quotation, it will appear here.',
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

  bool get _canRespond =>
      widget.quotation.status == 'CUSTOMER_SENT' && !widget.quotation.isExpired;

  Future<bool> _ensureDeliveryAddress() async {
    final userId = ref.read(sessionProvider).user?.id;
    if (userId == null) return false;
    final List<UserAddress> addresses;
    try {
      addresses =
          await ref.read(userAddressRepositoryProvider).listAddresses(userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not check delivery addresses: $e'),
            backgroundColor: AppColors.red600,
          ),
        );
      }
      return false;
    }
    if (addresses.isNotEmpty) return true;
    if (!mounted) return false;
    final add = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delivery address required'),
        content: const Text(
          'Add a delivery address before accepting this quotation. The nursery needs it before confirming your order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add Address'),
          ),
        ],
      ),
    );
    if (add == true && mounted) {
      await context.push('/my-addresses');
    }
    return false;
  }

  Future<void> _accept() async {
    final hasDeliveryAddress = await _ensureDeliveryAddress();
    if (!hasDeliveryAddress || !mounted) return;
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
      onTap: () async {
        final changed = await context.push<bool>('/quotations/${q.id}');
        if (changed == true && mounted) {
          ref.read(_buyerQuotationProvider.notifier).load();
        }
      },
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
                    q.quotationCode,
                    style: AppTypography.h4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (q.isExpired && q.status == 'CUSTOMER_SENT') ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  const SizedBox(width: 6),
                ],
                TradeStatusChip(
                    status: q.status, kind: TradeChipKind.quotation),
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
            if (q.validUntil != null && q.status == 'CUSTOMER_SENT') ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: q.isExpired ? AppColors.red600 : AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${q.isExpired ? "Expired" : "Valid until"}: ${DateFormat("d MMM yyyy").format(q.validUntil!)}',
                    style: AppTypography.caption.copyWith(
                      color:
                          q.isExpired ? AppColors.red600 : AppColors.textMuted,
                      fontWeight:
                          q.isExpired ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
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
    final paged = ref.watch(_buyerOrderProvider);

    if (paged.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (paged.error != null && paged.items.isEmpty) {
      return ErrorState(
        error: paged.error,
        onRetry: () => ref.read(_buyerOrderProvider.notifier).load(),
      );
    }

    if (paged.items.isEmpty) {
      return const EmptyState(
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
      onTap: () async {
        await context.push('/orders/${o.id}');
        if (mounted) ref.read(_buyerOrderProvider.notifier).load();
      },
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
                TradeStatusChip(status: o.status, kind: TradeChipKind.order),
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
// TAB 3 — DELIVERIES  (dispatches scoped to buyer's orders)
// ══════════════════════════════════════════════════════════════════════════════

class _DeliveriesTab extends ConsumerWidget {
  const _DeliveriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paged = ref.watch(_buyerDispatchProvider);

    if (paged.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (paged.error != null && paged.items.isEmpty) {
      return ErrorState(
        error: paged.error,
        onRetry: () => ref.read(_buyerDispatchProvider.notifier).load(),
      );
    }

    if (paged.items.isEmpty) {
      return const EmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'No active deliveries',
        subtitle:
            'Once a nursery dispatches your order, it will appear here — tap to track the driver live.',
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
      onTap: () => context.push('/dispatches/${d.id}/track'),
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
                TradeStatusChip(status: d.status, kind: TradeChipKind.dispatch),
              ],
            ),
            if (d.orderNumber?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      size: 14, color: AppColors.textSecondary),
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
                  const Icon(Icons.local_shipping_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    d.vehicleNumber!,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ],
                if (date != null) ...[
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.textMuted),
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
                        'Track Live',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right,
                          size: 16, color: AppColors.primaryMain),
                    ],
                  ),
              ],
            ),
            if (d.driverName?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 14, color: AppColors.textMuted),
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

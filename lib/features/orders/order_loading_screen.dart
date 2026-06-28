import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'orders.dart';

class OrderLoadingScreen extends ConsumerStatefulWidget {
  final int? nurseryId;

  const OrderLoadingScreen({super.key, this.nurseryId});

  @override
  ConsumerState<OrderLoadingScreen> createState() => _OrderLoadingScreenState();
}

class _OrderLoadingScreenState extends ConsumerState<OrderLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _states = <String, _LoadingTabState>{
    'CONFIRMED': _LoadingTabState(),
    'LOADING': _LoadingTabState(),
    'COMPLETED': _LoadingTabState(),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait(_tabs.map((tab) => _load(tab.status)));
  }

  Future<void> _load(String status) async {
    final tabState = _states[status]!;
    setState(() {
      tabState.isLoading = true;
      tabState.error = null;
    });
    try {
      final repo = ref.read(orderRepositoryProvider);
      final (orders, _) = await repo.listOrders(
        page: 1,
        perPage: 50,
        status: status,
        nurseryId: widget.nurseryId,
      );
      if (!mounted) return;
      setState(() {
        tabState.orders = orders;
        tabState.isLoading = false;
      });
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        tabState.error = e.message;
        tabState.isLoading = false;
      });
    }
  }

  Future<void> _runAction(
    Order order,
    Future<Order> Function(OrderRepository repo) action,
    String successMessage,
  ) async {
    try {
      await action(ref.read(orderRepositoryProvider));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppColors.primaryMain,
        ),
      );
      await _loadAll();
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.errorText,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(sessionProvider).capabilities;
    final canManage = caps.isNurseryOwner || caps.isManager;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Loading Workflow'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryMain,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryMain,
          tabs: [
            for (final tab in _tabs)
              Tab(
                text: '${tab.label} (${_states[tab.status]!.orders.length})',
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: AppColors.primaryMain,
        child: TabBarView(
          controller: _tabController,
          children: [
            _LoadingOrderList(
              state: _states['CONFIRMED']!,
              emptyTitle: _tabs[0].emptyTitle,
              emptySubtitle: _tabs[0].emptySubtitle,
              canManage: canManage,
              showItemAdjust: false,
              onRefresh: () => _load('CONFIRMED'),
              onOpen: (order) => context.push('/orders/${order.id}'),
              onStartLoading: (order) => _runAction(
                order,
                (repo) => repo.startLoading(order.id),
                'Loading started',
              ),
              onCompleteLoading: null,
            ),
            _LoadingOrderList(
              state: _states['LOADING']!,
              emptyTitle: _tabs[1].emptyTitle,
              emptySubtitle: _tabs[1].emptySubtitle,
              canManage: canManage,
              showItemAdjust: true,
              onRefresh: () => _load('LOADING'),
              onOpen: (order) => context.push('/orders/${order.id}'),
              onStartLoading: null,
              onCompleteLoading: (order) => _runAction(
                order,
                (repo) => repo.completeLoading(order.id),
                'Loading completed',
              ),
            ),
            _LoadingOrderList(
              state: _states['COMPLETED']!,
              emptyTitle: _tabs[2].emptyTitle,
              emptySubtitle: _tabs[2].emptySubtitle,
              canManage: canManage,
              showItemAdjust: false,
              onRefresh: () => _load('COMPLETED'),
              onOpen: (order) => context.push('/orders/${order.id}'),
              onStartLoading: null,
              onCompleteLoading: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingOrderList extends StatelessWidget {
  final _LoadingTabState state;
  final String emptyTitle;
  final String emptySubtitle;
  final bool canManage;
  final bool showItemAdjust;
  final Future<void> Function() onRefresh;
  final ValueChanged<Order> onOpen;
  final ValueChanged<Order>? onStartLoading;
  final ValueChanged<Order>? onCompleteLoading;

  const _LoadingOrderList({
    required this.state,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.canManage,
    required this.showItemAdjust,
    required this.onRefresh,
    required this.onOpen,
    required this.onStartLoading,
    required this.onCompleteLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryMain),
      );
    }

    if (state.error != null && state.orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            state.error!,
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: FilledButton(
              onPressed: onRefresh,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (state.orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: 120),
          const Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            emptyTitle,
            textAlign: TextAlign.center,
            style: AppTypography.h4,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            emptySubtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemBuilder: (context, index) {
        final order = state.orders[index];
        return _LoadingOrderCard(
          order: order,
          canManage: canManage,
          showItemAdjust: showItemAdjust,
          onOpen: () => onOpen(order),
          onStartLoading:
              onStartLoading != null ? () => onStartLoading!(order) : null,
          onCompleteLoading:
              onCompleteLoading != null ? () => onCompleteLoading!(order) : null,
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemCount: state.orders.length,
    );
  }
}

class _LoadingOrderCard extends ConsumerWidget {
  final Order order;
  final bool canManage;
  final bool showItemAdjust;
  final VoidCallback onOpen;
  final VoidCallback? onStartLoading;
  final VoidCallback? onCompleteLoading;

  const _LoadingOrderCard({
    required this.order,
    required this.canManage,
    required this.showItemAdjust,
    required this.onOpen,
    required this.onStartLoading,
    required this.onCompleteLoading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final date = DateTime.tryParse(order.orderDate);
    final dateStr =
        date != null ? DateFormat('dd MMM yyyy').format(date.toLocal()) : '';

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onOpen,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(order.orderNumber, style: AppTypography.h4),
                  ),
                  StatusBadge(
                    label: order.status,
                    variant: badgeVariantFromStatus(order.status),
                    dot: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (order.sellerNursery != null)
                Text(
                  order.sellerNursery!,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  _MetaItem(
                    icon: Icons.currency_rupee_rounded,
                    label: fmt.format(order.totalAmount),
                  ),
                  if (dateStr.isNotEmpty)
                    _MetaItem(icon: Icons.event_outlined, label: dateStr),
                  if (order.assignedManagerName?.isNotEmpty == true)
                    _MetaItem(
                      icon: Icons.manage_accounts_outlined,
                      label: order.assignedManagerName!,
                    ),
                ],
              ),

              // Item adjustment section (LOADING tab only)
              if (showItemAdjust && order.items.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppRadius.inputRadius,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Adjust Loaded Quantities',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Column headers
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Plant',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 64,
                            child: Text(
                              'Ordered',
                              textAlign: TextAlign.center,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              'Loaded',
                              textAlign: TextAlign.center,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primaryMain,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: AppSpacing.sm),
                      for (final item in order.items)
                        _LoadingItemRow(
                          key: ValueKey('${order.id}-${item.id}'),
                          order: order,
                          item: item,
                        ),
                    ],
                  ),
                ),
              ],

              // Action button
              if (canManage) ...[
                const SizedBox(height: AppSpacing.md),
                if (onStartLoading != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onStartLoading,
                      icon: const Icon(Icons.inventory_outlined),
                      label: const Text('Start Loading'),
                    ),
                  ),
                if (onCompleteLoading != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onCompleteLoading,
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text('Complete Loading'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.successText,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A single item row in the loading adjustment panel.
/// Manages its own TextEditingController and debounced API call.
class _LoadingItemRow extends ConsumerStatefulWidget {
  final Order order;
  final OrderItem item;

  const _LoadingItemRow({super.key, required this.order, required this.item});

  @override
  ConsumerState<_LoadingItemRow> createState() => _LoadingItemRowState();
}

class _LoadingItemRowState extends ConsumerState<_LoadingItemRow> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.item.loadedQuantity ?? widget.item.quantity;
    _ctrl = TextEditingController(text: _fmt(initial));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  Future<void> _save() async {
    final qty = double.tryParse(_ctrl.text.trim());
    if (qty == null || qty < 0) {
      setState(() => _hasError = true);
      return;
    }
    setState(() {
      _saving = true;
      _hasError = false;
    });
    try {
      await ref.read(orderRepositoryProvider).setLoadedQuantity(
            widget.order.id,
            widget.item.id,
            qty,
          );
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.errorText,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Plant name
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.displayName,
                  style: AppTypography.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.item.sizeName != null)
                  Text(
                    widget.item.sizeName!,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          // Ordered qty
          SizedBox(
            width: 64,
            child: Text(
              _fmt(widget.item.quantity),
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          // Loaded qty input
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: _hasError
                          ? AppColors.errorText
                          : AppColors.primaryMain,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: _hasError
                              ? AppColors.errorText
                              : AppColors.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: _hasError
                              ? AppColors.errorText
                              : AppColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                            color: AppColors.primaryMain, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _save(),
                    onTapOutside: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 4),
                if (_saving)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.primaryMain,
                    ),
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _LoadingTabState {
  bool isLoading = false;
  String? error;
  List<Order> orders = const [];
}

class _LoadingTab {
  final String label;
  final String status;
  final String emptyTitle;
  final String emptySubtitle;

  const _LoadingTab({
    required this.label,
    required this.status,
    required this.emptyTitle,
    required this.emptySubtitle,
  });
}

const _tabs = [
  _LoadingTab(
    label: 'Not Started',
    status: 'CONFIRMED',
    emptyTitle: 'No orders waiting',
    emptySubtitle: 'Confirmed orders ready for loading appear here.',
  ),
  _LoadingTab(
    label: 'In Loading',
    status: 'LOADING',
    emptyTitle: 'Nothing loading now',
    emptySubtitle: 'Orders move here after loading starts.',
  ),
  _LoadingTab(
    label: 'Completed',
    status: 'COMPLETED',
    emptyTitle: 'No completed loading',
    emptySubtitle: 'Orders appear here after loading is completed.',
  ),
];

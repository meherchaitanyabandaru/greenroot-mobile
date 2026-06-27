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
            for (final tab in _tabs)
              _LoadingOrderList(
                state: _states[tab.status]!,
                emptyTitle: tab.emptyTitle,
                emptySubtitle: tab.emptySubtitle,
                canManage: canManage,
                onRefresh: () => _load(tab.status),
                onOpen: (order) => context.push('/orders/${order.id}'),
                onStartLoading: (order) => _runAction(
                  order,
                  (repo) => repo.startLoading(order.id),
                  'Loading started',
                ),
                onCompleteLoading: (order) => _runAction(
                  order,
                  (repo) => repo.completeLoading(order.id),
                  'Loading completed',
                ),
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
  final Future<void> Function() onRefresh;
  final ValueChanged<Order> onOpen;
  final ValueChanged<Order> onStartLoading;
  final ValueChanged<Order> onCompleteLoading;

  const _LoadingOrderList({
    required this.state,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.canManage,
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
          onOpen: () => onOpen(order),
          onStartLoading: () => onStartLoading(order),
          onCompleteLoading: () => onCompleteLoading(order),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemCount: state.orders.length,
    );
  }
}

class _LoadingOrderCard extends StatelessWidget {
  final Order order;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onStartLoading;
  final VoidCallback onCompleteLoading;

  const _LoadingOrderCard({
    required this.order,
    required this.canManage,
    required this.onOpen,
    required this.onStartLoading,
    required this.onCompleteLoading,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final date = DateTime.tryParse(order.orderDate);
    final dateStr =
        date != null ? DateFormat('dd MMM yyyy').format(date.toLocal()) : '';
    final action = switch (order.status) {
      'CONFIRMED' => (
          label: 'Start Loading',
          icon: Icons.inventory_outlined,
          onTap: onStartLoading,
        ),
      'LOADING' => (
          label: 'Complete Loading',
          icon: Icons.done_all_rounded,
          onTap: onCompleteLoading,
        ),
      _ => null,
    };

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
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
                    _MetaItem(
                      icon: Icons.event_outlined,
                      label: dateStr,
                    ),
                  if (order.assignedManagerName?.isNotEmpty == true)
                    _MetaItem(
                      icon: Icons.manage_accounts_outlined,
                      label: order.assignedManagerName!,
                    ),
                ],
              ),
              if (canManage && action != null) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: action.onTap,
                    icon: Icon(action.icon),
                    label: Text(action.label),
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

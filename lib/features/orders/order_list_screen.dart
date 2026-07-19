import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/domain/lifecycle_presenter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/domain/rbac/roles.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'orders.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  final int? nurseryId;
  final String? statusFilter;
  const OrderListScreen({super.key, this.nurseryId, this.statusFilter});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref
        .read(orderListProvider.notifier)
        .load(nurseryId: widget.nurseryId, statusFilter: widget.statusFilter));
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        ref.read(orderListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(orderListProvider);
    final paged = listState.paged;
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    final session = ref.watch(sessionProvider);
    final caps = session.capabilities;
    final canCreate = caps.canSell || session.roles.contains(AppRole.buyer);
    final createLabel = caps.canSell ? 'New Order' : 'Place Order';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await context.push<bool>('/orders/create');
                if (created == true && mounted) {
                  ref.read(orderListProvider.notifier).load(
                      nurseryId: widget.nurseryId,
                      statusFilter: widget.statusFilter);
                }
              },
              backgroundColor: AppColors.primaryMain,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                createLabel,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter'),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(orderListProvider.notifier)
            .load(nurseryId: widget.nurseryId),
        color: AppColors.primaryMain,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (label, value) in [
                        ('All', null),
                        ('Pending', 'PENDING'),
                        ('Confirmed', 'CONFIRMED'),
                        ('Loading', 'LOADING'),
                        ('Loaded', 'LOADED'),
                        ('Partial', 'PARTIALLY_FULFILLED'),
                        ('Completed', 'COMPLETED'),
                        ('Cancelled', 'CANCELLED'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: _FilterChip(
                            label: label,
                            selected: listState.statusFilter == value,
                            onTap: () => ref
                                .read(orderListProvider.notifier)
                                .load(statusFilter: value),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (paged.isLoading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryMain)),
              )
            else if (paged.error != null && paged.items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: AppSpacing.md),
                      Text(paged.error!.message, style: AppTypography.body),
                      TextButton(
                        onPressed: () =>
                            ref.read(orderListProvider.notifier).load(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (paged.items.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 48, color: AppColors.textMuted),
                      SizedBox(height: AppSpacing.md),
                      Text('No orders found', style: AppTypography.h4),
                    ],
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final order = paged.items[i];
                      final display = LifecyclePresenter.forOrderStatus(
                        order.status,
                        role: caps.canSell
                            ? LifecycleRole.operator
                            : LifecycleRole.buyer,
                      );
                      final date = DateTime.tryParse(order.orderDate);
                      final dateStr = date != null
                          ? DateFormat('dd MMM yyyy').format(date.toLocal())
                          : '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Material(
                          color: AppColors.surface,
                          borderRadius: AppRadius.cardRadius,
                          child: InkWell(
                            onTap: () async {
                              await context.push('/orders/${order.id}');
                              if (mounted)
                                ref.read(orderListProvider.notifier).load(
                                    nurseryId: widget.nurseryId,
                                    statusFilter: widget.statusFilter);
                            },
                            borderRadius: AppRadius.cardRadius,
                            child: Container(
                              padding:
                                  const EdgeInsets.all(AppSpacing.cardPadding),
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
                                        child: Text(order.orderNumber,
                                            style: AppTypography.h4),
                                      ),
                                      StatusBadge(
                                        label: display.label,
                                        variant: display.variant,
                                        dot: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  if (order.sellerNursery != null)
                                    Text(order.sellerNursery!,
                                        style: AppTypography.bodySmall.copyWith(
                                            color: AppColors.textSecondary)),
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    children: [
                                      Text(
                                        fmt.format(order.totalAmount),
                                        style: AppTypography.h4.copyWith(
                                            color: AppColors.primaryMain),
                                      ),
                                      const Spacer(),
                                      if (dateStr.isNotEmpty)
                                        Text(dateStr,
                                            style: AppTypography.caption
                                                .copyWith(
                                                    color:
                                                        AppColors.textMuted)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: paged.items.length,
                  ),
                ),
              ),
              if (paged.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.x2l),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryMain)),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x3l)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryMain : AppColors.surface,
          border: Border.all(
              color: selected ? AppColors.primaryMain : AppColors.border),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

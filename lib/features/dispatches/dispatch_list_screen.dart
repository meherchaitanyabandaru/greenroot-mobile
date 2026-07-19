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
import 'dispatches.dart';

class DispatchListScreen extends ConsumerStatefulWidget {
  final int? nurseryId;
  const DispatchListScreen({super.key, this.nurseryId});

  @override
  ConsumerState<DispatchListScreen> createState() => _DispatchListScreenState();
}

class _DispatchListScreenState extends ConsumerState<DispatchListScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref
        .read(dispatchListProvider.notifier)
        .load(nurseryId: widget.nurseryId));
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        ref.read(dispatchListProvider.notifier).loadMore();
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
    final listState = ref.watch(dispatchListProvider);
    final paged = listState.paged;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(dispatchListProvider.notifier)
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
                        ('Dispatched', 'DISPATCHED'),
                        ('In Transit', 'IN_TRANSIT'),
                        ('Delivered', 'DELIVERED'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: _Chip(
                            label: label,
                            selected: listState.statusFilter == value,
                            onTap: () => ref
                                .read(dispatchListProvider.notifier)
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
                            ref.read(dispatchListProvider.notifier).load(),
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
                      Icon(Icons.local_shipping_outlined,
                          size: 48, color: AppColors.textMuted),
                      SizedBox(height: AppSpacing.md),
                      Text('No dispatches found', style: AppTypography.h4),
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
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _DispatchCard(
                        dispatch: paged.items[i],
                        onTap: () =>
                            context.push('/dispatches/${paged.items[i].id}'),
                      ),
                    ),
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

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip(
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

class _DispatchCard extends StatelessWidget {
  final Dispatch dispatch;
  final VoidCallback onTap;

  const _DispatchCard({required this.dispatch, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final display = LifecyclePresenter.forDispatchStatus(dispatch.status);
    final date = dispatch.dispatchDate != null
        ? DateTime.tryParse(dispatch.dispatchDate!)
        : null;
    final dateStr =
        date != null ? DateFormat('dd MMM yyyy').format(date.toLocal()) : '';

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.amber100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_shipping_rounded,
                        color: AppColors.amber600, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dispatch.dispatchCode,
                          style: AppTypography.h4,
                        ),
                        if (dispatch.orderNumber != null)
                          Text(
                            'Order: ${dispatch.orderNumber}',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: display.label,
                    variant: display.variant,
                    dot: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (dispatch.driverName != null) ...[
                    const Icon(Icons.person_outline_rounded,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      dispatch.driverName!,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  if (dispatch.vehicleNumber != null) ...[
                    const Icon(Icons.directions_car_outlined,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      dispatch.vehicleNumber!,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                  const Spacer(),
                  if (dateStr.isNotEmpty)
                    Text(dateStr,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

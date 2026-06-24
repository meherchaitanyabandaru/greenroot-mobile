import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_search_field.dart';
import '../../core/widgets/status_badge.dart';
import 'inventory.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  final bool canEdit;
  const InventoryListScreen({super.key, this.canEdit = false});

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryListProvider.notifier).load();
    });
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        ref.read(inventoryListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(inventoryListProvider);
    final paged = listState.paged;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: widget.canEdit
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/inventory/add'),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(inventoryListProvider.notifier)
            .load(search: _searchCtrl.text),
        color: AppColors.primaryMain,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  children: [
                    AppSearchField(
                      hint: 'Search inventory...',
                      controller: _searchCtrl,
                      onChanged: (val) {
                        Future.delayed(const Duration(milliseconds: 400), () {
                          if (_searchCtrl.text == val) {
                            ref
                                .read(inventoryListProvider.notifier)
                                .load(search: val);
                          }
                        });
                      },
                      onClear: () => ref
                          .read(inventoryListProvider.notifier)
                          .load(search: ''),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (label, value) in [
                            ('All', null),
                            ('Available', 'available'),
                            ('Low Stock', 'low_stock'),
                            ('Out of Stock', 'out_of_stock'),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: _FilterChip(
                                label: label,
                                selected: listState.statusFilter == value,
                                onTap: () => ref
                                    .read(inventoryListProvider.notifier)
                                    .load(statusFilter: value),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
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
                            ref.read(inventoryListProvider.notifier).load(),
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
                      Icon(Icons.inventory_2_outlined,
                          size: 48, color: AppColors.textMuted),
                      SizedBox(height: AppSpacing.md),
                      Text('No inventory items', style: AppTypography.h4),
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
                      child: _InventoryCard(
                        item: paged.items[i],
                        canEdit: widget.canEdit,
                        onTap: () =>
                            context.push('/inventory/${paged.items[i].id}'),
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
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x5l)),
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

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final bool canEdit;
  final VoidCallback onTap;

  const _InventoryCard(
      {required this.item, required this.canEdit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusVariant = _statusVariant(item.status);

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
          child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.local_florist_outlined,
                  color: AppColors.primaryMain, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: AppTypography.h4,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.nurseryName,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      StatusBadge(
                        label: _capitalize(item.status.replaceAll('_', ' ')),
                        variant: statusVariant,
                        dot: true,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${item.availableQuantity} ${item.sizeName}',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
          ),
        ),
      ),
    );
  }

  BadgeVariant _statusVariant(String status) => switch (status.toLowerCase()) {
        'available' => BadgeVariant.success,
        'low_stock' => BadgeVariant.warning,
        'out_of_stock' => BadgeVariant.error,
        _ => BadgeVariant.neutral,
      };

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

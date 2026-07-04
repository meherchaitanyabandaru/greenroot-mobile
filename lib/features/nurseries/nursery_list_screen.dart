import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_search_field.dart';
import '../../core/widgets/status_badge.dart';
import 'nurseries.dart';

class NurseryListScreen extends ConsumerStatefulWidget {
  const NurseryListScreen({super.key});

  @override
  ConsumerState<NurseryListScreen> createState() => _NurseryListScreenState();
}

class _NurseryListScreenState extends ConsumerState<NurseryListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(nurseryListProvider.notifier).load();
    });
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        ref.read(nurseryListProvider.notifier).loadMore();
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
    final paged = ref.watch(nurseryListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('Nurseries', style: AppTypography.h3),
        foregroundColor: AppColors.textPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(nurseryListProvider.notifier)
            .load(search: _searchCtrl.text),
        color: AppColors.primaryMain,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: AppSearchField(
                  hint: 'Search nurseries...',
                  controller: _searchCtrl,
                  onChanged: (val) {
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (_searchCtrl.text == val) {
                        ref.read(nurseryListProvider.notifier).load(search: val);
                      }
                    });
                  },
                  onClear: () =>
                      ref.read(nurseryListProvider.notifier).load(search: ''),
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
                      Text(paged.error!.message,
                          style: AppTypography.body, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: () =>
                            ref.read(nurseryListProvider.notifier).load(),
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
                      Icon(Icons.store_outlined,
                          size: 48, color: AppColors.textMuted),
                      SizedBox(height: AppSpacing.md),
                      Text('No nurseries found', style: AppTypography.h4),
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
                      child: _NurseryCard(
                        nursery: paged.items[i],
                        onTap: () =>
                            context.push('/nurseries/${paged.items[i].id}'),
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

class _NurseryCard extends StatelessWidget {
  final Nursery nursery;
  final VoidCallback onTap;

  const _NurseryCard({required this.nursery, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final addr = nursery.primaryAddress;
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
              child: const Icon(Icons.store_rounded,
                  color: AppColors.primaryMain, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nursery.name,
                      style: AppTypography.h4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (nursery.cityState.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(nursery.cityState,
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      StatusBadge(
                        label: _capitalize(nursery.status),
                        variant: badgeVariantFromStatus(nursery.status),
                        dot: true,
                      ),
                      if (addr?.city != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${nursery.users.length} staff',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
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

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

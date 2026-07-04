import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_search_field.dart';
import '../../core/widgets/status_badge.dart';
import 'plants.dart';

class PlantListScreen extends ConsumerStatefulWidget {
  const PlantListScreen({super.key});

  @override
  ConsumerState<PlantListScreen> createState() => _PlantListScreenState();
}

class _PlantListScreenState extends ConsumerState<PlantListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(plantListProvider.notifier).load();
    });
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(plantListProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(plantListProvider);
    final paged = listState.paged;
    final categories = ref.watch(plantCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('Plant Catalog', style: AppTypography.h3),
        foregroundColor: AppColors.textPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(plantListProvider.notifier).load(
              search: _searchCtrl.text,
            ),
        color: AppColors.primaryMain,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // Search + Filter header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSearchField(
                      hint: 'Search plants...',
                      controller: _searchCtrl,
                      onChanged: (val) {
                        Future.delayed(const Duration(milliseconds: 400), () {
                          if (_searchCtrl.text == val) {
                            ref.read(plantListProvider.notifier).load(search: val);
                          }
                        });
                      },
                      onClear: () => ref.read(plantListProvider.notifier).load(search: ''),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Plant type filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TypeChip(
                            label: 'All',
                            selected: listState.plantType == null,
                            onTap: () => ref.read(plantListProvider.notifier).load(plantType: ''),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          for (final type in ['flowering', 'fruit', 'vegetable', 'herb', 'ornamental', 'tree'])
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: _TypeChip(
                                label: _capitalize(type),
                                selected: listState.plantType == type,
                                onTap: () => ref
                                    .read(plantListProvider.notifier)
                                    .load(plantType: type),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Category filter
                    categories.when(
                      data: (cats) => cats.isEmpty
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.sm),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: cats
                                      .where((c) => c.isActive)
                                      .map((c) => Padding(
                                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                                            child: _CategoryChip(
                                              label: c.name,
                                              selected: listState.categoryId == c.id,
                                              onTap: () => ref.read(plantListProvider.notifier).load(
                                                    categoryId: listState.categoryId == c.id ? null : c.id,
                                                  ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            // List content
            if (paged.isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primaryMain),
                ),
              )
            else if (paged.error != null && paged.items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.x3l),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: AppSpacing.md),
                        Text(paged.error!.message, style: AppTypography.body, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.lg),
                        TextButton(
                          onPressed: () => ref.read(plantListProvider.notifier).load(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (paged.items.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_florist_outlined, size: 48, color: AppColors.textMuted),
                      SizedBox(height: AppSpacing.md),
                      Text('No plants found', style: AppTypography.h4),
                      SizedBox(height: AppSpacing.sm),
                      Text('Try adjusting your search or filters.',
                          style: AppTypography.bodySmall),
                    ],
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final plant = paged.items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _PlantCard(
                          plant: plant,
                          onTap: () => context.push('/plants/${plant.id}'),
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
                        child: CircularProgressIndicator(color: AppColors.primaryMain)),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x3l)),
            ],
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryMain : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primaryMain : AppColors.border,
          ),
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentMain.withValues(alpha: 0.15) : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.accentMain : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.forest800 : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  final Plant plant;
  final VoidCallback onTap;

  const _PlantCard({required this.plant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.xl)),
              child: SizedBox(
                width: 88,
                height: 88,
                child: plant.primaryImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: plant.primaryImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.forest100),
                        errorWidget: (_, __, ___) => _PlantPlaceholder(),
                      )
                    : _PlantPlaceholder(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.scientificName,
                      style: AppTypography.h4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (plant.commonName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        plant.commonName!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        if (plant.plantType != null)
                          StatusBadge(
                            label: _capitalize(plant.plantType!),
                            variant: BadgeVariant.accent,
                          ),
                        if (plant.categories.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.sm),
                          StatusBadge(
                            label: plant.categories.first.name,
                            variant: BadgeVariant.neutral,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ),
          ],
        ),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _PlantPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.forest100,
      child: const Center(
        child: Icon(Icons.local_florist_outlined, color: AppColors.primaryMain, size: 32),
      ),
    );
  }
}

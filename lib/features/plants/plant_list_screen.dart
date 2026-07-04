import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_search_field.dart';
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
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
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
    final idle = listState.search.isEmpty && !paged.isLoading;

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
        onRefresh: () async {
          if (_searchCtrl.text.isNotEmpty) {
            await ref
                .read(plantListProvider.notifier)
                .load(search: _searchCtrl.text);
          }
        },
        color: AppColors.primaryMain,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // Search bar only
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.screenPadding,
                  AppSpacing.screenPadding,
                  AppSpacing.sm,
                ),
                child: AppSearchField(
                  hint: 'Search plants...',
                  controller: _searchCtrl,
                  onChanged: (val) {
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (_searchCtrl.text == val) {
                        ref.read(plantListProvider.notifier).load(search: val);
                      }
                    });
                  },
                  onClear: () =>
                      ref.read(plantListProvider.notifier).reset(),
                ),
              ),
            ),

            // Idle state — prompt user to search
            if (idle)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_rounded,
                          size: 52, color: AppColors.textMuted),
                      SizedBox(height: AppSpacing.md),
                      Text('Search for plants',
                          style: AppTypography.h4),
                      SizedBox(height: AppSpacing.xs),
                      Text('Type a name or plant code above.',
                          style: AppTypography.bodySmall),
                    ],
                  ),
                ),
              )

            // Body
            else if (paged.isLoading)
              const SliverFillRemaining(
                child: Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primaryMain),
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
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: AppSpacing.md),
                        Text(paged.error!.message,
                            style: AppTypography.body,
                            textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.lg),
                        TextButton(
                          onPressed: () =>
                              ref.read(plantListProvider.notifier).load(),
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
                      Icon(Icons.local_florist_outlined,
                          size: 48, color: AppColors.textMuted),
                      SizedBox(height: AppSpacing.md),
                      Text('No plants found', style: AppTypography.h4),
                      SizedBox(height: AppSpacing.sm),
                      Text('Try a different search term.',
                          style: AppTypography.bodySmall),
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
                      final plant = paged.items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _PlantRow(
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
                      child: CircularProgressIndicator(
                          color: AppColors.primaryMain),
                    ),
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

// ── Plant row ─────────────────────────────────────────────────────────────────

class _PlantRow extends StatelessWidget {
  final Plant plant;
  final VoidCallback onTap;

  const _PlantRow({required this.plant, required this.onTap});

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
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppRadius.xl)),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: plant.primaryImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: plant.primaryImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.forest100),
                          errorWidget: (_, __, ___) => _Placeholder(),
                        )
                      : _Placeholder(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Name + code
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.scientificName,
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (plant.commonName != null &&
                          plant.commonName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          plant.commonName!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        plant.plantCode,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: AppSpacing.md),
                child: Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.forest100,
      child: const Center(
        child: Icon(Icons.local_florist_outlined,
            color: AppColors.primaryMain, size: 28),
      ),
    );
  }
}

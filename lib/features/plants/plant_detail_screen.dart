import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_badge.dart';
import 'plants.dart';

class PlantDetailScreen extends ConsumerWidget {
  final int plantId;
  const PlantDetailScreen({super.key, required this.plantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlant = ref.watch(plantDetailProvider(plantId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: asyncPlant.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryMain)),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              Text(err.toString(), style: AppTypography.body, textAlign: TextAlign.center),
              TextButton(
                onPressed: () => ref.refresh(plantDetailProvider(plantId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (plant) => _PlantDetailView(plant: plant),
      ),
    );
  }
}

class _PlantDetailView extends StatefulWidget {
  final Plant plant;
  const _PlantDetailView({required this.plant});

  @override
  State<_PlantDetailView> createState() => _PlantDetailViewState();
}

class _PlantDetailViewState extends State<_PlantDetailView> {
  int _imageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final plant = widget.plant;
    final images = plant.images;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: images.isNotEmpty ? 280 : 120,
          pinned: true,
          backgroundColor: AppColors.primaryMain,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: images.isNotEmpty
                ? Stack(
                    children: [
                      PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _imageIndex = i),
                        itemBuilder: (_, i) => CachedNetworkImage(
                          imageUrl: images[i].imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.forest900),
                          errorWidget: (_, __, ___) =>
                              Container(color: AppColors.forest900,
                                child: const Center(child: Icon(Icons.local_florist_outlined, color: Colors.white54, size: 48)),
                              ),
                        ),
                      ),
                      if (images.length > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              images.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: _imageIndex == i ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _imageIndex == i
                                      ? Colors.white
                                      : Colors.white38,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Container(
                    color: AppColors.forest800,
                    child: const Center(
                      child: Icon(Icons.local_florist_outlined,
                          color: Colors.white54, size: 64),
                    ),
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plant.scientificName,
                              style: AppTypography.h2),
                          if (plant.commonName != null) ...[
                            const SizedBox(height: 4),
                            Text(plant.commonName!,
                                style: AppTypography.body.copyWith(
                                    color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    StatusBadge(
                      label: plant.isActive ? 'Active' : 'Inactive',
                      variant: plant.isActive
                          ? BadgeVariant.success
                          : BadgeVariant.neutral,
                      dot: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Type + categories
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (plant.plantType != null)
                      StatusBadge(
                        label: _capitalize(plant.plantType!),
                        variant: BadgeVariant.accent,
                      ),
                    for (final cat in plant.categories)
                      StatusBadge(label: cat.name, variant: BadgeVariant.info),
                  ],
                ),

                // Description
                if (plant.englishDescription != null) ...[
                  const SizedBox(height: AppSpacing.x2l),
                  const Text('About', style: AppTypography.h4),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    plant.englishDescription!,
                    style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary, height: 1.6),
                  ),
                ],

                // Care details
                if (plant.lightRequirement != null ||
                    plant.waterRequirement != null) ...[
                  const SizedBox(height: AppSpacing.x2l),
                  const Text('Care Guide', style: AppTypography.h4),
                  const SizedBox(height: AppSpacing.md),
                  _CareGrid(plant: plant),
                ],

                // Plant code
                const SizedBox(height: AppSpacing.x2l),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.forest50,
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(color: AppColors.forest200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_rounded,
                          size: 18, color: AppColors.primaryMain),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Code: ', style: AppTypography.bodySmall),
                      Text(plant.plantCode,
                          style: AppTypography.label
                              .copyWith(color: AppColors.primaryMain)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x3l),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _CareGrid extends StatelessWidget {
  final Plant plant;
  const _CareGrid({required this.plant});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[];
    if (plant.lightRequirement != null)
      items.add((Icons.wb_sunny_outlined, 'Light', plant.lightRequirement!));
    if (plant.waterRequirement != null)
      items.add((Icons.water_drop_outlined, 'Water', plant.waterRequirement!));

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 2.4,
      children: items.map((item) => _CareCard(icon: item.$1, label: item.$2, value: item.$3)).toList(),
    );
  }
}

class _CareCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CareCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.forest100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.primaryMain),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                Text(
                  value,
                  style: AppTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

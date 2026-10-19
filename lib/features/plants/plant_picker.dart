import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'plants.dart';

/// Turns a tapped picker row into a catalog [Plant] (adding a botanical name
/// to the catalog on first use). Shows the API message and returns null on
/// failure, e.g. when an admin removed that plant.
Future<Plant?> resolvePickedPlant(
  BuildContext context,
  WidgetRef ref,
  PlantMatch match,
) async {
  try {
    return await ref.read(plantRepositoryProvider).resolvePlant(match);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is AppError ? e.message : 'Could not select plant'),
          backgroundColor: AppColors.red600,
        ),
      );
    }
    return null;
  }
}

// ── Plant picker bottom sheet ─────────────────────────────────────────────────

/// Bottom sheet that searches the catalog and the botanical names list, and
/// hands back a resolved catalog [Plant]. [existingPlantIds] are ticked.
class PlantPickerSheet extends ConsumerStatefulWidget {
  final String title;
  final Set<int> existingPlantIds;
  final void Function(Plant plant) onSelected;

  const PlantPickerSheet({
    super.key,
    required this.title,
    this.existingPlantIds = const {},
    required this.onSelected,
  });

  @override
  ConsumerState<PlantPickerSheet> createState() => PlantPickerSheetState();
}

class PlantPickerSheetState extends ConsumerState<PlantPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<PlantMatch> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(plantRepositoryProvider);
      final plants = await repo.lookupPlants(query.trim(), limit: 30);
      setState(() {
        _results = plants;
        _searched = true;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: AppTypography.h3,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Search 1.6 million plant names (common or scientific)',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search by name e.g. Ficus, Rose...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (v) {
                      if (v.trim().length >= 2) _search(v);
                    },
                    onSubmitted: _search,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: !_searched
                  ? Center(
                      child: Text(
                        'Type at least 2 characters to search',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                    )
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            'No plants found',
                            style: AppTypography.body
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 16),
                          itemBuilder: (_, i) {
                            final match = _results[i];
                            // Another size of a listed plant is fine; same plant + size is refused by the API.
                            final alreadyAdded = match.plant != null &&
                                widget.existingPlantIds
                                    .contains(match.plant!.id);
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.forest100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.eco_outlined,
                                  color: AppColors.primaryMain,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                match.title,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: match.subtitle != null
                                  ? Text(
                                      match.subtitle!,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    )
                                  : null,
                              trailing: alreadyAdded
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.textMuted,
                                      size: 20,
                                    )
                                  : const Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: AppColors.primaryMain,
                                      size: 20,
                                    ),
                              onTap: () async {
                                final plant = await resolvePickedPlant(
                                  context,
                                  ref,
                                  match,
                                );
                                if (plant != null) {
                                  widget.onSelected(plant);
                                }
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

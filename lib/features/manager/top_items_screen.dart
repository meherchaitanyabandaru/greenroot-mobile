import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../plants/plants.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class FeaturedPlant {
  final int id;
  final int nurseryId;
  final int plantId;
  final String plantName;
  final int displayOrder;
  final int? approximateQuantity;
  final String? approximateSize;
  final String? qualityNotes;
  final bool isActive;

  const FeaturedPlant({
    required this.id,
    required this.nurseryId,
    required this.plantId,
    required this.plantName,
    required this.displayOrder,
    this.approximateQuantity,
    this.approximateSize,
    this.qualityNotes,
    this.isActive = true,
  });

  factory FeaturedPlant.fromJson(Map<String, dynamic> j) => FeaturedPlant(
        id: (j['id'] as num).toInt(),
        nurseryId: (j['nursery_id'] as num).toInt(),
        plantId: (j['plant_id'] as num).toInt(),
        plantName: j['plant_name'] as String? ?? '',
        displayOrder: (j['display_order'] as num?)?.toInt() ?? 0,
        approximateQuantity: (j['approximate_quantity'] as num?)?.toInt(),
        approximateSize: j['approximate_size'] as String?,
        qualityNotes: j['quality_notes'] as String?,
        isActive: j['is_active'] as bool? ?? true,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _topItemsProvider =
    StateNotifierProvider.autoDispose<_TopItemsNotifier, AsyncValue<List<FeaturedPlant>>>(
  (ref) => _TopItemsNotifier(ref),
);

class _TopItemsNotifier extends StateNotifier<AsyncValue<List<FeaturedPlant>>> {
  final Ref _ref;

  _TopItemsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  int? get _nurseryId => _ref.read(sessionProvider).nurseryId;

  Future<void> _load() async {
    final nid = _nurseryId;
    if (nid == null) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final data = await ApiClient.instance.get<Map<String, dynamic>>(
        ApiConstants.featuredPlants(nid),
      );
      final list = (data['featured_plants'] as List<dynamic>? ?? [])
          .map((e) => FeaturedPlant.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } on AppError catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> refresh() => _load();

  Future<bool> add(int plantId, String plantName) async {
    final nid = _nurseryId;
    if (nid == null) return false;
    final current = state.valueOrNull ?? [];
    final nextOrder = current.length + 1;
    try {
      final data = await ApiClient.instance.post<Map<String, dynamic>>(
        ApiConstants.featuredPlants(nid),
        data: {
          'plant_id': plantId,
          'display_order': nextOrder,
          'photos': <String>[],
        },
      );
      final added = FeaturedPlant.fromJson(
          data['featured_plant'] as Map<String, dynamic>);
      state = AsyncValue.data([...current, added]);
      return true;
    } on AppError {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> remove(int featuredId) async {
    final nid = _nurseryId;
    if (nid == null) return false;
    try {
      await ApiClient.instance
          .delete(ApiConstants.featuredPlantById(nid, featuredId));
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
          current.where((p) => p.id != featuredId).toList());
      return true;
    } on AppError {
      return false;
    } catch (_) {
      return false;
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

const int _maxItems = 20;

class TopItemsScreen extends ConsumerWidget {
  const TopItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_topItemsProvider);
    final notifier = ref.read(_topItemsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: state.when(
          loading: () => const Text('My Top Items', style: AppTypography.h3),
          error: (_, __) => const Text('My Top Items', style: AppTypography.h3),
          data: (items) => Row(
            children: [
              const Text('My Top Items', style: AppTypography.h3),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: items.length >= _maxItems
                      ? AppColors.red600.withValues(alpha: 0.12)
                      : AppColors.forest100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length}/$_maxItems',
                  style: AppTypography.caption.copyWith(
                    color: items.length >= _maxItems
                        ? AppColors.red600
                        : AppColors.primaryMain,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          state.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) => items.length < _maxItems
                ? IconButton(
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Add Plant',
                    onPressed: () => _showPlantPicker(context, ref, items),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        'Max 20',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.red600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: state.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(e.toString(),
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: notifier.refresh,
                  child: const Text('Retry')),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? _EmptyState(
                onAdd: () => _showPlantPicker(context, ref, items),
              )
            : RefreshIndicator(
                onRefresh: notifier.refresh,
                color: AppColors.primaryMain,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.forest100,
                        borderRadius: AppRadius.cardRadius,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: AppColors.primaryMain),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'These plants represent what your nursery is known for. '
                              'Customers can discover you through this list in the marketplace.',
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.forest600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...items.asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm),
                            child: _PlantCard(
                              plant: entry.value,
                              rank: entry.key + 1,
                              onDelete: () async {
                                final ok = await notifier
                                    .remove(entry.value.id);
                                if (!ok && context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Could not remove item. Try again.'),
                                    backgroundColor: AppColors.red600,
                                  ));
                                }
                              },
                            ),
                          ),
                        ),
                    if (items.length < _maxItems) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showPlantPicker(context, ref, items),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                            'Add Plant (${_maxItems - items.length} slots left)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryMain,
                          side: const BorderSide(
                              color: AppColors.primaryMain),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.x3l),
                  ],
                ),
              ),
      ),
    );
  }

  void _showPlantPicker(
      BuildContext context, WidgetRef ref, List<FeaturedPlant> existing) {
    final existingIds = existing.map((p) => p.plantId).toSet();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlantPickerSheet(
        existingPlantIds: existingIds,
        onSelected: (plant) async {
          Navigator.of(context).pop();
          final notifier = ref.read(_topItemsProvider.notifier);
          final ok = await notifier.add(plant.id, plant.displayName);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not add plant. Try again.'),
              backgroundColor: AppColors.red600,
            ));
          }
        },
      ),
    );
  }
}

// ── Plant card ────────────────────────────────────────────────────────────────

class _PlantCard extends StatelessWidget {
  final FeaturedPlant plant;
  final int rank;
  final VoidCallback onDelete;

  const _PlantCard({
    required this.plant,
    required this.rank,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 48,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              '#$rank',
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryMain,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(
            height: 56,
            child: VerticalDivider(width: 1, color: AppColors.border),
          ),
          // Plant info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.plantName,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (plant.approximateSize != null ||
                      plant.approximateQuantity != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (plant.approximateSize != null)
                          _Tag(plant.approximateSize!),
                        if (plant.approximateQuantity != null)
                          _Tag('~${plant.approximateQuantity} pcs'),
                      ],
                    ),
                  ],
                  if (plant.qualityNotes?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      plant.qualityNotes!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.textMuted, size: 20),
            tooltip: 'Remove',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Remove plant?'),
                content: Text(
                    '${plant.plantName} will be removed from your top items.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                    child: const Text('Remove',
                        style: TextStyle(color: AppColors.red600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: AppColors.forest600),
      ),
    );
  }
}

// ── Plant picker bottom sheet ─────────────────────────────────────────────────

class _PlantPickerSheet extends ConsumerStatefulWidget {
  final Set<int> existingPlantIds;
  final void Function(Plant plant) onSelected;

  const _PlantPickerSheet({
    required this.existingPlantIds,
    required this.onSelected,
  });

  @override
  ConsumerState<_PlantPickerSheet> createState() => _PlantPickerSheetState();
}

class _PlantPickerSheetState extends ConsumerState<_PlantPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Plant> _results = [];
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
      final (plants, _) = await repo.listPlants(
        page: 1,
        perPage: 30,
        search: query.trim(),
      );
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
                  horizontal: AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Plant to Top Items',
                      style: AppTypography.h3),
                  const SizedBox(height: 4),
                  Text(
                    'Search from 20,000+ plants in the catalog',
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
                                      strokeWidth: 2)),
                            )
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
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
                              vertical: AppSpacing.sm),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 16),
                          itemBuilder: (_, i) {
                            final plant = _results[i];
                            final alreadyAdded = widget.existingPlantIds
                                .contains(plant.id);
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.forest100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.eco_outlined,
                                    color: AppColors.primaryMain, size: 20),
                              ),
                              title: Text(
                                plant.displayName,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: alreadyAdded
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary,
                                ),
                              ),
                              subtitle: plant.commonName != null &&
                                      plant.scientificName !=
                                          plant.displayName
                                  ? Text(plant.scientificName,
                                      style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textMuted))
                                  : null,
                              trailing: alreadyAdded
                                  ? const Icon(Icons.check_circle_rounded,
                                      color: AppColors.primaryMain, size: 20)
                                  : const Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: AppColors.primaryMain,
                                      size: 20),
                              enabled: !alreadyAdded,
                              onTap: alreadyAdded
                                  ? null
                                  : () => widget.onSelected(plant),
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

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.eco_outlined,
                  color: AppColors.primaryMain, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('No Top Items Yet', style: AppTypography.h3,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Select up to 20 plants your nursery is known for.\n'
              'Customers discover you through this list in the marketplace.',
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Your First Plant'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

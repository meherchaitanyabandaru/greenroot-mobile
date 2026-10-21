import '../../core/utilities/number_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../plants/plant_picker.dart';
import '../plants/plants.dart';
import 'top_items.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

/// The nursery's top items (its showcase, max 20). Owner and managers edit;
/// the list is not stock — orders never change it.
class TopItemsScreen extends ConsumerWidget {
  const TopItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(topItemsProvider);
    final notifier = ref.read(topItemsProvider.notifier);
    final items = state.valueOrNull ?? const <TopItem>[];
    final full = items.length >= maxTopItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            const Text('My Top Items', style: AppTypography.h3),
            if (state.hasValue) ...[
              const SizedBox(width: 10),
              _Counter(count: items.length),
            ],
          ],
        ),
        actions: [
          if (state.hasValue && !full)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: IconButton.filled(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Add plant',
                style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,),
                onPressed: () => _add(context, ref, items),
              ),
            ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.textMuted,),
              const SizedBox(height: 12),
              Text(e.toString(),
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: notifier.refresh, child: const Text('Retry'),),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? _EmptyState(onAdd: () => _add(context, ref, items))
            : RefreshIndicator(
                onRefresh: notifier.refresh,
                color: AppColors.primaryMain,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm,),
                      decoration: const BoxDecoration(
                          color: AppColors.forest100,
                          borderRadius: AppRadius.cardRadius,),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: AppColors.primaryMain,),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'What your nursery is known for. Buyers and nearby nurseries discover you through this list. '
                              'It is not stock — orders never change it.',
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.forest600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final (i, item) in items.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ItemCard(
                          item: item,
                          rank: i + 1,
                          onEdit: item.canEdit
                              ? () => _edit(context, ref, item)
                              : null,
                          onDelete: item.canEdit
                              ? () => _run(
                                  context, notifier.remove(item.id), 'Removed',)
                              : null,
                        ),
                      ),
                    if (!full) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () => _add(context, ref, items),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                            'Add plant (${maxTopItems - items.length} slots left)',),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryMain,
                          side: const BorderSide(color: AppColors.primaryMain),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),),
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

  void _add(BuildContext context, WidgetRef ref, List<TopItem> existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlantPickerSheet(
        title: 'Add Plant to Top Items',
        existingPlantIds: existing.map((p) => p.plantId).toSet(),
        onSelected: (plant) {
          Navigator.of(context).pop();
          _openDetails(context, ref,
              plantId: plant.id, plantName: plant.displayName,);
        },
      ),
    );
  }

  void _edit(BuildContext context, WidgetRef ref, TopItem item) =>
      _openDetails(context, ref,
          plantId: item.plantId, plantName: item.plantName, item: item,);

  void _openDetails(BuildContext context, WidgetRef ref,
      {required int plantId, required String plantName, TopItem? item,}) {
    final notifier = ref.read(topItemsProvider.notifier);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailsSheet(
        plantName: plantName,
        item: item,
        onSave: (sizeId, price, notes) {
          final draft = TopItemDraft(
            plantId: plantId,
            sizeId: sizeId,
            unitPrice: price,
            qualityNotes: notes,
            photos: item?.photos ?? const [],
          );
          return item == null
              ? notifier.add(draft)
              : notifier.save(item.id, draft);
        },
      ),
    );
  }

  Future<void> _run(
      BuildContext context, Future<String?> action, String done,) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await action;
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? done),
        backgroundColor: error == null ? null : AppColors.red600,
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final int count;
  const _Counter({required this.count});

  @override
  Widget build(BuildContext context) {
    final full = count >= maxTopItems;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: full
            ? AppColors.red600.withValues(alpha: 0.12)
            : AppColors.forest100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count/$maxTopItems',
        style: AppTypography.caption.copyWith(
            color: full ? AppColors.red600 : AppColors.primaryMain,
            fontWeight: FontWeight.w700,),
      ),
    );
  }
}

// ── Item card ─────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final TopItem item;
  final int rank;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ItemCard(
      {required this.item, required this.rank, this.onEdit, this.onDelete,});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: AppColors.border),),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Row(
          children: [
            Container(
              width: 48,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('#$rank',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.primaryMain,
                      fontWeight: FontWeight.w800,),),
            ),
            const SizedBox(
                height: 56,
                child: VerticalDivider(width: 1, color: AppColors.border),),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 14,),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.plantName,
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,),
                    const SizedBox(height: 3),
                    Wrap(
                      children: [
                        _Tag(item.sizeName),
                        if (item.unitPrice != null)
                          _Tag('₹${_formatPrice(item.unitPrice)}'),
                        if (item.photos.isNotEmpty)
                          _Tag(
                              '${item.photos.length} photo${item.photos.length > 1 ? 's' : ''}',),
                      ],
                    ),
                    if (item.qualityNotes?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(item.qualityNotes!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,),
                    ],
                  ],
                ),
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.textMuted, size: 20,),
                tooltip: 'Remove',
                onPressed: () => showDialog(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: const Text('Remove plant?'),
                    content: Text(
                        '${item.plantName} (${item.sizeName}) will be removed from your top items.',),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog),
                          child: const Text('Cancel'),),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialog);
                          onDelete!();
                        },
                        child: const Text('Remove',
                            style: TextStyle(color: AppColors.red600),),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
      margin: const EdgeInsets.only(right: 6, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: AppColors.forest100, borderRadius: BorderRadius.circular(20),),
      child: Text(label,
          style: AppTypography.caption.copyWith(color: AppColors.forest600),),
    );
  }
}

// ── Size, price and notes ─────────────────────────────────────────────────────

/// 100.0 → "100", 99.5 → "99.5"; empty when there is no price.
String _formatPrice(double? price) {
  if (price == null) return '';
  return price % 1 == 0 ? price.toStringAsFixed(0) : price.toString();
}

class _DetailsSheet extends ConsumerStatefulWidget {
  final String plantName;
  final TopItem? item;
  final Future<String?> Function(int sizeId, double? price, String? notes)
      onSave;

  const _DetailsSheet(
      {required this.plantName, required this.onSave, this.item,});

  @override
  ConsumerState<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends ConsumerState<_DetailsSheet> {
  late int? _sizeId = widget.item?.sizeId;
  late final _price =
      TextEditingController(text: _formatPrice(widget.item?.unitPrice));
  late final _notes =
      TextEditingController(text: widget.item?.qualityNotes ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final priceText = _price.text.trim();
    final price = priceText.isEmpty ? null : double.tryParse(priceText);
    if (_sizeId == null) return setState(() => _error = 'Choose a size');
    if (priceText.isNotEmpty && (price == null || price < 0)) {
      return setState(() => _error = 'Price must be 0 or more');
    }
    if (_notes.text.length > 500) {
      return setState(() => _error = 'Notes: at most 500 characters');
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(_sizeId!, price, _notes.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = ref.watch(plantSizesProvider);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),),
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 16,
            AppSpacing.screenPadding, AppSpacing.x2l,),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                widget.item == null
                    ? 'Add ${widget.plantName}'
                    : 'Edit ${widget.plantName}',
                style: AppTypography.h3,),
            const SizedBox(height: AppSpacing.md),
            Text('Size',
                style: AppTypography.bodySmall
                    .copyWith(fontWeight: FontWeight.w700),),
            const SizedBox(height: AppSpacing.sm),
            sizes.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load sizes: $e',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.red600),),
              data: (list) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in list)
                    ChoiceChip(
                      label: Text(s.displayName),
                      selected: _sizeId == s.id,
                      onSelected: (_) => setState(() => _sizeId = s.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: NumberInput.money,
              decoration: const InputDecoration(
                  labelText: 'Indicative price per plant (optional)',
                  prefixText: '₹ ',),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _notes,
              maxLength: 500,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                  labelText: 'Quality notes (optional)',
                  hintText: 'e.g. Grafted, 2 ft, healthy roots',),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.red600),),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    padding: const EdgeInsets.symmetric(vertical: 14),),
                child: Text(_saving
                    ? 'Saving…'
                    : (widget.item == null ? 'Add to top items' : 'Save'),),
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
              child: const Icon(
                Icons.eco_outlined,
                color: AppColors.primaryMain,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Top Items Yet',
              style: AppTypography.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Select up to 20 plants your nursery is known for.\n'
              'Buyers and nearby nurseries discover you through this list.',
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
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

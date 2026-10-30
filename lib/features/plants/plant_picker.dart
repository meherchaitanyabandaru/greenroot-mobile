import 'dart:async';

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
  // When set, "Other / not listed" is offered with what was typed: the
  // catalog never stops someone asking for a plant (quotation requests).
  final void Function(String typed)? onOther;

  const PlantPickerSheet({
    super.key,
    required this.title,
    this.existingPlantIds = const {},
    required this.onSelected,
    this.onOther,
  });

  @override
  ConsumerState<PlantPickerSheet> createState() => PlantPickerSheetState();
}

class PlantPickerSheetState extends ConsumerState<PlantPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<PlantMatch> _results = [];
  bool _loading = false;
  bool _searched = false;
  Timer? _debounce;
  int _seq = 0; // only the latest search may show its results

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Searches once typing pauses. Long names take the server longer than
  /// short prefixes, so an older reply can arrive last: it is ignored.
  void _searchSoon(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    _debounce?.cancel();
    final seq = ++_seq;
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(plantRepositoryProvider);
      final plants = await repo.lookupPlants(query.trim(), limit: 30);
      if (!mounted || seq != _seq) return;
      setState(() {
        _results = plants;
        _searched = true;
        _loading = false;
      });
    } catch (_) {
      if (mounted && seq == _seq) setState(() => _loading = false);
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
                      if (v.trim().length >= 2) _searchSoon(v);
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
                  : _results.isEmpty && widget.onOther == null
                      ? PlantNotFound(query: _searchCtrl.text)
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          itemCount: _results.length + 1,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 16),
                          itemBuilder: (_, i) {
                            if (i == _results.length) {
                              return widget.onOther != null
                                  ? OtherPlantTile(
                                      typed: _searchCtrl.text,
                                      onTap: () => widget.onOther!(_searchCtrl.text.trim()),
                                    )
                                  : SuggestPlantTile(query: _searchCtrl.text);
                            }
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

/// "Other / not listed": ask for the plant by the name you know it by.
class OtherPlantTile extends StatelessWidget {
  final String typed;
  final VoidCallback onTap;
  const OtherPlantTile({super.key, required this.typed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.edit_note_rounded, color: AppColors.primaryMain),
      title: const Text('Other / not listed'),
      subtitle: Text(
        typed.isEmpty
            ? 'Enter the plant as you know it'
            : 'Ask for "$typed" by your own name for it',
        style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

// ── Not found: suggest it ─────────────────────────────────────────────────────

/// "No plants found" with a way to suggest [query] to GreenRoot's plant list.
/// Admins review suggestions; nothing is added until they do.
class PlantNotFound extends ConsumerWidget {
  final String query;
  final bool compact; // inline under a search field
  const PlantNotFound({super.key, required this.query, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = query.trim();
    final children = [
      Text(
        'No plants found for "$q"',
        textAlign: TextAlign.center,
        style: (compact ? AppTypography.bodySmall : AppTypography.body)
            .copyWith(color: AppColors.textSecondary),
      ),
      TextButton.icon(
        onPressed: () => suggestPlant(context, ref, q),
        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
        label: Text('Suggest "$q" to GreenRoot'),
      ),
    ];
    return compact
        ? Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          );
  }
}

/// Asks for the details and sends the suggestion; tells the user the outcome.
Future<void> suggestPlant(BuildContext context, WidgetRef ref, String name) async {
  final nameCtrl = TextEditingController(text: name);
  final sciCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final send = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Suggest a plant'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Our team checks it and adds it to the plant list. '
              "You'll get a notification.",
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Plant name *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: sciCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Scientific name (if you know it)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Local name, flower colour, variety...',
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // The theme makes filled buttons full width; not in a dialog row.
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () {
            if (nameCtrl.text.trim().length >= 2) Navigator.pop(ctx, true);
          },
          child: const Text('Send'),
        ),
      ],
    ),
  );
  final plantName = nameCtrl.text.trim();
  final sci = sciCtrl.text.trim();
  final notes = notesCtrl.text.trim();
  // Not disposed: the dialog may still be animating out with them.
  if (send != true || !context.mounted) return;

  String message;
  var ok = true;
  try {
    final (result, plant) = await ref.read(plantRepositoryProvider).suggestPlant(
          name: plantName,
          scientificName: sci.isEmpty ? null : sci,
          notes: notes.isEmpty ? null : notes,
        );
    message = switch (result) {
      'EXISTS' => 'GreenRoot already has it as '
          '"${plant?.commonName?.isNotEmpty == true ? plant!.commonName : plant?.scientificName ?? plantName}". '
          'Search for that name.',
      'ALREADY_SUGGESTED' =>
        '"$plantName" is already suggested. We will add it soon.',
      _ => "Thanks! We'll review \"$plantName\" and let you know.",
    };
  } catch (e) {
    ok = false;
    message = e is AppError ? e.message : 'Could not send the suggestion';
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: ok ? AppColors.primaryMain : AppColors.red600,
    ),
  );
}

/// Last row of a results list: fuzzy botanical matches rarely come back
/// empty, so "not found" alone would hide the suggestion for local names.
class SuggestPlantTile extends ConsumerWidget {
  final String query;
  const SuggestPlantTile({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = query.trim();
    if (q.length < 2) return const SizedBox.shrink(); // nothing typed yet
    return ListTile(
      dense: true,
      leading: const Icon(
        Icons.add_circle_outline_rounded,
        color: AppColors.primaryMain,
      ),
      title: Text(
        'Not in the list? Suggest "$q"',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.primaryMain,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => suggestPlant(context, ref, q),
    );
  }
}

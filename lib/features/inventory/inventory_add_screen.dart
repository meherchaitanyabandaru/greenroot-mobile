import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../plants/plants.dart';
import 'inventory.dart';

class InventoryAddScreen extends ConsumerStatefulWidget {
  const InventoryAddScreen({super.key});

  @override
  ConsumerState<InventoryAddScreen> createState() => _InventoryAddScreenState();
}

class _InventoryAddScreenState extends ConsumerState<InventoryAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityCtrl = TextEditingController();
  Plant? _selectedPlant;
  PlantSize? _selectedSize;
  String _status = 'AVAILABLE';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _quantityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedPlant == null) {
      setState(() => _error = 'Please select a plant');
      return;
    }
    if (_selectedSize == null) {
      setState(() => _error = 'Please select a size');
      return;
    }
    final nurseryId = ref.read(sessionProvider).nurseryId;
    if (nurseryId == null) {
      setState(() => _error = 'No nursery found for your account');
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(inventoryRepositoryProvider).upsert(
        nurseryId: nurseryId,
        plantId: _selectedPlant!.id,
        sizeId: _selectedSize!.id,
        availableQuantity: int.parse(_quantityCtrl.text.trim()),
        status: _status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory item added successfully'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = ref.watch(plantSizesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Inventory'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryMain),
                  )
                : const Text('Save', style: TextStyle(color: AppColors.primaryMain, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.red100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.red600),
                ),
                child: Text(_error!, style: AppTypography.bodySmall.copyWith(color: AppColors.red600)),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Plant selector
            _sectionLabel('Plant'),
            const SizedBox(height: AppSpacing.sm),
            _PlantSearchField(
              selected: _selectedPlant,
              onSelected: (plant) => setState(() => _selectedPlant = plant),
            ),
            const SizedBox(height: AppSpacing.x2l),

            // Size selector
            _sectionLabel('Size'),
            const SizedBox(height: AppSpacing.sm),
            sizes.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryMain)),
              error: (err, _) => Text('Failed to load sizes: $err', style: AppTypography.bodySmall),
              data: (sizeList) => sizeList.isEmpty
                  ? Text('No sizes available', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted))
                  : Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: sizeList.map((size) {
                        final selected = _selectedSize?.id == size.id;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedSize = size),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primaryMain : AppColors.surface,
                              border: Border.all(
                                  color: selected ? AppColors.primaryMain : AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              size.displayName,
                              style: AppTypography.body.copyWith(
                                color: selected ? Colors.white : AppColors.textPrimary,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: AppSpacing.x2l),

            // Quantity
            _sectionLabel('Available Quantity'),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _quantityCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration('e.g. 50'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a quantity';
                final n = int.tryParse(v.trim());
                if (n == null || n < 0) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.x2l),

            // Status
            _sectionLabel('Status'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: ['AVAILABLE', 'OUT_OF_STOCK', 'SEASONAL'].map((s) {
                final selected = _status == s;
                return GestureDetector(
                  onTap: () => setState(() => _status = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primaryMain : AppColors.surface,
                      border: Border.all(
                          color: selected ? AppColors.primaryMain : AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(s),
                      style: AppTypography.body.copyWith(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.x3l),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'AVAILABLE': return 'Available';
      case 'OUT_OF_STOCK': return 'Out of Stock';
      case 'SEASONAL': return 'Seasonal';
      default: return s;
    }
  }
}

Widget _sectionLabel(String label) => Text(label, style: AppTypography.h4);

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryMain, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.red600),
      ),
    );

// ── Plant search widget ────────────────────────────────────────────────────────

class _PlantSearchField extends ConsumerStatefulWidget {
  final Plant? selected;
  final ValueChanged<Plant> onSelected;

  const _PlantSearchField({required this.selected, required this.onSelected});

  @override
  ConsumerState<_PlantSearchField> createState() => _PlantSearchFieldState();
}

class _PlantSearchFieldState extends ConsumerState<_PlantSearchField> {
  final _ctrl = TextEditingController();
  List<Plant> _results = [];
  bool _searching = false;
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) {
      _ctrl.text = widget.selected!.displayName;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() { _results = []; _showDropdown = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      final repo = ref.read(plantRepositoryProvider);
      final (results, _) = await repo.listPlants(search: query, page: 1, perPage: 10);
      if (mounted) setState(() { _results = results; _showDropdown = results.isNotEmpty; });
    } catch (e) {
      if (mounted) {
        setState(() { _results = []; _showDropdown = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plant search error: $e'), backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          decoration: _inputDecoration('Search plant by name...').copyWith(
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryMain)),
                  )
                : widget.selected != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() { _results = []; _showDropdown = false; });
                        },
                      )
                    : const Icon(Icons.search, color: AppColors.textMuted),
          ),
          onChanged: (val) {
            Future.delayed(const Duration(milliseconds: 400), () {
              if (_ctrl.text == val) _search(val);
            });
          },
        ),
        if (_showDropdown) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) {
                final plant = _results[i];
                return ListTile(
                  dense: true,
                  title: Text(plant.scientificName, style: AppTypography.body),
                  subtitle: plant.commonName != null
                      ? Text(plant.commonName!, style: AppTypography.bodySmall)
                      : null,
                  onTap: () {
                    _ctrl.text = plant.displayName;
                    setState(() { _showDropdown = false; _results = []; });
                    widget.onSelected(plant);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

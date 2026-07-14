import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../nurseries/nurseries.dart';
import '../plants/plants.dart';
import 'orders.dart';

// ── Buyer Order Create Screen ─────────────────────────────────────────────────
// Customers use this to place a direct order with any active nursery.
// POST /orders without buyer_mobile (API infers from auth token).

class BuyerOrderCreateScreen extends ConsumerStatefulWidget {
  const BuyerOrderCreateScreen({super.key});

  @override
  ConsumerState<BuyerOrderCreateScreen> createState() =>
      _BuyerOrderCreateScreenState();
}

class _BuyerOrderCreateScreenState
    extends ConsumerState<BuyerOrderCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_ItemRow> _items = [];

  Nursery? _selectedNursery;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    for (final r in _items) {
      r.dispose();
    }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_ItemRow()));

  void _removeItem(int index) {
    _items.removeAt(index).dispose();
    setState(() {});
  }

  double get _grandTotal => _items.fold(0.0, (s, r) => s + r.lineTotal);

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedNursery == null) {
      setState(() => _error = 'Select a nursery first');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one plant item');
      return;
    }
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].plant == null) {
        setState(() => _error = 'Select a plant for item ${i + 1}');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final reqs = _items
          .map((r) => OrderItemRequest(
                plantId: r.plant!.id,
                quantity: double.parse(r.qtyCtrl.text.trim()),
                unitPrice: double.parse(r.priceCtrl.text.trim()),
                totalPrice: r.lineTotal,
              ))
          .toList();

      await ref.read(orderRepositoryProvider).createBuyerOrder(
            sellerNurseryId: _selectedNursery!.id,
            items: reqs,
            buyerName:
                _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed successfully'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Plants'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            // ── Nursery picker ────────────────────────────────────────────
            _SectionLabel('Select Nursery'),
            _NurseryPickerTile(
              selected: _selectedNursery,
              onSelected: (n) => setState(() {
                _selectedNursery = n;
                _error = null;
              }),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Optional name ─────────────────────────────────────────────
            _SectionLabel('Your Name (optional)'),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDeco('e.g. Ravi Kumar'),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Items ─────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _SectionLabel('Plants')),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Plant'),
                ),
              ],
            ),
            if (_items.isEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tap "Add Plant" to add items to your order.',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ..._items.asMap().entries.map((e) => _ItemRowWidget(
                  key: ObjectKey(e.value),
                  row: e.value,
                  index: e.key,
                  onRemove: () => _removeItem(e.key),
                  onChanged: () => setState(() {}),
                )),
            const SizedBox(height: AppSpacing.sm),

            // ── Notes ─────────────────────────────────────────────────────
            _SectionLabel('Notes (optional)'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: _inputDeco('Any special instructions…'),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Total ─────────────────────────────────────────────────────
            if (_items.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Order Total',
                        style: AppTypography.label.copyWith(
                            color: AppColors.primaryHover,
                            fontWeight: FontWeight.bold)),
                    Text(
                      '₹${_grandTotal.toStringAsFixed(2)}',
                      style: AppTypography.h4
                          .copyWith(color: AppColors.primaryHover),
                    ),
                  ],
                ),
              ),

            // ── Error ─────────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.errorText)),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // ── Submit ────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Place Order',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ── Nursery picker tile ───────────────────────────────────────────────────────

class _NurseryPickerTile extends ConsumerStatefulWidget {
  final Nursery? selected;
  final ValueChanged<Nursery> onSelected;

  const _NurseryPickerTile({required this.selected, required this.onSelected});

  @override
  ConsumerState<_NurseryPickerTile> createState() => _NurseryPickerTileState();
}

class _NurseryPickerTileState extends ConsumerState<_NurseryPickerTile> {
  Future<void> _pick() async {
    final result = await showModalBottomSheet<Nursery>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _NurseryPickerSheet(),
    );
    if (result != null) widget.onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.selected;
    return GestureDetector(
      onTap: _pick,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          border: Border.all(
              color: n != null ? AppColors.primaryMain : AppColors.border),
          borderRadius: BorderRadius.circular(8),
          color: n != null
              ? AppColors.primaryLight.withOpacity(0.4)
              : AppColors.surface,
        ),
        child: Row(
          children: [
            Icon(Icons.storefront_rounded,
                color: n != null
                    ? AppColors.primaryMain
                    : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: n != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.name,
                            style: AppTypography.label
                                .copyWith(color: AppColors.primaryHover)),
                        if (n.cityState.isNotEmpty)
                          Text(n.cityState,
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.textSecondary)),
                      ],
                    )
                  : Text('Choose a nursery',
                      style: AppTypography.body
                          .copyWith(color: AppColors.textSecondary)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _NurseryPickerSheet extends ConsumerStatefulWidget {
  const _NurseryPickerSheet();

  @override
  ConsumerState<_NurseryPickerSheet> createState() =>
      _NurseryPickerSheetState();
}

class _NurseryPickerSheetState extends ConsumerState<_NurseryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Nursery> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch('');
    _searchCtrl.addListener(() => _fetch(_searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (nurseries, _) = await ref
          .read(nurseryRepositoryProvider)
          .listNurseries(
              search: query.isEmpty ? null : query, status: 'active');
      if (mounted) setState(() => _results = nurseries);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: _inputDeco('Search nurseries…')
                  .copyWith(prefixIcon: const Icon(Icons.search)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.errorText)))
                    : _results.isEmpty
                        ? Center(
                            child: Text('No nurseries found',
                                style: AppTypography.body
                                    .copyWith(color: AppColors.textSecondary)))
                        : ListView.separated(
                            controller: controller,
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final n = _results[i];
                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.primaryLight,
                                  child: Icon(Icons.local_florist,
                                      color: AppColors.primaryMain, size: 20),
                                ),
                                title: Text(n.name, style: AppTypography.label),
                                subtitle: n.cityState.isNotEmpty
                                    ? Text(n.cityState,
                                        style: AppTypography.bodySmall)
                                    : null,
                                onTap: () => Navigator.of(context).pop(n),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Plant item row ────────────────────────────────────────────────────────────

class _ItemRow {
  Plant? plant;
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();

  double get lineTotal {
    final q = double.tryParse(qtyCtrl.text.trim()) ?? 0;
    final p = double.tryParse(priceCtrl.text.trim()) ?? 0;
    return q * p;
  }

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _ItemRowWidget extends ConsumerStatefulWidget {
  final _ItemRow row;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemRowWidget({
    super.key,
    required this.row,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  ConsumerState<_ItemRowWidget> createState() => _ItemRowWidgetState();
}

class _ItemRowWidgetState extends ConsumerState<_ItemRowWidget> {
  @override
  void initState() {
    super.initState();
    widget.row.qtyCtrl.addListener(widget.onChanged);
    widget.row.priceCtrl.addListener(widget.onChanged);
  }

  Future<void> _pickPlant() async {
    final result = await showModalBottomSheet<Plant>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _PlantPickerSheet(),
    );
    if (result != null) {
      setState(() => widget.row.plant = result);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Item ${widget.index + 1}',
                  style: AppTypography.label
                      .copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              GestureDetector(
                onTap: widget.onRemove,
                child: const Icon(Icons.remove_circle_outline,
                    color: AppColors.errorText, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickPlant,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                    color: row.plant != null
                        ? AppColors.primaryMain
                        : AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_florist,
                      size: 18,
                      color: row.plant != null
                          ? AppColors.primaryMain
                          : AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.plant?.displayName ?? 'Select plant',
                      style: row.plant != null
                          ? AppTypography.label
                          : AppTypography.body
                              .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  decoration: _inputDeco('Qty').copyWith(labelText: 'Qty'),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Enter qty';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  decoration:
                      _inputDeco('Price ₹').copyWith(labelText: 'Price ₹'),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n < 0) return 'Enter price';
                    return null;
                  },
                ),
              ),
            ],
          ),
          if (row.lineTotal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Line total: ₹${row.lineTotal.toStringAsFixed(2)}',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Plant picker sheet ────────────────────────────────────────────────────────

class _PlantPickerSheet extends ConsumerStatefulWidget {
  const _PlantPickerSheet();

  @override
  ConsumerState<_PlantPickerSheet> createState() => _PlantPickerSheetState();
}

class _PlantPickerSheetState extends ConsumerState<_PlantPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Plant> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch('');
    _searchCtrl.addListener(() => _fetch(_searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch(String q) async {
    setState(() => _loading = true);
    try {
      final (plants, _) = await ref
          .read(plantRepositoryProvider)
          .listPlants(search: q.isEmpty ? null : q);
      if (mounted) setState(() => _results = plants);
    } catch (_) {
      // leave results as-is on error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: _inputDeco('Search plants…')
                  .copyWith(prefixIcon: const Icon(Icons.search)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text('No plants found',
                            style: AppTypography.body
                                .copyWith(color: AppColors.textSecondary)))
                    : ListView.separated(
                        controller: controller,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = _results[i];
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primaryLight,
                              child: Icon(Icons.eco,
                                  color: AppColors.primaryMain, size: 20),
                            ),
                            title:
                                Text(p.displayName, style: AppTypography.label),
                            subtitle: p.commonName != null &&
                                    p.scientificName != p.displayName
                                ? Text(p.scientificName,
                                    style: AppTypography.bodySmall
                                        .copyWith(fontStyle: FontStyle.italic))
                                : null,
                            onTap: () => Navigator.of(context).pop(p),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style:
                AppTypography.label.copyWith(color: AppColors.textSecondary)),
      );
}

InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.primaryMain, width: 1.5)),
    );

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../plants/plants.dart';
import 'orders.dart';

class OrderCreateScreen extends ConsumerStatefulWidget {
  const OrderCreateScreen({super.key});

  @override
  ConsumerState<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends ConsumerState<OrderCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_ItemRow> _items = [];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    for (final r in _items) {
      r.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_ItemRow()));
  }

  void _removeItem(int index) {
    final row = _items.removeAt(index);
    row.dispose();
    setState(() {});
  }

  double get _grandTotal =>
      _items.fold(0.0, (sum, r) => sum + r.lineTotal);

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one item');
      return;
    }
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].plant == null) {
        setState(() => _error = 'Select a plant for item ${i + 1}');
        return;
      }
    }

    final nurseryId = ref.read(sessionProvider).nurseryId;
    if (nurseryId == null) {
      setState(() => _error = 'No nursery found for your account');
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      final itemRequests = _items.map((r) => OrderItemRequest(
        plantId: r.plant!.id,
        quantity: double.parse(r.qtyCtrl.text.trim()),
        unitPrice: double.parse(r.priceCtrl.text.trim()),
        totalPrice: r.lineTotal,
      )).toList();

      await ref.read(orderRepositoryProvider).createOrder(
        buyerMobile: _mobileCtrl.text.trim(),
        buyerName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        sellerNurseryId: nurseryId,
        items: itemRequests,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order created successfully'),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Order'),
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

            // Buyer details
            Text('Buyer', style: AppTypography.h4),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _mobileCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration('Mobile number (10 digits)'),
              validator: (v) {
                if (v == null || v.trim().length != 10) return 'Enter a valid 10-digit mobile number';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration('Buyer name (optional)'),
            ),
            const SizedBox(height: AppSpacing.x2l),

            // Order items
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Items', style: AppTypography.h4),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 18, color: AppColors.primaryMain),
                  label: const Text('Add Item', style: TextStyle(color: AppColors.primaryMain)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('No items yet — tap Add Item', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                ),
              )
            else
              ...List.generate(_items.length, (i) => _ItemRowWidget(
                key: ValueKey(_items[i]),
                row: _items[i],
                index: i,
                onRemove: () => _removeItem(i),
                onChanged: () => setState(() {}),
              )),

            if (_items.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ₹${_grandTotal.toStringAsFixed(2)}',
                  style: AppTypography.h4.copyWith(color: AppColors.primaryMain),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.x2l),

            // Notes
            Text('Notes', style: AppTypography.h4),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: _inputDecoration('Optional notes'),
            ),
            const SizedBox(height: AppSpacing.x3l),
          ],
        ),
      ),
    );
  }
}

// ── Item row model ─────────────────────────────────────────────────────────────

class _ItemRow {
  Plant? plant;
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController priceCtrl = TextEditingController(text: '0');

  double get lineTotal {
    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
    return qty * price;
  }

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

// ── Item row widget ────────────────────────────────────────────────────────────

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
  final _searchCtrl = TextEditingController();
  List<Plant> _results = [];
  bool _searching = false;
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    if (widget.row.plant != null) {
      _searchCtrl.text = widget.row.plant!.displayName;
    }
    widget.row.qtyCtrl.addListener(widget.onChanged);
    widget.row.priceCtrl.addListener(widget.onChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() { _results = []; _showDropdown = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      final (results, _) = await ref.read(plantRepositoryProvider)
          .listPlants(search: query, page: 1, perPage: 10);
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
    final row = widget.row;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Item ${widget.index + 1}',
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.red600, size: 20),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Plant search
          TextField(
            controller: _searchCtrl,
            decoration: _inputDecoration('Search plant...').copyWith(
              suffixIcon: _searching
                  ? const Padding(padding: EdgeInsets.all(10),
                      child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryMain)))
                  : const Icon(Icons.search, color: AppColors.textMuted, size: 18),
            ),
            onChanged: (val) {
              Future.delayed(const Duration(milliseconds: 400), () {
                if (_searchCtrl.text == val) _search(val);
              });
            },
          ),
          if (_showDropdown) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                itemBuilder: (_, i) {
                  final plant = _results[i];
                  return ListTile(
                    dense: true,
                    title: Text(plant.scientificName, style: AppTypography.bodySmall),
                    subtitle: plant.commonName != null
                        ? Text(plant.commonName!, style: AppTypography.caption)
                        : null,
                    onTap: () {
                      _searchCtrl.text = plant.displayName;
                      setState(() { row.plant = plant; _showDropdown = false; _results = []; });
                      widget.onChanged();
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  decoration: _inputDecoration('Qty'),
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: row.priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  decoration: _inputDecoration('Unit price ₹'),
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.forest100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '₹${row.lineTotal.toStringAsFixed(0)}',
                    style: AppTypography.body.copyWith(
                        color: AppColors.primaryMain, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryMain, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.red600)),
    );

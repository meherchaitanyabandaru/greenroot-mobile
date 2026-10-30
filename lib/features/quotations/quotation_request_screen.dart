import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../nurseries/nurseries.dart';
import '../orders/buyer_order_create_screen.dart' show NurseryPickerTile;
import '../plants/plant_picker.dart';
import 'quotations.dart';

/// A customer asks one nursery for prices: plants from the catalog or by
/// their own name ("Other / not listed"), quantities and what they need
/// (variety, size, grade). The nursery prices it and sends a quotation; the
/// catalog never stops the request.
class QuotationRequestScreen extends ConsumerStatefulWidget {
  final Nursery? nursery;
  const QuotationRequestScreen({super.key, this.nursery});

  @override
  ConsumerState<QuotationRequestScreen> createState() => _QuotationRequestScreenState();
}

class _QuotationRequestScreenState extends ConsumerState<QuotationRequestScreen> {
  Nursery? _nursery;
  final List<RequestLine> _lines = [];
  final _noteCtrl = TextEditingController();
  // One key per form: a retry after a lost answer is the same request.
  final _submitKey = newIdempotencyKey();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nursery = widget.nursery;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _addLine() async {
    final picked = await showModalBottomSheet<RequestLine>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => PlantPickerSheet(
        title: 'Which plant do you need?',
        onSelected: (plant) => Navigator.of(sheet).pop(
          RequestLine(plantId: plant.id, plantName: plant.displayName, quantity: 1),
        ),
        onOther: (typed) => Navigator.of(sheet).pop(
          RequestLine(customPlantName: typed, quantity: 1),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final line = await _editLine(picked);
    if (line != null) setState(() => _lines.add(line));
  }

  Future<RequestLine?> _editLine(RequestLine line) => showModalBottomSheet<RequestLine>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => RequestLineSheet(line: line),
      );

  Future<void> _submit() async {
    if (_nursery == null || _lines.isEmpty) {
      setState(() => _error = _nursery == null ? 'Choose a nursery first' : 'Add at least one plant');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final q = await ref.read(quotationRepositoryProvider).createRequest(
            nurseryId: _nursery!.id,
            lines: _lines,
            note: _noteCtrl.text,
            idempotencyKey: _submitKey,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to ${_nursery!.name}. You will be told when prices are ready.')),
      );
      context.pushReplacement('/quotations/${q.id}');
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Request a quotation'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const Text('Nursery', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          NurseryPickerTile(selected: _nursery, onSelected: (n) => setState(() => _nursery = n)),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            Expanded(child: Text('Plants (${_lines.length})', style: AppTypography.label)),
            TextButton.icon(onPressed: _addLine, icon: const Icon(Icons.add_rounded), label: const Text('Add plant')),
          ],),
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                "Add the plants you need. Can't find one? Choose \"Other / not listed\" and write it as you know it.",
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ),
          for (var i = 0; i < _lines.length; i++)
            RequestLineTile(
              line: _lines[i],
              onEdit: () async {
                final edited = await _editLine(_lines[i]);
                if (edited != null) setState(() => _lines[i] = edited);
              },
              onRemove: () => setState(() => _lines.removeAt(i)),
            ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _noteCtrl,
            label: 'Message to the nursery (optional)',
            hint: 'e.g. needed by next Friday, delivery to the farm',
            maxLines: 3,
            maxLength: 1000,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppTypography.body.copyWith(color: AppColors.red600)),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Send request', isLoading: _sending, onPressed: _sending ? null : _submit),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The nursery has 7 days to send prices. You accept or reject the quotation; nothing is ordered until you accept.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A line of the request: the name, whether it is the customer's own name
/// for a plant not in the catalog, quantity and specifications.
class RequestLineTile extends StatelessWidget {
  final RequestLine line;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  const RequestLineTile({super.key, required this.line, required this.onEdit, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final specs = [
      if (line.variety?.isNotEmpty == true) line.variety!,
      if (line.sizeDescription?.isNotEmpty == true) line.sizeDescription!,
      if (line.grade?.isNotEmpty == true) 'Grade ${line.grade}',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onEdit,
        title: Text(line.displayName, style: AppTypography.label),
        subtitle: Text(
          [
            'Qty ${_qty(line.quantity)}',
            if (specs.isNotEmpty) specs,
            if (line.isCustom) 'Your name — not in the plant list',
          ].join('\n'),
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        isThreeLine: line.isCustom || specs.isNotEmpty,
        trailing: IconButton(
          tooltip: 'Remove ${line.displayName}',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();

/// Quantity and specifications for a line; for a plant not in the list also
/// the name (required) and an optional botanical name. Pops the line.
class RequestLineSheet extends StatefulWidget {
  final RequestLine line;
  const RequestLineSheet({super.key, required this.line});

  @override
  State<RequestLineSheet> createState() => _RequestLineSheetState();
}

class _RequestLineSheetState extends State<RequestLineSheet> {
  late final _name = TextEditingController(text: widget.line.customPlantName ?? '');
  late final _botanical = TextEditingController(text: widget.line.scientificName ?? '');
  late final _qtyCtrl = TextEditingController(text: _qty(widget.line.quantity));
  late final _variety = TextEditingController(text: widget.line.variety ?? '');
  late final _size = TextEditingController(text: widget.line.sizeDescription ?? '');
  late final _grade = TextEditingController(text: widget.line.grade ?? '');
  late final _notes = TextEditingController(text: widget.line.notes ?? '');
  bool _tried = false;

  @override
  void dispose() {
    for (final c in [_name, _botanical, _qtyCtrl, _variety, _size, _grade, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _done() {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final custom = widget.line.isCustom;
    setState(() => _tried = true);
    if (qty <= 0 || (custom && _name.text.trim().length < 2)) return;
    Navigator.of(context).pop(RequestLine(
      plantId: widget.line.plantId,
      plantName: widget.line.plantName,
      customPlantName: custom ? _name.text.trim() : null,
      scientificName: custom ? _botanical.text.trim() : null,
      variety: _variety.text,
      sizeDescription: _size.text,
      grade: _grade.text,
      notes: _notes.text,
      quantity: qty,
    ),);
  }

  @override
  Widget build(BuildContext context) {
    final custom = widget.line.isCustom;
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Text(custom ? 'Plant not in the list' : widget.line.displayName, style: AppTypography.h3),
          if (custom) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Write it the way you and the nursery know it. GreenRoot keeps your name exactly as written.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _name,
              label: 'Plant name',
              hint: 'e.g. Nela vemu, Banginapalli mango',
              textCapitalization: TextCapitalization.words,
              errorText: _tried && _name.text.trim().length < 2 ? 'Enter the plant name' : null,
              onChanged: (_) => _tried ? setState(() {}) : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _botanical, label: 'Botanical name (optional)', hint: 'If you know it'),
          ],
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _qtyCtrl,
            label: 'Quantity',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            errorText: _tried && qty <= 0 ? 'Enter how many you need' : null,
            onChanged: (_) => _tried ? setState(() {}) : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: _variety, label: 'Variety (optional)', hint: 'e.g. grafted, dwarf'),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: _size, label: 'Plant size (optional)', hint: 'e.g. 2 ft, 6 inch bag'),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: _grade, label: 'Grade (optional)', hint: 'e.g. A'),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: _notes, label: 'Notes (optional)', maxLines: 2),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Save', onPressed: _done),
        ],
      ),
    );
  }
}

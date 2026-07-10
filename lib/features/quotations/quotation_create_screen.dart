import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../plants/plants.dart';
import '../owner/owner_members_screen.dart' show NurseryManager;
import 'quotations.dart';

// ── Quotation type enum ────────────────────────────────────────────────────────

enum QuotationTypeChoice { internal, customer }

// ── Item row data model ────────────────────────────────────────────────────────

class _ItemRow {
  int? plantId;
  String plantName = '';
  final TextEditingController qtyCtrl   = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController descCtrl  = TextEditingController();

  _ItemRow();

  _ItemRow.fromItem(QuotationItem item) {
    plantId   = item.plantId;
    plantName = item.commonName?.isNotEmpty == true ? item.commonName! : item.scientificName;
    qtyCtrl.text   = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString();
    priceCtrl.text = item.unitPrice % 1 == 0 ? item.unitPrice.toInt().toString() : item.unitPrice.toString();
    descCtrl.text  = item.description ?? '';
  }

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
    descCtrl.dispose();
  }

  double get lineTotal =>
      (double.tryParse(qtyCtrl.text) ?? 0) * (double.tryParse(priceCtrl.text) ?? 0);
}

// ── Type-selection dialog ──────────────────────────────────────────────────────

Future<QuotationTypeChoice?> showQuotationTypeDialog(BuildContext context) {
  return showDialog<QuotationTypeChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('What would you like to create?', style: AppTypography.h4),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TypeOption(
            icon: Icons.folder_outlined,
            iconColor: AppColors.textSecondary,
            title: 'Internal Quotation',
            subtitle: 'For planning only — no customer needed',
            onTap: () => Navigator.pop(ctx, QuotationTypeChoice.internal),
          ),
          const Divider(height: 1, color: AppColors.border),
          _TypeOption(
            icon: Icons.request_quote_outlined,
            iconColor: AppColors.primaryMain,
            title: 'Quotation',
            subtitle: 'Prepare and share with customer',
            onTap: () => Navigator.pop(ctx, QuotationTypeChoice.customer),
          ),

        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: Text('Cancel', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
        ),
      ],
    ),
  );
}

class _TypeOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TypeOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.label),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class QuotationCreateScreen extends ConsumerStatefulWidget {
  /// null = create mode. If non-null, the type is fixed by the existing quotation.
  final Quotation? quotation;
  /// Pre-selected type (used when navigating from selling screen FAB).
  final String? initialType;

  const QuotationCreateScreen({super.key, this.quotation, this.initialType});

  @override
  ConsumerState<QuotationCreateScreen> createState() => _QuotationCreateScreenState();
}

class _QuotationCreateScreenState extends ConsumerState<QuotationCreateScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();

  late List<_ItemRow> _items;
  bool _saving = false;
  String? _error;
  NurseryManager? _assignedManager; // owner-only pre-assignment
  DateTime? _validUntil;

  // Type is determined once (from quotation, initialType, or dialog)
  String? _quotationType; // 'INTERNAL' or 'CUSTOMER'

  bool get _isEdit   => widget.quotation != null;
  bool get _isInternal => _quotationType == 'INTERNAL';

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final q = widget.quotation!;
      _quotationType = q.quotationType;
      _nameCtrl.text   = q.recipientName ?? '';
      _mobileCtrl.text = q.recipientMobile ?? '';
      _notesCtrl.text  = q.notes ?? '';
      _validUntil      = q.validUntil;
      _items = q.items.map(_ItemRow.fromItem).toList();
      if (_items.isEmpty) _items = [_ItemRow()];
    } else {
      _quotationType = widget.initialType; // may be null → dialog shown in didChangeDependencies
      _items = [_ItemRow()];
    }
    for (final row in _items) {
      row.qtyCtrl.addListener(_onChanged);
      row.priceCtrl.addListener(_onChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Show type dialog once if type is not yet determined
    if (!_isEdit && _quotationType == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickType());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _notesCtrl.dispose();
    _scrollCtrl.dispose();
    for (final row in _items) {
      row.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _pickType() async {
    if (!mounted) return;
    final choice = await showQuotationTypeDialog(context);
    if (!mounted) return;

    if (choice == null) {
      // User cancelled — go back
      context.pop();
      return;
    }

    setState(() {
      _quotationType = choice == QuotationTypeChoice.internal ? 'INTERNAL' : 'CUSTOMER';
    });
  }

  void _addItem() {
    final row = _ItemRow();
    row.qtyCtrl.addListener(_onChanged);
    row.priceCtrl.addListener(_onChanged);
    setState(() => _items.add(row));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _removeItem(int index) {
    if (_items.length == 1) return;
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  double get _grandTotal => _items.fold(0.0, (s, r) => s + r.lineTotal);

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].plantId == null) {
        setState(() => _error = 'Select a plant for item ${i + 1}');
        return;
      }
    }

    final session = ref.read(sessionProvider);
    final nurseryId = session.nurseryId;
    final isOwner = session.capabilities.isNurseryOwner;
    setState(() => _saving = true);

    try {
      final itemRequests = _items.map((r) => QuotationItemRequest(
        plantId:    r.plantId!,
        description: r.descCtrl.text.trim().isEmpty ? null : r.descCtrl.text.trim(),
        quantity:   double.parse(r.qtyCtrl.text.trim()),
        unitPrice:  double.parse(r.priceCtrl.text.trim()),
        totalPrice: r.lineTotal,
      )).toList();

      final repo = ref.read(quotationRepositoryProvider);

      if (_isEdit) {
        await repo.updateQuotation(
          id:              widget.quotation!.id,
          recipientName:   _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          recipientMobile: _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
          notes:           _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          validUntil:      _validUntil,
          items:           itemRequests,
        );
      } else {
        await repo.createQuotation(
          quotationType:         _quotationType ?? 'CUSTOMER',
          nurseryId:             nurseryId,
          assignedManagerUserId: isOwner ? _assignedManager?.userId : null,
          recipientName:         _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          recipientMobile:       _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
          notes:                 _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          validUntil:            _validUntil,
          items:                 itemRequests,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Quotation updated' : 'Quotation created'),
          backgroundColor: AppColors.primaryMain,
        ));
        Navigator.of(context).pop(true);
      }
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // While waiting for type selection dialog, show loading
    if (_quotationType == null && !_isEdit) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('New Quotation'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primaryMain)),
      );
    }

    final typeLabel = _isInternal ? 'Internal Quotation' : 'Quotation';
    final title = _isEdit ? 'Edit Quotation' : typeLabel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryMain))
                : Text('Save', style: AppTypography.body.copyWith(color: AppColors.primaryMain, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  // Error
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.red100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.red600),
                      ),
                      child: Text(_error!, style: AppTypography.bodySmall.copyWith(color: AppColors.red600)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Customer section — only for CUSTOMER type
                  if (!_isInternal) ...[
                    Text(
                      'Customer',
                      style: AppTypography.label.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Required for customer quotations',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: _inputDec('Customer Name'),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final mobile = _mobileCtrl.text.trim();
                            if ((v == null || v.trim().isEmpty) && mobile.isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextFormField(
                          controller: _mobileCtrl,
                          decoration: _inputDec('Mobile'),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Items header
                  Row(children: [
                    Text('Items', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _addItem,
                      child: Row(children: [
                        const Icon(Icons.add_circle_outline, color: AppColors.primaryMain, size: 18),
                        const SizedBox(width: 4),
                        Text('Add Item', style: AppTypography.bodySmall.copyWith(color: AppColors.primaryMain, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.sm),

                  // Items
                  ..._items.asMap().entries.map((e) => _ItemCard(
                    key: ValueKey(e.key),
                    row: e.value,
                    index: e.key,
                    total: _items.length,
                    onRemove: () => _removeItem(e.key),
                    onChanged: _onChanged,
                    onPlantSelected: (id, name) {
                      setState(() {
                        e.value.plantId   = id;
                        e.value.plantName = name;
                      });
                    },
                  )),

                  const SizedBox(height: AppSpacing.sm),
                  const Divider(color: AppColors.border),

                  // Notes
                  const SizedBox(height: AppSpacing.md),
                  Text('Notes', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: _inputDec('Add notes...'),
                    maxLines: 3,
                    minLines: 2,
                  ),

                  // Valid Until
                  const SizedBox(height: AppSpacing.md),
                  Text('Valid Until', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('Optional — defaults to 15 days after approval',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _validUntil ?? now.add(const Duration(days: 15)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _validUntil = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _validUntil != null
                                ? '${_validUntil!.day} ${_monthName(_validUntil!.month)} ${_validUntil!.year}'
                                : 'Pick a date…',
                            style: AppTypography.body.copyWith(
                              color: _validUntil != null ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                          ),
                        ),
                        if (_validUntil != null)
                          GestureDetector(
                            onTap: () => setState(() => _validUntil = null),
                            child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                          ),
                      ]),
                    ),
                  ),

                  // Owner-only: optional manager assignment on create
                  if (!_isEdit) ...[
                    Builder(builder: (context) {
                      final isOwner = ref.watch(sessionProvider).capabilities.isNurseryOwner;
                      final nurseryId = ref.watch(sessionProvider).nurseryId;
                      if (!isOwner || nurseryId == null) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          Text('Assign to Manager', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text('Optional — leave blank to keep private', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                          const SizedBox(height: AppSpacing.sm),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showModalBottomSheet<NurseryManager>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: AppColors.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                builder: (_) => _ManagerPickerSheetCreate(nurseryId: nurseryId),
                              );
                              if (picked != null) setState(() => _assignedManager = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _assignedManager != null ? AppColors.primaryMain : AppColors.border,
                                ),
                              ),
                              child: Row(children: [
                                Icon(
                                  _assignedManager != null ? Icons.person_rounded : Icons.person_add_outlined,
                                  size: 18,
                                  color: _assignedManager != null ? AppColors.primaryMain : AppColors.textMuted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _assignedManager != null
                                        ? (_assignedManager!.name ?? 'Manager')
                                        : 'Select manager...',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: _assignedManager != null ? AppColors.textPrimary : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                if (_assignedManager != null)
                                  GestureDetector(
                                    onTap: () => setState(() => _assignedManager = null),
                                    child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                                  )
                                else
                                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                              ]),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],

                  const SizedBox(height: AppSpacing.x3l),
                ],
              ),
            ),

            // Fixed footer: total + save
            Container(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(children: [
                Text('₹${_grandTotal.toStringAsFixed(2)}',
                    style: AppTypography.h3.copyWith(color: AppColors.primaryMain)),
                const Spacer(),
                SizedBox(
                  width: 130,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMain,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isEdit ? 'Update' : 'Save Draft',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][m];

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryMain, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.red600)),
  );
}

// ── Type badge ─────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final bool isInternal;
  const _TypeBadge({required this.isInternal});

  @override
  Widget build(BuildContext context) {
    final color = isInternal ? AppColors.textSecondary : AppColors.primaryMain;
    final bg    = isInternal ? AppColors.border : AppColors.forest100;
    final label = isInternal ? 'Internal Quotation' : 'Quotation';
    final icon  = isInternal ? Icons.folder_outlined : Icons.request_quote_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Caution banner ─────────────────────────────────────────────────────────────

class _CautionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Note: GreenRoot does not set or verify any price rates. '
            'All prices shown are as entered by the owner/user.',
            style: AppTypography.caption.copyWith(color: const Color(0xFF92400E)),
          ),
        ),
      ]),
    );
  }
}

// ── Item card ──────────────────────────────────────────────────────────────────

class _ItemCard extends ConsumerStatefulWidget {
  final _ItemRow row;
  final int index;
  final int total;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final void Function(int plantId, String plantName) onPlantSelected;

  const _ItemCard({
    super.key,
    required this.row,
    required this.index,
    required this.total,
    required this.onRemove,
    required this.onChanged,
    required this.onPlantSelected,
  });

  @override
  ConsumerState<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends ConsumerState<_ItemCard> {
  final _searchCtrl = TextEditingController();
  List<Plant> _results = [];
  bool _searching  = false;
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    if (widget.row.plantId != null) {
      _searchCtrl.text = widget.row.plantName;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() { _results = []; _showDropdown = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      final (results, _) = await ref.read(plantRepositoryProvider)
          .listPlants(search: q, page: 1, perPage: 10);
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

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
    filled: true,
    fillColor: AppColors.background,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: AppColors.primaryMain, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    final row        = widget.row;
    final isSelected = row.plantId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSelected ? AppColors.primaryMain.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item header row
          Row(children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: AppColors.forest100, borderRadius: BorderRadius.circular(4)),
              child: Center(
                child: Text('${widget.index + 1}',
                    style: AppTypography.caption.copyWith(color: AppColors.primaryMain, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 6),
            if (isSelected) ...[
              Expanded(
                child: Text(row.plantName,
                    style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.primaryMain),
                    overflow: TextOverflow.ellipsis),
              ),
              GestureDetector(
                onTap: () {
                  setState(() { _searchCtrl.clear(); _showDropdown = false; });
                  row.plantId   = null;
                  row.plantName = '';
                  widget.onChanged();
                },
                child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
              ),
            ] else
              Expanded(child: Text('Select plant', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted))),
            const SizedBox(width: 6),
            if (widget.total > 1)
              GestureDetector(
                onTap: widget.onRemove,
                child: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.red600),
              ),
          ]),

          // Plant search
          if (!isSelected) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _searchCtrl,
              decoration: _dec('Search plant name...').copyWith(
                suffixIcon: _searching
                    ? const Padding(padding: EdgeInsets.all(8),
                        child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryMain)))
                    : const Icon(Icons.search, size: 16, color: AppColors.textMuted),
              ),
              style: AppTypography.bodySmall,
              onChanged: (val) {
                Future.delayed(const Duration(milliseconds: 350), () {
                  if (mounted && _searchCtrl.text == val) _search(val);
                });
              },
            ),
            if (_showDropdown)
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (_, i) {
                    final plant = _results[i];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(plant.scientificName, style: AppTypography.bodySmall),
                      subtitle: plant.commonName != null
                          ? Text(plant.commonName!, style: AppTypography.caption.copyWith(color: AppColors.textMuted))
                          : null,
                      onTap: () {
                        final name = plant.commonName?.isNotEmpty == true ? plant.commonName! : plant.scientificName;
                        _searchCtrl.text = name;
                        setState(() { _showDropdown = false; _results = []; });
                        widget.onPlantSelected(plant.id, name);
                      },
                    );
                  },
                ),
              ),
          ],

          // Qty + Price row
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: row.qtyCtrl,
                decoration: _dec('Qty'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                style: AppTypography.bodySmall,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if ((double.tryParse(v) ?? 0) <= 0) return '>0';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextFormField(
                controller: row.priceCtrl,
                decoration: _dec('Unit Price ₹'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                style: AppTypography.bodySmall,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if ((double.tryParse(v) ?? -1) < 0) return '≥0';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 80,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '₹${row.lineTotal.toStringAsFixed(0)}',
                style: AppTypography.bodySmall.copyWith(color: AppColors.primaryMain, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
          ]),

          // Description
          const SizedBox(height: 6),
          TextField(
            controller: row.descCtrl,
            decoration: _dec('Description (optional)'),
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

// ── Manager picker bottom sheet ────────────────────────────────────────────────

class _ManagerPickerSheetCreate extends StatefulWidget {
  final int nurseryId;
  const _ManagerPickerSheetCreate({required this.nurseryId});

  @override
  State<_ManagerPickerSheetCreate> createState() => _ManagerPickerSheetCreateState();
}

class _ManagerPickerSheetCreateState extends State<_ManagerPickerSheetCreate> {
  List<NurseryManager>? _managers;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final managers = await ApiClient.instance.get<List<NurseryManager>>(
        ApiConstants.nurseryManagers(widget.nurseryId),
        fromJson: (json) {
          final map = json as Map<String, dynamic>;
          final list = map['managers'] as List<dynamic>? ??
              map['users'] as List<dynamic>? ??
              [];
          return list
              .cast<Map<String, dynamic>>()
              .map(NurseryManager.fromJson)
              .toList();
        },
      );
      if (mounted) setState(() { _managers = managers; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 16, AppSpacing.screenPadding, 8),
            child: Row(children: [
              Expanded(child: Text('Assign Manager', style: AppTypography.h3)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryMain))
                : _error != null
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Failed to load managers',
                            style: AppTypography.body.copyWith(color: AppColors.red600)),
                        TextButton(
                            onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
                            child: const Text('Retry')),
                      ]))
                    : _managers == null || _managers!.isEmpty
                        ? Center(child: Text('No managers in this nursery',
                              style: AppTypography.body.copyWith(color: AppColors.textMuted)))
                        : ListView.separated(
                            controller: ctrl,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
                            itemCount: _managers!.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                            itemBuilder: (_, i) {
                              final m = _managers![i];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.forest100,
                                  child: Text(
                                      (m.name?.isNotEmpty == true) ? m.name![0].toUpperCase() : '?',
                                      style: AppTypography.body.copyWith(
                                          color: AppColors.primaryMain, fontWeight: FontWeight.w700)),
                                ),
                                title: Text(m.name ?? 'Manager', style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                                subtitle: Text(m.mobile ?? '', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                                trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                                onTap: () => Navigator.pop(context, m),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

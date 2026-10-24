part of '../local_market_screen.dart';

class _PostWantScreen extends ConsumerStatefulWidget {
  final MarketAd? editing;
  const _PostWantScreen({this.editing});

  @override
  ConsumerState<_PostWantScreen> createState() => _PostWantScreenState();
}

class _PostWantScreenState extends ConsumerState<_PostWantScreen> {
  int? _plantId;
  String? _plantName;
  String? _size;
  DateTime? _neededBy;
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ad = widget.editing;
    if (ad != null) {
      _plantId = ad.plantId;
      _plantName = ad.plantName;
      _size = ad.sizeDescription;
      _neededBy = ad.neededBy;
      _qtyCtrl.text = ad.quantity?.toString() ?? '';
      _noteCtrl.text = ad.description ?? '';
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _mkTextPrimary,
          ),
        ),
      );

  bool get _valid =>
      _plantId != null &&
      _size != null &&
      (_qtyCtrl.text.trim().isEmpty ||
          (int.tryParse(_qtyCtrl.text.trim()) ?? 0) > 0);

  String? get _dateParam => _neededBy == null
      ? null
      : '${_neededBy!.year}-${_neededBy!.month.toString().padLeft(2, '0')}-${_neededBy!.day.toString().padLeft(2, '0')}';

  void _pickPlant() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PlantPickerSheet(
        title: 'Which plant do you need?',
        onSelected: (plant) {
          Navigator.of(sheetContext).pop();
          setState(() {
            _plantId = plant.id;
            _plantName = plant.displayName;
          });
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _neededBy ?? now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Needed by',
    );
    if (picked != null) setState(() => _neededBy = picked);
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final qty = int.tryParse(_qtyCtrl.text.trim());
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    try {
      final post = ref.read(postAdProvider.notifier);
      if (widget.editing != null) {
        await post.update(
          widget.editing!.id,
          sizeDescription: _size,
          quantity: qty,
          description: note,
          neededBy: _dateParam ?? '',
        );
      } else {
        final id = await post.create(
          extra: await _gpsPickup(ref),
          adType: 'WANT',
          neededBy: _dateParam,
          plantId: _plantId,
          plantName: _plantName!,
          title: 'Wanted: ${_plantName!}',
          sizeDescription: _size,
          quantity: qty,
          description: note,
        );
        // A want goes live at once: there is no draft step for a request.
        await ref.read(adActionProvider.notifier).perform(id, 'publish');
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.editing != null
                ? 'Wanted post updated'
                : 'Posted. Nurseries that have it can now reply.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: _stExpired,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = ref.watch(plantSizesProvider);
    final editing = widget.editing != null;
    return Scaffold(
      backgroundColor: _mkBg,
      appBar: AppBar(
        title: Text(editing ? 'Edit wanted post' : 'Plants I Want'),
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tell nurseries what you are looking for. No price here: '
            'nurseries that have it reply and offer a price in the chat.',
            style: AppTypography.bodySmall.copyWith(color: _mkTextSecondary),
          ),
          const SizedBox(height: 18),
          _label('Plant *'),
          InkWell(
            onTap: editing ? null : _pickPlant,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: _inputDec('Search plants, e.g. Neem, Rose...').copyWith(
                suffixIcon: editing ? null : const Icon(Icons.search_rounded),
              ),
              isEmpty: _plantName == null,
              child: _plantName == null
                  ? null
                  : Text(_plantName!, style: AppTypography.body),
            ),
          ),
          const SizedBox(height: 16),
          _label('Size *'),
          sizes.when(
            loading: () => const LinearProgressIndicator(color: _mkGreen),
            error: (e, _) => Text(e.toString(), style: const TextStyle(color: _stExpired)),
            data: (list) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final PlantSize size in list)
                  ChoiceChip(
                    label: Text(size.displayName),
                    selected: _size == size.displayName,
                    onSelected: (_) => setState(() => _size = size.displayName),
                    selectedColor: _mkGreen,
                    labelStyle: TextStyle(
                      color: _size == size.displayName ? Colors.white : _mkTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    showCheckmark: false,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _label('How many (optional)'),
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: NumberInput.whole,
            decoration: _inputDec('e.g. 300'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _label('Needed by (optional)'),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: _inputDec('Pick a date').copyWith(
                suffixIcon: _neededBy == null
                    ? const Icon(Icons.event_outlined)
                    : IconButton(
                        tooltip: 'Clear date',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _neededBy = null),
                      ),
              ),
              isEmpty: _neededBy == null,
              child: _neededBy == null
                  ? null
                  : Text(_shortDate(_neededBy!), style: AppTypography.body),
            ),
          ),
          const SizedBox(height: 16),
          _label('Note (optional)'),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: _inputDec('e.g. For a highway project, need healthy stock'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _mkGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _valid && !_saving ? _submit : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      editing ? 'Save' : 'Post',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 6. POST AD SCREEN (multi-step wizard)
// ══════════════════════════════════════════════════════════════════════════════

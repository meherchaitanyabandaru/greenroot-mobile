part of '../local_market_screen.dart';

class _PostAdScreen extends ConsumerStatefulWidget {
  final MarketAd? editingAd;
  const _PostAdScreen({this.editingAd});

  @override
  ConsumerState<_PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends ConsumerState<_PostAdScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  // Form fields
  final _plantCtrl = TextEditingController();
  int? _plantId;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();

  final List<XFile> _pickedFiles = [];
  List<String> _existingPhotos = [];
  String? _selectedCategory;

  // Pickup & access: road and truck are asked separately (a road may be too
  // narrow for a truck); null until the seller answers.
  bool? _road;
  bool? _truck;
  final _pickupCtrl = TextEditingController();
  final _accessCtrl = TextEditingController();
  bool _saving = false;
  bool _publishing = false;
  // Draft created by an earlier Save/Publish attempt on this screen: a retry
  // updates it instead of creating a duplicate ad each time.
  int? _createdAdId;

  static const _categories = [
    'Fruit Plants',
    'Flower Plants',
    'Forest Plants',
    'Ornamentals',
  ];

  @override
  void initState() {
    super.initState();
    _plantCtrl.addListener(_onRequiredFieldChanged);
    _titleCtrl.addListener(_onRequiredFieldChanged);
    final ad = widget.editingAd;
    if (ad != null) {
      _plantCtrl.text = ad.plantName;
      _plantId = ad.plantId;
      _titleCtrl.text = ad.title;
      _descCtrl.text = ad.description ?? '';
      _qtyCtrl.text = ad.quantity?.toString() ?? '';
      _priceCtrl.text = ad.pricePerUnit?.toStringAsFixed(0) ?? '';
      _sizeCtrl.text = ad.sizeDescription ?? '';
      _existingPhotos = List<String>.from(ad.photos);
      _selectedCategory = ad.categoryName;
      _road = ad.roadAccessible;
      _truck = ad.truckAccessible;
      _pickupCtrl.text = ad.pickupPoint ?? '';
      _accessCtrl.text = ad.accessInstructions ?? '';
    }
    _pickupCtrl.addListener(_onRequiredFieldChanged);
  }

  void _onRequiredFieldChanged() => setState(() {});

  @override
  void dispose() {
    _plantCtrl.removeListener(_onRequiredFieldChanged);
    _titleCtrl.removeListener(_onRequiredFieldChanged);
    _pickupCtrl.removeListener(_onRequiredFieldChanged);
    _pickupCtrl.dispose();
    _accessCtrl.dispose();
    _pageCtrl.dispose();
    _plantCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _sizeCtrl.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool get _step1Valid =>
      _titleCtrl.text.trim().isNotEmpty && _plantCtrl.text.trim().isNotEmpty;

  /// What still blocks the photos & pickup step, or null when it is complete.
  String? get _accessError {
    if (_road == null) return 'Tell buyers if a road reaches your plants';
    if (_truck == null) return 'Tell buyers if a truck can reach your plants';
    if (_road == false && _pickupCtrl.text.trim().isEmpty) {
      return 'No road: add a pickup point buyers can reach';
    }
    return null;
  }

  Map<String, dynamic> get _accessJson => {
        'road_accessible': _road,
        'truck_accessible': _truck,
        'pickup_landmark': _pickupCtrl.text.trim(),
        'access_instructions': _accessCtrl.text.trim(),
      };

  void _pickPlant() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PlantPickerSheet(
        title: 'Which plant are you selling?',
        onSelected: (plant) {
          Navigator.of(sheetContext).pop();
          setState(() {
            _plantId = plant.id;
            _plantCtrl.text = plant.displayName;
            if (_titleCtrl.text.trim().isEmpty) {
              _titleCtrl.text = plant.displayName;
            }
          });
        },
      ),
    );
  }

  String get _effectivePlantName {
    final p = _plantCtrl.text.trim();
    return p.isNotEmpty ? p : _titleCtrl.text.trim();
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      final uploaded = await _uploadNew();
      final photos = [..._existingPhotos, ...uploaded];
      final plantName = _effectivePlantName;
      final existingId = widget.editingAd?.id ?? _createdAdId;
      if (existingId != null) {
        await ref.read(postAdProvider.notifier).update(
              existingId,
              plantId: _plantId,
              plantName: plantName.isNotEmpty ? plantName : null,
              title: _titleCtrl.text.trim(),
              categoryName: _selectedCategory,
              description:
                  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              quantity: int.tryParse(_qtyCtrl.text.trim()),
              pricePerUnit: double.tryParse(_priceCtrl.text.trim()),
              sizeDescription:
                  _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
              photos: photos,
              extra: widget.editingAd != null
                  ? _accessJson
                  : {..._accessJson, ...await _gpsPickup(ref)},
            );
      } else {
        _createdAdId = await ref.read(postAdProvider.notifier).create(
              plantId: _plantId,
              plantName: plantName,
              title: _titleCtrl.text.trim(),
              categoryName: _selectedCategory,
              description:
                  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              quantity: int.tryParse(_qtyCtrl.text.trim()),
              pricePerUnit: double.tryParse(_priceCtrl.text.trim()),
              sizeDescription:
                  _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
              photos: photos,
              extra: {..._accessJson, ...await _gpsPickup(ref)},
            );
      }
      if (mounted) Navigator.of(context).pop();
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

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      final uploaded = await _uploadNew();
      final photos = [..._existingPhotos, ...uploaded];
      int adId;
      final plantName = _effectivePlantName;
      final existingId = widget.editingAd?.id ?? _createdAdId;
      if (existingId != null) {
        await ref.read(postAdProvider.notifier).update(
              existingId,
              plantId: _plantId,
              plantName: plantName.isNotEmpty ? plantName : null,
              title: _titleCtrl.text.trim(),
              categoryName: _selectedCategory,
              description:
                  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              quantity: int.tryParse(_qtyCtrl.text.trim()),
              pricePerUnit: double.tryParse(_priceCtrl.text.trim()),
              sizeDescription:
                  _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
              photos: photos,
              extra: widget.editingAd != null
                  ? _accessJson
                  : {..._accessJson, ...await _gpsPickup(ref)},
            );
        adId = existingId;
      } else {
        adId = _createdAdId = await ref.read(postAdProvider.notifier).create(
              plantId: _plantId,
              plantName: plantName,
              title: _titleCtrl.text.trim(),
              categoryName: _selectedCategory,
              description:
                  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              quantity: int.tryParse(_qtyCtrl.text.trim()),
              pricePerUnit: double.tryParse(_priceCtrl.text.trim()),
              sizeDescription:
                  _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
              photos: photos,
              extra: {..._accessJson, ...await _gpsPickup(ref)},
            );
      }
      // Only publish if the ad is in DRAFT state (already-live ads just need the update)
      final currentStatus = widget.editingAd?.status;
      final needsPublish = currentStatus == null ||
          currentStatus == 'DRAFT' ||
          currentStatus == 'PAUSED';
      if (needsPublish) {
        await ref.read(adActionProvider.notifier).perform(adId, 'publish');
      }
      if (mounted) Navigator.of(context).pop();
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
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<List<String>> _uploadNew() async {
    final results = <String>[];
    for (final f in _pickedFiles) {
      final url = await uploadAdPhoto(f, ref.read(marketRepositoryProvider));
      results.add(url);
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mkBg,
      appBar: AppBar(
        title: Text(widget.editingAd != null ? 'Edit Ad' : 'Plants I Have'),
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: List.generate(3, (i) {
                    final done = i < _step;
                    final active = i == _step;
                    return Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: done || active ? _mkGreen : _mkBorder,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          if (i < 2) const SizedBox(width: 6),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _stepLabel(0, 'Details'),
                    _stepLabel(1, 'Photos & pickup'),
                    _stepLabel(2, 'Preview'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _DetailsStep(
            onPickPlant: _pickPlant,
            plantCtrl: _plantCtrl,
            titleCtrl: _titleCtrl,
            descCtrl: _descCtrl,
            qtyCtrl: _qtyCtrl,
            priceCtrl: _priceCtrl,
            sizeCtrl: _sizeCtrl,
            selectedCategory: _selectedCategory,
            categories: _categories,
            onCategoryChanged: (c) => setState(() => _selectedCategory = c),
          ),
          _PhotosStep(
            existingPhotos: _existingPhotos,
            pickedFiles: _pickedFiles,
            onExistingRemoved: (url) =>
                setState(() => _existingPhotos.remove(url)),
            onNewPicked: (files) => setState(() => _pickedFiles.addAll(files)),
            onNewRemoved: (f) => setState(() => _pickedFiles.remove(f)),
            onReplace: (old, file) => setState(() {
              if (old is XFile) {
                _pickedFiles[_pickedFiles.indexOf(old)] = file;
              } else {
                _existingPhotos.remove(old);
                _pickedFiles.insert(0, file);
              }
            }),
            pickup: _PickupAccessForm(
              road: _road,
              truck: _truck,
              pickupCtrl: _pickupCtrl,
              instructionsCtrl: _accessCtrl,
              error: _accessError,
              onRoad: (v) => setState(() {
                _road = v;
                if (!v) _truck = false; // a truck needs a road
              }),
              onTruck: (v) => setState(() => _truck = v),
            ),
          ),
          _PreviewStep(
            plantCtrl: _plantCtrl,
            titleCtrl: _titleCtrl,
            descCtrl: _descCtrl,
            qtyCtrl: _qtyCtrl,
            priceCtrl: _priceCtrl,
            sizeCtrl: _sizeCtrl,
            existingPhotos: _existingPhotos,
            pickedFiles: _pickedFiles,
            access: _AccessInfo(
              road: _road,
              truck: _truck,
              pickupPoint: _pickupCtrl.text.trim(),
              instructions: _accessCtrl.text.trim(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: _mkCard,
            border: Border(top: BorderSide(color: _mkBorder)),
          ),
          child: Row(
            children: [
              if (_step > 0)
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _mkTextSecondary,
                      side: const BorderSide(color: _mkBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        _saving || _publishing ? null : () => _goTo(_step - 1),
                    child: const Text(
                      'Back',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              if (_step == 2) ...[
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _mkGreen,
                      side: const BorderSide(color: _mkGreen),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saving || _publishing ? null : _saveDraft,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _mkGreen,
                            ),
                          )
                        : const Text(
                            'Save Draft',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mkGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saving || _publishing ? null : _publish,
                    child: _publishing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.editingAd?.status == 'PUBLISHED' ||
                                    widget.editingAd?.status == 'PAUSED'
                                ? 'Save Changes'
                                : 'Publish',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ] else
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mkGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: (_step == 0 && !_step1Valid) ||
                            (_step == 1 && _accessError != null)
                        ? null
                        : () => _goTo(_step + 1),
                    child: const Text(
                      'Next',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepLabel(int i, String label) {
    final active = _step == i;
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        color: active ? _mkGreen : _mkTextSecondary,
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  final TextEditingController plantCtrl,
      titleCtrl,
      descCtrl,
      qtyCtrl,
      priceCtrl,
      sizeCtrl;
  final String? selectedCategory;
  final List<String> categories;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onPickPlant;

  const _DetailsStep({
    required this.onPickPlant,
    required this.plantCtrl,
    required this.titleCtrl,
    required this.descCtrl,
    required this.qtyCtrl,
    required this.priceCtrl,
    required this.sizeCtrl,
    required this.selectedCategory,
    required this.categories,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Plant first: picking it fills the title. Then what buyers compare:
    // quantity, price, size. Category and description are extras.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _label('Plant *'),
        TextField(
          controller: plantCtrl,
          readOnly: true,
          onTap: onPickPlant,
          decoration: _inputDec('Search plants, e.g. Mango, Rose...').copyWith(
            suffixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 14),
        _label('Ad title *'),
        TextField(
          controller: titleCtrl,
          maxLength: 120,
          decoration: _inputDec('e.g. Grafted mango saplings, 2 ft'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Quantity available'),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: NumberInput.whole,
                    decoration: _inputDec('e.g. 50'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Price per plant (₹)'),
                  TextField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: NumberInput.money,
                    decoration: _inputDec('Leave empty: on request'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _label('Size'),
        _SizeChips(controller: sizeCtrl),
        const SizedBox(height: 14),
        _label('Category'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...categories.map((c) {
              final sel = selectedCategory == c;
              return ChoiceChip(
                label: Text(
                  c,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : _mkTextSecondary,
                  ),
                ),
                selected: sel,
                onSelected: (_) => onCategoryChanged(sel ? null : c),
                selectedColor: _mkGreen,
                backgroundColor: _mkCard,
                side: BorderSide(color: sel ? _mkGreen : _mkBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                showCheckmark: false,
              );
            }),
          ],
        ),
        const SizedBox(height: 14),
        _label('Description'),
        TextField(
          controller: descCtrl,
          maxLines: 4,
          maxLength: 500,
          decoration: _inputDec(
            'Condition, age, pot size, pickup times...',
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
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
}

/// Where a new ad is: the phone's GPS when allowed (the server falls back to
/// the nursery's address). Nearby browsing needs every live ad placed.
Future<Map<String, dynamic>> _gpsPickup(WidgetRef ref) async {
  var pos = await ref.read(marketPositionProvider.future);
  if (pos == null) {
    // The cached "no position" may predate the user turning location on:
    // ask again now rather than posting (and failing) without a location.
    ref.invalidate(marketPositionProvider);
    pos = await ref.read(marketPositionProvider.future);
  }
  if (pos == null) return const {};
  return {
    'pickup_latitude': pos.latitude,
    'pickup_longitude': pos.longitude,
    'pickup_gps_accuracy_meters': pos.accuracy,
    'pickup_location_source': 'gps_confirmed',
  };
}

/// The catalog sizes as chips, writing the chosen name into [controller]
/// (the same sizes wanted posts use, so buyers and sellers match).
class _SizeChips extends ConsumerWidget {
  final TextEditingController controller;
  const _SizeChips({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(plantSizesProvider).when(
          loading: () => const LinearProgressIndicator(color: _mkGreen),
          // No free-text fallback: a typed "44" has no unit buyers can read.
          error: (_, __) => TextButton.icon(
            onPressed: () => ref.invalidate(plantSizesProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Could not load sizes. Tap to retry'),
          ),
          data: (sizes) => ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final size in sizes)
                  ChoiceChip(
                    label: Text(size.displayName),
                    selected: value.text == size.displayName,
                    onSelected: (on) =>
                        controller.text = on ? size.displayName : '',
                    selectedColor: _mkGreen,
                    labelStyle: TextStyle(
                      color: value.text == size.displayName
                          ? Colors.white
                          : _mkTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    showCheckmark: false,
                  ),
              ],
            ),
          ),
        );
  }
}

const _maxAdPhotos = 3;

/// Asks camera or gallery, then picks up to [count] photos (the camera takes
/// one). Shrinks at pick time: less memory and a faster preview; uploads are
/// resized again to 1200px.
Future<List<XFile>> _pickAdPhotos(BuildContext context, int count) async {
  if (count <= 0) return const [];
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: _mkCard,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: _mkGreen),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(sheet, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: _mkGreen),
            title: Text(count == 1 ? 'Choose from gallery' : 'Choose from gallery (up to $count)'),
            onTap: () => Navigator.pop(sheet, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return const [];
  if (!context.mounted) return const [];
  // The phone shrinks to 1600px at pick time (less memory, faster preview);
  // uploads are resized again to 1200px with the watermark.
  if (source == ImageSource.camera || count == 1) {
    final f = await pickPhoto(context, source, maxSide: 1600, quality: 85);
    return f == null ? const [] : [f];
  }
  return pickPhotos(context, limit: count, maxSide: 1600, quality: 85);
}

class _PhotosStep extends StatelessWidget {
  final List<String> existingPhotos;
  final List<XFile> pickedFiles;
  final void Function(String) onExistingRemoved;
  final void Function(List<XFile>) onNewPicked;
  final void Function(XFile) onNewRemoved;

  /// Swaps a photo (an existing URL or a picked file) for a new pick.
  final void Function(Object old, XFile file) onReplace;
  final Widget pickup;

  const _PhotosStep({
    required this.existingPhotos,
    required this.pickedFiles,
    required this.onExistingRemoved,
    required this.onNewPicked,
    required this.onNewRemoved,
    required this.onReplace,
    required this.pickup,
  });

  Future<void> _replace(BuildContext context, Object old) async {
    final files = await _pickAdPhotos(context, 1);
    if (files.isNotEmpty) onReplace(old, files.first);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Upload images (${existingPhotos.length + pickedFiles.length}/$_maxAdPhotos)',
          style: AppTypography.h3
              .copyWith(color: _mkTextPrimary, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Take photos or pick from your gallery, up to $_maxAdPhotos. The first is the cover. Tap a photo to replace it.',
          style: AppTypography.caption.copyWith(color: _mkTextSecondary),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            ...existingPhotos.map(
              (url) => _PhotoTile(
                onTap: () => _replace(context, url),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: _mkTextSecondary,
                  ),
                ),
                onRemove: () => onExistingRemoved(url),
              ),
            ),
            ...pickedFiles.map(
              (f) => _PhotoTile(
                onTap: () => _replace(context, f),
                child: Image.file(
                  File(f.path),
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.photo_outlined,
                    color: _mkTextSecondary,
                  ),
                ),
                onRemove: () => onNewRemoved(f),
              ),
            ),
            if (existingPhotos.length + pickedFiles.length < _maxAdPhotos)
              GestureDetector(
                onTap: () async {
                  final files = await _pickAdPhotos(
                    context,
                    _maxAdPhotos - existingPhotos.length - pickedFiles.length,
                  );
                  if (files.isNotEmpty) onNewPicked(files);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _mkBg,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: _mkBorder, style: BorderStyle.solid),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: _mkGreen,
                        size: 28,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Add Photo',
                        style: TextStyle(
                          fontSize: 10,
                          color: _mkGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        pickup,
      ],
    );
  }
}

/// "Pickup & access" questions on Plants I Have. Road and truck are separate:
/// a road may be too narrow for a truck. No road means a pickup point.
class _PickupAccessForm extends StatelessWidget {
  final bool? road;
  final bool? truck;
  final TextEditingController pickupCtrl;
  final TextEditingController instructionsCtrl;
  final String? error;
  final ValueChanged<bool> onRoad;
  final ValueChanged<bool> onTruck;

  const _PickupAccessForm({
    required this.road,
    required this.truck,
    required this.pickupCtrl,
    required this.instructionsCtrl,
    required this.error,
    required this.onRoad,
    required this.onTruck,
  });

  Widget _yesNo(String label, IconData icon, bool? value,
          ValueChanged<bool>? onChanged, {String? note,}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: _mkGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _mkTextPrimary,
                    ),
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Yes')),
                    ButtonSegment(value: false, label: Text('No')),
                  ],
                  selected: {if (value != null) value},
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  onSelectionChanged: onChanged == null
                      ? null
                      : (v) {
                          if (v.isNotEmpty) onChanged(v.first);
                        },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (st) => st.contains(WidgetState.selected)
                          ? (value == false ? _stExpiredBg : _mkLight)
                          : _mkCard,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (st) => st.contains(WidgetState.selected)
                          ? (value == false ? _stExpired : _mkDark)
                          : _mkTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Text(
                  note,
                  style: AppTypography.caption.copyWith(color: _stPaused),
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pickupRequired = road == false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pickup & road access',
          style: AppTypography.h3
              .copyWith(color: _mkTextPrimary, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Helps buyers know if they can bring a truck or must meet you somewhere.',
          style: AppTypography.caption.copyWith(color: _mkTextSecondary),
        ),
        const SizedBox(height: 16),
        _yesNo('Road to the plants?', Icons.add_road_rounded, road, onRoad),
        _yesNo(
          'Truck can reach directly?',
          Icons.local_shipping_outlined,
          truck,
          road == false ? null : onTruck,
          note: road == false
              ? 'No road, so no truck: buyers collect at the pickup point.'
              : truck == false
                  ? 'Buyers will see that a truck cannot reach your plants.'
                  : null,
        ),
        Text(
          pickupRequired ? 'Pickup point *' : 'Pickup point (optional)',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _mkTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: pickupCtrl,
          maxLength: 255,
          decoration: _inputDec('e.g. Gate on NH-44, near the banyan tree')
              .copyWith(prefixIcon: const Icon(Icons.place_outlined)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Additional instructions (optional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _mkTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: instructionsCtrl,
          maxLines: 3,
          maxLength: 500,
          decoration: _inputDec('Directions, narrow roads, best time to come...'),
        ),
        if (error != null)
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: _stExpired),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  error!,
                  style: AppTypography.caption.copyWith(color: _stExpired),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// How buyers reach a for-sale ad's plants: road, truck, pickup point, notes.
class _AccessInfo extends StatelessWidget {
  final bool? road;
  final bool? truck;
  final String? pickupPoint;
  final String? instructions;

  const _AccessInfo({
    this.road,
    this.truck,
    this.pickupPoint,
    this.instructions,
  });

  @override
  Widget build(BuildContext context) {
    final point = (pickupPoint ?? '').trim();
    final notes = (instructions ?? '').trim();
    if (road == null && truck == null && point.isEmpty && notes.isEmpty) {
      return const SizedBox.shrink();
    }
    final limited = road == false || truck == false;
    Widget row(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.body.copyWith(color: _mkTextPrimary),
                ),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Pickup & access',
              style: AppTypography.h4.copyWith(color: _mkTextPrimary),
            ),
            const Spacer(),
            if (limited)
              const _Chip('⚠ Limited access', Color(0xFFFEF3C7), Color(0xFFB45309)),
          ],
        ),
        const SizedBox(height: 10),
        if (road != null)
          road!
              ? row(Icons.add_road_rounded, _mkGreen, 'Road accessible')
              : row(Icons.block_rounded, _stExpired, 'No road to the plants'),
        if (truck != null)
          truck!
              ? row(Icons.local_shipping_rounded, _mkGreen, 'Truck accessible')
              : row(Icons.local_shipping_outlined, _stPaused,
                  'A truck cannot reach directly',),
        if (point.isNotEmpty)
          row(Icons.place_rounded, _mkGreen, 'Pickup point: $point'),
        if (notes.isNotEmpty)
          row(Icons.info_outline_rounded, _mkTextSecondary, notes),
      ],
    );
  }
}

/// Ad photos full screen: swipe between them, pinch or double-tap to zoom,
/// nothing cropped. Pops with the photo it ended on.
class _PhotoViewer extends StatefulWidget {
  final List<String> photos;
  final int initial;
  const _PhotoViewer({required this.photos, required this.initial});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _ctrl = PageController(initialPage: widget.initial);
  late int _page = widget.initial;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(_page);
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(
              '${_page + 1} / ${widget.photos.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
          ),
          body: PageView.builder(
            controller: _ctrl,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _ZoomablePhoto(url: widget.photos[i]),
          ),
        ),
      );
}

class _ZoomablePhoto extends StatefulWidget {
  final String url;
  const _ZoomablePhoto({required this.url});

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _zoom = TransformationController();

  // Dragging moves a zoomed photo; unzoomed, swipes go to the page view.
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() {
      final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
      if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        // Double-tap toggles 2.5x zoom; pinch zooms freely.
        onDoubleTap: () => _zoom.value = _zoom.value.isIdentity()
            ? (Matrix4.identity()..scaleByDouble(2.5, 2.5, 1, 1))
            : Matrix4.identity(),
        child: InteractiveViewer(
          transformationController: _zoom,
          panEnabled: _zoomed,
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const CircularProgressIndicator(color: Colors.white),
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                size: 56,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      );
}

class _PhotoTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  const _PhotoTile({
    required this.child,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.expand(child: child),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xDD000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 13,),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewStep extends StatelessWidget {
  final TextEditingController plantCtrl,
      titleCtrl,
      descCtrl,
      qtyCtrl,
      priceCtrl,
      sizeCtrl;
  final List<String> existingPhotos;
  final List<XFile> pickedFiles;
  final Widget access;

  const _PreviewStep({
    required this.access,
    required this.plantCtrl,
    required this.titleCtrl,
    required this.descCtrl,
    required this.qtyCtrl,
    required this.priceCtrl,
    required this.sizeCtrl,
    required this.existingPhotos,
    required this.pickedFiles,
  });

  @override
  Widget build(BuildContext context) {
    final allPhotos = [...existingPhotos, ...pickedFiles.map((f) => f.path)];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Preview',
          style: AppTypography.h3
              .copyWith(color: _mkTextPrimary, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'This is how your ad will look.',
          style: AppTypography.caption.copyWith(color: _mkTextSecondary),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: _mkCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _mkBorder),
            boxShadow: const [_cardShadow],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (allPhotos.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: Image(
                    image: existingPhotos.isNotEmpty
                        ? NetworkImage(allPhotos.first)
                        : FileImage(File(allPhotos.first)) as ImageProvider,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _mkLight,
                      child: const Icon(
                        Icons.local_florist_outlined,
                        size: 56,
                        color: _mkGreen,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 160,
                  color: _mkLight,
                  child: const Center(
                    child: Icon(
                      Icons.local_florist_outlined,
                      size: 56,
                      color: _mkGreen,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleCtrl.text.trim().isEmpty
                          ? 'Ad Title'
                          : titleCtrl.text.trim(),
                      style: AppTypography.h4.copyWith(color: _mkTextPrimary),
                    ),
                    const SizedBox(height: 6),
                    if (priceCtrl.text.trim().isNotEmpty)
                      Text(
                        _priceLabel(double.tryParse(priceCtrl.text.trim()), 'PER_PLANT'),
                        style: const TextStyle(
                          color: _mkGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    if (qtyCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _Chip(
                        '${qtyCtrl.text.trim()} available',
                        _mkLight,
                        _mkDark,
                      ),
                    ],
                    if (descCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        descCtrl.text.trim(),
                        style: AppTypography.body
                            .copyWith(color: _mkTextPrimary, height: 1.5),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    access,
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 7. SAVED ADS SCREEN
// ══════════════════════════════════════════════════════════════════════════════

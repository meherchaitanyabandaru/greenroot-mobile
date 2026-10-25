part of 'my_addresses_screen.dart';

class AddressFormScreen extends ConsumerStatefulWidget {
  final UserAddress? existing;
  final MapPickResult? mapResult;
  final Future<void> Function(AddressFormData) onSave;

  const AddressFormScreen({
    super.key,
    this.existing,
    this.mapResult,
    required this.onSave,
  });

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  // After a failed Save, re-check as the user types so fixed fields clear.
  bool _triedSave = false;
  final _labelCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController(); // edit mode only
  final _pincodeCtrl = TextEditingController();
  String? _selectedState; // edit mode only
  double? _latitude;
  double? _longitude;
  bool _isDefault = false;
  bool _saving = false;
  String? _saveError;
  bool _useProfileContact = true;

  // Mutable — updated if user taps "Change Location"
  MapPickResult? _mapResult;

  bool get _isMapMode => _mapResult != null;
  bool get _pincodeLocked => _mapResult?.postalCode != null;

  @override
  void initState() {
    super.initState();
    _mapResult = widget.mapResult;

    final e = widget.existing;
    if (e != null) {
      _labelCtrl.text = e.addressType ?? '';
      _nameCtrl.text = e.contactName ?? '';
      _mobileCtrl.text = e.contactMobile ?? '';
      _line1Ctrl.text = e.addressLine1 ?? '';
      _line2Ctrl.text = e.addressLine2 ?? '';
      _cityCtrl.text = e.city ?? '';
      _pincodeCtrl.text = e.postalCode ?? '';
      _selectedState = _indianStates.contains(e.state) ? e.state : null;
      _latitude = e.latitude;
      _longitude = e.longitude;
      _isDefault = e.isDefault;
      _useProfileContact = (e.contactName?.trim().isEmpty ?? true) &&
          (e.contactMobile?.trim().isEmpty ?? true);
    } else if (_mapResult != null) {
      _pincodeCtrl.text = _mapResult!.postalCode ?? '';
      _latitude = _mapResult!.latitude;
      _longitude = _mapResult!.longitude;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeLocation() async {
    final result = await Navigator.push<MapPickResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddressMapPickerScreen(initial: _mapResult),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _mapResult = result;
      _pincodeCtrl.text = result.postalCode ?? '';
      _latitude = result.latitude;
      _longitude = result.longitude;
    });
  }

  /// Edit mode: re-pin on the map and take its city, state and PIN.
  Future<void> _movePin() async {
    final lat = _latitude, lon = _longitude;
    final result = await Navigator.push<MapPickResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddressMapPickerScreen(
          initial: lat == null || lon == null
              ? null
              : MapPickResult(
                  latitude: lat,
                  longitude: lon,
                  city: _cityCtrl.text.trim(),
                  state: _selectedState ?? '',
                  postalCode: _pincodeCtrl.text.trim(),
                ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      if (result.city.isNotEmpty) _cityCtrl.text = result.city;
      if (_indianStates.contains(result.state)) _selectedState = result.state;
      if (result.postalCode != null) _pincodeCtrl.text = result.postalCode!;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _triedSave = true);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });

    final city = _isMapMode ? _mapResult!.city : _cityCtrl.text.trim();
    final state = _isMapMode ? _mapResult!.state : _selectedState;
    final pincode = _pincodeCtrl.text.trim();

    try {
      final contactName = _useProfileContact ? null : _nameCtrl.text.trim();
      final contactMobile = _useProfileContact ? null : _mobileCtrl.text.trim();
      await widget.onSave(AddressFormData(
        addressType:
            _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
        contactName: contactName?.isEmpty == true ? null : contactName,
        contactMobile: contactMobile?.isEmpty == true ? null : contactMobile,
        addressLine1: _line1Ctrl.text.trim(),
        addressLine2:
            _line2Ctrl.text.trim().isEmpty ? null : _line2Ctrl.text.trim(),
        city: city.isNotEmpty ? city : null,
        state: (state?.isNotEmpty == true) ? state : null,
        country: 'India',
        postalCode: pincode.isEmpty ? null : pincode,
        latitude: _latitude,
        longitude: _longitude,
        isDefault: _isDefault,
      ),);
      if (mounted) Navigator.pop(context);
    } on AppError catch (e) {
      setState(() => _saveError = e.message);
    } catch (e) {
      setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final profile = ref.watch(sessionProvider).user;
    final profileName = profile?.name?.trim();
    final profileMobile = profile?.mobile?.trim();
    final profileLabel = [
      if (profileName?.isNotEmpty == true) profileName,
      if (profileMobile?.isNotEmpty == true) '+91 $profileMobile',
    ].whereType<String>().join(' - ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(isEdit ? 'Edit Address' : 'Add Address',
            style: AppTypography.h3,),
        foregroundColor: AppColors.textPrimary,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _triedSave
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Map location banner (new address only) ────────────
                    if (_isMapMode && !isEdit) ...[
                      _MapLocationBanner(
                        result: _mapResult!,
                        onChangeLocation: _changeLocation,
                      ),
                      const SizedBox(height: AppSpacing.x2l),
                    ],

                    // ── Contact info ──────────────────────────────────────
                    _FieldGroup(children: [
                      _Field(
                        label: 'Label',
                        child: TextFormField(
                          controller: _labelCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _deco('e.g. Home, Office, Nursery'),
                        ),
                      ),
                      _ProfileContactToggle(
                        value: _useProfileContact,
                        profileLabel: profileLabel.isEmpty
                            ? 'Profile contact details'
                            : profileLabel,
                        onChanged: (v) =>
                            setState(() => _useProfileContact = v),
                      ),
                      if (!_useProfileContact) ...[
                        _Field(
                          label: 'Alternate Contact Name',
                          child: TextFormField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: _deco('Person available here'),
                          ),
                        ),
                        _Field(
                          label: 'Alternate Mobile Number',
                          child: TextFormField(
                            controller: _mobileCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: _deco('10-digit mobile number'),
                          ),
                        ),
                      ],
                    ],),
                    const SizedBox(height: AppSpacing.md),

                    // ── Address lines ─────────────────────────────────────
                    const _SectionLabel('Address'),
                    _FieldGroup(children: [
                      _Field(
                        label: 'Address Line 1 *',
                        child: TextFormField(
                          controller: _line1Ctrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _deco('Flat no., Building, Street'),
                          validator: (v) => v?.trim().isEmpty == true
                              ? 'Address line 1 is required'
                              : null,
                        ),
                      ),
                      _Field(
                        label: 'Address Line 2 (optional)',
                        child: TextFormField(
                          controller: _line2Ctrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _deco('Area, Locality, Landmark'),
                        ),
                      ),
                    ],),
                    const SizedBox(height: AppSpacing.sm),

                    // ── City / Pincode ────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _isMapMode
                              ? _LockedField(
                                  label: 'City',
                                  value: _mapResult!.city,
                                )
                              : _Field(
                                  label: 'City',
                                  child: TextFormField(
                                    controller: _cityCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: _deco('City'),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _pincodeLocked
                              ? _LockedField(
                                  label: 'Pincode',
                                  value: _mapResult!.postalCode!,
                                )
                              : _Field(
                                  label: _isMapMode
                                      ? 'Pincode * (not on map)'
                                      : 'Pincode *',
                                  child: TextFormField(
                                    controller: _pincodeCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    decoration: _deco('6-digit PIN'),
                                    validator: (v) {
                                      final s = v?.trim() ?? '';
                                      if (s.isEmpty) return 'Required';
                                      if (s.length != 6) {
                                        return 'Must be 6 digits';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // ── State ─────────────────────────────────────────────
                    _isMapMode
                        ? _LockedField(
                            label: 'State',
                            value: _mapResult!.state,
                            fullWidth: true,
                          )
                        : _Field(
                            label: 'State',
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedState,
                              hint: const Text('Select state'),
                              isExpanded: true,
                              decoration: _deco(''),
                              items: _indianStates
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s,
                                            overflow: TextOverflow.ellipsis,),
                                      ),)
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedState = v),
                            ),
                          ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Set as default ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4,),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_outline_rounded,
                              color: AppColors.primaryMain, size: 20,),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Set as default address',
                                    style: AppTypography.body,),
                                // The default moves only by choosing another one.
                                if (widget.existing?.isDefault == true)
                                  Text(
                                    'To change it, set another address as default.',
                                    style: AppTypography.caption.copyWith(
                                        color: AppColors.textMuted,),
                                  ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isDefault,
                            onChanged: widget.existing?.isDefault == true
                                ? null
                                : (v) => setState(() => _isDefault = v),
                          ),
                        ],
                      ),
                    ),

                    // ── GPS badge ─────────────────────────────────────────
                    // Editing keeps the pin unless moved: a new street with an
                    // old pin sends the truck to the old place.
                    if (isEdit && !_isMapMode) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(children: [
                        if (_latitude != null && _longitude != null)
                          _GeocodedBadge(lat: _latitude!, lon: _longitude!),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _movePin,
                          icon: const Icon(Icons.edit_location_alt_outlined,
                              size: 18,),
                          label: Text(_latitude == null
                              ? 'Pin on map'
                              : 'Move pin',),
                        ),
                      ],),
                    ] else if (_latitude != null && _longitude != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _GeocodedBadge(lat: _latitude!, lon: _longitude!),
                    ],

                    if (_saveError != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _ErrorBanner(_saveError!),
                    ],

                    const SizedBox(height: AppSpacing.x3l),
                  ],
                ),
              ),
            ),

            // ── Save button ───────────────────────────────────────────────
            _SaveBar(
              label: isEdit ? 'Save Changes' : 'Save Address',
              saving: _saving,
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Map location banner ───────────────────────────────────────────────────────
// Shown at top of AddressFormScreen for new addresses.

class _MapLocationBanner extends StatelessWidget {
  final MapPickResult result;
  final VoidCallback onChangeLocation;

  const _MapLocationBanner(
      {required this.result, required this.onChangeLocation,});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryMain.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: AppColors.primaryMain, size: 18,),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location Pinned on Map',
                  style: AppTypography.body.copyWith(
                      color: AppColors.primaryMain,
                      fontWeight: FontWeight.w700,),
                ),
              ),
              TextButton(
                onPressed: onChangeLocation,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,),
                child: Text('Change',
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primaryMain,
                        fontWeight: FontWeight.w700,),),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${result.city}, ${result.state}'
            '${result.postalCode != null ? ' — ${result.postalCode}' : ''}',
            style: AppTypography.body,
          ),
          if (result.postalCode == null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 13, color: AppColors.amber700,),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Pincode not on map — please enter it below',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.amber700),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 12, color: AppColors.textMuted,),
              const SizedBox(width: 4),
              Text(
                'City & State locked from map',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Locked field ──────────────────────────────────────────────────────────────
// Read-only display for city, state, pincode that came from the map picker.

class _LockedField extends StatelessWidget {
  final String label;
  final String value;
  final bool fullWidth;

  const _LockedField({
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.primaryMain.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                    color: AppColors.primaryMain, fontWeight: FontWeight.w500,),
              ),
              const Spacer(),
              const Icon(Icons.lock_rounded,
                  size: 12, color: AppColors.primaryMain,),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,),
        ],
      ),
    );

    return fullWidth
        ? SizedBox(width: double.infinity, child: content)
        : content;
  }
}

// ── Geocoded badge ────────────────────────────────────────────────────────────

class _GeocodedBadge extends StatelessWidget {
  final double lat;
  final double lon;
  const _GeocodedBadge({required this.lat, required this.lon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryMain.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gps_fixed_rounded,
              size: 14, color: AppColors.primaryMain,),
          const SizedBox(width: 6),
          Text(
            'GPS: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
            style: AppTypography.caption.copyWith(color: AppColors.primaryMain),
          ),
        ],
      ),
    );
  }
}

// ── Save bar ──────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  final String label;
  final bool saving;
  final VoidCallback onSave;

  const _SaveBar(
      {required this.label, required this.saving, required this.onSave,});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.md,
          AppSpacing.screenPadding,
          MediaQuery.of(context).padding.bottom + AppSpacing.md,),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: saving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2,),)
              : Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15,),),
        ),
      ),
    );
  }
}

// ── Add button ────────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Address'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryMain,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }
}

// ── Layout helpers ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: AppTypography.h4),
      );
}

class _FieldGroup extends StatelessWidget {
  final List<Widget> children;
  const _FieldGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: children[i],
            ),
            if (i < children.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary, fontWeight: FontWeight.w500,),),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ProfileContactToggle extends StatelessWidget {
  final bool value;
  final String profileLabel;
  final ValueChanged<bool> onChanged;

  const _ProfileContactToggle({
    required this.value,
    required this.profileLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.forest100,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_pin_circle_outlined,
            color: AppColors.primaryMain,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use my profile contact details',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                profileLabel,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(error, style: AppTypography.body, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.red100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(message,
            style: AppTypography.bodySmall.copyWith(color: AppColors.red600),),
      );
}

class _Chip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Chip(this.text, {required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
        child: Text(text,
            style: AppTypography.caption.copyWith(
                color: fg, fontWeight: FontWeight.w700, fontSize: 10,),),
      );
}

// ── Shared input decoration ───────────────────────────────────────────────────

InputDecoration _deco(String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
    );

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart' show ApiClient;
import '../../core/services/geocoding/geocoding_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'address_map_picker_screen.dart';

// ── Address model ─────────────────────────────────────────────────────────────
// Matches user_addresses DB columns exactly.

class UserAddress {
  final int id;
  final String? addressType;
  final String? contactName;
  final String? contactMobile;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  const UserAddress({
    required this.id,
    this.addressType,
    this.contactName,
    this.contactMobile,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.latitude,
    this.longitude,
    required this.isDefault,
  });

  factory UserAddress.fromJson(Map<String, dynamic> j) => UserAddress(
        id: (j['id'] as num).toInt(),
        addressType: j['address_type'] as String?,
        contactName: j['contact_name'] as String?,
        contactMobile: j['contact_mobile'] as String?,
        addressLine1: j['address_line1'] as String?,
        addressLine2: j['address_line2'] as String?,
        city: j['city'] as String?,
        state: j['state'] as String?,
        country: j['country'] as String?,
        postalCode: j['postal_code'] as String?,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        isDefault: j['is_default'] as bool? ?? false,
      );

  String get displayAddress {
    final parts = [addressLine1, addressLine2, city, state, postalCode]
        .where((p) => p?.isNotEmpty == true)
        .toList();
    return parts.isEmpty ? 'No address details' : parts.join(', ');
  }
}

// ── Address form data ─────────────────────────────────────────────────────────
// Matches CreateAddressRequest DTO exactly (including lat/lon).

class AddressFormData {
  final String? addressType;
  final String? contactName;
  final String? contactMobile;
  final String addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  const AddressFormData({
    this.addressType,
    this.contactName,
    this.contactMobile,
    required this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        if (addressType?.isNotEmpty == true) 'address_type': addressType,
        if (contactName?.isNotEmpty == true) 'contact_name': contactName,
        if (contactMobile?.isNotEmpty == true) 'contact_mobile': contactMobile,
        'address_line1': addressLine1,
        if (addressLine2?.isNotEmpty == true) 'address_line2': addressLine2,
        if (city?.isNotEmpty == true) 'city': city,
        if (state?.isNotEmpty == true) 'state': state,
        'country': country?.isNotEmpty == true ? country : 'India',
        if (postalCode?.isNotEmpty == true) 'postal_code': postalCode,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'is_default': isDefault,
      };
}

// ── Indian states ─────────────────────────────────────────────────────────────

const _indianStates = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar',
  'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh',
  'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra',
  'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
  'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
  'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
  'Andaman and Nicobar Islands', 'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu', 'Delhi',
  'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
];

// ── Repository ────────────────────────────────────────────────────────────────

final userAddressRepositoryProvider =
    Provider((ref) => UserAddressRepository(ApiClient.instance));

class UserAddressRepository {
  final ApiClient _api;
  const UserAddressRepository(this._api);

  Future<List<UserAddress>> listAddresses(int userId) async {
    final res = await _api.get(ApiConstants.userAddresses(userId));
    final list = res['addresses'] as List<dynamic>? ?? [];
    return list
        .map((e) => UserAddress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserAddress> addAddress(int userId, AddressFormData form) async {
    final res = await _api.post(
      ApiConstants.userAddresses(userId),
      data: form.toJson(),
    );
    return UserAddress.fromJson(res['address'] as Map<String, dynamic>);
  }

  Future<UserAddress> updateAddress(int id, AddressFormData form) async {
    final res = await _api.put(
      ApiConstants.userAddressById(id),
      data: form.toJson(),
    );
    return UserAddress.fromJson(res['address'] as Map<String, dynamic>);
  }

  Future<void> deleteAddress(int id) async {
    await _api.delete(ApiConstants.userAddressById(id));
  }
}

// ── My Addresses screen ───────────────────────────────────────────────────────

class MyAddressesScreen extends ConsumerStatefulWidget {
  const MyAddressesScreen({super.key});

  @override
  ConsumerState<MyAddressesScreen> createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends ConsumerState<MyAddressesScreen> {
  List<UserAddress> _addresses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final userId = ref.read(sessionProvider).user?.id;
      if (userId == null) throw Exception('Not logged in');
      final list = await ref
          .read(userAddressRepositoryProvider)
          .listAddresses(userId);
      if (mounted) setState(() => _addresses = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Two-step flow: map picker → form (new) | form only (edit) ────────────

  Future<void> _openForm([UserAddress? existing]) async {
    final isEdit = existing != null;
    MapPickResult? mapResult;

    if (!isEdit) {
      // Step 1 — map picker
      mapResult = await Navigator.push<MapPickResult>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const AddressMapPickerScreen(),
        ),
      );
      if (mapResult == null || !mounted) return; // user cancelled the map
    }

    // Step 2 — address form
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddressFormScreen(
          existing: existing,
          mapResult: mapResult,
          onSave: (form) async {
            final userId = ref.read(sessionProvider).user?.id;
            if (userId == null) return;
            final repo = ref.read(userAddressRepositoryProvider);
            if (existing == null) {
              final addr = await repo.addAddress(userId, form);
              if (mounted) setState(() => _addresses = [..._addresses, addr]);
            } else {
              final addr = await repo.updateAddress(existing.id, form);
              if (mounted) {
                setState(() => _addresses = _addresses
                    .map((a) => a.id == existing.id ? addr : a)
                    .toList());
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _delete(UserAddress a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Remove "${a.displayAddress}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.red600))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(userAddressRepositoryProvider).deleteAddress(a.id);
      if (mounted) setState(() => _addresses.removeWhere((x) => x.id == a.id));
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red600),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('My Addresses', style: AppTypography.h3),
        foregroundColor: AppColors.textPrimary,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryMain))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _addresses.isEmpty
                  ? _EmptyState(onAdd: () => _openForm())
                  : _AddressListView(
                      addresses: _addresses,
                      onEdit: (a) => _openForm(a),
                      onDelete: _delete,
                      onAdd: () => _openForm(),
                      onRefresh: _load,
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
                color: AppColors.forest100, shape: BoxShape.circle),
            child: const Icon(Icons.location_on_outlined,
                size: 52, color: AppColors.primaryMain),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('No Addresses Yet', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add a delivery address so nurseries\nknow where to deliver your plants.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          _AddButton(onTap: onAdd),
          const SizedBox(height: AppSpacing.x2l),
        ],
      ),
    );
  }
}

// ── Address list ──────────────────────────────────────────────────────────────

class _AddressListView extends StatelessWidget {
  final List<UserAddress> addresses;
  final void Function(UserAddress) onEdit;
  final void Function(UserAddress) onDelete;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  const _AddressListView({
    required this.addresses,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            color: AppColors.primaryMain,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding, AppSpacing.md,
                  AppSpacing.screenPadding, AppSpacing.md),
              itemCount: addresses.length,
              itemBuilder: (_, i) => _AddressCard(
                address: addresses[i],
                onEdit: () => onEdit(addresses[i]),
                onDelete: () => onDelete(addresses[i]),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPadding, AppSpacing.sm,
              AppSpacing.screenPadding,
              MediaQuery.of(context).padding.bottom + AppSpacing.md),
          child: _AddButton(onTap: onAdd),
        ),
      ],
    );
  }
}

// ── Address card ──────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final UserAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressCard(
      {required this.address, required this.onEdit, required this.onDelete});

  IconData get _icon {
    switch (address.addressType?.toUpperCase()) {
      case 'HOME': return Icons.home_outlined;
      case 'WORK': case 'OFFICE': return Icons.business_outlined;
      case 'FARM': return Icons.agriculture_outlined;
      default: return Icons.location_on_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: address.isDefault
                ? AppColors.primaryMain.withValues(alpha: 0.4)
                : AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(_icon, color: AppColors.primaryMain, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (address.addressType?.isNotEmpty == true)
                      _Chip(address.addressType!.toUpperCase(),
                          bg: AppColors.forest100,
                          fg: AppColors.primaryMain),
                    if (address.isDefault) ...[
                      const SizedBox(width: 6),
                      _Chip('DEFAULT',
                          bg: AppColors.primaryMain, fg: Colors.white),
                    ],
                  ]),
                  if (address.contactName?.isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(address.contactName!,
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w600)),
                  ],
                  if (address.contactMobile?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(address.contactMobile!,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 5),
                  Text(address.displayAddress,
                      style: AppTypography.body
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8), Text('Edit'),
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 18, color: AppColors.red600),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppColors.red600)),
                    ])),
              ],
              icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit address — full-screen form ─────────────────────────────────────
//
// New address flow:
//   AddressMapPickerScreen → MapPickResult → AddressFormScreen
//   City, State, Pincode come from map (locked / read-only).
//   Address Line 1, Line 2, Label, Name, Mobile are always manually entered.
//
// Edit address flow:
//   AddressFormScreen only (pre-filled from existing data, all fields editable).

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
  final _labelCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();   // edit mode only
  final _pincodeCtrl = TextEditingController();
  String? _selectedState;                      // edit mode only
  double? _latitude;
  double? _longitude;
  bool _isDefault = false;
  bool _saving = false;
  String? _saveError;

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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _saveError = null; });

    final city = _isMapMode ? _mapResult!.city : _cityCtrl.text.trim();
    final state = _isMapMode ? _mapResult!.state : _selectedState;
    final pincode = _pincodeCtrl.text.trim();

    try {
      await widget.onSave(AddressFormData(
        addressType:
            _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
        contactName:
            _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        contactMobile:
            _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
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
      ));
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(isEdit ? 'Edit Address' : 'Add Address',
            style: AppTypography.h3),
        foregroundColor: AppColors.textPrimary,
      ),
      body: Form(
        key: _formKey,
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
                      _Field(
                        label: 'Full Name',
                        child: TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _deco('Contact person name'),
                        ),
                      ),
                      _Field(
                        label: 'Mobile Number',
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
                    ]),
                    const SizedBox(height: AppSpacing.md),

                    // ── Address lines ─────────────────────────────────────
                    _SectionLabel('Address'),
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
                    ]),
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
                                      if (s.length != 6) return 'Must be 6 digits';
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
                              value: _selectedState,
                              hint: const Text('Select state'),
                              isExpanded: true,
                              decoration: _deco(''),
                              items: _indianStates
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s,
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedState = v),
                            ),
                          ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Set as default ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_outline_rounded,
                              color: AppColors.primaryMain, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('Set as default address',
                                style: AppTypography.body),
                          ),
                          Switch(
                            value: _isDefault,
                            onChanged: (v) =>
                                setState(() => _isDefault = v),
                            activeColor: AppColors.primaryMain,
                          ),
                        ],
                      ),
                    ),

                    // ── GPS badge ─────────────────────────────────────────
                    if (_latitude != null && _longitude != null) ...[
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
      {required this.result, required this.onChangeLocation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.primaryMain.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: AppColors.primaryMain, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location Pinned on Map',
                  style: AppTypography.body.copyWith(
                      color: AppColors.primaryMain,
                      fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: onChangeLocation,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text('Change',
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primaryMain,
                        fontWeight: FontWeight.w700)),
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
                    size: 13, color: AppColors.amber700),
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
                  size: 12, color: AppColors.textMuted),
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
                    color: AppColors.primaryMain,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              const Icon(Icons.lock_rounded,
                  size: 12, color: AppColors.primaryMain),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.body
                  .copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: content) : content;
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
        border:
            Border.all(color: AppColors.primaryMain.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gps_fixed_rounded,
              size: 14, color: AppColors.primaryMain),
          const SizedBox(width: 6),
          Text(
            'GPS: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
            style:
                AppTypography.caption.copyWith(color: AppColors.primaryMain),
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
      {required this.label, required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.md,
          AppSpacing.screenPadding,
          MediaQuery.of(context).padding.bottom + AppSpacing.md),
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
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
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        child,
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
          const Icon(Icons.error_outline,
              size: 48, color: AppColors.textMuted),
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
            style:
                AppTypography.bodySmall.copyWith(color: AppColors.red600)),
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
                color: fg, fontWeight: FontWeight.w700, fontSize: 10)),
      );
}

// ── Shared input decoration ───────────────────────────────────────────────────

InputDecoration _deco(String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
    );

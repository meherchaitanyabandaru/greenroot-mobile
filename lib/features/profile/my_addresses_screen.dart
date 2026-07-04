import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart' show ApiClient;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class UserAddress {
  final int id;
  final String? addressType;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final bool isDefault;

  const UserAddress({
    required this.id,
    this.addressType,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    required this.isDefault,
  });

  factory UserAddress.fromJson(Map<String, dynamic> j) => UserAddress(
        id: (j['id'] as num).toInt(),
        addressType: j['address_type'] as String?,
        addressLine1: j['address_line1'] as String?,
        addressLine2: j['address_line2'] as String?,
        city: j['city'] as String?,
        state: j['state'] as String?,
        country: j['country'] as String?,
        postalCode: j['postal_code'] as String?,
        isDefault: j['is_default'] as bool? ?? false,
      );

  String get fullAddress {
    final parts = [addressLine1, addressLine2, city, state, postalCode]
        .where((p) => p?.isNotEmpty == true)
        .toList();
    return parts.isEmpty ? 'No address details' : parts.join(', ');
  }
}

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

  Future<UserAddress> addAddress(int userId, _AddressForm form) async {
    final res = await _api.post(
      ApiConstants.userAddresses(userId),
      data: form.toJson(),
    );
    return UserAddress.fromJson(res['address'] as Map<String, dynamic>);
  }

  Future<UserAddress> updateAddress(int addressId, _AddressForm form) async {
    final res = await _api.put(
      ApiConstants.userAddressById(addressId),
      data: form.toJson(),
    );
    return UserAddress.fromJson(res['address'] as Map<String, dynamic>);
  }

  Future<void> deleteAddress(int addressId) async {
    await _api.delete(ApiConstants.userAddressById(addressId));
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = ref.read(sessionProvider).user?.id;
      if (userId == null) throw Exception('Not logged in');
      final addresses = await ref
          .read(userAddressRepositoryProvider)
          .listAddresses(userId);
      if (mounted) setState(() => _addresses = addresses);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddEdit([UserAddress? existing]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressFormSheet(
        existing: existing,
        onSave: (form) async {
          final userId = ref.read(sessionProvider).user?.id;
          if (userId == null) return;
          final repo = ref.read(userAddressRepositoryProvider);
          if (existing == null) {
            final addr = await repo.addAddress(userId, form);
            setState(() => _addresses = [..._addresses, addr]);
          } else {
            final addr = await repo.updateAddress(existing.id, form);
            setState(() => _addresses = _addresses
                .map((a) => a.id == existing.id ? addr : a)
                .toList());
          }
        },
      ),
    );
    if (result == true) {}
  }

  Future<void> _delete(UserAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text(
            'Remove "${address.fullAddress}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.red600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(userAddressRepositoryProvider)
          .deleteAddress(address.id);
      setState(() => _addresses.removeWhere((a) => a.id == address.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Address removed'),
              backgroundColor: AppColors.primaryMain),
        );
      }
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
        title: const Text('My Addresses', style: AppTypography.h3),
        foregroundColor: AppColors.textPrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEdit(),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Address'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryMain))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: AppSpacing.md),
                      Text(_error!, style: AppTypography.body),
                      TextButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _addresses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.forest100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.location_on_outlined,
                                size: 36, color: AppColors.primaryMain),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const Text('No Addresses Yet',
                              style: AppTypography.h3),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Add a delivery address so nurseries know\nwhere to deliver your plants.',
                            style: AppTypography.body.copyWith(
                                color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.x2l),
                          ElevatedButton.icon(
                            onPressed: () => _showAddEdit(),
                            icon:
                                const Icon(Icons.add_location_alt_rounded),
                            label: const Text('Add Address'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryMain,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primaryMain,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenPadding,
                            AppSpacing.md,
                            AppSpacing.screenPadding,
                            100),
                        itemCount: _addresses.length,
                        itemBuilder: (context, i) =>
                            _AddressCard(
                          address: _addresses[i],
                          onEdit: () => _showAddEdit(_addresses[i]),
                          onDelete: () => _delete(_addresses[i]),
                        ),
                      ),
                    ),
    );
  }
}

// ── Address card ──────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final UserAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
  });

  IconData get _typeIcon {
    switch (address.addressType?.toUpperCase()) {
      case 'HOME':
        return Icons.home_outlined;
      case 'WORK':
      case 'OFFICE':
        return Icons.business_outlined;
      case 'FARM':
        return Icons.agriculture_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: address.isDefault
                ? AppColors.primaryMain.withValues(alpha: 0.4)
                : AppColors.border),
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(_typeIcon, color: AppColors.primaryMain, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (address.addressType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.forest100,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          address.addressType!.toUpperCase(),
                          style: AppTypography.caption.copyWith(
                              color: AppColors.primaryMain,
                              fontWeight: FontWeight.w700,
                              fontSize: 10),
                        ),
                      ),
                    if (address.isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMain,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'DEFAULT',
                          style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 10),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Text(address.fullAddress, style: AppTypography.body),
                  if (address.country?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(address.country!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
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
                      SizedBox(width: 8),
                      Text('Edit'),
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: AppColors.red600),
                      SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(color: AppColors.red600)),
                    ])),
              ],
              icon: const Icon(Icons.more_vert,
                  size: 20, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Address form ──────────────────────────────────────────────────────────────

class _AddressForm {
  final String? addressType;
  final String addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;

  const _AddressForm({
    this.addressType,
    required this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.country,
    this.postalCode,
  });

  Map<String, dynamic> toJson() => {
        if (addressType != null) 'address_type': addressType,
        'address_line1': addressLine1,
        if (addressLine2?.isNotEmpty == true) 'address_line2': addressLine2,
        if (city?.isNotEmpty == true) 'city': city,
        if (state?.isNotEmpty == true) 'state': state,
        if (country?.isNotEmpty == true) 'country': country,
        if (postalCode?.isNotEmpty == true) 'postal_code': postalCode,
      };
}

class _AddressFormSheet extends StatefulWidget {
  final UserAddress? existing;
  final Future<void> Function(_AddressForm form) onSave;

  const _AddressFormSheet({this.existing, required this.onSave});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  String? _addressType = 'HOME';
  bool _saving = false;
  String? _error;

  static const _types = ['HOME', 'WORK', 'FARM', 'OTHER'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _line1Ctrl.text = e.addressLine1 ?? '';
      _line2Ctrl.text = e.addressLine2 ?? '';
      _cityCtrl.text = e.city ?? '';
      _stateCtrl.text = e.state ?? '';
      _countryCtrl.text = e.country ?? '';
      _postalCtrl.text = e.postalCode ?? '';
      _addressType = e.addressType ?? 'HOME';
    }
  }

  @override
  void dispose() {
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_AddressForm(
        addressType: _addressType,
        addressLine1: _line1Ctrl.text.trim(),
        addressLine2:
            _line2Ctrl.text.trim().isEmpty ? null : _line2Ctrl.text.trim(),
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        state:
            _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
        country: _countryCtrl.text.trim().isEmpty
            ? null
            : _countryCtrl.text.trim(),
        postalCode: _postalCtrl.text.trim().isEmpty
            ? null
            : _postalCtrl.text.trim(),
      ));
      if (mounted) Navigator.pop(context, true);
    } on AppError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.x3l,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),
              Text(isEdit ? 'Edit Address' : 'Add Address',
                  style: AppTypography.h3),
              const SizedBox(height: AppSpacing.x2l),

              // Type selector
              Text('Address Type',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: _types
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _addressType == t
                                        ? Colors.white
                                        : AppColors.textPrimary)),
                            selected: _addressType == t,
                            selectedColor: AppColors.primaryMain,
                            onSelected: (_) =>
                                setState(() => _addressType = t),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _line1Ctrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDeco('Address Line 1 *'),
                validator: (v) => (v?.trim().isEmpty ?? true)
                    ? 'Required'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _line2Ctrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDeco('Address Line 2 (optional)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDeco('City'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _stateCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDeco('State'),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _postalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco('PIN Code'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _countryCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDeco('Country'),
                  ),
                ),
              ]),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.red600)),
                ),
              ],
              const SizedBox(height: AppSpacing.x2l),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Save Changes' : 'Add Address',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText: hint,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.primaryMain, width: 1.5)),
    );

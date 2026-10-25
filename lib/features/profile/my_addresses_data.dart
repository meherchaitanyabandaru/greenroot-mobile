part of 'my_addresses_screen.dart';

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
        isDefault: (j['is_default'] ?? j['is_primary']) as bool? ?? false,
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
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Andaman and Nicobar Islands',
  'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi',
  'Jammu and Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
];

// ── Repository ────────────────────────────────────────────────────────────────

final userAddressRepositoryProvider =
    Provider((ref) => UserAddressRepository(ref.watch(apiClientProvider)));

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

  Future<List<UserAddress>> listNurseryAddresses(int nurseryId) async {
    final res = await _api.get(ApiConstants.nurseryAddresses(nurseryId));
    final list = res['addresses'] as List<dynamic>? ?? [];
    return list
        .map((e) => UserAddress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Nursery addresses call "default" primary; sending only is_default
  // would clear the pickup address on every edit.
  Map<String, dynamic> _nurseryJson(AddressFormData form) =>
      {...form.toJson(), 'is_primary': form.isDefault};

  Future<UserAddress> addNurseryAddress(
    int nurseryId,
    AddressFormData form,
  ) async {
    final res = await _api.post(
      ApiConstants.nurseryAddresses(nurseryId),
      data: _nurseryJson(form),
    );
    return UserAddress.fromJson(res['address'] as Map<String, dynamic>);
  }

  Future<UserAddress> updateNurseryAddress(
    int id,
    AddressFormData form,
  ) async {
    final res = await _api.put(
      ApiConstants.nurseryAddressById(id),
      data: _nurseryJson(form),
    );
    return UserAddress.fromJson(res['address'] as Map<String, dynamic>);
  }

  Future<void> deleteNurseryAddress(int id) async {
    await _api.delete(ApiConstants.nurseryAddressById(id));
  }
}

// ── My Addresses screen ───────────────────────────────────────────────────────

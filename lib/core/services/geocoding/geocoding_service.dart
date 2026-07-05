import 'package:dio/dio.dart';

// ── Result from the map picker ────────────────────────────────────────────────
// Returned by AddressMapPickerScreen. city/state are always present (from OSM).
// postalCode is present for 90%+ of urban India; null for some rural areas.

class MapPickResult {
  final double latitude;
  final double longitude;
  final String city;
  final String state;
  final String? postalCode; // null if OSM has no postcode for this pin
  final String country;

  const MapPickResult({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.state,
    this.postalCode,
    this.country = 'India',
  });
}

// ── Address suggestion (search autocomplete) ──────────────────────────────────
// Maps onto user_addresses DB columns: address_line1, address_line2, city,
// state, postal_code, country, latitude, longitude.

class AddressSuggestion {
  final String displayName;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final double? latitude;
  final double? longitude;

  const AddressSuggestion({
    required this.displayName,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.latitude,
    this.longitude,
  });

  @override
  String toString() => displayName;
}

// ── Provider-agnostic interface ───────────────────────────────────────────────
// Swap between Nominatim / Geoapify / LocationIQ / Google by changing
// the geocodingServiceProvider — all UI code is unchanged.

abstract class GeocodingService {
  /// Forward geocode: search by text, return ranked suggestions.
  Future<List<AddressSuggestion>> search(
    String query, {
    CancelToken? cancelToken,
  });

  /// Reverse geocode: lat/lon → address components.
  /// Returns null if the provider returns no usable result.
  Future<AddressSuggestion?> reverseGeocode(
    double lat,
    double lon, {
    CancelToken? cancelToken,
  });
}

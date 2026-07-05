import 'package:dio/dio.dart';
import 'geocoding_service.dart';

// ── Nominatim (OpenStreetMap) implementation ──────────────────────────────────
//
// Nominatim TOS:
//  • Max 1 req/s — enforced by 400 ms search debounce + 800 ms reverse debounce
//  • Valid User-Agent required
//  • No bulk geocoding
//
// Replace NominatimGeocodingService with any other class that implements
// GeocodingService in geocoding_provider.dart — zero UI changes needed.

class NominatimGeocodingService implements GeocodingService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org';
  static const _userAgent = 'GreenRoot/1.0 (support@greenroot.in)';

  late final Dio _dio;

  // Session-level cache keyed by query string or "rev:lat,lon"
  final Map<String, List<AddressSuggestion>> _cache = {};

  NominatimGeocodingService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'User-Agent': _userAgent,
        'Accept-Language': 'en',
        'Accept': 'application/json',
      },
    ));
  }

  // ── Forward geocode ─────────────────────────────────────────────────────────

  @override
  Future<List<AddressSuggestion>> search(
    String query, {
    CancelToken? cancelToken,
  }) async {
    final key = query.toLowerCase().trim();
    if (_cache.containsKey(key)) return _cache[key]!;

    final response = await _dio.get<List<dynamic>>(
      '/search',
      queryParameters: {
        'q': query,
        'format': 'json',
        'addressdetails': 1,
        'countrycodes': 'in',
        'limit': 5,
        'accept-language': 'en',
      },
      cancelToken: cancelToken,
    );

    final data = response.data ?? [];
    final suggestions =
        data.map((e) => _parse(e as Map<String, dynamic>)).toList();
    _cache[key] = suggestions;
    return suggestions;
  }

  // ── Reverse geocode ─────────────────────────────────────────────────────────

  @override
  Future<AddressSuggestion?> reverseGeocode(
    double lat,
    double lon, {
    CancelToken? cancelToken,
  }) async {
    // Cache key at ~100m precision (4 decimal places ≈ 11m)
    final key = 'rev:${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
    if (_cache.containsKey(key)) {
      return _cache[key]?.firstOrNull;
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/reverse',
      queryParameters: {
        'lat': lat,
        'lon': lon,
        'format': 'json',
        'addressdetails': 1,
        'zoom': 14, // neighbourhood level — returns road + suburb + city + state
      },
      cancelToken: cancelToken,
    );

    if (response.data == null) return null;
    final result = _parse(response.data!);
    _cache[key] = [result];
    return result;
  }

  // ── Parse Nominatim JSON → AddressSuggestion ──────────────────────────────
  //
  // OSM address keys vary across Indian regions. Priority order below covers
  // the most common patterns tested against Hyderabad, Chennai, Warangal,
  // rural Karnataka.

  static AddressSuggestion _parse(Map<String, dynamic> json) {
    final addr = (json['address'] as Map<String, dynamic>?) ?? {};

    // address_line1: flat/house number + road/street
    final houseNo = _str(addr, ['house_number']);
    final road = _str(addr, ['road', 'pedestrian', 'footway', 'path', 'street']);
    final line1 = _join([houseNo, road]);

    // address_line2: neighbourhood / suburb / city_district
    final line2 = _str(addr, [
      'neighbourhood',
      'suburb',
      'quarter',
      'city_district',
      'subdistrict',
    ]);

    // city: most-specific field that represents a city/town/village
    final city = _str(addr, [
      'city',
      'town',
      'village',
      'municipality',
      'county',
      'state_district',
    ]);

    final state = _str(addr, ['state']);
    final postalCode = _str(addr, ['postcode']);
    final country = _str(addr, ['country']);

    final lat = double.tryParse((json['lat'] as String?) ?? '');
    final lon = double.tryParse((json['lon'] as String?) ?? '');

    return AddressSuggestion(
      displayName: (json['display_name'] as String?) ?? '',
      addressLine1: line1.isEmpty ? null : line1,
      addressLine2: (line2?.isEmpty ?? true) ? null : line2,
      city: (city?.isEmpty ?? true) ? null : city,
      state: (state?.isEmpty ?? true) ? null : state,
      postalCode: (postalCode?.isEmpty ?? true) ? null : postalCode,
      country: (country?.isEmpty ?? true) ? null : country,
      latitude: lat,
      longitude: lon,
    );
  }

  static String? _str(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  static String _join(List<String?> parts) =>
      parts.where((p) => p != null && p.isNotEmpty).join(', ');
}

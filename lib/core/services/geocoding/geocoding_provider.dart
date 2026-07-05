import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'geocoding_service.dart';
import 'nominatim_service.dart';

// ── Geocoding provider ────────────────────────────────────────────────────────
//
// To switch from Nominatim to another provider (Geoapify, LocationIQ, Google):
//   1. Implement GeocodingService in a new file
//   2. Replace NominatimGeocodingService() here — UI is untouched

final geocodingServiceProvider = Provider<GeocodingService>(
  (_) => NominatimGeocodingService(),
);

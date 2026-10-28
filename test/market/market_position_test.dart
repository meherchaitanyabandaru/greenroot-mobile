import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:greenroot_mobile/features/market/market_area.dart';

/// No Wi-Fi/cell fix (low power times out), but the GPS chip has one.
class _GpsOnly extends GeolocatorPlatform {
  final asked = <LocationAccuracy>[];

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    asked.add(locationSettings!.accuracy);
    if (locationSettings.accuracy == LocationAccuracy.low) {
      throw TimeoutException('no network location');
    }
    return Position(
      latitude: 16.9174,
      longitude: 81.8306,
      timestamp: DateTime(2026, 10, 28),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  test('falls back to GPS when the low-power fix times out', () async {
    final geo = _GpsOnly();
    GeolocatorPlatform.instance = geo;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final pos = await container.read(marketPositionProvider.future);

    expect(pos?.latitude, 16.9174);
    expect(geo.asked, [LocationAccuracy.low, LocationAccuracy.high]);
  });
}

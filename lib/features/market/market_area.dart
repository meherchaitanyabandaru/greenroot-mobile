// Where the Local Market looks: the phone's position (when the user allows
// it) and how far around it. The market is local -- 60 km by default, never
// past 100 km. With no phone position the server uses the nursery's address.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/presentation/providers/session_provider.dart';

const kDefaultRadiusKm = 60.0;
const kMinRadiusKm = 10.0;
const kMaxRadiusKm = 100.0;

/// The radius the user chose, saved on the phone per account.
class MarketRadiusNotifier extends StateNotifier<double> {
  MarketRadiusNotifier(this._userId) : super(kDefaultRadiusKm) {
    _load();
  }

  final int? _userId;
  String get _key => 'market_radius_km_v1_$_userId';

  Future<void> _load() async {
    if (_userId == null) return;
    final saved = (await SharedPreferences.getInstance()).getDouble(_key);
    if (saved != null && mounted) {
      state = saved.clamp(kMinRadiusKm, kMaxRadiusKm);
    }
  }

  Future<void> save(double km) async {
    state = km.clamp(kMinRadiusKm, kMaxRadiusKm);
    if (_userId == null) return;
    await (await SharedPreferences.getInstance()).setDouble(_key, state);
  }
}

final marketRadiusProvider =
    StateNotifierProvider<MarketRadiusNotifier, double>(
  (ref) => MarketRadiusNotifier(
    ref.watch(sessionProvider.select((s) => s.user?.id)),
  ),
);

/// The phone's position, asked once per app session (invalidate to ask
/// again); null when location is off or refused.
final marketPositionProvider = FutureProvider<Position?>((ref) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );
  } catch (_) {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
});

/// Query parameters for "ads around me".
Map<String, String> marketAreaParams(double? lat, double? lon, double radiusKm) => {
      if (lat != null && lon != null) 'near_lat': lat.toStringAsFixed(5),
      if (lat != null && lon != null) 'near_lon': lon.toStringAsFixed(5),
      'radius_km': radiusKm.toStringAsFixed(0),
    };

/// "12 km away" / "800 m away" for an ad card.
String distanceLabel(double km) =>
    km < 1 ? '${(km * 1000).round()} m away' : '${km.round()} km away';

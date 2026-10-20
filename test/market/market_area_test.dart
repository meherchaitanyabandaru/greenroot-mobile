import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/market/market_area.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('area params send the phone position only when known', () {
    expect(marketAreaParams(17.44012, 78.34891, 60), {
      'near_lat': '17.44012',
      'near_lon': '78.34891',
      'radius_km': '60',
    });
    expect(marketAreaParams(null, null, 100), {'radius_km': '100'});
  });

  test('radius is saved per account and kept within 10-100 km', () async {
    SharedPreferences.setMockInitialValues({});
    final a = MarketRadiusNotifier(1);
    expect(a.state, kDefaultRadiusKm);
    await a.save(500);
    expect(a.state, kMaxRadiusKm);

    final again = MarketRadiusNotifier(1);
    await Future<void>.delayed(Duration.zero);
    expect(again.state, kMaxRadiusKm, reason: 'restored for the same account');

    final other = MarketRadiusNotifier(2);
    await Future<void>.delayed(Duration.zero);
    expect(other.state, kDefaultRadiusKm, reason: 'another account keeps its own');
  });
}

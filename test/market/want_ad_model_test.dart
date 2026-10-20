import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/market/local_market_providers.dart';

void main() {
  test('a wanted post parses as a want with its date and no price', () {
    final ad = MarketAd.fromJson({
      'id': 70,
      'code': 'MKT-000070',
      'ad_type': 'WANT',
      'needed_by': '2026-11-30T00:00:00Z',
      'nursery_id': 3,
      'nursery_name': 'Rose Gardens',
      'plant_id': 2,
      'plant_name': 'Neem',
      'title': 'Wanted: Neem',
      'quantity': 300,
      'size_description': 'Sapling',
      'photos': <String>[],
      'status': 'PUBLISHED',
      'created_at': '2026-10-20T10:00:00Z',
    });
    expect(ad.isWant, isTrue);
    expect(ad.neededBy, DateTime.utc(2026, 11, 30));
    expect(ad.pricePerUnit, isNull);
  });

  test('older ads without ad_type are for sale', () {
    final ad = MarketAd.fromJson({
      'id': 1,
      'code': 'MKT-000001',
      'nursery_id': 1,
      'nursery_name': 'A',
      'plant_name': 'Rose',
      'title': 'Roses',
      'photos': <String>[],
      'status': 'PUBLISHED',
      'created_at': '2026-10-20T10:00:00Z',
    });
    expect(ad.isWant, isFalse);
    expect(ad.adType, 'SELL');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/market/local_market_providers.dart';

void main() {
  test('a seller profile parses the owner selfie, activity and live ads', () {
    final p = SellerProfile.fromJson({
      'nursery_id': 3,
      'nursery_name': 'mehar nursery',
      'verified': true,
      'city': 'Hyderabad',
      'owner_name': 'Mehar B',
      'owner_photo': 'http://192.168.1.4:9000/profile-images/17/a.jpg',
      'member_since': '2026-10-01T00:00:00Z',
      'ads_posted': 4,
      'live_ads': 1,
      'deals_agreed': 2,
      'ads': [
        {
          'id': 9,
          'code': 'MKT-000009',
          'nursery_id': 3,
          'nursery_name': 'mehar nursery',
          'plant_name': 'Guava',
          'title': 'Guava grafts',
          'photos': <String>[],
          'status': 'PUBLISHED',
          'posted_by_name': 'Mehar B',
          'posted_by_photo': 'http://192.168.1.4:9000/profile-images/17/a.jpg',
          'created_at': '2026-10-19T10:00:00Z',
        },
      ],
    });
    expect(p.ownerPhoto, endsWith('a.jpg'));
    expect((p.liveAds, p.adsPosted, p.dealsAgreed), (1, 4, 2));
    expect(p.ads.single.postedByName, 'Mehar B');
    expect(p.ads.single.postedByPhoto, isNotNull);
  });
}

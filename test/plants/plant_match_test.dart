import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/plants/plants.dart';

void main() {
  group('PlantMatch.fromJson', () {
    test('catalog row shows common name, scientific name below', () {
      final m = PlantMatch.fromJson({
        'plant': {
          'id': 2,
          'plant_code': 'PLT-000002',
          'scientific_name': 'Azadirachta indica',
          'common_name': 'Neem',
          'is_active': true,
        },
      });
      expect(m.plant?.id, 2);
      expect(m.title, 'Neem');
      expect(m.subtitle, 'Azadirachta indica');
    });

    test('botanical name shows family until resolved', () {
      final m = PlantMatch.fromJson({
        'name': {
          'wfo_id': 'wfo-0000318521',
          'scientific_name': 'Syzygium cumini',
          'family': 'Myrtaceae',
          'taxon_rank': 'species',
          'status': 'ACCEPTED',
        },
      });
      expect(m.plant, isNull);
      expect(m.wfoId, 'wfo-0000318521');
      expect(m.title, 'Syzygium cumini');
      expect(m.subtitle, 'Myrtaceae');
    });

    test('synonym tells the user the current name', () {
      final m = PlantMatch.fromJson({
        'name': {
          'wfo_id': 'wfo-0000303023',
          'scientific_name': 'Sapota achras',
          'family': 'Sapotaceae',
          'taxon_rank': 'species',
          'status': 'SYNONYM',
          'accepted_wfo_id': 'wfo-0000235995',
          'accepted_name': 'Manilkara zapota',
        },
      });
      expect(m.subtitle, 'Now called Manilkara zapota');
    });
  });
}

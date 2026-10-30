// Customer quotation requests: unlisted plants by the customer's own name,
// the request body, pricing by the nursery, and how search results read.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/plants/plant_picker.dart';
import 'package:greenroot_mobile/features/plants/plants.dart';
import 'package:greenroot_mobile/features/quotations/quotation_request_panel.dart';
import 'package:greenroot_mobile/features/quotations/quotations.dart';

import '../helpers/fake_api_client.dart';

Map<String, dynamic> _quotation({String status = 'CUSTOMER_REQUESTED', bool priced = false, Map<String, dynamic>? caps}) => {
      'id': 9,
      'quotation_code': 'QUO-9',
      'created_by_user_id': 10,
      'total_amount': 0,
      'status': status,
      'created_at': '2026-10-30T10:00:00Z',
      'is_request': true,
      'request_note': 'Needed by Friday',
      'request_expires_at': DateTime.now().add(const Duration(days: 6)).toIso8601String(),
      'capabilities': caps ?? {'can_price': true, 'can_decline': true},
      'items': [
        {'id': 1, 'plant_id': 7, 'scientific_name': 'Mangifera indica', 'common_name': 'Mango', 'quantity': 50,
         'unit_price': 0, 'total_price': 0, 'is_priced': priced,},
        {'id': 2, 'scientific_name': '', 'is_custom': true, 'custom_plant_name': 'Nela vemu', 'variety': 'dwarf',
         'size_description': '2 ft', 'quantity': 20, 'is_priced': priced,},
      ],
    };

Widget _host(FakeApiClient fake, Widget child) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fake.apiClient)],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  late FakeApiClient fake;
  setUp(() => fake = FakeApiClient()..reset());

  test('a custom line reads as the customer wrote it; unpriced lines and missing plant ids parse', () {
    final q = Quotation.fromJson(_quotation());
    final custom = q.items[1];
    expect(custom.isCustom, isTrue);
    expect(custom.plantId, 0);
    expect(custom.displayName, 'Nela vemu');
    expect(custom.specs, 'dwarf · 2 ft');
    expect(custom.isPriced, isFalse);
    expect(q.isRequest, isTrue);
    expect(q.capabilities!.canPrice, isTrue);
  });

  test('request lines send either the plant or the custom name with specifications', () {
    expect(const RequestLine(plantId: 7, plantName: 'Mango', quantity: 50, sizeDescription: ' ').toJson(),
        {'plant_id': 7, 'quantity': 50.0},);
    expect(const RequestLine(customPlantName: ' Nela vemu ', variety: 'dwarf', quantity: 20).toJson(),
        {'custom_plant_name': 'Nela vemu', 'variety': 'dwarf', 'quantity': 20.0},);
  });

  test('the request is sent once: with an Idempotency-Key, to the requests endpoint', () async {
    fake.route('/quotations/requests', {'quotation': _quotation()});
    final repo = QuotationRepository(fake.apiClient);
    await repo.createRequest(nurseryId: 3, note: ' Needed by Friday ', idempotencyKey: 'k-1', lines: const [
      RequestLine(plantId: 7, quantity: 50),
      RequestLine(customPlantName: 'Nela vemu', quantity: 20),
    ],);
    final call = fake.calls.single;
    expect(call.path, endsWith('/quotations/requests'));
    expect(call.headers['Idempotency-Key'], 'k-1');
    final body = call.data as Map;
    expect(body['nursery_id'], 3);
    expect(body['note'], 'Needed by Friday');
    expect((body['items'] as List).last, {'custom_plant_name': 'Nela vemu', 'quantity': 20.0});
  });

  test('search results say why they matched; a near spelling is only offered', () {
    final alias = PlantMatch.fromJson({
      'plant': {'id': 7, 'plant_code': 'P7', 'scientific_name': 'Azadirachta indica', 'common_name': 'Neem', 'is_active': true},
      'match_type': 'ALIAS', 'matched_name': 'Vepa',
    });
    expect(alias.subtitle, 'Also called Vepa · Azadirachta indica');
    final near = PlantMatch.fromJson({'name': {'wfo_id': 'w', 'scientific_name': 'Mangifera indica'}, 'match_type': 'BOTANICAL_FUZZY'});
    expect(near.isNearSpelling, isTrue);
    expect(near.subtitle, startsWith('Did you mean this?'));
  });

  testWidgets('"Other / not listed" hands back what was typed', (tester) async {
    String? other;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OtherPlantTile(typed: 'nela vemu', onTap: () => other = 'nela vemu'))));
    expect(find.textContaining('nela vemu'), findsOneWidget);
    await tester.tap(find.text('Other / not listed'));
    expect(other, 'nela vemu');
  });

  testWidgets('the nursery prices lines; the custom line stays the customer\'s plant', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    final q = Quotation.fromJson(_quotation());
    fake.route('/quotations/9/price', {'quotation': _quotation(priced: true)});
    await tester.pumpWidget(_host(fake, QuotationRequestPanel(quotation: q, onChanged: () {})));
    expect(find.text('"Needed by Friday"'), findsOneWidget);
    expect(find.text('Decline request'), findsOneWidget);
    expect(find.text('Cancel my request'), findsNothing, reason: 'the nursery side cannot cancel');

    await tester.pumpWidget(_host(fake, PriceRequestSheet(quotation: q)));
    expect(find.textContaining("Customer's own name"), findsOneWidget);
    final fields = find.byType(TextField);
    // Per line: quantity, then price.
    await tester.enterText(fields.at(1), '120');
    await tester.enterText(fields.at(2), '15');
    await tester.enterText(fields.at(3), '35');
    await tester.tap(find.text('Save prices'));
    await tester.pumpAndSettle();
    final body = fake.calls.single.data as Map;
    expect(body['items'], [
      {'item_id': 1, 'unit_price': 120.0},
      {'item_id': 2, 'unit_price': 35.0, 'quantity': 15.0},
    ]);
  });
}

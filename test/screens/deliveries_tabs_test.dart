// Selling and Buying each have a Deliveries tab: Selling lists this
// nursery's outgoing deliveries; Buying lists deliveries coming to the user
// (the API needs buying=true, or an owner sees their own outgoing ones).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/buyer/buyer_tab.dart';
import 'package:greenroot_mobile/features/owner/owner_tab.dart';

import '../helpers/fake_api_client.dart';

const _page = {'page': 1, 'per_page': 20, 'total': 1, 'total_pages': 1};

Map<String, dynamic> _dispatch(String status) => {
      'id': 7,
      'dispatch_code': 'DSP-20261023-0007',
      'order_id': 9,
      'order_number': 'ORD-20261023-0009',
      'dispatch_status': status,
      'driver_name': 'Ramu',
      'created_at': '2026-10-23T10:00:00Z',
    };

Widget _app(FakeApiClient fake, Widget home) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fake.apiClient)],
      child: MaterialApp(home: home),
    );

void main() {
  late FakeApiClient fake;

  setUp(() {
    fake = FakeApiClient()..reset();
    fake
      ..route('/quotations', {'quotations': [], 'pagination': _page})
      ..route('/orders', {'orders': [], 'pagination': _page})
      ..route('/dispatches', {'dispatches': [_dispatch('DELIVERED')], 'pagination': _page});
  });

  testWidgets('Selling has Deliveries with outgoing dispatches and filters', (tester) async {
    await tester.pumpWidget(_app(fake, const OwnerTab()));
    await tester.pumpAndSettle();

    expect(find.text('Quotations'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Deliveries'), findsOneWidget);
    expect(find.text('New Quotation'), findsOneWidget);

    await tester.tap(find.text('Deliveries'));
    await tester.pumpAndSettle();

    for (final chip in ['All', 'Pending', 'Dispatched', 'In Transit', 'Delivered']) {
      expect(find.text(chip), findsWidgets, reason: chip);
    }
    expect(find.text('DSP-20261023-0007'), findsOneWidget);
    // Deliveries are created from an order, so no "New …" button here.
    expect(find.byType(FloatingActionButton), findsNothing);

    final call = fake.calls.lastWhere((c) => c.path.endsWith('/dispatches'));
    expect(call.query['buying'], isNull); // seller view: outgoing
  });

  testWidgets('Buying asks for incoming deliveries only', (tester) async {
    await tester.pumpWidget(_app(fake, const BuyerTab()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deliveries'));
    await tester.pumpAndSettle();

    expect(find.text('DSP-20261023-0007'), findsOneWidget);
    final call = fake.calls.lastWhere((c) => c.path.endsWith('/dispatches'));
    expect(call.query['buying'], isTrue);
  });
}

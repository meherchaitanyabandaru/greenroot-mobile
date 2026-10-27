import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/widgets/order_timeline.dart';
import 'package:greenroot_mobile/features/orders/loading_proof_screen.dart';
import 'package:greenroot_mobile/features/orders/orders.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';

Widget _app(Widget child) =>
    ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('loading proof shows the declaration and the truck',
      (tester) async {
    final fake = FakeApiClient()
      ..enqueue(response: {
        'loading_proof': {
          'photos': <Map<String, dynamic>>[],
          'declared_no_prohibited_items': true,
          'completed_at': '2026-10-27T13:28:31Z',
          'completed_by_name': 'Priya Owner',
          'truck': {
            'vehicle_number': 'TS09AB1234',
            'vehicle_type': 'Mini truck',
            'driver_name': 'Raju Driver',
            'driver_mobile': '9400000000',
            'outside_transport': false,
            'trip_status': 'DISPATCHED',
          },
        },
      },);
    await tester.pumpWidget(
      _app(const LoadingProofScreen(orderId: 7, orderCode: 'ORD-7')),
    );
    await tester.pumpAndSettle();

    expect(fake.calls.single.path, endsWith('/orders/7/loading-proof'));
    expect(find.text('Declared: no prohibited items'), findsOneWidget);
    expect(find.textContaining('by Priya Owner'), findsOneWidget);
    expect(find.text('TS09AB1234 · Mini truck'), findsOneWidget);
    expect(find.text('Raju Driver'), findsOneWidget);
    expect(find.text('No photos were added when loading was done.'),
        findsOneWidget,);
  });

  testWidgets('timeline offers loading photos only once loading is done',
      (tester) async {
    for (final (status, shown) in [('LOADING', false), ('LOADED', true)]) {
      var opened = false;
      await tester.pumpWidget(
        _app(
          OrderTimeline(
            order: Order.fromJson(orderJson(status: status)),
            onLoadingProof: () => opened = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final icon = find.bySemanticsLabel('Loading photos and truck');
      expect(icon, shown ? findsOneWidget : findsNothing, reason: status);
      if (shown) {
        await tester.tap(icon);
        expect(opened, isTrue);
      }
    }
  });
}

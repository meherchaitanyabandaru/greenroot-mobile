// Customers pick a nursery for an order or a price request: only approved
// nurseries are offered (the API's status value is APPROVED; "active" matched
// none, so the list was always empty).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/nurseries/nurseries.dart';
import 'package:greenroot_mobile/features/orders/buyer_order_create_screen.dart';

import '../helpers/fake_api_client.dart';

void main() {
  testWidgets('the picker asks for approved nurseries and shows them', (tester) async {
    final fake = FakeApiClient()..reset();
    fake.route('/nurseries', {
      'nurseries': [{'id': 7, 'name': 'Journey Nursery 9763', 'status': 'APPROVED'}],
      'pagination': {'page': 1, 'per_page': 20, 'total': 1, 'total_pages': 1},
    });
    Nursery? picked;
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fake.apiClient)],
      child: MaterialApp(home: Scaffold(body: NurseryPickerTile(selected: null, onSelected: (n) => picked = n))),
    ),);
    await tester.tap(find.byType(NurseryPickerTile));
    await tester.pumpAndSettle();
    expect(fake.calls.last.query['nursery_status'], 'APPROVED');
    await tester.tap(find.text('Journey Nursery 9763'));
    await tester.pumpAndSettle();
    expect(picked?.id, 7);
  });
}

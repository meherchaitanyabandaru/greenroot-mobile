import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/orders/loading_done_sheet.dart';
import 'package:greenroot_mobile/features/orders/orders.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';

void main() {
  testWidgets(
      'loading completes only after the no-prohibited-items declaration',
      (tester) async {
    final fake = FakeApiClient()
      ..enqueue(response: orderDetailResponse(status: 'LOADED'));
    final order = Order.fromJson(orderJson(status: 'LOADING'));
    Order? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider
              .overrideWith((ref) => OrderRepository(fake.apiClient)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showLoadingDoneSheet(context, order),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Optional · up to 3 · 0/3 added'), findsOneWidget);
    expect(find.bySemanticsLabel('Take photo'), findsNWidgets(3));
    final button = find.widgetWithText(FilledButton, 'Complete Loading');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.text(loadingDeclaration));
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(fake.calls.single.path, endsWith('/complete-loading'));
    expect(fake.calls.single.data, {'declared_no_prohibited_items': true});
    expect(result?.status, 'LOADED');
  });
}

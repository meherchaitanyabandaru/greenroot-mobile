import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/consent/consent.dart';
import 'package:greenroot_mobile/features/orders/loading_done_sheet.dart';
import 'package:greenroot_mobile/features/orders/orders.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';

void main() {
  testWidgets(
      '"I confirm", then the seller ticks each statement: loading completes with both',
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
          consentTemplatesProvider.overrideWith((ref) async => {
                ConsentStep.sellerLoading: const ConsentTemplate(ConsentStep.sellerLoading, 1,
                    'Before the plants leave the nursery', ['Varieties match.', 'Quantities are right.'],),
              },),
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
    // The statement is shown in full; the button that says "I confirm" sends it.
    expect(find.text(loadingDeclaration), findsOneWidget);
    await tester.tap(
        find.widgetWithText(FilledButton, 'I confirm · Complete Loading'),);
    await tester.pumpAndSettle();

    // The seller's confirmation: Confirm stays off until every statement is ticked.
    expect(find.text('Varieties match.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm')).onPressed, isNull);
    expect(fake.calls, isEmpty);
    for (final box in find.byType(Checkbox).evaluate().toList()) {
      await tester.tap(find.byWidget(box.widget));
    }
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(fake.calls.single.path, endsWith('/complete-loading'));
    expect(fake.calls.single.data, {
      'declared_no_prohibited_items': true,
      'consent': {'consent_version': 1, 'accepted': true},
    });
    expect(result?.status, 'LOADED');
  });
}

// Delivery needs the customer: the driver/nursery enters their 4-digit code;
// only nursery staff may deliver without it, giving a reason; the customer
// sees their code and "I received the plants".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/dispatches/delivery_confirmation.dart';
import 'package:greenroot_mobile/features/dispatches/dispatches.dart';

import '../helpers/fake_api_client.dart';

Map<String, dynamic> _json(String status, {Map<String, dynamic> caps = const {}, String? code}) => {
      'id': 7,
      'dispatch_code': 'DSP-20261024-0007',
      'order_id': 9,
      'dispatch_status': status,
      'created_at': '2026-10-24T10:00:00Z',
      'capabilities': caps,
      if (code != null) 'delivery_code': code,
    };

Widget _host(FakeApiClient fake, Dispatch d) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fake.apiClient)],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDeliverSheet(context, ref, d),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  late FakeApiClient fake;
  setUp(() => fake = FakeApiClient()..reset());

  testWidgets('driver must enter the 4-digit code; no way around it', (tester) async {
    final d = Dispatch.fromJson(_json('IN_TRANSIT', caps: {'can_mark_delivered': true}));
    fake.setResponse({'dispatch': _json('DELIVERED')});
    await tester.pumpWidget(_host(fake, d));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final confirm = find.widgetWithText(FilledButton, 'Confirm delivery');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(find.text("Customer can't give the code?"), findsNothing);

    // The 4th digit sends the code by itself.
    await tester.enterText(find.byKey(const Key('deliveryCodeField')), '4821');
    await tester.pumpAndSettle();

    final call = fake.calls.single;
    expect(call.path, endsWith('/dispatches/7/deliver'));
    expect(call.data, {'code': '4821'});
  });

  testWidgets('nursery can deliver without the code, giving a reason', (tester) async {
    final d = Dispatch.fromJson(_json('DISPATCHED',
        caps: {'can_mark_delivered': true, 'can_override_delivery': true},),);
    fake.setResponse({'dispatch': _json('DELIVERED')});
    await tester.pumpWidget(_host(fake, d));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Customer can't give the code?"));
    await tester.pumpAndSettle();
    final mark = find.widgetWithText(FilledButton, 'Mark delivered without the code');
    await tester.enterText(find.byKey(const Key('overrideReasonField')), 'short');
    await tester.pump();
    expect(tester.widget<FilledButton>(mark).onPressed, isNull, reason: 'reason too short');

    await tester.enterText(find.byKey(const Key('overrideReasonField')), 'Phone off; handed to his son');
    await tester.pump();
    await tester.tap(mark);
    await tester.pumpAndSettle();
    expect(fake.calls.single.data, {'override_reason': 'Phone off; handed to his son'});
  });

  testWidgets('customer sees their code and can confirm receipt', (tester) async {
    final d = Dispatch.fromJson(_json('IN_TRANSIT',
        code: '4821', caps: {'can_confirm_receipt': true, 'can_report_issue': true},),);
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fake.apiClient)],
      child: MaterialApp(
        home: Scaffold(body: CustomerDeliveryCard(dispatch: d, onChanged: (_) {})),
      ),
    ),);
    expect(find.text('4 8 2 1'), findsOneWidget);
    expect(find.text('I received the plants'), findsOneWidget);
    expect(find.text('Report a problem'), findsOneWidget);
  });

  testWidgets('no card for someone who is not the customer', (tester) async {
    final d = Dispatch.fromJson(_json('IN_TRANSIT'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CustomerDeliveryCard(dispatch: d, onChanged: (_) {})),
    ),);
    expect(find.byType(Card), findsNothing);
  });

  test('confirmation label says how it was delivered', () {
    Dispatch delivered(String how) => Dispatch.fromJson(
        {..._json('DELIVERED'), 'delivery_confirmation': how, 'delivery_override_reason': 'Phone off'},);
    expect(deliveryConfirmationLabel(delivered('CUSTOMER_CODE')), contains("customer's code"));
    expect(deliveryConfirmationLabel(delivered('UNCONFIRMED')), contains('without customer confirmation: Phone off'));
    expect(deliveryConfirmationLabel(Dispatch.fromJson(_json('IN_TRANSIT'))), isNull);
  });
}

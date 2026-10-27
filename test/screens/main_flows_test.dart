// The money and decision flows, on real API response shapes
// (test/contract/fixtures): what the user sees, and what the app sends.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/buyer/buyer_tab.dart';
import 'package:greenroot_mobile/features/orders/order_detail_screen.dart';
import 'package:greenroot_mobile/features/subscriptions/subscription_payment_screen.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/fixtures.dart';

const _page = {'page': 1, 'per_page': 20, 'total': 1, 'total_pages': 1};

Widget _app(FakeApiClient fake, String who, Widget home) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fake.apiClient), signedInAs(who)],
      child: MaterialApp(home: home),
    );

void main() {
  late FakeApiClient fake;
  setUp(() => fake = FakeApiClient()..reset());

  testWidgets('customer declines a quotation with a reason', (tester) async {
    final q = (fixture('quotation_detail') as Map<String, dynamic>)['quotation'] as Map<String, dynamic>;
    q['status'] = 'CUSTOMER_SENT';
    q['capabilities'] = {'can_accept': true, 'can_reject': true};
    fake
      ..route('/quotations', {'quotations': [q], 'pagination': _page})
      ..route('/orders', {'orders': [], 'pagination': _page})
      ..route('/dispatches', {'dispatches': [], 'pagination': _page})
      ..route('/buyer-reject', {'quotation': {...q, 'status': 'CUSTOMER_REJECTED'}});

    await tester.pumpWidget(_app(fake, 'buyer', const BuyerTab()));
    await tester.pumpAndSettle();
    expect(find.text(q['quotation_code'] as String), findsOneWidget);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Price too high');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Decline Offer'));
    await tester.pumpAndSettle();

    final call = fake.calls.lastWhere((c) => c.path.endsWith('/buyer-reject'));
    expect(call.method, 'POST');
    expect(call.path, endsWith('/quotations/${q['id']}/buyer-reject'));
    expect(call.data, {'reason': 'Price too high'});
  });

  testWidgets('nursery confirms a new order', (tester) async {
    final o = (fixture('order_detail') as Map<String, dynamic>)['order'] as Map<String, dynamic>;
    o['order_status'] = 'PENDING';
    o.remove('lifecycle'); // the captured one describes a completed order
    fake
      ..route('/orders/${o['id']}', {'order': o})
      ..route('/dispatches', {'dispatches': []})
      ..route('/confirm', {'order': {...o, 'order_status': 'CONFIRMED'}});

    // The next action pulses forever, so pump frames instead of settling.
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.pumpWidget(_app(fake, 'owner', OrderDetailScreen(orderId: o['id'] as int)));
    await settle();
    expect(find.text(o['order_number'] as String), findsWidgets);

    await tester.tap(find.text('Confirm Order'));
    await settle();

    final call = fake.calls.lastWhere((c) => c.path.endsWith('/confirm'));
    expect(call.method, 'POST');
    expect(call.path, endsWith('/orders/${o['id']}/confirm'));
  });

  testWidgets('payment screen: three plans, four cycles, priced by the API; pays the chosen one', (tester) async {
    final subs = fixture('subscriptions_me') as Map<String, dynamic>;
    final sub = (subs['subscriptions'] as List).first as Map<String, dynamic>;
    final plans = ((fixture('subscription_plans') as Map)['plans'] as List).cast<Map<String, dynamic>>();
    final basic = plans.firstWhere((p) => p['plan_code'] == 'BASIC');
    fake
      ..route('/subscription-plans', fixture('subscription_plans'))
      ..route('/subscriptions/me', subs);

    await tester.pumpWidget(_app(fake, 'owner', SubscriptionPaymentScreen(subscriptionId: sub['id'] as int)));
    await tester.pumpAndSettle();

    // Only the paid plans, each with its team size and monthly price.
    expect(find.text('Basic'), findsOneWidget);
    expect(find.text('Growth'), findsOneWidget);
    expect(find.text('Enterprise'), findsOneWidget);
    expect(find.text('Free'), findsNothing);
    expect(find.text('Up to 10 managers'), findsOneWidget);
    expect(find.text('MOST POPULAR'), findsOneWidget);

    final scroll = find.byType(Scrollable).first;
    final pay = find.textContaining('Securely');
    Future<void> payShows(String text) async {
      await tester.scrollUntilVisible(pay, 300, scrollable: scroll);
      expect(find.text(text), findsOneWidget);
      await tester.drag(scroll, const Offset(0, 3000)); // back to the top
      await tester.pumpAndSettle();
    }

    // Growth, monthly by default.
    await payShows('Pay ₹499.00 Securely');
    // Quarterly: 5% off, and the saving is spelled out.
    await tester.ensureVisible(find.text('Quarterly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quarterly'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Quarterly saving (5%)'), 300, scrollable: scroll);
    expect(find.text('Quarterly saving (5%)'), findsOneWidget);
    await payShows('Pay ₹1,422.15 Securely');
    // Basic, still quarterly.
    await tester.ensureVisible(find.text('Basic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basic'));
    await tester.pumpAndSettle();
    await payShows('Pay ₹852.15 Securely');

    // Pay (no gateway: mock mode). The chosen plan and cycle go to the API.
    fake.enqueue(type: FakeResponseType.serviceUnavailable); // payment-order: payments off
    fake.enqueue(response: {'subscription': {...sub, 'plan_code': 'BASIC', 'plan_name': 'Basic'}});
    await tester.scrollUntilVisible(pay, 300, scrollable: scroll);
    await tester.ensureVisible(pay);
    await tester.pumpAndSettle();
    await tester.tap(pay);
    await tester.pumpAndSettle();
    final order = fake.calls.lastWhere((c) => c.path.endsWith('/payment-order'));
    final renew = fake.calls.lastWhere((c) => c.path.endsWith('/renew'));
    for (final c in [order, renew]) {
      expect((c.data as Map)['plan_id'], basic['id']);
      expect((c.data as Map)['billing_cycle'], 'QUARTERLY');
    }
    expect(find.text('Payment Successful!'), findsOneWidget);
  });
}

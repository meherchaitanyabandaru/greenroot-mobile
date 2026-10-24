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

  testWidgets('payment screen prices the plan from the API, per billing cycle', (tester) async {
    final subs = fixture('subscriptions_me') as Map<String, dynamic>;
    final sub = (subs['subscriptions'] as List).first as Map<String, dynamic>;
    fake
      ..route('/subscription-plans', fixture('subscription_plans'))
      ..route('/subscriptions/me', subs);
    final growth = ((fixture('subscription_plans') as Map)['plans'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['plan_code'] == 'GROWTH');

    await tester.pumpWidget(_app(fake, 'owner', SubscriptionPaymentScreen(subscriptionId: sub['id'] as int)));
    await tester.pumpAndSettle();

    String rupees(num v) => '₹${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
    final sixMonth = growth['six_month_price'] as num;
    final yearly = growth['yearly_price'] as num;
    // Both cycles are priced from the API's plan.
    expect(find.text('${rupees(sixMonth)} / 6 months'), findsOneWidget);
    expect(find.text('${rupees(yearly)} / year'), findsOneWidget);

    // 6 months is preselected; switching cycles reprices the Pay button.
    final pay = find.textContaining('Securely');
    await tester.scrollUntilVisible(pay, 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Pay ${rupees(sixMonth)}.00 Securely'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000)); // back to the top
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(pay, 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Pay ${rupees(yearly)}.00 Securely'), findsOneWidget);
  });
}

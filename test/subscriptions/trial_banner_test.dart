// The home banner: a calm note through the free trial, a warning in its last
// week, and for a paid plan only in the last week (a monthly plan would
// otherwise read "expires" all month).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/subscriptions/subscription_models.dart';
import 'package:greenroot_mobile/features/subscriptions/subscription_provider.dart';
import 'package:greenroot_mobile/features/subscriptions/trial_banner_widget.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/fixtures.dart';

SubscriptionModel _sub(
  String code,
  String name,
  int days, {
  String status = 'ACTIVE',
}) =>
    SubscriptionModel.fromJson({
      'id': 1,
      'subscription_code': 'SUB-1',
      'plan_code': code,
      'plan_name': name,
      'start_date': '2026-10-27',
      'end_date': '2026-11-26',
      'subscription_status': status,
      'days_remaining': days,
    });

Future<void> _show(WidgetTester tester, SubscriptionModel sub) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [
          signedInAs('owner'),
          subscriptionProvider.overrideWith((ref) async => sub),
        ],
        child: const MaterialApp(home: Scaffold(body: TrialExpiryBanner())),
      ),
    );

void main() {
  // The session helper needs the shared API client.
  setUp(() => FakeApiClient()..reset());
  final cases = <String, (SubscriptionModel, String?, String?)>{
    'trial, first day': (
      _sub('TRIAL', 'Community Trial', 30),
      'Free trial: 30 days left. Unlimited orders and quotations, on us.',
      'See plans'
    ),
    'trial, last 2 days': (
      _sub('TRIAL', 'Community Trial', 2),
      'Your free trial ends in 2 days. Choose a plan to keep selling.',
      'Choose plan'
    ),
    'trial, last day': (
      _sub('TRIAL', 'Community Trial', 0),
      'Your free trial ends today. Choose a plan to keep selling.',
      'Choose plan'
    ),
    'monthly Gold mid-month': (_sub('GROWTH', 'Gold', 20), null, null),
    'Gold, last 5 days': (
      _sub('GROWTH', 'Gold', 5),
      'Your Gold plan ends in 5 days.',
      'Renew'
    ),
    'expired': (
      _sub('GROWTH', 'Gold', -3, status: 'EXPIRED'),
      'Your subscription has ended. Choose a plan to keep selling.',
      'Renew'
    ),
  };
  for (final c in cases.entries) {
    testWidgets(c.key, (tester) async {
      await _show(tester, c.value.$1);
      await tester.pumpAndSettle(); // the subscription loads
      if (c.value.$2 == null) {
        expect(find.byType(TextButton), findsNothing);
      } else {
        expect(find.text(c.value.$2!), findsOneWidget);
        expect(find.text(c.value.$3!), findsOneWidget);
      }
    });
  }
}

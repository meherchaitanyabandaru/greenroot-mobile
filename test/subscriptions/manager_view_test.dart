// A manager's subscription screen shows the owner's plan as it really is:
// "on hold" while it is paused or lapsed (it used to say ACTIVE regardless).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/subscriptions/subscription_screen.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/fixtures.dart';

void main() {
  testWidgets('paused nursery plan reads as on hold for its manager',
      (tester) async {
    final fake = FakeApiClient()..reset();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fake.apiClient),
          signedInAs('manager'),
        ],
        child: const MaterialApp(home: SubscriptionScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ON HOLD'), findsOneWidget);
    expect(find.text('ACTIVE'), findsNothing);
    final line = find.text('Plan not active — owner must renew');
    await tester.scrollUntilVisible(line, 200, scrollable: find.byType(Scrollable).first);
    expect(line, findsOneWidget);
  });
}

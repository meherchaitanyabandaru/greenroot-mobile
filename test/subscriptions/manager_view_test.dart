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
    // The screen reloads the workspaces on open.
    fake.route('/me/workspaces', fixture('workspaces_manager'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fake.apiClient),
          signedInAs('manager'),
        ],
        child: const MaterialApp(home: SubscriptionScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('ON HOLD'), findsOneWidget);
    expect(find.text('ACTIVE'), findsNothing);
    final line = find.text('Plan not active — owner must renew');
    await tester.scrollUntilVisible(
      line,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(line, findsOneWidget);
  });

  testWidgets('a plan resumed since sign-in shows as active (reloaded on open)',
      (tester) async {
    final fake = FakeApiClient()..reset();
    final ws =
        (fixture('workspaces_manager') as List).cast<Map<String, dynamic>>();
    ws.last['subscription_active'] = true; // resumed after this session began
    fake.route('/me/workspaces', ws);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fake.apiClient),
          signedInAs('manager'), // the session still says paused
        ],
        child: const MaterialApp(home: SubscriptionScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('ON HOLD'), findsNothing);
  });
}

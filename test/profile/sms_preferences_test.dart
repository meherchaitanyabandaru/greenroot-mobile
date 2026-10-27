// SMS preferences: OTP/payment SMS are always on; only promotional SMS is a
// user choice, saved via PUT /sms/preferences/me.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/constants/api_constants.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/core/testing/test_keys.dart';
import 'package:greenroot_mobile/features/profile/sms_preferences_screen.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_provider_container.dart';

Map<String, dynamic> prefs({required bool optIn}) => {
      'preferences': {
        'user_id': 3,
        'promotional_opt_in': optIn,
        'promotional_consent_at': optIn ? '2026-10-16T10:00:00Z' : null,
      },
    };

void main() {
  late FakeApiClient fake;

  setUp(() => fake = FakeApiClient());

  test('repository reads and updates promotional consent', () async {
    final repo = makeTestContainer(fake.apiClient)
        .read(smsPreferencesRepositoryProvider);

    fake.enqueue(response: prefs(optIn: false));
    expect((await repo.get()).promotionalOptIn, isFalse);

    fake.enqueue(response: prefs(optIn: true));
    final updated = await repo.setPromotional(true);
    expect(updated.promotionalOptIn, isTrue);
    expect(updated.consentAt, isNotNull);

    expect(fake.calls.map((c) => '${c.method} ${c.path}'), [
      'GET ${ApiConstants.smsPreferencesMe}',
      'PUT ${ApiConstants.smsPreferencesMe}',
    ]);
  });

  testWidgets('toggling offers saves consent; service SMS stay always on',
      (tester) async {
    fake.enqueue(response: prefs(optIn: false));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(fake.apiClient)],
        child: const MaterialApp(home: SmsPreferencesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login OTP'), findsOneWidget);
    expect(find.text('Always on'), findsNWidgets(2));
    final toggle = find.byKey(const Key(TestKeys.smsPromotionalSwitch));
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

    fake.enqueue(response: prefs(optIn: true)); // PUT
    fake.enqueue(response: prefs(optIn: true)); // refetch
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(fake.calls.where((c) => c.method == 'PUT'), hasLength(1));
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(find.text('You will receive offers by SMS'), findsOneWidget);
  });
}

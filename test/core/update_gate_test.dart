// Below CLIENT_MIN_VERSION only the update screen shows; a failed check never
// locks the user out.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/core/update/update_gate.dart';

import '../helpers/fake_api_client.dart';

Widget _app(FakeApiClient fake) => ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fake.apiClient),
        appVersionProvider.overrideWith((ref) async => '1.0.0'),
      ],
      child: const MaterialApp(home: UpdateGate(child: Text('home'))),
    );

void main() {
  late FakeApiClient fake;
  setUp(() => fake = FakeApiClient()..reset());

  testWidgets('below the minimum: only the update screen', (tester) async {
    fake.route('/app/version-policy', {
      'policy': {'update_required': true, 'update_url': 'https://play.google.com/store/apps/details?id=in.greenroot'},
    });
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.text('home'), findsNothing);
    final call = fake.calls.single;
    expect(call.query['version'], '1.0.0');
    expect(call.query['platform'], anyOf('android', 'ios'));
  });

  testWidgets('up to date: the app', (tester) async {
    fake.route('/app/version-policy', {'policy': {'update_required': false}});
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('check fails (offline): the app, never a lock-out', (tester) async {
    fake.setError(FakeResponseType.networkError);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('Update required'), findsNothing);
  });
}

// The first screen everyone sees: validation and the OTP request.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/core/testing/test_keys.dart';
import 'package:greenroot_mobile/features/auth/presentation/screens/login_screen.dart';

import '../helpers/fake_api_client.dart';

void main() {
  late FakeApiClient fake;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    fake = FakeApiClient()..reset();
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/otp', builder: (_, s) => Text('OTP for ${s.uri.queryParameters['mobile']}')),
    ],);
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fake.apiClient)],
      child: MaterialApp.router(routerConfig: router),
    ),);
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester) async {
    final button = find.byKey(const Key(TestKeys.loginSendOtpButton));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('a valid number and the terms are required before an OTP is sent', (tester) async {
    await pumpLogin(tester);

    await send(tester);
    expect(find.text('Mobile number is required'), findsOneWidget);

    await tester.enterText(find.byKey(const Key(TestKeys.loginMobileField)), '12345');
    await send(tester);
    expect(find.text('Enter a 10-digit mobile number starting with 6, 7, 8 or 9'), findsOneWidget);

    await tester.enterText(find.byKey(const Key(TestKeys.loginMobileField)), '9811100001');
    await send(tester);
    expect(find.text('Please agree to the Terms & Conditions and Privacy Policy'), findsOneWidget);
    expect(fake.calls, isEmpty); // nothing sent yet

    await tester.tap(find.byKey(const Key(TestKeys.loginAgreeCheckbox)));
    fake.route('/auth/send-otp', {'message': 'OTP sent'});
    await send(tester);

    final call = fake.calls.single;
    expect(call.path, endsWith('/auth/send-otp'));
    expect(call.data['mobile'], '9811100001');
    expect(find.text('OTP for 9811100001'), findsOneWidget);
  });
}

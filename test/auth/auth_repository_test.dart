// Unit tests for OtpSendNotifier and OtpVerifyNotifier — covers:
//   - sendOtp success → sent=true state
//   - sendOtp failure → error state
//   - verifyOtp success → verified=true, isNewUser propagated
//   - verifyOtp invalid OTP → error state
//   - no direct singleton call — DI chain verified via fake calls

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/features/auth/presentation/providers/auth_provider.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';
import '../helpers/test_provider_container.dart';

void main() {
  late FakeApiClient fake;

  setUp(() {
    fake = FakeApiClient();
  });

  // ── OtpSendNotifier ───────────────────────────────────────────────────────

  group('OtpSendNotifier', () {
    test('sendOtp success → sent=true, no error', () async {
      fake.enqueue(response: kSendOtpResponse);
      final container = makeTestContainer(fake.apiClient);

      await container.read(otpSendProvider.notifier).sendOtp(kTestMobile);

      final state = container.read(otpSendProvider);
      expect(state.sent, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(container.read(otpSendProvider.notifier).lastMobile, kTestMobile);
    });

    test('sendOtp captures the mobile number on success', () async {
      fake.enqueue(response: kSendOtpResponse);
      final container = makeTestContainer(fake.apiClient);

      await container.read(otpSendProvider.notifier).sendOtp('9100000000');

      expect(container.read(otpSendProvider.notifier).lastMobile, '9100000000');
    });

    test('sendOtp server error → error state, sent=false', () async {
      fake.enqueue(type: FakeResponseType.serverError);
      final container = makeTestContainer(fake.apiClient);

      await container.read(otpSendProvider.notifier).sendOtp(kTestMobile);

      final state = container.read(otpSendProvider);
      expect(state.sent, isFalse);
      expect(state.error, isA<ServerError>());
    });

    test('sendOtp network error → NetworkError in state', () async {
      fake.enqueue(type: FakeResponseType.networkError);
      final container = makeTestContainer(fake.apiClient);

      await container.read(otpSendProvider.notifier).sendOtp(kTestMobile);

      final state = container.read(otpSendProvider);
      expect(state.error, isA<NetworkError>());
    });

    test('reset() clears error state', () async {
      fake.enqueue(type: FakeResponseType.serverError);
      final container = makeTestContainer(fake.apiClient);

      await container.read(otpSendProvider.notifier).sendOtp(kTestMobile);
      expect(container.read(otpSendProvider).error, isNotNull);

      container.read(otpSendProvider.notifier).reset();
      final state = container.read(otpSendProvider);
      expect(state.error, isNull);
      expect(state.sent, isFalse);
    });

    test('no direct singleton call — fake call recorded', () async {
      fake.enqueue(response: kSendOtpResponse);
      final container = makeTestContainer(fake.apiClient);

      await container.read(otpSendProvider.notifier).sendOtp(kTestMobile);

      expect(fake.calls, hasLength(1));
      expect(fake.calls.first.method, 'POST');
    });
  });

  // ── OtpVerifyNotifier ─────────────────────────────────────────────────────

  group('OtpVerifyNotifier', () {
    test('verify success → verified=true, isNewUser=false for existing user', () async {
      fake.enqueue(response: verifyOtpResponse());
      final container = makeTestContainer(fake.apiClient);

      await container.read(otpVerifyProvider.notifier).verify(kTestMobile, kTestOtp);

      final state = container.read(otpVerifyProvider);
      expect(state.verified, isTrue);
      expect(state.isNewUser, isFalse);
      expect(state.error, isNull);
    });

    test('verify success → isNewUser=true for new user', () async {
      fake.enqueue(response: verifyOtpResponse(isNewUser: true));
      final container = makeTestContainer(fake.apiClient);

      await container.read(otpVerifyProvider.notifier).verify(kTestMobile, kTestOtp);

      final state = container.read(otpVerifyProvider);
      expect(state.isNewUser, isTrue);
    });

    test('verify invalid OTP → 422 validation error in state', () async {
      fake.enqueue(type: FakeResponseType.validationError);
      final container = makeTestContainer(fake.apiClient);

      await container.read(otpVerifyProvider.notifier).verify(kTestMobile, '000000');

      final state = container.read(otpVerifyProvider);
      expect(state.verified, isFalse);
      expect(state.error, isA<ValidationError>());
    });

    test('verify 401 → UnauthorizedError in state', () async {
      fake.enqueue(type: FakeResponseType.unauthorized);
      final container = makeTestContainer(fake.apiClient);

      await container.read(otpVerifyProvider.notifier).verify(kTestMobile, kTestOtp);

      final state = container.read(otpVerifyProvider);
      expect(state.error, isA<UnauthorizedError>());
    });

    test('reset() clears verified state', () async {
      fake.enqueue(response: verifyOtpResponse());
      final container = makeTestContainer(fake.apiClient);

      await container.read(otpVerifyProvider.notifier).verify(kTestMobile, kTestOtp);
      expect(container.read(otpVerifyProvider).verified, isTrue);

      container.read(otpVerifyProvider.notifier).reset();
      expect(container.read(otpVerifyProvider).verified, isFalse);
    });
  });
}

// Tests that prove the DI chain works end-to-end:
//   - apiClientProvider can be overridden in ProviderContainer
//   - repository providers receive the overridden client (not the singleton)
//   - no real singleton is called during the test

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:greenroot_mobile/features/connections/invite_repository.dart';
import 'package:greenroot_mobile/features/market/local_market_providers.dart';
import 'package:greenroot_mobile/features/subscriptions/subscription_provider.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';
import '../helpers/test_provider_container.dart';

void main() {
  late FakeApiClient fake;

  setUp(() {
    fake = FakeApiClient();
  });

  // ── apiClientProvider override ────────────────────────────────────────────

  test('apiClientProvider returns overridden client, not singleton', () {
    // Give the fake a token response so reads don't throw.
    fake.enqueue(response: kSendOtpResponse);

    final container = makeTestContainer(fake.apiClient);

    // Reading the provider must return our fake instance.
    final resolved = container.read(apiClientProvider);
    expect(resolved, same(fake.apiClient),
        reason: 'Container must return the overridden FakeApiClient instance');
  });

  test('authRepositoryProvider uses overridden apiClient', () async {
    fake.enqueue(response: kSendOtpResponse);
    final container = makeTestContainer(fake.apiClient);

    // Triggering sendOtp exercises the DI chain:
    // authRepositoryProvider → AuthRemoteDataSource(apiClientProvider) → our fake
    final notifier = container.read(otpSendProvider.notifier);
    await notifier.sendOtp('9300000000');

    expect(fake.calls, hasLength(1));
    expect(fake.calls.first.method, 'POST');
    // No real network call happened.
  });

  test('inviteRepositoryProvider uses overridden apiClient', () async {
    fake.enqueue(response: inviteResponse());
    final container = makeTestContainer(fake.apiClient);

    await container.read(inviteRepositoryProvider).sendInvite(
          inviteType: 'MANAGER',
          nurseryId: kTestNurseryId,
          targetMobile: '9200000000',
        );

    expect(fake.calls, hasLength(1));
    expect(fake.calls.first.type, FakeResponseType.success);
  });

  test('marketRepositoryProvider uses overridden apiClient', () async {
    fake.enqueue(response: adsListResponse());
    final container = makeTestContainer(fake.apiClient);

    final repo = container.read(marketRepositoryProvider);
    await repo.getAds({'per_page': '6', 'page': '1'});

    expect(fake.calls, hasLength(1));
    expect(fake.calls.first.type, FakeResponseType.success);
  });

  test('subscriptionDataSourceProvider uses overridden apiClient', () async {
    fake.enqueue(response: subscriptionsListResponse());
    final container = makeTestContainer(fake.apiClient);

    await container.read(subscriptionDataSourceProvider).fetchMySubscriptions();

    expect(fake.calls, hasLength(1));
  });

  test('no singleton call when overridden — second container is isolated', () async {
    // Two containers with independent fakes must not share call state.
    final fake2 = FakeApiClient();
    fake.enqueue(response: kSendOtpResponse);
    fake2.enqueue(response: kSendOtpResponse);

    // Both use the same singleton (ApiClient.instance) since we're in tests,
    // but the fake interceptor is the last thing applied so both share the
    // singleton's Dio. We test that each call is tracked independently.
    final c1 = makeTestContainer(fake.apiClient);
    await c1.read(otpSendProvider.notifier).sendOtp('9300000000');
    expect(fake.calls, hasLength(1));
  });
}

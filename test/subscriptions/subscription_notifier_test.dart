// Unit tests for subscription providers — covers:
//   - subscriptionProvider loads active subscription
//   - subscriptionProvider returns null when no subscriptions exist
//   - subscriptionProvider picks most recent when no active found
//   - subscriptionPlansProvider loads plans
//   - renewSubscription returns updated subscription
//   - cancelSubscription returns CANCELLED status
//   - failed renew/cancel throws and does not show false success

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/features/subscriptions/subscription_provider.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';
import '../helpers/test_provider_container.dart';

void main() {
  late FakeApiClient fake;

  setUp(() {
    fake = FakeApiClient();
  });

  // ── subscriptionProvider ──────────────────────────────────────────────────

  group('subscriptionProvider', () {
    test('active subscription is returned when status=ACTIVE', () async {
      fake.enqueue(response: subscriptionsListResponse(status: 'ACTIVE'));
      final container = makeTestContainer(fake.apiClient);

      final sub = await container.read(subscriptionProvider.future);

      expect(sub, isNotNull);
      expect(sub!.id, kTestSubscriptionId);
      expect(sub.isActive, isTrue);
    });

    test('returns null when no subscriptions exist', () async {
      fake.enqueue(response: {'subscriptions': []});
      final container = makeTestContainer(fake.apiClient);

      final sub = await container.read(subscriptionProvider.future);

      expect(sub, isNull);
    });

    test('returns most recent subscription when none active', () async {
      final response = {
        'subscriptions': [
          {
            ...subscriptionJson(status: 'EXPIRED'),
            'end_date': '2024-01-01',
          },
          {
            ...subscriptionJson(status: 'EXPIRED'),
            'id': 402,
            'subscription_code': 'SUB-00402',
            'end_date': '2024-06-01', // More recent
          },
        ],
      };
      fake.enqueue(response: response);
      final container = makeTestContainer(fake.apiClient);

      final sub = await container.read(subscriptionProvider.future);

      expect(sub, isNotNull);
      expect(sub!.id, 402, reason: 'Most recent expired sub must be returned');
    });

    test('server error propagates as AsyncError', () async {
      fake.enqueue(type: FakeResponseType.serverError);
      final container = makeTestContainer(fake.apiClient);

      expect(
        () => container.read(subscriptionProvider.future),
        throwsA(isA<ServerError>()),
      );
    });
  });

  // ── subscriptionPlansProvider ─────────────────────────────────────────────

  group('subscriptionPlansProvider', () {
    test('loads plans list', () async {
      fake.enqueue(response: subscriptionPlansResponse());
      final container = makeTestContainer(fake.apiClient);

      final plans = await container.read(subscriptionPlansProvider.future);

      expect(plans, hasLength(1));
      expect(plans.first.planCode, 'PRO');
      expect(plans.first.planName, 'Pro Plan');
    });

    test('empty plans returns empty list without throwing', () async {
      fake.enqueue(response: {'plans': []});
      final container = makeTestContainer(fake.apiClient);

      final plans = await container.read(subscriptionPlansProvider.future);
      expect(plans, isEmpty);
    });
  });

  // ── SubscriptionRemoteDataSource mutations ────────────────────────────────

  group('renewSubscription', () {
    test('renew returns updated subscription with ACTIVE status', () async {
      fake.enqueue(response: renewSubscriptionResponse());
      final container = makeTestContainer(fake.apiClient);
      final ds = container.read(subscriptionDataSourceProvider);

      final sub = await ds.renewSubscription(
        subscriptionId: kTestSubscriptionId,
        billingCycle: 'YEARLY',
        paymentMethod: 'RAZORPAY',
      );

      expect(sub.isActive, isTrue);
      expect(sub.id, kTestSubscriptionId);
    });

    test('renew server error throws ServerError — no false success', () async {
      fake.enqueue(type: FakeResponseType.serverError);
      final container = makeTestContainer(fake.apiClient);
      final ds = container.read(subscriptionDataSourceProvider);

      expect(
        () => ds.renewSubscription(
          subscriptionId: kTestSubscriptionId,
          billingCycle: 'YEARLY',
          paymentMethod: 'RAZORPAY',
        ),
        throwsA(isA<ServerError>()),
        reason: 'Failed renewal must throw — no silent success allowed',
      );
    });

    test('renew 401 throws UnauthorizedError', () async {
      fake.enqueue(type: FakeResponseType.unauthorized);
      final container = makeTestContainer(fake.apiClient);
      final ds = container.read(subscriptionDataSourceProvider);

      expect(
        () => ds.renewSubscription(
          subscriptionId: kTestSubscriptionId,
          billingCycle: 'SIX_MONTHS',
          paymentMethod: 'RAZORPAY',
        ),
        throwsA(isA<UnauthorizedError>()),
      );
    });
  });

  group('cancelSubscription', () {
    test('cancel returns subscription with CANCELLED status', () async {
      fake.enqueue(response: cancelSubscriptionResponse());
      final container = makeTestContainer(fake.apiClient);
      final ds = container.read(subscriptionDataSourceProvider);

      final sub = await ds.cancelSubscription(kTestSubscriptionId, 'Too expensive');

      expect(sub.isCancelled, isTrue);
    });

    test('cancel server error throws — subscription not falsely cancelled', () async {
      fake.enqueue(type: FakeResponseType.serverError);
      final container = makeTestContainer(fake.apiClient);
      final ds = container.read(subscriptionDataSourceProvider);

      expect(
        () => ds.cancelSubscription(kTestSubscriptionId, null),
        throwsA(isA<ServerError>()),
        reason: 'Failed cancel must throw — no silent state update',
      );
    });
  });
}

// Subscription payments: the API prices a Razorpay order; the checkout result
// goes back with renew/create for verification. No keys on the API = mock.

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/subscriptions/razorpay_checkout.dart';
import 'package:greenroot_mobile/features/subscriptions/subscription_provider.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';
import '../helpers/test_provider_container.dart';

void main() {
  late FakeApiClient fake;
  setUp(() => fake = FakeApiClient());

  test('payment order is read from the API', () async {
    fake.enqueue(
      response: {
        'payment_order': {
          'order_id': 'order_1',
          'amount': 1000000,
          'currency': 'INR',
          'key_id': 'rzp_test_k',
        },
      },
    );
    final ds =
        makeTestContainer(fake.apiClient).read(subscriptionDataSourceProvider);
    final order = await ds.createPaymentOrder(
      subscriptionId: kTestSubscriptionId,
      planId: 3,
      billingCycle: 'YEARLY',
    );
    expect(
      (order!.orderId, order.amountPaise, order.keyId),
      ('order_1', 1000000, 'rzp_test_k'),
    );
    final body = fake.calls.single.data as Map;
    expect(body['subscription_id'], kTestSubscriptionId);
    expect(
      body.containsKey('amount'),
      isFalse,
      reason: 'the API prices the order, never the app',
    );
  });

  test('503 means online payments are off: fall back to mock', () async {
    fake.setError(FakeResponseType.serviceUnavailable);
    final ds =
        makeTestContainer(fake.apiClient).read(subscriptionDataSourceProvider);
    expect(
      await ds.createPaymentOrder(billingCycle: 'YEARLY', planId: 3),
      isNull,
    );
  });

  test('renew sends the checkout result for verification', () async {
    fake.enqueue(response: renewSubscriptionResponse());
    final ds =
        makeTestContainer(fake.apiClient).read(subscriptionDataSourceProvider);
    await ds.renewSubscription(
      subscriptionId: kTestSubscriptionId,
      billingCycle: 'YEARLY',
      paymentMethod: 'UPI',
      paid: const CheckoutResult('order_1', 'pay_1', 'sig_1'),
    );
    final body = fake.calls.single.data as Map;
    expect(body['provider'], 'razorpay');
    expect(body['provider_order_id'], 'order_1');
    expect(body['provider_payment_id'], 'pay_1');
    expect(body['provider_signature'], 'sig_1');
  });

  test('without a checkout result renew stays mock', () async {
    fake.enqueue(response: renewSubscriptionResponse());
    final ds =
        makeTestContainer(fake.apiClient).read(subscriptionDataSourceProvider);
    await ds.renewSubscription(
      subscriptionId: kTestSubscriptionId,
      billingCycle: 'YEARLY',
      paymentMethod: 'UPI',
    );
    expect((fake.calls.single.data as Map)['provider'], 'razorpay_mock');
  });
}

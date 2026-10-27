// An owner who cancels keeps what they paid for: the app asks the API to
// cancel at the end of the period, never immediately (no refund comes back).
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/subscriptions/subscription_datasource.dart';
import 'package:greenroot_mobile/features/subscriptions/subscription_models.dart';

import '../helpers/fake_api_client.dart';

void main() {
  test('cancel is at the end of the paid period', () async {
    final fake = FakeApiClient()..reset();
    fake.enqueue(
      response: {
        'subscription': {
          'id': 9,
          'subscription_code': 'SUB-9',
          'plan_code': 'ENTERPRISE',
          'plan_name': 'Platinum',
          'start_date': '2026-12-27',
          'end_date': '2027-12-26',
          'subscription_status': 'ACTIVE',
          'cancel_requested_at': '2026-10-27T08:00:00Z',
        },
      },
    );
    final sub = await SubscriptionRemoteDataSource(fake.apiClient)
        .cancelSubscription(9, null);
    final call = fake.calls.single;
    expect(call.path, endsWith('/subscriptions/9/cancel'));
    expect((call.data as Map)['cancel_immediately'], isFalse);
    expect(sub.status, 'ACTIVE');
    expect(sub.cancelRequestedAt, isNotNull);
  });

  test('no pending cancellation reads as null', () {
    final s = SubscriptionModel.fromJson({
      'id': 1,
      'subscription_code': 'SUB-1',
      'start_date': '2026-10-27',
      'subscription_status': 'ACTIVE',
    });
    expect(s.cancelRequestedAt, isNull);
  });
}

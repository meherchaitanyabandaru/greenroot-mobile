import '../../../../core/errors/app_error.dart';
import '../../../../core/network/api_client.dart';
import 'subscription_models.dart';

class SubscriptionRemoteDataSource {
  final ApiClient _client;
  const SubscriptionRemoteDataSource(this._client);

  Future<List<SubscriptionModel>> fetchMySubscriptions() async {
    final res = await _client.get('/api/v1/subscriptions/me');
    final list = res['subscriptions'] as List<dynamic>? ?? [];
    return list
        .map((e) => SubscriptionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SubscriptionPlan>> fetchPlans() async {
    final res = await _client.get('/api/v1/subscription-plans');
    final list = res['plans'] as List<dynamic>? ?? [];
    return list
        .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubscriptionModel> renewSubscription({
    required int subscriptionId,
    required String billingCycle,
    required String paymentMethod,
    String provider = 'razorpay_mock',
    String? providerOrderId,
  }) async {
    final body = {
      'billing_cycle': billingCycle,
      'payment_method': paymentMethod,
      'provider': provider,
      'provider_order_id':
          providerOrderId ?? 'MOCK-ORDER-${DateTime.now().millisecondsSinceEpoch}',
    };
    final res = await _client.post(
        '/api/v1/subscriptions/$subscriptionId/renew', data: body);
    final sub = res['subscription'] as Map<String, dynamic>?;
    if (sub == null) throw ServerError(500, 'Invalid response from server');
    return SubscriptionModel.fromJson(sub);
  }

  Future<SubscriptionModel> cancelSubscription(
      int subscriptionId, String? reason) async {
    final body = <String, dynamic>{
      'cancel_immediately': true,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    final res = await _client.post(
        '/api/v1/subscriptions/$subscriptionId/cancel', data: body);
    final sub = res['subscription'] as Map<String, dynamic>?;
    if (sub == null) throw ServerError(500, 'Invalid response from server');
    return SubscriptionModel.fromJson(sub);
  }

  Future<List<SubscriptionPayment>> fetchPayments(int subscriptionId) async {
    final res =
        await _client.get('/api/v1/subscriptions/$subscriptionId/payments');
    final list = res['payments'] as List<dynamic>? ?? [];
    return list
        .map((e) => SubscriptionPayment.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

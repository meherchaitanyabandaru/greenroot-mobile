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
    int? planId,
    required String billingCycle,
    required String paymentMethod,
    String provider = 'razorpay_mock',
    String? providerOrderId,
    String? promoCode,
  }) async {
    final body = <String, dynamic>{
      if (planId != null) 'plan_id': planId,
      'billing_cycle': billingCycle,
      'payment_method': paymentMethod,
      'provider': provider,
      'provider_order_id':
          providerOrderId ?? 'MOCK-ORDER-${DateTime.now().millisecondsSinceEpoch}',
      if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
    };
    final res = await _client.post(
        '/api/v1/subscriptions/$subscriptionId/renew', data: body,);
    final sub = res['subscription'] as Map<String, dynamic>?;
    if (sub == null) throw const ServerError(500, 'Invalid response from server');
    return SubscriptionModel.fromJson(sub);
  }

  /// POST /subscriptions — first subscription, or after an old one is gone.
  Future<SubscriptionModel> createSubscription({
    required int planId,
    required String billingCycle,
    required String paymentMethod,
    String? promoCode,
  }) async {
    final res = await _client.post('/api/v1/subscriptions', data: {
      'plan_id': planId,
      'billing_cycle': billingCycle,
      'payment_method': paymentMethod,
      'provider': 'razorpay_mock',
      'provider_order_id': 'MOCK-ORDER-${DateTime.now().millisecondsSinceEpoch}',
      if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
    },);
    final sub = res['subscription'] as Map<String, dynamic>?;
    if (sub == null) throw const ServerError(500, 'Invalid response from server');
    return SubscriptionModel.fromJson(sub);
  }

  Future<Map<String, dynamic>> validatePromo({
    required String promoCode,
    required String planCode,
    required String billingCycle,
  }) async {
    final res = await _client.post('/api/v1/subscription-promos/validate', data: {
      'promo_code': promoCode,
      'plan_code': planCode,
      'billing_cycle': billingCycle,
    },);
    return (res['validation'] as Map<String, dynamic>?) ?? {};
  }

  Future<SubscriptionModel> cancelSubscription(
      int subscriptionId, String? reason,) async {
    final body = <String, dynamic>{
      'cancel_immediately': true,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    final res = await _client.post(
        '/api/v1/subscriptions/$subscriptionId/cancel', data: body,);
    final sub = res['subscription'] as Map<String, dynamic>?;
    if (sub == null) throw const ServerError(500, 'Invalid response from server');
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import 'subscription_datasource.dart';
import 'subscription_models.dart';

final _dataSourceProvider = Provider<SubscriptionRemoteDataSource>(
  (ref) => SubscriptionRemoteDataSource(ApiClient.instance),
);

/// Current user's active subscription (null if none).
final subscriptionProvider = FutureProvider.autoDispose<SubscriptionModel?>((ref) async {
  final ds = ref.watch(_dataSourceProvider);
  final list = await ds.fetchMySubscriptions();
  if (list.isEmpty) return null;
  final active = list.where((s) => s.isActive).toList();
  if (active.isNotEmpty) return active.first;
  list.sort((a, b) => (b.endDate ?? DateTime(0)).compareTo(a.endDate ?? DateTime(0)));
  return list.first;
});

/// All subscription plans available.
final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) {
  return ref.watch(_dataSourceProvider).fetchPlans();
});

/// Payment history for a subscription.
final subscriptionPaymentsProvider =
    FutureProvider.autoDispose.family<List<SubscriptionPayment>, int>(
        (ref, subscriptionId) {
  return ref.watch(_dataSourceProvider).fetchPayments(subscriptionId);
});

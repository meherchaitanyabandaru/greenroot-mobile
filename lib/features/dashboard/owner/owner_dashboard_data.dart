import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class OrderMetrics {
  final int total;
  final int pending;
  final int confirmed;
  final int delivered;
  final int cancelled;

  const OrderMetrics({
    this.total = 0,
    this.pending = 0,
    this.confirmed = 0,
    this.delivered = 0,
    this.cancelled = 0,
  });

  factory OrderMetrics.fromJson(Map<String, dynamic> j) => OrderMetrics(
        total: (j['total'] as num?)?.toInt() ?? 0,
        pending: (j['pending'] as num?)?.toInt() ?? 0,
        confirmed: (j['confirmed'] as num?)?.toInt() ?? 0,
        delivered: (j['delivered'] as num?)?.toInt() ?? 0,
        cancelled: (j['cancelled'] as num?)?.toInt() ?? 0,
      );

  int get active => total - delivered - cancelled;
}

class QuoteMetrics {
  final int total;
  final int pending;
  final int approved;
  final int rejected;

  const QuoteMetrics({
    this.total = 0,
    this.pending = 0,
    this.approved = 0,
    this.rejected = 0,
  });

  factory QuoteMetrics.fromJson(Map<String, dynamic> j) => QuoteMetrics(
        total: (j['total'] as num?)?.toInt() ?? 0,
        pending: (j['pending'] as num?)?.toInt() ?? 0,
        approved: (j['approved'] as num?)?.toInt() ?? 0,
        rejected: (j['rejected'] as num?)?.toInt() ?? 0,
      );
}

class InventoryMetrics {
  final int totalItems;
  final int available;

  const InventoryMetrics({this.totalItems = 0, this.available = 0});

  factory InventoryMetrics.fromJson(Map<String, dynamic> j) => InventoryMetrics(
        totalItems: (j['total_items'] as num?)?.toInt() ?? 0,
        available: (j['available'] as num?)?.toInt() ?? 0,
      );
}

class ConnectionMetrics {
  final int managers;
  final int drivers;
  final int customers;

  const ConnectionMetrics({this.managers = 0, this.drivers = 0, this.customers = 0});

  factory ConnectionMetrics.fromJson(Map<String, dynamic> j) => ConnectionMetrics(
        managers: (j['managers'] as num?)?.toInt() ?? 0,
        drivers: (j['drivers'] as num?)?.toInt() ?? 0,
        customers: (j['customers'] as num?)?.toInt() ?? 0,
      );

  int get total => managers + drivers + customers;
}

class OwnerDashboardData {
  final int? nurseryId;
  final String? nurseryName;
  final OrderMetrics sellOrders;
  final OrderMetrics buyOrders;
  final QuoteMetrics sellQuotations;
  final QuoteMetrics buyQuotations;
  final InventoryMetrics inventory;
  final ConnectionMetrics connections;

  const OwnerDashboardData({
    this.nurseryId,
    this.nurseryName,
    required this.sellOrders,
    required this.buyOrders,
    required this.sellQuotations,
    required this.buyQuotations,
    required this.inventory,
    required this.connections,
  });

  factory OwnerDashboardData.fromJson(Map<String, dynamic> j) => OwnerDashboardData(
        nurseryId: (j['nursery_id'] as num?)?.toInt(),
        nurseryName: j['nursery_name'] as String?,
        sellOrders: OrderMetrics.fromJson(j['sell_orders'] as Map<String, dynamic>? ?? {}),
        buyOrders: OrderMetrics.fromJson(j['buy_orders'] as Map<String, dynamic>? ?? {}),
        sellQuotations: QuoteMetrics.fromJson(j['sell_quotations'] as Map<String, dynamic>? ?? {}),
        buyQuotations: QuoteMetrics.fromJson(j['buy_quotations'] as Map<String, dynamic>? ?? {}),
        inventory: InventoryMetrics.fromJson(j['inventory'] as Map<String, dynamic>? ?? {}),
        connections: ConnectionMetrics.fromJson(j['connections'] as Map<String, dynamic>? ?? {}),
      );

  static const empty = OwnerDashboardData(
    sellOrders: OrderMetrics(),
    buyOrders: OrderMetrics(),
    sellQuotations: QuoteMetrics(),
    buyQuotations: QuoteMetrics(),
    inventory: InventoryMetrics(),
    connections: ConnectionMetrics(),
  );
}

// ── Repository ────────────────────────────────────────────────────────────────

class OwnerDashboardRepository {
  final ApiClient _client;
  OwnerDashboardRepository(this._client);

  Future<OwnerDashboardData> fetch() async {
    return _client.get(
      ApiConstants.ownerDashboard,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return OwnerDashboardData.fromJson(d['dashboard'] as Map<String, dynamic>);
      },
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final ownerDashboardRepositoryProvider = Provider<OwnerDashboardRepository>(
  (ref) => OwnerDashboardRepository(ApiClient.instance),
);

final ownerDashboardProvider = FutureProvider.autoDispose<OwnerDashboardData>((ref) async {
  return ref.watch(ownerDashboardRepositoryProvider).fetch();
});

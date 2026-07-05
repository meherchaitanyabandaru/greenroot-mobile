import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/network/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class OrderItem {
  final int id;
  final int plantId;
  final String scientificName;
  final String? commonName;
  final String? sizeName;
  final double quantity;
  final double? loadedQuantity;
  final double unitPrice;
  final double totalPrice;

  const OrderItem({
    required this.id,
    required this.plantId,
    required this.scientificName,
    this.commonName,
    this.sizeName,
    required this.quantity,
    this.loadedQuantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: (j['id'] as num).toInt(),
        plantId: (j['plant_id'] as num).toInt(),
        scientificName: j['scientific_name'] as String,
        commonName: j['common_name'] as String?,
        sizeName: j['size_name'] as String?,
        quantity: (j['quantity'] as num).toDouble(),
        loadedQuantity: (j['loaded_quantity'] as num?)?.toDouble(),
        unitPrice: (j['unit_price'] as num).toDouble(),
        totalPrice: (j['total_price'] as num).toDouble(),
      );

  String get displayName =>
      commonName?.isNotEmpty == true ? commonName! : scientificName;
}

class NurseryManager {
  final int userId;
  final String name;
  final String mobile;

  const NurseryManager({required this.userId, required this.name, required this.mobile});

  factory NurseryManager.fromJson(Map<String, dynamic> j) => NurseryManager(
        userId: (j['user_id'] as num).toInt(),
        name: j['first_name'] as String? ?? 'Manager',
        mobile: j['mobile'] as String? ?? '',
      );
}

class Order {
  final int id;
  final String orderCode;
  final String orderNumber;
  final String? buyerName;
  final String? sellerNursery;
  final int? sellerNurseryId;
  final String status;
  final double totalAmount;
  final String? notes;
  final String orderDate;
  final String? createdAt;
  final List<OrderItem> items;
  // Timestamps
  final String? loadingStartedAt;
  final String? loadingCompletedAt;
  final String? cancelledAt;
  final String? cancelReason;
  // People
  final int? assignedManagerUserId;
  final String? assignedManagerName;
  final String? customerName;

  const Order({
    required this.id,
    required this.orderCode,
    required this.orderNumber,
    this.buyerName,
    this.sellerNursery,
    this.sellerNurseryId,
    required this.status,
    required this.totalAmount,
    this.notes,
    required this.orderDate,
    this.createdAt,
    required this.items,
    this.loadingStartedAt,
    this.loadingCompletedAt,
    this.cancelledAt,
    this.cancelReason,
    this.assignedManagerUserId,
    this.assignedManagerName,
    this.customerName,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: (j['id'] as num).toInt(),
        orderCode: j['order_code'] as String,
        orderNumber: j['order_number'] as String,
        buyerName: j['buyer_name'] as String?,
        sellerNursery: j['seller_nursery'] as String?,
        sellerNurseryId: (j['seller_nursery_id'] as num?)?.toInt(),
        status: j['order_status'] as String,
        totalAmount: (j['total_amount'] as num).toDouble(),
        notes: j['notes'] as String?,
        orderDate: j['order_date'] as String,
        createdAt: j['created_at'] as String?,
        items: (j['items'] as List<dynamic>?)
                ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        loadingStartedAt: j['loading_started_at'] as String?,
        loadingCompletedAt: j['loading_completed_at'] as String?,
        cancelledAt: j['cancelled_at'] as String?,
        cancelReason: j['cancel_reason'] as String?,
        assignedManagerUserId:
            (j['assigned_manager_user_id'] as num?)?.toInt(),
        assignedManagerName: j['assigned_manager_name'] as String?,
        customerName: j['customer_name'] as String?,
      );
}

// ── Request DTOs ──────────────────────────────────────────────────────────────

class OrderItemRequest {
  final int plantId;
  final int? sizeId;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final String? remarks;

  const OrderItemRequest({
    required this.plantId,
    this.sizeId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.remarks,
  });

  Map<String, dynamic> toJson() => {
        'plant_id': plantId,
        if (sizeId != null) 'size_id': sizeId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
        if (remarks?.isNotEmpty == true) 'remarks': remarks,
      };
}

// ── Repository ────────────────────────────────────────────────────────────────

class OrderRepository {
  final ApiClient _client;
  OrderRepository(this._client);

  Future<(List<Order>, ApiPagination)> listOrders({
    int page = 1,
    int perPage = 20,
    String? status,
    int? nurseryId,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (status?.isNotEmpty == true) 'status': status,
      if (nurseryId != null) 'nursery_id': nurseryId,
    };
    return _client.get(
      ApiConstants.orders,
      queryParameters: params,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['orders'] as List<dynamic>)
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination =
            ApiPagination.fromJson(d['pagination'] as Map<String, dynamic>);
        return (items, pagination);
      },
    );
  }

  Future<Order> getOrder(int id) async {
    return _client.get(
      ApiConstants.orderById(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Order.fromJson(d['order'] as Map<String, dynamic>);
      },
    );
  }

  Future<Order> updateStatus(int id, String status) async {
    return _client.put(
      ApiConstants.orderStatus(id),
      data: {'order_status': status},
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Order.fromJson(d['order'] as Map<String, dynamic>);
      },
    );
  }

  Future<Order> confirmOrder(int id) async {
    return _client.post(
      ApiConstants.orderConfirm(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Order.fromJson(d['order'] as Map<String, dynamic>);
      },
    );
  }

  Future<Order> startLoading(int id) async {
    return _client.post(
      ApiConstants.orderStartLoading(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Order.fromJson(d['order'] as Map<String, dynamic>);
      },
    );
  }

  Future<Order> completeLoading(int id) async {
    return _client.post(
      ApiConstants.orderCompleteLoading(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Order.fromJson(d['order'] as Map<String, dynamic>);
      },
    );
  }

  Future<OrderItem> setLoadedQuantity(int orderId, int itemId, double qty) async {
    return _client.put(
      ApiConstants.orderItemLoadedQuantity(orderId, itemId),
      data: {'loaded_quantity': qty},
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return OrderItem.fromJson(d['item'] as Map<String, dynamic>);
      },
    );
  }

  Future<Order> cancelOrder(int id, {String? reason}) async {
    return _client.post(
      ApiConstants.orderCancel(id),
      data: {if (reason?.isNotEmpty == true) 'reason': reason},
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Order.fromJson(d['order'] as Map<String, dynamic>);
      },
    );
  }

  Future<Order> assignManager(int orderId, int managerUserId) async {
    return _client.post(
      ApiConstants.orderAssignManager(orderId),
      data: {'manager_user_id': managerUserId},
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Order.fromJson(d['order'] as Map<String, dynamic>);
      },
    );
  }

  Future<List<NurseryManager>> getNurseryManagers(int nurseryId) async {
    return _client.get(
      ApiConstants.nurseryManagers(nurseryId),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final users = d['users'] as List<dynamic>? ?? [];
        return users
            .map((e) => NurseryManager.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<(List<Order>, ApiPagination)> listBuyingOrders({
    int page = 1,
    int perPage = 20,
  }) async {
    return _client.get(
      ApiConstants.orders,
      queryParameters: {'page': page, 'per_page': perPage, 'buying': 'true'},
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['orders'] as List<dynamic>)
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination =
            ApiPagination.fromJson(d['pagination'] as Map<String, dynamic>);
        return (items, pagination);
      },
    );
  }

  Future<Order> createOrder({
    required String buyerMobile,
    String? buyerName,
    required int sellerNurseryId,
    required List<OrderItemRequest> items,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'buyer_mobile': buyerMobile,
      if (buyerName?.isNotEmpty == true) 'buyer_name': buyerName,
      'seller_nursery_id': sellerNurseryId,
      'items': items.map((i) => i.toJson()).toList(),
      if (notes?.isNotEmpty == true) 'notes': notes,
    };
    return _client.post(
      ApiConstants.orders,
      data: body,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Order.fromJson(d['order'] as Map<String, dynamic>);
      },
    );
  }

  // Buyer creates their own order — no buyer_mobile needed (API uses auth token)
  Future<Order> createBuyerOrder({
    required int sellerNurseryId,
    required List<OrderItemRequest> items,
    String? buyerName,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'seller_nursery_id': sellerNurseryId,
      'items': items.map((i) => i.toJson()).toList(),
      if (buyerName?.isNotEmpty == true) 'buyer_name': buyerName,
      if (notes?.isNotEmpty == true) 'notes': notes,
    };
    return _client.post(
      ApiConstants.orders,
      data: body,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Order.fromJson(d['order'] as Map<String, dynamic>);
      },
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ApiClient.instance),
);

class OrderListState {
  final PagedState<Order> paged;
  final String? statusFilter;
  final int? nurseryId;

  const OrderListState({required this.paged, this.statusFilter, this.nurseryId});

  OrderListState copyWith({
    PagedState<Order>? paged,
    String? statusFilter,
    int? nurseryId,
    bool clearStatus = false,
  }) =>
      OrderListState(
        paged: paged ?? this.paged,
        statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
        nurseryId: nurseryId ?? this.nurseryId,
      );
}

class OrderListNotifier extends StateNotifier<OrderListState> {
  final OrderRepository _repo;
  int _page = 0;

  OrderListNotifier(this._repo)
      : super(OrderListState(paged: PagedState.initial()));

  Future<void> load({String? statusFilter, int? nurseryId}) async {
    final sf = statusFilter ?? state.statusFilter;
    final nid = nurseryId ?? state.nurseryId;
    state = state.copyWith(
      statusFilter: sf,
      nurseryId: nid,
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) = await _repo.listOrders(page: 1, status: sf, nurseryId: nid);
      _page = 1;
      state = state.copyWith(
        paged: PagedState(
          items: items,
          isLoading: false,
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError catch (e) {
      state = state.copyWith(
          paged: state.paged.copyWith(isLoading: false, error: e));
    }
  }

  Future<void> loadMore() async {
    if (state.paged.isLoadingMore || !state.paged.hasMore) return;
    state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: true));
    try {
      final (items, pagination) = await _repo.listOrders(
          page: _page + 1, status: state.statusFilter, nurseryId: state.nurseryId);
      _page++;
      state = state.copyWith(
        paged: state.paged.copyWith(
          items: [...state.paged.items, ...items],
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError {
      state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: false));
    }
  }
}

final orderListProvider =
    StateNotifierProvider<OrderListNotifier, OrderListState>((ref) {
  return OrderListNotifier(ref.watch(orderRepositoryProvider));
});

final orderDetailProvider =
    FutureProvider.family<Order, int>((ref, id) async {
  return ref.watch(orderRepositoryProvider).getOrder(id);
});

// ── Buying perspective providers ───────────────────────────────────────────────

class BuyingOrderListNotifier extends StateNotifier<OrderListState> {
  final OrderRepository _repo;
  int _page = 0;

  BuyingOrderListNotifier(this._repo)
      : super(OrderListState(paged: PagedState.initial()));

  Future<void> load() async {
    state = state.copyWith(
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) = await _repo.listBuyingOrders(page: 1);
      _page = 1;
      state = state.copyWith(
        paged: PagedState(
          items: items,
          isLoading: false,
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError catch (e) {
      state = state.copyWith(
          paged: state.paged.copyWith(isLoading: false, error: e));
    }
  }

  Future<void> loadMore() async {
    if (state.paged.isLoadingMore || !state.paged.hasMore) return;
    state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: true));
    try {
      final (items, pagination) = await _repo.listBuyingOrders(page: _page + 1);
      _page++;
      state = state.copyWith(
        paged: state.paged.copyWith(
          items: [...state.paged.items, ...items],
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError {
      state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: false));
    }
  }
}

final buyingOrderListProvider =
    StateNotifierProvider<BuyingOrderListNotifier, OrderListState>((ref) {
  return BuyingOrderListNotifier(ref.watch(orderRepositoryProvider));
});

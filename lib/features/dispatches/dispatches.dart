import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/network/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class DispatchItem {
  final int id;
  final String? plantName;
  final double quantity;
  final String? notes;

  const DispatchItem({
    required this.id,
    this.plantName,
    required this.quantity,
    this.notes,
  });

  factory DispatchItem.fromJson(Map<String, dynamic> j) => DispatchItem(
        id: (j['id'] as num).toInt(),
        plantName: j['plant_name'] as String?,
        quantity: (j['quantity'] as num).toDouble(),
        notes: j['notes'] as String?,
      );
}

class Dispatch {
  final int id;
  final String dispatchCode;
  final int orderId;
  final String? orderNumber;
  final String? dispatchNumber;
  final String status;
  final String? vehicleNumber;
  final String? driverName;
  final int? driverUserId;
  final String? dispatchDate;
  final String? deliveryDate;
  final String? destinationAddress;
  final String? notes;
  final String createdAt;
  final List<DispatchItem> items;

  const Dispatch({
    required this.id,
    required this.dispatchCode,
    required this.orderId,
    this.orderNumber,
    this.dispatchNumber,
    required this.status,
    this.vehicleNumber,
    this.driverName,
    this.driverUserId,
    this.dispatchDate,
    this.deliveryDate,
    this.destinationAddress,
    this.notes,
    required this.createdAt,
    required this.items,
  });

  factory Dispatch.fromJson(Map<String, dynamic> j) => Dispatch(
        id: (j['id'] as num).toInt(),
        dispatchCode: j['dispatch_code'] as String,
        orderId: (j['order_id'] as num).toInt(),
        orderNumber: j['order_number'] as String?,
        dispatchNumber: j['dispatch_number'] as String?,
        status: j['dispatch_status'] as String,
        vehicleNumber: j['vehicle_number'] as String?,
        driverName: j['driver_name'] as String?,
        driverUserId: j['driver_user_id'] != null ? (j['driver_user_id'] as num).toInt() : null,
        dispatchDate: j['dispatch_date'] as String?,
        deliveryDate: j['delivery_date'] as String?,
        destinationAddress: j['destination_address'] as String?,
        notes: j['notes'] as String?,
        createdAt: j['created_at'] as String,
        items: (j['items'] as List<dynamic>?)
                ?.map((e) => DispatchItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class DispatchRepository {
  final ApiClient _client;
  DispatchRepository(this._client);

  Future<(List<Dispatch>, ApiPagination)> listDispatches({
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
      ApiConstants.dispatches,
      queryParameters: params,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['dispatches'] as List<dynamic>)
            .map((e) => Dispatch.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination =
            ApiPagination.fromJson(d['pagination'] as Map<String, dynamic>);
        return (items, pagination);
      },
    );
  }

  Future<Dispatch> getDispatch(int id) async {
    return _client.get(
      ApiConstants.dispatchById(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Dispatch.fromJson(d['dispatch'] as Map<String, dynamic>);
      },
    );
  }

  Future<Dispatch> updateStatus(int id, String status) async {
    return _client.put(
      ApiConstants.dispatchStatus(id),
      data: {'dispatch_status': status},
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Dispatch.fromJson(d['dispatch'] as Map<String, dynamic>);
      },
    );
  }

  Future<Dispatch> findByCode(String code) async {
    return _client.get(
      ApiConstants.dispatchByCode(code.trim().toUpperCase()),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Dispatch.fromJson(d['dispatch'] as Map<String, dynamic>);
      },
    );
  }

  Future<Dispatch> acceptDispatch(int id) async {
    return _client.post(
      ApiConstants.acceptDispatch(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Dispatch.fromJson(d['dispatch'] as Map<String, dynamic>);
      },
    );
  }

  Future<Dispatch> createDispatch(
    int orderId, {
    String? destinationAddress,
    String? notes,
  }) async {
    return _client.post(
      ApiConstants.dispatches,
      data: {
        'order_id': orderId,
        if (destinationAddress?.isNotEmpty == true)
          'destination_address': destinationAddress,
        if (notes?.isNotEmpty == true) 'notes': notes,
      },
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Dispatch.fromJson(d['dispatch'] as Map<String, dynamic>);
      },
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final dispatchRepositoryProvider = Provider<DispatchRepository>(
  (ref) => DispatchRepository(ApiClient.instance),
);

class DispatchListState {
  final PagedState<Dispatch> paged;
  final String? statusFilter;
  final int? nurseryId;

  const DispatchListState({required this.paged, this.statusFilter, this.nurseryId});

  DispatchListState copyWith({
    PagedState<Dispatch>? paged,
    String? statusFilter,
    int? nurseryId,
    bool clearStatus = false,
  }) =>
      DispatchListState(
        paged: paged ?? this.paged,
        statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
        nurseryId: nurseryId ?? this.nurseryId,
      );
}

class DispatchListNotifier extends StateNotifier<DispatchListState> {
  final DispatchRepository _repo;
  int _page = 0;

  DispatchListNotifier(this._repo)
      : super(DispatchListState(paged: PagedState.initial()));

  Future<void> load({String? statusFilter, int? nurseryId}) async {
    final sf = statusFilter ?? state.statusFilter;
    final nid = nurseryId ?? state.nurseryId;
    state = state.copyWith(
      statusFilter: sf,
      nurseryId: nid,
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) =
          await _repo.listDispatches(page: 1, status: sf, nurseryId: nid);
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
      final (items, pagination) = await _repo.listDispatches(
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

final dispatchListProvider =
    StateNotifierProvider<DispatchListNotifier, DispatchListState>((ref) {
  return DispatchListNotifier(ref.watch(dispatchRepositoryProvider));
});

final dispatchDetailProvider =
    FutureProvider.family<Dispatch, int>((ref, id) async {
  return ref.watch(dispatchRepositoryProvider).getDispatch(id);
});

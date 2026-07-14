import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/network/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class TripEvent {
  final int id;
  final String eventType;
  final String? note;
  final String createdAt;

  const TripEvent({
    required this.id,
    required this.eventType,
    this.note,
    required this.createdAt,
  });

  factory TripEvent.fromJson(Map<String, dynamic> j) => TripEvent(
        id: (j['id'] as num).toInt(),
        eventType: j['event_type'] as String,
        note: j['note'] as String?,
        createdAt: j['created_at'] as String,
      );
}

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
  final int? sellerNurseryId;
  final String? vehicleNumber;
  final String? driverName;
  final String? driverMobile;
  final int? driverUserId;
  final String? dispatchDate;
  final String? deliveryDate;
  final String? destinationAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final bool requiresDriverAck;
  final String? notes;
  final String createdAt;
  final String? updatedAt;
  final List<DispatchItem> items;

  const Dispatch({
    required this.id,
    required this.dispatchCode,
    required this.orderId,
    this.orderNumber,
    this.dispatchNumber,
    required this.status,
    this.sellerNurseryId,
    this.vehicleNumber,
    this.driverName,
    this.driverMobile,
    this.driverUserId,
    this.dispatchDate,
    this.deliveryDate,
    this.destinationAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.requiresDriverAck = false,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    required this.items,
  });

  factory Dispatch.fromJson(Map<String, dynamic> j) => Dispatch(
        id: (j['id'] as num).toInt(),
        dispatchCode: j['dispatch_code'] as String,
        orderId: (j['order_id'] as num).toInt(),
        orderNumber: j['order_number'] as String?,
        dispatchNumber: j['dispatch_number'] as String?,
        status: j['dispatch_status'] as String,
        sellerNurseryId: j['seller_nursery_id'] != null
            ? (j['seller_nursery_id'] as num).toInt()
            : null,
        vehicleNumber: j['vehicle_number'] as String?,
        driverName: j['driver_name'] as String?,
        driverMobile: j['driver_mobile'] as String?,
        driverUserId: j['driver_user_id'] != null
            ? (j['driver_user_id'] as num).toInt()
            : null,
        dispatchDate: j['dispatch_date'] as String?,
        deliveryDate: j['delivery_date'] as String?,
        destinationAddress: j['destination_address'] as String?,
        deliveryLatitude: (j['delivery_latitude'] as num?)?.toDouble(),
        deliveryLongitude: (j['delivery_longitude'] as num?)?.toDouble(),
        requiresDriverAck: j['requires_driver_ack'] == true,
        notes: j['notes'] as String?,
        createdAt: j['created_at'] as String,
        updatedAt: j['updated_at'] as String?,
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

  Future<(List<Dispatch>, ApiPagination)> listBuyingDispatches({
    int page = 1,
    int perPage = 20,
  }) async {
    return _client.get(
      ApiConstants.dispatches,
      queryParameters: {'page': page, 'per_page': perPage, 'buying': 'true'},
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

  Future<List<Dispatch>> listByOrder(int orderId) async {
    return _client.get(
      ApiConstants.dispatchesByOrder(orderId),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return (d['dispatches'] as List<dynamic>)
            .map((e) => Dispatch.fromJson(e as Map<String, dynamic>))
            .toList();
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

  Future<Dispatch> acknowledgeDeliveryUpdate(int id) async {
    return _client.post(
      ApiConstants.dispatchAckDeliveryUpdate(id),
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

  // ── Driver-specific ──────────────────────────────────────────────────────────

  // RBAC §8: no explicit reject endpoint in current API. Returns null to signal gap.
  // The backend must reject second active trip acceptance via 409.
  Future<Dispatch?> rejectDispatch(int id) => Future.value(null);

  Future<TripEvent> addTripEvent(
    int dispatchId,
    String eventType, {
    String? note,
  }) async {
    return _client.post(
      ApiConstants.tripEvents(dispatchId),
      data: {
        'event_type': eventType,
        if (note?.isNotEmpty == true) 'note': note,
      },
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return TripEvent.fromJson(
            (d['trip_event'] ?? d) as Map<String, dynamic>);
      },
    );
  }

  Future<void> postGpsLocation({
    required int driverId,
    required double latitude,
    required double longitude,
    int? dispatchId,
  }) async {
    await _client.post<dynamic>(
      ApiConstants.postTracking,
      data: {
        'driver_id': driverId,
        'latitude': latitude,
        'longitude': longitude,
        if (dispatchId != null) 'dispatch_id': dispatchId,
      },
    );
  }

  // Returns the driver's single active trip (ACCEPTED|DISPATCHED|IN_TRANSIT),
  // or null if none. If multiple active trips exist (data integrity error) it
  // returns null and the caller should surface a safe error.
  Future<Dispatch?> getActiveTrip() async {
    try {
      final (dispatches, _) = await listDispatches(page: 1, perPage: 50);
      const activeStatuses = {'ACCEPTED', 'DISPATCHED', 'IN_TRANSIT'};
      final active =
          dispatches.where((d) => activeStatuses.contains(d.status)).toList();
      if (active.length > 1) {
        // Data-integrity violation — do not silently pick one.
        return null;
      }
      return active.firstOrNull;
    } catch (_) {
      return null;
    }
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

  const DispatchListState(
      {required this.paged, this.statusFilter, this.nurseryId});

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
          page: _page + 1,
          status: state.statusFilter,
          nurseryId: state.nurseryId);
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

// ── Driver active trip ─────────────────────────────────────────────────────────

enum ActiveTripResult { none, found, integrityError }

class ActiveTripState {
  final Dispatch? trip;
  final ActiveTripResult result;
  const ActiveTripState({required this.trip, required this.result});
}

final activeDriverTripProvider =
    FutureProvider.autoDispose<ActiveTripState>((ref) async {
  final repo = ref.watch(dispatchRepositoryProvider);
  try {
    final (dispatches, _) = await repo.listDispatches(page: 1, perPage: 50);
    const activeStatuses = {'ACCEPTED', 'DISPATCHED', 'IN_TRANSIT'};
    final active =
        dispatches.where((d) => activeStatuses.contains(d.status)).toList();
    if (active.length > 1) {
      return const ActiveTripState(
          trip: null, result: ActiveTripResult.integrityError);
    }
    return ActiveTripState(
      trip: active.firstOrNull,
      result: active.isEmpty ? ActiveTripResult.none : ActiveTripResult.found,
    );
  } catch (_) {
    return const ActiveTripState(trip: null, result: ActiveTripResult.none);
  }
});

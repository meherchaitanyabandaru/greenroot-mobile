import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/domain/lifecycle_models.dart';
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
        note: (j['remarks'] ?? j['note']) as String?,
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

class DispatchCapabilities {
  final bool canAccept;
  final bool canMarkDispatched;
  final bool canStartTrip;
  final bool canMarkDelivered;
  final bool canCancel;
  final bool canAddItems;
  final bool canViewTracking;
  final bool canShareCode;
  // Delivery confirmation: staff without the code (with a reason); the
  // customer's "received" and "report a problem".
  final bool canOverrideDelivery;
  final bool canConfirmReceipt;
  final bool canReportIssue;
  final bool canRenewInvite;

  const DispatchCapabilities({
    this.canAccept = false,
    this.canMarkDispatched = false,
    this.canStartTrip = false,
    this.canMarkDelivered = false,
    this.canCancel = false,
    this.canAddItems = false,
    this.canViewTracking = false,
    this.canShareCode = false,
    this.canOverrideDelivery = false,
    this.canConfirmReceipt = false,
    this.canReportIssue = false,
    this.canRenewInvite = false,
  });

  factory DispatchCapabilities.fromJson(Map<String, dynamic> j) =>
      DispatchCapabilities(
        canAccept: j['can_accept'] == true,
        canMarkDispatched: j['can_mark_dispatched'] == true,
        canStartTrip: j['can_start_trip'] == true,
        canMarkDelivered: j['can_mark_delivered'] == true,
        canCancel: j['can_cancel'] == true,
        canAddItems: j['can_add_items'] == true,
        canViewTracking: j['can_view_tracking'] == true,
        canShareCode: j['can_share_code'] == true,
        canOverrideDelivery: j['can_override_delivery'] == true,
        canConfirmReceipt: j['can_confirm_receipt'] == true,
        canReportIssue: j['can_report_issue'] == true,
        canRenewInvite: j['can_renew_invite'] == true,
      );
}

class Dispatch {
  final int id;
  final String dispatchCode;
  // The trip's secret: only the QR / join code carries it (dispatch codes are guessable).
  final String? tripUuid;
  final int orderId;
  final String? orderNumber;
  final String? orderStatus;
  final String? loadingStartedAt;
  final String? loadingCompletedAt;
  final String? dispatchNumber;
  final String status;
  final int? sellerNurseryId;
  final String? sellerNurseryName;
  final String? vehicleNumber;
  final String? driverName;
  final String? driverMobile;
  final int? driverUserId;
  final String? dispatchDate;
  final String? deliveryDate;
  // When the driver accepted / started the trip (timeline times).
  final String? driverAcceptedAt;
  final String? tripStartedAt;
  final String? destinationAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final bool requiresDriverAck;
  final String? notes;
  final String createdAt;
  final String? updatedAt;
  final List<DispatchItem> items;
  final BackendLifecycle? lifecycle;
  final DispatchCapabilities? capabilities;
  // Outside lorry: the driver has no app.
  final bool isOutsideTransport;
  final String? outsideVehicleNumber;
  final String? outsideDriverName;
  final String? outsideDriverMobile;
  // Lorry driver requirements and invitation validity.
  final String? requiredVehicleType;
  final String? inviteExpiresAt;
  // CUSTOMER_CODE, CUSTOMER_APP or UNCONFIRMED (nursery override).
  final String? deliveryConfirmation;
  final String? deliveryOverrideReason;
  final String? deliveryIssue;
  // Only in the customer's own view, while the trip is on its way.
  final String? deliveryCode;

  bool get deliveryUnconfirmed => deliveryConfirmation == 'UNCONFIRMED';

  const Dispatch({
    required this.id,
    required this.dispatchCode,
    this.tripUuid,
    required this.orderId,
    this.orderNumber,
    this.orderStatus,
    this.loadingStartedAt,
    this.loadingCompletedAt,
    this.dispatchNumber,
    required this.status,
    this.sellerNurseryId,
    this.sellerNurseryName,
    this.vehicleNumber,
    this.driverName,
    this.driverMobile,
    this.driverUserId,
    this.dispatchDate,
    this.deliveryDate,
    this.driverAcceptedAt,
    this.tripStartedAt,
    this.destinationAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.requiresDriverAck = false,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    required this.items,
    this.lifecycle,
    this.capabilities,
    this.isOutsideTransport = false,
    this.outsideVehicleNumber,
    this.outsideDriverName,
    this.outsideDriverMobile,
    this.requiredVehicleType,
    this.inviteExpiresAt,
    this.deliveryConfirmation,
    this.deliveryOverrideReason,
    this.deliveryIssue,
    this.deliveryCode,
  });

  /// What the nursery shares (QR or text) and the driver joins with.
  String? get tripCode => tripUuid == null ? null : 'TRIP-$tripUuid';

  factory Dispatch.fromJson(Map<String, dynamic> j) => Dispatch(
        id: (j['id'] as num).toInt(),
        dispatchCode: j['dispatch_code'] as String,
        tripUuid: j['trip_uuid'] as String?,
        orderId: (j['order_id'] as num).toInt(),
        orderNumber: j['order_number'] as String?,
        orderStatus: j['order_status'] as String?,
        loadingStartedAt: j['loading_started_at'] as String?,
        loadingCompletedAt: j['loading_completed_at'] as String?,
        dispatchNumber: j['dispatch_number'] as String?,
        status: j['dispatch_status'] as String,
        sellerNurseryId: j['seller_nursery_id'] != null
            ? (j['seller_nursery_id'] as num).toInt()
            : null,
        sellerNurseryName: j['seller_nursery_name'] as String?,
        vehicleNumber: j['vehicle_number'] as String?,
        driverName: j['driver_name'] as String?,
        driverMobile: j['driver_mobile'] as String?,
        driverUserId: j['driver_user_id'] != null
            ? (j['driver_user_id'] as num).toInt()
            : null,
        dispatchDate: j['dispatch_date'] as String?,
        deliveryDate: j['delivery_date'] as String?,
        driverAcceptedAt: j['driver_accepted_at'] as String?,
        tripStartedAt: j['trip_started_at'] as String?,
        destinationAddress: j['destination_address'] as String?,
        deliveryLatitude: (j['delivery_latitude'] as num?)?.toDouble(),
        deliveryLongitude: (j['delivery_longitude'] as num?)?.toDouble(),
        requiresDriverAck: j['requires_driver_ack'] == true,
        notes: j['notes'] as String?,
        createdAt: j['created_at'] as String,
        updatedAt: j['updated_at'] as String?,
        lifecycle: j['lifecycle'] is Map<String, dynamic>
            ? BackendLifecycle.fromJson(j['lifecycle'] as Map<String, dynamic>)
            : null,
        capabilities: j['capabilities'] is Map<String, dynamic>
            ? DispatchCapabilities.fromJson(
                j['capabilities'] as Map<String, dynamic>,)
            : null,
        items: (j['items'] as List<dynamic>?)
                ?.map((e) => DispatchItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        isOutsideTransport: j['is_outside_transport'] == true,
        outsideVehicleNumber: j['outside_vehicle_number'] as String?,
        outsideDriverName: j['outside_driver_name'] as String?,
        outsideDriverMobile: j['outside_driver_mobile'] as String?,
        requiredVehicleType: j['required_vehicle_type'] as String?,
        inviteExpiresAt: j['invite_expires_at'] as String?,
        deliveryConfirmation: j['delivery_confirmation'] as String?,
        deliveryOverrideReason: j['delivery_override_reason'] as String?,
        deliveryIssue: j['delivery_issue'] as String?,
        deliveryCode: j['delivery_code'] as String?,
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
    bool buying = false, // incoming deliveries, not this nursery's outgoing ones
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (status?.isNotEmpty == true) 'dispatch_status': status,
      if (nurseryId != null) 'nursery_id': nurseryId,
      if (buying) 'buying': true,
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

  /// Driver or nursery: delivered with the customer's [code], or (nursery
  /// only) without it, giving [overrideReason].
  Future<Dispatch> deliver(int id, {String? code, String? overrideReason}) {
    return _client.post(
      ApiConstants.deliverDispatch(id),
      data: {
        if (code != null) 'code': code,
        if (overrideReason != null) 'override_reason': overrideReason,
      },
      fromJson: (data) => Dispatch.fromJson(
          (data as Map<String, dynamic>)['dispatch'] as Map<String, dynamic>,),
    );
  }

  /// Customer: "I received the plants" and/or a problem ([issue]).
  Future<Dispatch> confirmReceipt(int id, {String? issue}) {
    return _client.post(
      ApiConstants.dispatchReceipt(id),
      data: {if (issue != null) 'issue': issue},
      fromJson: (data) => Dispatch.fromJson(
          (data as Map<String, dynamic>)['dispatch'] as Map<String, dynamic>,),
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

  /// [tripCode] is the trip's QR code (`TRIP-<uuid>`); the API refuses anything else.
  Future<Dispatch> acceptDispatch(int id, String tripCode) async {
    return _client.post(
      ApiConstants.acceptDispatch(id),
      data: {'trip_code': tripCode},
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
        // The API field is `remarks`; `note` was silently dropped.
        if (note?.isNotEmpty == true) 'remarks': note,
      },
      fromJson: (data) {
        // The API wraps it as {"event": {...}}; parsing the wrapper failed
        // after a successful save, so drivers saw an error and re-sent it.
        final d = data as Map<String, dynamic>;
        return TripEvent.fromJson(
            (d['event'] ?? d['trip_event'] ?? d) as Map<String, dynamic>,);
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
    String? requiredVehicleType,
    // Outside lorry (driver without the app): vehicle number required.
    String? outsideVehicleNumber,
    String? outsideDriverName,
    String? outsideDriverMobile,
  }) async {
    return _client.post(
      ApiConstants.dispatches,
      data: {
        'order_id': orderId,
        if (destinationAddress?.isNotEmpty == true)
          'destination_address': destinationAddress,
        if (notes?.isNotEmpty == true) 'notes': notes,
        if (requiredVehicleType?.isNotEmpty == true)
          'required_vehicle_type': requiredVehicleType,
        if (outsideVehicleNumber != null) ...{
          'is_outside_transport': true,
          'outside_vehicle_number': outsideVehicleNumber,
          if (outsideDriverName?.isNotEmpty == true)
            'outside_driver_name': outsideDriverName,
          if (outsideDriverMobile?.isNotEmpty == true)
            'outside_driver_mobile': outsideDriverMobile,
        },
      },
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Dispatch.fromJson(d['dispatch'] as Map<String, dynamic>);
      },
    );
  }

  Future<Dispatch> renewInvite(int dispatchId) async {
    return _client.post(
      '${ApiConstants.dispatches}/$dispatchId/new-invite',
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
      {required this.paged, this.statusFilter, this.nurseryId,});

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
          paged: state.paged.copyWith(isLoading: false, error: e),);
    }
  }

  Future<void> loadMore() async {
    if (state.paged.isLoadingMore || !state.paged.hasMore) return;
    state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: true));
    try {
      final (items, pagination) = await _repo.listDispatches(
          page: _page + 1,
          status: state.statusFilter,
          nurseryId: state.nurseryId,);
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
    FutureProvider.autoDispose.family<Dispatch, int>((ref, id) async {
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
          trip: null, result: ActiveTripResult.integrityError,);
    }
    return ActiveTripState(
      trip: active.firstOrNull,
      result: active.isEmpty ? ActiveTripResult.none : ActiveTripResult.found,
    );
  } catch (_) {
    return const ActiveTripState(trip: null, result: ActiveTripResult.none);
  }
});

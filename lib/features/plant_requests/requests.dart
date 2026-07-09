import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/network/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class RequestResponse {
  final int id;
  final int requestId;
  final int supplierNurseryId;
  final String supplierNursery;
  final String respondedByName;
  final int availableQuantity;
  final String? remarks;
  final String status;

  const RequestResponse({
    required this.id,
    required this.requestId,
    required this.supplierNurseryId,
    required this.supplierNursery,
    required this.respondedByName,
    required this.availableQuantity,
    this.remarks,
    required this.status,
  });

  factory RequestResponse.fromJson(Map<String, dynamic> j) => RequestResponse(
        id: (j['id'] as num).toInt(),
        requestId: (j['request_id'] as num).toInt(),
        supplierNurseryId: (j['supplier_nursery_id'] as num).toInt(),
        supplierNursery: j['supplier_nursery'] as String,
        respondedByName: j['responded_by_name'] as String,
        availableQuantity: (j['available_quantity'] as num).toInt(),
        remarks: j['remarks'] as String?,
        status: j['status'] as String,
      );
}

class PlantRequest {
  final int id;
  final String requestCode;
  final int requestingNurseryId;
  final String requestingNursery;
  final String requestedByName;
  final int plantId;
  final String scientificName;
  final String? commonName;
  final String? sizeCode;
  final String? sizeName;
  final int quantityRequired;
  final int radiusKm;
  final String? notes;
  final String status;
  final String? expiresAt;
  final String createdAt;
  final List<RequestResponse> responses;

  const PlantRequest({
    required this.id,
    required this.requestCode,
    required this.requestingNurseryId,
    required this.requestingNursery,
    required this.requestedByName,
    required this.plantId,
    required this.scientificName,
    this.commonName,
    this.sizeCode,
    this.sizeName,
    required this.quantityRequired,
    required this.radiusKm,
    this.notes,
    required this.status,
    this.expiresAt,
    required this.createdAt,
    required this.responses,
  });

  factory PlantRequest.fromJson(Map<String, dynamic> j) => PlantRequest(
        id: (j['id'] as num).toInt(),
        requestCode: j['request_code'] as String,
        requestingNurseryId: (j['requesting_nursery_id'] as num).toInt(),
        requestingNursery: j['requesting_nursery'] as String,
        requestedByName: j['requested_by_name'] as String,
        plantId: (j['plant_id'] as num).toInt(),
        scientificName: j['scientific_name'] as String,
        commonName: j['common_name'] as String?,
        sizeCode: j['size_code'] as String?,
        sizeName: j['size_name'] as String?,
        quantityRequired: (j['quantity_required'] as num).toInt(),
        radiusKm: (j['radius_km'] as num).toInt(),
        notes: j['notes'] as String?,
        status: j['status'] as String,
        expiresAt: j['expires_at'] as String?,
        createdAt: j['created_at'] as String,
        responses: (j['responses'] as List<dynamic>?)
                ?.map((e) =>
                    RequestResponse.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  String get displayName =>
      commonName?.isNotEmpty == true ? commonName! : scientificName;
}

// ── Repository ────────────────────────────────────────────────────────────────

class RequestRepository {
  final ApiClient _client;
  RequestRepository(this._client);

  Future<(List<PlantRequest>, ApiPagination)> listRequests({
    int page = 1,
    int perPage = 20,
    String? search,
    String? status,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (search?.isNotEmpty == true) 'search': search,
      if (status?.isNotEmpty == true) 'status': status,
    };
    return _client.get(
      ApiConstants.plantRequests,
      queryParameters: params,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['plant_requests'] as List<dynamic>)
            .map((e) => PlantRequest.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination =
            ApiPagination.fromJson(d['pagination'] as Map<String, dynamic>);
        return (items, pagination);
      },
    );
  }

  Future<PlantRequest> getRequest(int id) async {
    return _client.get(
      ApiConstants.plantRequestById(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return PlantRequest.fromJson(d['request'] as Map<String, dynamic>);
      },
    );
  }

  Future<PlantRequest> createRequest({
    required int requestingNurseryId,
    required int plantId,
    required int quantityRequired,
    required int radiusKm,
    String? notes,
    int? sizeId,
  }) async {
    return _client.post(
      ApiConstants.plantRequests,
      data: {
        'requesting_nursery_id': requestingNurseryId,
        'plant_id': plantId,
        'quantity_required': quantityRequired,
        'radius_km': radiusKm,
        'status': 'OPEN',
        if (notes?.isNotEmpty == true) 'notes': notes,
        if (sizeId != null) 'size_id': sizeId,
      },
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return PlantRequest.fromJson(d['request'] as Map<String, dynamic>);
      },
    );
  }

  Future<RequestResponse> respondToRequest({
    required int requestId,
    required int supplierNurseryId,
    required int availableQuantity,
    String? remarks,
  }) async {
    return _client.post(
      ApiConstants.plantRequestRespond(requestId),
      data: {
        'supplier_nursery_id': supplierNurseryId,
        'available_quantity': availableQuantity,
        'status': 'ACCEPTED',
        if (remarks?.isNotEmpty == true) 'remarks': remarks,
      },
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final resp = d['response'] as Map<String, dynamic>?;
        if (resp != null) return RequestResponse.fromJson(resp);
        return RequestResponse.fromJson(d);
      },
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final requestRepositoryProvider = Provider<RequestRepository>(
  (ref) => RequestRepository(ApiClient.instance),
);

class RequestListState {
  final PagedState<PlantRequest> paged;
  final String search;
  final String? statusFilter;

  const RequestListState({
    required this.paged,
    this.search = '',
    this.statusFilter,
  });

  RequestListState copyWith({
    PagedState<PlantRequest>? paged,
    String? search,
    String? statusFilter,
    bool clearStatus = false,
  }) =>
      RequestListState(
        paged: paged ?? this.paged,
        search: search ?? this.search,
        statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
      );
}

class RequestListNotifier extends StateNotifier<RequestListState> {
  final RequestRepository _repo;
  int _page = 0;

  RequestListNotifier(this._repo)
      : super(RequestListState(paged: PagedState.initial()));

  Future<void> load({String? search, String? statusFilter}) async {
    final s = search ?? state.search;
    final sf = statusFilter ?? state.statusFilter;
    state = state.copyWith(
      search: s,
      statusFilter: sf,
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) =
          await _repo.listRequests(page: 1, search: s, status: sf);
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
      final (items, pagination) = await _repo.listRequests(
          page: _page + 1, search: state.search, status: state.statusFilter);
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

final requestListProvider =
    StateNotifierProvider<RequestListNotifier, RequestListState>((ref) {
  return RequestListNotifier(ref.watch(requestRepositoryProvider));
});

final requestDetailProvider =
    FutureProvider.family<PlantRequest, int>((ref, id) async {
  return ref.watch(requestRepositoryProvider).getRequest(id);
});

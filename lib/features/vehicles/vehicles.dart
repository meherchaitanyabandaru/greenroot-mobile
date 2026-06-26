import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/network/api_client.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class Vehicle {
  final int id;
  final String vehicleCode;
  final String vehicleNumber;
  final String? vehicleType;
  final double? capacityKG;
  final String? ownerName;
  final String? mobile;
  final String status;
  final String createdAt;

  const Vehicle({
    required this.id,
    required this.vehicleCode,
    required this.vehicleNumber,
    this.vehicleType,
    this.capacityKG,
    this.ownerName,
    this.mobile,
    required this.status,
    required this.createdAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: (j['id'] as num).toInt(),
        vehicleCode: j['vehicle_code'] as String,
        vehicleNumber: j['vehicle_number'] as String,
        vehicleType: j['vehicle_type'] as String?,
        capacityKG: (j['capacity_kg'] as num?)?.toDouble(),
        ownerName: j['owner_name'] as String?,
        mobile: j['mobile'] as String?,
        status: j['status'] as String,
        createdAt: (j['created_at'] as String?) ?? '',
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class VehicleRepository {
  final ApiClient _client;
  VehicleRepository(this._client);

  Future<(List<Vehicle>, ApiPagination)> listVehicles({
    int page = 1,
    int perPage = 20,
    String? status,
    String? type,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (status?.isNotEmpty == true) 'status': status,
      if (type?.isNotEmpty == true) 'type': type,
      if (search?.isNotEmpty == true) 'search': search,
    };
    return _client.get(
      ApiConstants.vehicles,
      queryParameters: params,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['vehicles'] as List<dynamic>)
            .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination =
            ApiPagination.fromJson(d['pagination'] as Map<String, dynamic>);
        return (items, pagination);
      },
    );
  }

  Future<Vehicle> getVehicle(int id) async {
    return _client.get(
      ApiConstants.vehicleById(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Vehicle.fromJson(d['vehicle'] as Map<String, dynamic>);
      },
    );
  }

  Future<Vehicle> createVehicle(Map<String, dynamic> body) async {
    return _client.post(
      ApiConstants.vehicles,
      data: body,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Vehicle.fromJson(d['vehicle'] as Map<String, dynamic>);
      },
    );
  }

  Future<Vehicle> updateVehicle(int id, Map<String, dynamic> body) async {
    return _client.put(
      ApiConstants.vehicleById(id),
      data: body,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Vehicle.fromJson(d['vehicle'] as Map<String, dynamic>);
      },
    );
  }

  Future<void> deleteVehicle(int id) async {
    await _client.delete<dynamic>(ApiConstants.vehicleById(id));
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final vehicleRepositoryProvider = Provider<VehicleRepository>(
  (ref) => VehicleRepository(ApiClient.instance),
);

class VehicleListState {
  final PagedState<Vehicle> paged;
  final String? statusFilter;

  const VehicleListState({required this.paged, this.statusFilter});

  VehicleListState copyWith({
    PagedState<Vehicle>? paged,
    String? statusFilter,
    bool clearStatus = false,
  }) =>
      VehicleListState(
        paged: paged ?? this.paged,
        statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
      );
}

class VehicleListNotifier extends StateNotifier<VehicleListState> {
  final VehicleRepository _repo;
  int _page = 0;

  VehicleListNotifier(this._repo)
      : super(VehicleListState(paged: PagedState.initial()));

  Future<void> load({String? statusFilter}) async {
    final sf = statusFilter ?? state.statusFilter;
    state = state.copyWith(
      statusFilter: sf,
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) = await _repo.listVehicles(page: 1, status: sf);
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
      final (items, pagination) = await _repo.listVehicles(
          page: _page + 1, status: state.statusFilter);
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

  Future<bool> deleteVehicle(int id) async {
    try {
      await _repo.deleteVehicle(id);
      state = state.copyWith(
        paged: state.paged.copyWith(
          items: state.paged.items.where((v) => v.id != id).toList(),
        ),
      );
      return true;
    } on AppError {
      return false;
    }
  }
}

final vehicleListProvider =
    StateNotifierProvider<VehicleListNotifier, VehicleListState>((ref) {
  return VehicleListNotifier(ref.watch(vehicleRepositoryProvider));
});

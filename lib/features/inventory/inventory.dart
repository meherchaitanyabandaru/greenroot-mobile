import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/network/api_client.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class InventoryItem {
  final int id;
  final String inventoryCode;
  final int nurseryId;
  final String nurseryName;
  final int plantId;
  final String scientificName;
  final String? commonName;
  final int sizeId;
  final String sizeCode;
  final String sizeName;
  final int availableQuantity;
  final String status;

  const InventoryItem({
    required this.id,
    required this.inventoryCode,
    required this.nurseryId,
    required this.nurseryName,
    required this.plantId,
    required this.scientificName,
    this.commonName,
    required this.sizeId,
    required this.sizeCode,
    required this.sizeName,
    required this.availableQuantity,
    required this.status,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        id: (j['id'] as num).toInt(),
        inventoryCode: j['inventory_code'] as String,
        nurseryId: (j['nursery_id'] as num).toInt(),
        nurseryName: j['nursery_name'] as String,
        plantId: (j['plant_id'] as num).toInt(),
        scientificName: j['scientific_name'] as String,
        commonName: j['common_name'] as String?,
        sizeId: (j['size_id'] as num).toInt(),
        sizeCode: j['size_code'] as String,
        sizeName: j['size_name'] as String,
        availableQuantity: (j['available_quantity'] as num).toInt(),
        status: j['inventory_status'] as String,
      );

  String get displayName =>
      commonName?.isNotEmpty == true ? commonName! : scientificName;
}

// ── Repository ────────────────────────────────────────────────────────────────

class InventoryRepository {
  final ApiClient _client;
  InventoryRepository(this._client);

  Future<(List<InventoryItem>, ApiPagination)> listInventory({
    int page = 1,
    int perPage = 20,
    String? search,
    int? nurseryId,
    int? plantId,
    String? status,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (search?.isNotEmpty == true) 'search': search,
      if (nurseryId != null) 'nursery_id': nurseryId,
      if (plantId != null) 'plant_id': plantId,
      if (status?.isNotEmpty == true) 'status': status,
    };
    return _client.get(
      ApiConstants.inventory,
      queryParameters: params,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['inventory'] as List<dynamic>)
            .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination =
            ApiPagination.fromJson(d['pagination'] as Map<String, dynamic>);
        return (items, pagination);
      },
    );
  }

  Future<InventoryItem> getItem(int id) async {
    return _client.get(
      ApiConstants.inventoryById(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return InventoryItem.fromJson(d['inventory'] as Map<String, dynamic>);
      },
    );
  }

  Future<InventoryItem> upsert({
    required int nurseryId,
    required int plantId,
    required int sizeId,
    required int availableQuantity,
    required String status,
  }) async {
    return _client.post(
      ApiConstants.inventory,
      data: {
        'nursery_id': nurseryId,
        'plant_id': plantId,
        'size_id': sizeId,
        'available_quantity': availableQuantity,
        'inventory_status': status,
      },
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return InventoryItem.fromJson(d['inventory'] as Map<String, dynamic>);
      },
    );
  }

  Future<InventoryItem> update(int id, {
    required int availableQuantity,
    required String status,
  }) async {
    return _client.put(
      ApiConstants.inventoryById(id),
      data: {
        'available_quantity': availableQuantity,
        'inventory_status': status,
      },
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return InventoryItem.fromJson(d['inventory'] as Map<String, dynamic>);
      },
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ApiClient.instance),
);

class InventoryListState {
  final PagedState<InventoryItem> paged;
  final String search;
  final String? statusFilter;

  const InventoryListState({
    required this.paged,
    this.search = '',
    this.statusFilter,
  });

  InventoryListState copyWith({
    PagedState<InventoryItem>? paged,
    String? search,
    String? statusFilter,
    bool clearStatus = false,
  }) =>
      InventoryListState(
        paged: paged ?? this.paged,
        search: search ?? this.search,
        statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
      );
}

class InventoryListNotifier extends StateNotifier<InventoryListState> {
  final InventoryRepository _repo;
  int _page = 0;

  InventoryListNotifier(this._repo)
      : super(InventoryListState(paged: PagedState.initial()));

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
          await _repo.listInventory(page: 1, search: s, status: sf);
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
      final (items, pagination) = await _repo.listInventory(
        page: _page + 1,
        search: state.search,
        status: state.statusFilter,
      );
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

final inventoryListProvider =
    StateNotifierProvider<InventoryListNotifier, InventoryListState>((ref) {
  return InventoryListNotifier(ref.watch(inventoryRepositoryProvider));
});

final inventoryDetailProvider =
    FutureProvider.family<InventoryItem, int>((ref, id) async {
  return ref.watch(inventoryRepositoryProvider).getItem(id);
});

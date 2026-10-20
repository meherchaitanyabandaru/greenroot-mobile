import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/network/api_client.dart';

/// One of a network nursery's top items (its showcase — not stock).
class NetworkTopItem {
  final int plantId;
  final String plantName;
  final String sizeName;
  final double? unitPrice;
  final String? qualityNotes;
  final List<String> photos;

  const NetworkTopItem({
    required this.plantId,
    required this.plantName,
    required this.sizeName,
    this.unitPrice,
    this.qualityNotes,
    this.photos = const [],
  });

  factory NetworkTopItem.fromJson(Map<String, dynamic> j) => NetworkTopItem(
        plantId: (j['plant_id'] as num).toInt(),
        plantName: j['plant_name'] as String? ?? 'Plant',
        sizeName: j['size_name'] as String? ?? '',
        unitPrice: (j['unit_price'] as num?)?.toDouble(),
        qualityNotes: j['quality_notes'] as String?,
        photos: (j['photos'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      );
}

class NearbyNursery {
  final int nurseryId;
  final String nurseryName;
  final String? village;
  final double? distanceKm;
  final bool roadAccessible;
  final bool lorryAccessible;
  final String? contactNumber;
  final List<NetworkTopItem> topItems;

  const NearbyNursery({
    required this.nurseryId,
    required this.nurseryName,
    this.village,
    this.distanceKm,
    required this.roadAccessible,
    required this.lorryAccessible,
    this.contactNumber,
    required this.topItems,
  });

  factory NearbyNursery.fromJson(Map<String, dynamic> j) => NearbyNursery(
        nurseryId: (j['nursery_id'] as num).toInt(),
        nurseryName: j['nursery_name'] as String? ?? 'Nursery',
        village: j['village'] as String?,
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        roadAccessible: j['road_accessible'] as bool? ?? false,
        lorryAccessible: j['lorry_accessible'] as bool? ?? false,
        contactNumber: j['contact_number'] as String?,
        topItems: (j['top_items'] as List<dynamic>?)
                ?.map((e) => NetworkTopItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class SourcingRepository {
  final ApiClient _client;
  SourcingRepository(this._client);

  Future<(List<NearbyNursery>, ApiPagination)> listNetworkNurseries({
    int page = 1,
    int perPage = 20,
    String? plantName,
    int? radiusKm,
  }) async {
    return _client.get(
      ApiConstants.sourcingNetworkNurseries,
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (plantName?.isNotEmpty == true) 'plant_name': plantName,
        if (radiusKm != null) 'radius_km': radiusKm,
      },
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['nurseries'] as List<dynamic>)
            .map((e) => NearbyNursery.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination =
            ApiPagination.fromJson(d['pagination'] as Map<String, dynamic>);
        return (items, pagination);
      },
    );
  }

}

final sourcingRepositoryProvider = Provider<SourcingRepository>(
  (ref) => SourcingRepository(ApiClient.instance),
);

class SourcingNetworkState {
  final PagedState<NearbyNursery> paged;
  final String search;

  const SourcingNetworkState({
    required this.paged,
    this.search = '',
  });

  SourcingNetworkState copyWith({
    PagedState<NearbyNursery>? paged,
    String? search,
  }) =>
      SourcingNetworkState(
        paged: paged ?? this.paged,
        search: search ?? this.search,
      );
}

class SourcingNetworkNotifier extends StateNotifier<SourcingNetworkState> {
  final SourcingRepository _repo;
  int _page = 0;

  SourcingNetworkNotifier(this._repo)
      : super(SourcingNetworkState(paged: PagedState.initial()));

  Future<void> load({String? search}) async {
    final nextSearch = search ?? state.search;
    state = state.copyWith(
      search: nextSearch,
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) = await _repo.listNetworkNurseries(
        page: 1,
        plantName: nextSearch,
      );
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
        paged: state.paged.copyWith(isLoading: false, error: e),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.paged.isLoadingMore || !state.paged.hasMore) return;
    state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: true));
    try {
      final (items, pagination) = await _repo.listNetworkNurseries(
        page: _page + 1,
        plantName: state.search,
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

final sourcingNetworkProvider =
    StateNotifierProvider<SourcingNetworkNotifier, SourcingNetworkState>((ref) {
  return SourcingNetworkNotifier(ref.watch(sourcingRepositoryProvider));
});

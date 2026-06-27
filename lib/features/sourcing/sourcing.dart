import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/network/api_client.dart';

class FeaturedPlant {
  final int id;
  final int plantId;
  final String plantName;
  final int displayOrder;
  final int? approximateQuantity;
  final String? approximateSize;
  final String? qualityNotes;

  const FeaturedPlant({
    required this.id,
    required this.plantId,
    required this.plantName,
    required this.displayOrder,
    this.approximateQuantity,
    this.approximateSize,
    this.qualityNotes,
  });

  factory FeaturedPlant.fromJson(Map<String, dynamic> j) => FeaturedPlant(
        id: (j['id'] as num).toInt(),
        plantId: (j['plant_id'] as num).toInt(),
        plantName: j['plant_name'] as String? ?? 'Plant',
        displayOrder: (j['display_order'] as num?)?.toInt() ?? 0,
        approximateQuantity: (j['approximate_quantity'] as num?)?.toInt(),
        approximateSize: j['approximate_size'] as String?,
        qualityNotes: j['quality_notes'] as String?,
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
  final List<FeaturedPlant> featuredPlants;

  const NearbyNursery({
    required this.nurseryId,
    required this.nurseryName,
    this.village,
    this.distanceKm,
    required this.roadAccessible,
    required this.lorryAccessible,
    this.contactNumber,
    required this.featuredPlants,
  });

  factory NearbyNursery.fromJson(Map<String, dynamic> j) => NearbyNursery(
        nurseryId: (j['nursery_id'] as num).toInt(),
        nurseryName: j['nursery_name'] as String? ?? 'Nursery',
        village: j['village'] as String?,
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        roadAccessible: j['road_accessible'] as bool? ?? false,
        lorryAccessible: j['lorry_accessible'] as bool? ?? false,
        contactNumber: j['contact_number'] as String?,
        featuredPlants: (j['featured_plants'] as List<dynamic>?)
                ?.map((e) => FeaturedPlant.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class SourcingPost {
  final int id;
  final String postCode;
  final int nurseryId;
  final String nurseryName;
  final String postType;
  final String plantName;
  final String? sizeDescription;
  final int? quantity;
  final String urgency;
  final int radiusKm;
  final int responseCount;
  final String status;
  final String? notes;
  final String createdAt;

  const SourcingPost({
    required this.id,
    required this.postCode,
    required this.nurseryId,
    required this.nurseryName,
    required this.postType,
    required this.plantName,
    this.sizeDescription,
    this.quantity,
    required this.urgency,
    required this.radiusKm,
    required this.responseCount,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory SourcingPost.fromJson(Map<String, dynamic> j) => SourcingPost(
        id: (j['id'] as num).toInt(),
        postCode: j['post_code'] as String? ?? '',
        nurseryId: (j['nursery_id'] as num).toInt(),
        nurseryName: j['nursery_name'] as String? ?? 'Nursery',
        postType: j['post_type'] as String? ?? 'NEED',
        plantName: j['plant_name'] as String? ?? 'Plant',
        sizeDescription: j['size_description'] as String?,
        quantity: (j['quantity'] as num?)?.toInt(),
        urgency: j['urgency'] as String? ?? 'FLEXIBLE',
        radiusKm: (j['radius_km'] as num?)?.toInt() ?? 50,
        responseCount: (j['response_count'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'OPEN',
        notes: j['notes'] as String?,
        createdAt: j['created_at'] as String? ?? '',
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

  Future<(List<SourcingPost>, ApiPagination)> listPosts({
    int page = 1,
    int perPage = 20,
    String? postType,
    String? status,
    String? plantName,
  }) async {
    return _client.get(
      ApiConstants.sourcingPosts,
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (postType?.isNotEmpty == true) 'post_type': postType,
        if (status?.isNotEmpty == true) 'status': status,
        if (plantName?.isNotEmpty == true) 'plant_name': plantName,
      },
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['posts'] as List<dynamic>)
            .map((e) => SourcingPost.fromJson(e as Map<String, dynamic>))
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

class SourcingPostListState {
  final PagedState<SourcingPost> paged;
  final String? postType;

  const SourcingPostListState({
    required this.paged,
    this.postType,
  });

  SourcingPostListState copyWith({
    PagedState<SourcingPost>? paged,
    String? postType,
  }) =>
      SourcingPostListState(
        paged: paged ?? this.paged,
        postType: postType ?? this.postType,
      );
}

class SourcingPostListNotifier extends StateNotifier<SourcingPostListState> {
  final SourcingRepository _repo;
  final String _initialPostType;
  int _page = 0;

  SourcingPostListNotifier(this._repo, this._initialPostType)
      : super(
          SourcingPostListState(
            paged: PagedState.initial(),
            postType: _initialPostType,
          ),
        );

  Future<void> load({String? postType}) async {
    final nextType = postType ?? state.postType ?? _initialPostType;
    state = state.copyWith(
      postType: nextType,
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) = await _repo.listPosts(
        page: 1,
        postType: nextType,
        status: 'OPEN',
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
      final (items, pagination) = await _repo.listPosts(
        page: _page + 1,
        postType: state.postType,
        status: 'OPEN',
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

final sourcingPostsProvider = StateNotifierProvider.family<
    SourcingPostListNotifier, SourcingPostListState, String>((ref, postType) {
  return SourcingPostListNotifier(
    ref.watch(sourcingRepositoryProvider),
    postType,
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/network/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class PlantCategory {
  final int id;
  final String name;
  final bool isActive;

  const PlantCategory(
      {required this.id, required this.name, required this.isActive});

  factory PlantCategory.fromJson(Map<String, dynamic> j) => PlantCategory(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        isActive: j['is_active'] as bool? ?? true,
      );
}

class PlantSize {
  final int id;
  final String sizeCode;
  final String displayName;
  final int displayOrder;

  const PlantSize({
    required this.id,
    required this.sizeCode,
    required this.displayName,
    required this.displayOrder,
  });

  factory PlantSize.fromJson(Map<String, dynamic> j) => PlantSize(
        id: (j['id'] as num).toInt(),
        sizeCode: j['size_code'] as String,
        displayName: j['display_name'] as String,
        displayOrder: (j['display_order'] as num).toInt(),
      );
}

class PlantImage {
  final int id;
  final String imageUrl;
  final bool isPrimary;
  final int displayOrder;

  const PlantImage({
    required this.id,
    required this.imageUrl,
    required this.isPrimary,
    required this.displayOrder,
  });

  factory PlantImage.fromJson(Map<String, dynamic> j) => PlantImage(
        id: (j['id'] as num).toInt(),
        imageUrl: j['image_url'] as String,
        isPrimary: j['is_primary'] as bool? ?? false,
        displayOrder: (j['display_order'] as num?)?.toInt() ?? 0,
      );
}

class Plant {
  final int id;
  final String plantCode;
  final String scientificName;
  final String? commonName;
  final String? englishDescription;
  final String? plantType;
  final String? lightRequirement;
  final String? waterRequirement;
  final bool isActive;
  final List<PlantCategory> categories;
  final List<PlantImage> images;

  const Plant({
    required this.id,
    required this.plantCode,
    required this.scientificName,
    this.commonName,
    this.englishDescription,
    this.plantType,
    this.lightRequirement,
    this.waterRequirement,
    required this.isActive,
    required this.categories,
    required this.images,
  });

  factory Plant.fromJson(Map<String, dynamic> j) => Plant(
        id: (j['id'] as num).toInt(),
        plantCode: j['plant_code'] as String,
        scientificName: j['scientific_name'] as String,
        commonName: j['common_name'] as String?,
        englishDescription: j['english_description'] as String?,
        plantType: j['plant_type'] as String?,
        lightRequirement: j['light_requirement'] as String?,
        waterRequirement: j['water_requirement'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        categories: (j['categories'] as List<dynamic>?)
                ?.map((e) => PlantCategory.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        images: (j['images'] as List<dynamic>?)
                ?.map((e) => PlantImage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  String? get primaryImageUrl {
    if (images.isEmpty) return null;
    final primary = images.where((i) => i.isPrimary).firstOrNull;
    return (primary ?? images.first).imageUrl;
  }

  String get displayName =>
      commonName?.isNotEmpty == true ? commonName! : scientificName;
}

// ── Repository ────────────────────────────────────────────────────────────────

class PlantRepository {
  final ApiClient _client;
  PlantRepository(this._client);

  Future<(List<Plant>, ApiPagination)> listPlants({
    int page = 1,
    int perPage = 20,
    String? search,
    int? categoryId,
    String? plantType,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (search?.isNotEmpty == true) 'search': search,
      if (categoryId != null) 'category_id': categoryId,
      if (plantType?.isNotEmpty == true) 'plant_type': plantType,
    };
    return _client.get(
      ApiConstants.plants,
      queryParameters: params,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['plants'] as List<dynamic>)
            .map((e) => Plant.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination =
            ApiPagination.fromJson(d['pagination'] as Map<String, dynamic>);
        return (items, pagination);
      },
    );
  }

  Future<Plant> getPlant(int id) async {
    return _client.get(
      ApiConstants.plantById(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Plant.fromJson(d['plant'] as Map<String, dynamic>);
      },
    );
  }

  Future<List<PlantCategory>> getCategories() async {
    return _client.get(
      ApiConstants.plantCategories,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return (d['categories'] as List<dynamic>)
            .map((e) => PlantCategory.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<List<PlantSize>> getSizes() async {
    return _client.get(
      ApiConstants.plantSizes,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return (d['sizes'] as List<dynamic>)
            .map((e) => PlantSize.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final plantRepositoryProvider = Provider<PlantRepository>(
  (ref) => PlantRepository(ApiClient.instance),
);

final plantCategoriesProvider =
    FutureProvider<List<PlantCategory>>((ref) async {
  return ref.watch(plantRepositoryProvider).getCategories();
});

final plantSizesProvider = FutureProvider<List<PlantSize>>((ref) async {
  return ref.watch(plantRepositoryProvider).getSizes();
});

// List state
class PlantListState {
  final PagedState<Plant> paged;
  final String search;

  const PlantListState({required this.paged, this.search = ''});

  PlantListState copyWith({PagedState<Plant>? paged, String? search}) =>
      PlantListState(
        paged: paged ?? this.paged,
        search: search ?? this.search,
      );
}

class PlantListNotifier extends StateNotifier<PlantListState> {
  final PlantRepository _repo;
  int _page = 0;

  PlantListNotifier(this._repo)
      : super(PlantListState(paged: PagedState.initial()));

  Future<void> load({String? search}) async {
    final s = search ?? state.search;
    state = state.copyWith(
      search: s,
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) = await _repo.listPlants(page: 1, search: s);
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
      final (items, pagination) = await _repo.listPlants(
        page: _page + 1,
        search: state.search,
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

final plantListProvider =
    StateNotifierProvider<PlantListNotifier, PlantListState>((ref) {
  return PlantListNotifier(ref.watch(plantRepositoryProvider));
});

final plantDetailProvider = FutureProvider.family<Plant, int>((ref, id) async {
  return ref.watch(plantRepositoryProvider).getPlant(id);
});

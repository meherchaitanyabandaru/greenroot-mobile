import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/network/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class NurseryAddress {
  final int id;
  final String? addressType;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final bool isPrimary;

  const NurseryAddress({
    required this.id,
    this.addressType,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    required this.isPrimary,
  });

  factory NurseryAddress.fromJson(Map<String, dynamic> j) => NurseryAddress(
        id: (j['id'] as num).toInt(),
        addressType: j['address_type'] as String?,
        addressLine1: j['address_line1'] as String?,
        addressLine2: j['address_line2'] as String?,
        city: j['city'] as String?,
        state: j['state'] as String?,
        country: j['country'] as String?,
        postalCode: j['postal_code'] as String?,
        isPrimary: j['is_primary'] as bool? ?? false,
      );

  String get fullAddress {
    final parts = [
      addressLine1,
      addressLine2,
      city,
      state,
      postalCode,
    ].where((p) => p?.isNotEmpty == true).toList();
    return parts.isEmpty ? 'No address' : parts.join(', ');
  }
}

class NurseryUserLink {
  final int id;
  final String firstName;
  final String mobile;
  final String? email;
  final String roleCode;
  final String roleName;
  final bool isActive;

  const NurseryUserLink({
    required this.id,
    required this.firstName,
    required this.mobile,
    this.email,
    required this.roleCode,
    required this.roleName,
    required this.isActive,
  });

  factory NurseryUserLink.fromJson(Map<String, dynamic> j) => NurseryUserLink(
        id: (j['id'] as num).toInt(),
        firstName: j['first_name'] as String? ?? '',
        mobile: j['mobile'] as String? ?? '',
        email: j['email'] as String?,
        roleCode: j['role_code'] as String? ?? '',
        roleName: j['role_name'] as String? ?? '',
        isActive: j['is_active'] as bool? ?? true,
      );
}

class Nursery {
  final int id;
  final String? nurseryCode;
  final String name;
  final String? mobile;
  final String? email;
  final String? website;
  final String? description;
  final String status;
  final List<NurseryAddress> addresses;
  final List<NurseryUserLink> users;

  const Nursery({
    required this.id,
    this.nurseryCode,
    required this.name,
    this.mobile,
    this.email,
    this.website,
    this.description,
    required this.status,
    required this.addresses,
    required this.users,
  });

  factory Nursery.fromJson(Map<String, dynamic> j) => Nursery(
        id: (j['id'] as num).toInt(),
        nurseryCode: j['nursery_code'] as String? ?? j['code'] as String?,
        name: j['name'] as String,
        mobile: j['mobile'] as String?,
        email: j['email'] as String?,
        website: j['website'] as String?,
        description: j['description'] as String?,
        status: j['status'] as String? ?? 'active',
        addresses: (j['addresses'] as List<dynamic>?)
                ?.map((e) => NurseryAddress.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        users: (j['users'] as List<dynamic>?)
                ?.map((e) => NurseryUserLink.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  NurseryAddress? get primaryAddress =>
      addresses.where((a) => a.isPrimary).firstOrNull ?? addresses.firstOrNull;

  String get cityState {
    final addr = primaryAddress;
    if (addr == null) return '';
    return [addr.city, addr.state]
        .where((s) => s?.isNotEmpty == true)
        .join(', ');
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class NurseryRepository {
  final ApiClient _client;
  NurseryRepository(this._client);

  Future<(List<Nursery>, ApiPagination)> listNurseries({
    int page = 1,
    int perPage = 20,
    String? search,
    String? city,
    String? state,
    String? status,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (search?.isNotEmpty == true) 'search': search,
      if (city?.isNotEmpty == true) 'city': city,
      if (state?.isNotEmpty == true) 'state': state,
      if (status?.isNotEmpty == true) 'nursery_status': status,
    };
    return _client.get(
      ApiConstants.nurseries,
      queryParameters: params,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['nurseries'] as List<dynamic>)
            .map((e) => Nursery.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination =
            ApiPagination.fromJson(d['pagination'] as Map<String, dynamic>);
        return (items, pagination);
      },
    );
  }

  Future<Nursery> getNursery(int id) async {
    return _client.get(
      ApiConstants.nurseryById(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Nursery.fromJson(d['nursery'] as Map<String, dynamic>);
      },
    );
  }

  Future<List<Nursery>> getMyNurseries() async {
    return _client.get(
      ApiConstants.myNurseries,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return (d['nurseries'] as List<dynamic>)
            .map((e) => Nursery.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final nurseryRepositoryProvider = Provider<NurseryRepository>(
  (ref) => NurseryRepository(ApiClient.instance),
);

class NurseryListNotifier extends StateNotifier<PagedState<Nursery>> {
  final NurseryRepository _repo;
  int _page = 0;
  String _search = '';

  NurseryListNotifier(this._repo) : super(PagedState.initial());

  Future<void> load({String? search}) async {
    _search = search ?? _search;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final (items, pagination) =
          await _repo.listNurseries(page: 1, search: _search);
      _page = 1;
      state = PagedState(
        items: items,
        isLoading: false,
        isLoadingMore: false,
        hasMore: pagination.hasMore,
      );
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final (items, pagination) =
          await _repo.listNurseries(page: _page + 1, search: _search);
      _page++;
      state = state.copyWith(
        items: [...state.items, ...items],
        isLoadingMore: false,
        hasMore: pagination.hasMore,
      );
    } on AppError {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final nurseryListProvider =
    StateNotifierProvider<NurseryListNotifier, PagedState<Nursery>>((ref) {
  return NurseryListNotifier(ref.watch(nurseryRepositoryProvider));
});

final nurseryDetailProvider =
    FutureProvider.family<Nursery, int>((ref, id) async {
  return ref.watch(nurseryRepositoryProvider).getNursery(id);
});

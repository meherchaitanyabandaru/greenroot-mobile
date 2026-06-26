import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/network/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class QuotationItem {
  final int id;
  final int plantId;
  final String scientificName;
  final String? commonName;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  const QuotationItem({
    required this.id,
    required this.plantId,
    required this.scientificName,
    this.commonName,
    this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory QuotationItem.fromJson(Map<String, dynamic> j) => QuotationItem(
        id: (j['id'] as num).toInt(),
        plantId: (j['plant_id'] as num).toInt(),
        scientificName: j['scientific_name'] as String,
        commonName: j['common_name'] as String?,
        description: j['description'] as String?,
        quantity: (j['quantity'] as num).toDouble(),
        unitPrice: (j['unit_price'] as num).toDouble(),
        totalPrice: (j['total_price'] as num).toDouble(),
      );

  String get displayName =>
      commonName?.isNotEmpty == true ? commonName! : scientificName;
}

class Quotation {
  final int id;
  final String quotationCode;
  final String quotationType; // INTERNAL or CUSTOMER
  final int createdByUserId;
  final String? createdByName;
  final int? nurseryId;
  final String? nurseryName;
  final String? nurseryPhone;
  final int? buyerNurseryId;
  final String? recipientName;
  final String? recipientMobile;
  final String? notes;
  final double totalAmount;
  final String status;
  final String createdAt;
  final List<QuotationItem> items;

  const Quotation({
    required this.id,
    required this.quotationCode,
    this.quotationType = 'CUSTOMER',
    required this.createdByUserId,
    this.createdByName,
    this.nurseryId,
    this.nurseryName,
    this.nurseryPhone,
    this.buyerNurseryId,
    this.recipientName,
    this.recipientMobile,
    this.notes,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  bool get isInternal => quotationType == 'INTERNAL';

  factory Quotation.fromJson(Map<String, dynamic> j) => Quotation(
        id: (j['id'] as num).toInt(),
        quotationCode: j['quotation_code'] as String,
        quotationType: j['quotation_type'] as String? ?? 'CUSTOMER',
        createdByUserId: (j['created_by_user_id'] as num).toInt(),
        createdByName: j['created_by_name'] as String?,
        nurseryId: j['nursery_id'] != null ? (j['nursery_id'] as num).toInt() : null,
        nurseryName: j['nursery_name'] as String?,
        nurseryPhone: j['nursery_phone'] as String?,
        buyerNurseryId: j['buyer_nursery_id'] != null ? (j['buyer_nursery_id'] as num).toInt() : null,
        recipientName: j['recipient_name'] as String?,
        recipientMobile: j['recipient_mobile'] as String?,
        notes: j['notes'] as String?,
        totalAmount: (j['total_amount'] as num).toDouble(),
        status: j['status'] as String,
        createdAt: j['created_at'] as String,
        items: (j['items'] as List<dynamic>?)
                ?.map((e) => QuotationItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ── Request DTOs ──────────────────────────────────────────────────────────────

class QuotationItemRequest {
  final int plantId;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  const QuotationItemRequest({
    required this.plantId,
    this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toJson() => {
        'plant_id': plantId,
        if (description?.isNotEmpty == true) 'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
      };
}

// ── Repository ────────────────────────────────────────────────────────────────

class QuotationRepository {
  final ApiClient _client;
  QuotationRepository(this._client);

  Future<(List<Quotation>, ApiPagination)> listQuotations({
    int page = 1,
    int perPage = 20,
  }) async {
    return _client.get(
      ApiConstants.quotations,
      queryParameters: {'page': page, 'per_page': perPage},
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['quotations'] as List<dynamic>)
            .map((e) => Quotation.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination =
            ApiPagination.fromJson(d['pagination'] as Map<String, dynamic>);
        return (items, pagination);
      },
    );
  }

  Future<Quotation> getQuotation(int id) async {
    return _client.get(
      ApiConstants.quotationById(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Quotation.fromJson(d['quotation'] as Map<String, dynamic>);
      },
    );
  }

  Future<Quotation> createQuotation({
    required String quotationType, // 'INTERNAL' or 'CUSTOMER'
    int? nurseryId,
    String? recipientName,
    String? recipientMobile,
    String? notes,
    required List<QuotationItemRequest> items,
  }) async {
    final body = <String, dynamic>{
      'quotation_type': quotationType,
      if (nurseryId != null) 'nursery_id': nurseryId,
      if (recipientName?.isNotEmpty == true) 'recipient_name': recipientName,
      if (recipientMobile?.isNotEmpty == true) 'recipient_mobile': recipientMobile,
      if (notes?.isNotEmpty == true) 'notes': notes,
      'items': items.map((i) => i.toJson()).toList(),
    };
    return _client.post(
      ApiConstants.quotations,
      data: body,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Quotation.fromJson(d['quotation'] as Map<String, dynamic>);
      },
    );
  }

  Future<Quotation> updateQuotation({
    required int id,
    String? recipientName,
    String? recipientMobile,
    String? notes,
    required List<QuotationItemRequest> items,
  }) async {
    final body = <String, dynamic>{
      if (recipientName?.isNotEmpty == true) 'recipient_name': recipientName,
      if (recipientMobile?.isNotEmpty == true) 'recipient_mobile': recipientMobile,
      if (notes?.isNotEmpty == true) 'notes': notes,
      'items': items.map((i) => i.toJson()).toList(),
    };
    return _client.put(
      ApiConstants.quotationById(id),
      data: body,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Quotation.fromJson(d['quotation'] as Map<String, dynamic>);
      },
    );
  }

  Future<void> deleteQuotation(int id) async {
    await _client.delete(ApiConstants.quotationById(id));
  }

  Future<(List<Quotation>, ApiPagination)> listBuyingQuotations({
    int page = 1,
    int perPage = 20,
  }) async {
    return _client.get(
      ApiConstants.quotations,
      queryParameters: {'page': page, 'per_page': perPage, 'buying': 'true'},
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['quotations'] as List<dynamic>)
            .map((e) => Quotation.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination =
            ApiPagination.fromJson(d['pagination'] as Map<String, dynamic>);
        return (items, pagination);
      },
    );
  }

  Future<Quotation> acceptQuotation(int id) async {
    return _client.post(
      '${ApiConstants.quotationById(id)}/buyer-accept',
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Quotation.fromJson(d['quotation'] as Map<String, dynamic>);
      },
    );
  }

  Future<Quotation> rejectQuotation(int id, {String? reason}) async {
    return _client.post(
      '${ApiConstants.quotationById(id)}/buyer-reject',
      data: {if (reason?.isNotEmpty == true) 'reason': reason},
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Quotation.fromJson(d['quotation'] as Map<String, dynamic>);
      },
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final quotationRepositoryProvider = Provider<QuotationRepository>(
  (ref) => QuotationRepository(ApiClient.instance),
);

class QuotationListState {
  final PagedState<Quotation> paged;
  const QuotationListState({required this.paged});
  QuotationListState copyWith({PagedState<Quotation>? paged}) =>
      QuotationListState(paged: paged ?? this.paged);
}

class QuotationListNotifier extends StateNotifier<QuotationListState> {
  final QuotationRepository _repo;
  int _page = 0;

  QuotationListNotifier(this._repo)
      : super(QuotationListState(paged: PagedState.initial()));

  Future<void> load() async {
    state = state.copyWith(
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) = await _repo.listQuotations(page: 1);
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
      final (items, pagination) =
          await _repo.listQuotations(page: _page + 1);
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

  void remove(int id) {
    state = state.copyWith(
      paged: state.paged.copyWith(
        items: state.paged.items.where((q) => q.id != id).toList(),
      ),
    );
  }
}

final quotationListProvider =
    StateNotifierProvider<QuotationListNotifier, QuotationListState>((ref) {
  return QuotationListNotifier(ref.watch(quotationRepositoryProvider));
});

final quotationDetailProvider =
    FutureProvider.family<Quotation, int>((ref, id) async {
  return ref.watch(quotationRepositoryProvider).getQuotation(id);
});

// ── Buying perspective providers ───────────────────────────────────────────────

class BuyingQuotationListNotifier extends StateNotifier<QuotationListState> {
  final QuotationRepository _repo;
  int _page = 0;

  BuyingQuotationListNotifier(this._repo)
      : super(QuotationListState(paged: PagedState.initial()));

  Future<void> load() async {
    state = state.copyWith(
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) = await _repo.listBuyingQuotations(page: 1);
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
      final (items, pagination) =
          await _repo.listBuyingQuotations(page: _page + 1);
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

  void updateItem(Quotation updated) {
    state = state.copyWith(
      paged: state.paged.copyWith(
        items: state.paged.items
            .map((q) => q.id == updated.id ? updated : q)
            .toList(),
      ),
    );
  }
}

final buyingQuotationListProvider =
    StateNotifierProvider<BuyingQuotationListNotifier, QuotationListState>(
        (ref) {
  return BuyingQuotationListNotifier(ref.watch(quotationRepositoryProvider));
});

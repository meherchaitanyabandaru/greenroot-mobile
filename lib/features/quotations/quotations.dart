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
  final String? nurseryBrandColor;
  final int? assignedManagerUserId;
  final String? assignedManagerName;
  final int? convertedOrderId;
  final String? convertedOrderCode;
  final DateTime? convertedAt;
  final int? customerUserId;
  final int? buyerNurseryId;
  final String? recipientName;
  final String? recipientMobile;
  final String? notes;
  final String? rejectionReason;
  final double totalAmount;
  final String status;
  final DateTime? validUntil;
  final DateTime? sentAt;
  final DateTime? customerRespondedAt;
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
    this.nurseryBrandColor,
    this.assignedManagerUserId,
    this.assignedManagerName,
    this.convertedOrderId,
    this.convertedOrderCode,
    this.convertedAt,
    this.customerUserId,
    this.buyerNurseryId,
    this.recipientName,
    this.recipientMobile,
    this.notes,
    this.rejectionReason,
    required this.totalAmount,
    required this.status,
    this.validUntil,
    this.sentAt,
    this.customerRespondedAt,
    required this.createdAt,
    required this.items,
  });

  bool get isInternal => quotationType == 'INTERNAL';

  bool get isExpired =>
      validUntil != null && DateTime.now().isAfter(validUntil!);

  factory Quotation.fromJson(Map<String, dynamic> j) => Quotation(
        id: (j['id'] as num).toInt(),
        quotationCode: j['quotation_code'] as String,
        quotationType: j['quotation_type'] as String? ?? 'CUSTOMER',
        createdByUserId: (j['created_by_user_id'] as num).toInt(),
        createdByName: j['created_by_name'] as String?,
        nurseryId:
            j['nursery_id'] != null ? (j['nursery_id'] as num).toInt() : null,
        nurseryName: j['nursery_name'] as String?,
        nurseryPhone: j['nursery_phone'] as String?,
        nurseryBrandColor: j['nursery_brand_color'] as String?,
        assignedManagerUserId: j['assigned_manager_user_id'] != null
            ? (j['assigned_manager_user_id'] as num).toInt()
            : null,
        assignedManagerName: j['assigned_manager_name'] as String?,
        convertedOrderId: j['converted_order_id'] != null
            ? (j['converted_order_id'] as num).toInt()
            : null,
        convertedOrderCode: j['converted_order_code'] as String?,
        convertedAt: j['converted_at'] != null
            ? DateTime.tryParse(j['converted_at'] as String)?.toLocal()
            : null,
        customerUserId: j['customer_user_id'] != null
            ? (j['customer_user_id'] as num).toInt()
            : null,
        buyerNurseryId: j['buyer_nursery_id'] != null
            ? (j['buyer_nursery_id'] as num).toInt()
            : null,
        recipientName: j['recipient_name'] as String?,
        recipientMobile: j['recipient_mobile'] as String?,
        notes: j['notes'] as String?,
        rejectionReason: j['rejection_reason'] as String?,
        totalAmount: (j['total_amount'] as num).toDouble(),
        status: j['status'] as String,
        validUntil: j['valid_until'] != null
            ? DateTime.tryParse(j['valid_until'] as String)?.toLocal()
            : null,
        sentAt: j['sent_at'] != null
            ? DateTime.tryParse(j['sent_at'] as String)?.toLocal()
            : null,
        customerRespondedAt: j['customer_responded_at'] != null
            ? DateTime.tryParse(j['customer_responded_at'] as String)?.toLocal()
            : null,
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
    String? search,
    String? status,
    bool unassignedOnly = false,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? amountMin,
    double? amountMax,
  }) async {
    return _client.get(
      ApiConstants.quotations,
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (search?.isNotEmpty == true) 'search': search,
        if (status?.isNotEmpty == true) 'status': status,
        if (unassignedOnly) 'unassigned': 'true',
        if (dateFrom != null)
          'date_from':
              '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}',
        if (dateTo != null)
          'date_to':
              '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}',
        if (amountMin != null) 'amount_min': amountMin.toString(),
        if (amountMax != null) 'amount_max': amountMax.toString(),
      },
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
    int? assignedManagerUserId, // owner-only: pre-assign on creation
    int? customerUserId,
    String? recipientName,
    String? recipientMobile,
    DateTime? validUntil,
    String? notes,
    required List<QuotationItemRequest> items,
  }) async {
    final body = <String, dynamic>{
      'quotation_type': quotationType,
      if (nurseryId != null) 'nursery_id': nurseryId,
      if (assignedManagerUserId != null)
        'assigned_manager_user_id': assignedManagerUserId,
      if (customerUserId != null) 'customer_user_id': customerUserId,
      if (recipientName?.isNotEmpty == true) 'recipient_name': recipientName,
      if (recipientMobile?.isNotEmpty == true)
        'recipient_mobile': recipientMobile,
      if (validUntil != null)
        'valid_until': validUntil.toUtc().toIso8601String(),
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
    int? customerUserId,
    String? recipientName,
    String? recipientMobile,
    DateTime? validUntil,
    String? notes,
    required List<QuotationItemRequest> items,
  }) async {
    final body = <String, dynamic>{
      if (customerUserId != null) 'customer_user_id': customerUserId,
      if (recipientName?.isNotEmpty == true) 'recipient_name': recipientName,
      if (recipientMobile?.isNotEmpty == true)
        'recipient_mobile': recipientMobile,
      if (validUntil != null)
        'valid_until': validUntil.toUtc().toIso8601String(),
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

  Future<Quotation> updateQuotationCustomer({
    required int id,
    int? customerUserId,
    String? recipientName,
    String? recipientMobile,
  }) async {
    final body = <String, dynamic>{
      if (customerUserId != null) 'customer_user_id': customerUserId,
      if (recipientName?.isNotEmpty == true) 'recipient_name': recipientName,
      if (recipientMobile?.isNotEmpty == true)
        'recipient_mobile': recipientMobile,
    };
    return _client.put(
      ApiConstants.quotationCustomer(id),
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

  Future<Quotation> approveQuotation(int id) async {
    return sendToCustomer(id);
  }

  Future<Quotation> sendToCustomer(int id) async {
    return _client.post(
      ApiConstants.quotationSend(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Quotation.fromJson(d['quotation'] as Map<String, dynamic>);
      },
    );
  }

  Future<Quotation> recallQuotation(int id) async {
    return _client.post(
      ApiConstants.quotationRecall(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Quotation.fromJson(d['quotation'] as Map<String, dynamic>);
      },
    );
  }

  Future<Quotation> convertToOrder(int id) async {
    return _client.post(
      ApiConstants.quotationConvert(id),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Quotation.fromJson(d['quotation'] as Map<String, dynamic>);
      },
    );
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

  Future<Quotation> assignManager(int id, {required int managerUserId}) async {
    return _client.post(
      ApiConstants.quotationAssignManager(id),
      data: {'manager_user_id': managerUserId},
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Quotation.fromJson(d['quotation'] as Map<String, dynamic>);
      },
    );
  }

  Future<Quotation> unassignManager(int id) async {
    return _client.delete(
      ApiConstants.quotationAssignManager(id),
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

// Tab filter for the quotation list screen.
// Owner: all / unassigned / mine.  Manager: all / created / assigned.
enum QuotationTab { all, unassigned, mine, createdByMe, assignedToMe }

class QuotationListState {
  final PagedState<Quotation> paged;
  final String search;
  final String? statusFilter;
  final QuotationTab tab;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? amountMin;
  final double? amountMax;

  const QuotationListState({
    required this.paged,
    this.search = '',
    this.statusFilter,
    this.tab = QuotationTab.all,
    this.dateFrom,
    this.dateTo,
    this.amountMin,
    this.amountMax,
  });

  bool get hasActiveFilters =>
      statusFilter != null ||
      dateFrom != null ||
      dateTo != null ||
      amountMin != null ||
      amountMax != null;

  QuotationListState copyWith({
    PagedState<Quotation>? paged,
    String? search,
    String? statusFilter,
    bool clearStatus = false,
    QuotationTab? tab,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? amountMin,
    double? amountMax,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearAmountMin = false,
    bool clearAmountMax = false,
  }) =>
      QuotationListState(
        paged: paged ?? this.paged,
        search: search ?? this.search,
        statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
        tab: tab ?? this.tab,
        dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
        dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
        amountMin: clearAmountMin ? null : (amountMin ?? this.amountMin),
        amountMax: clearAmountMax ? null : (amountMax ?? this.amountMax),
      );
}

class QuotationListNotifier extends StateNotifier<QuotationListState> {
  final QuotationRepository _repo;
  int _page = 0;

  QuotationListNotifier(this._repo)
      : super(QuotationListState(paged: PagedState.initial()));

  Future<void> load() async {
    final s = state;
    state = state.copyWith(
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) = await _repo.listQuotations(
        page: 1,
        search: s.search,
        status: s.statusFilter,
        unassignedOnly: s.tab == QuotationTab.unassigned,
        dateFrom: s.dateFrom,
        dateTo: s.dateTo,
        amountMin: s.amountMin,
        amountMax: s.amountMax,
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
      final (items, pagination) = await _repo.listQuotations(
        page: _page + 1,
        search: state.search,
        status: state.statusFilter,
        unassignedOnly: state.tab == QuotationTab.unassigned,
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
        amountMin: state.amountMin,
        amountMax: state.amountMax,
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

  void setSearch(String q) {
    state = state.copyWith(search: q);
    load();
  }

  void setStatusFilter(String? status) {
    state = state.copyWith(statusFilter: status, clearStatus: status == null);
    load();
  }

  void setTab(QuotationTab tab) {
    state = state.copyWith(tab: tab);
    load();
  }

  void applyFilters({
    String? statusFilter,
    bool clearStatus = false,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? amountMin,
    double? amountMax,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearAmountMin = false,
    bool clearAmountMax = false,
  }) {
    state = state.copyWith(
      statusFilter: statusFilter,
      clearStatus: clearStatus,
      dateFrom: dateFrom,
      dateTo: dateTo,
      amountMin: amountMin,
      amountMax: amountMax,
      clearDateFrom: clearDateFrom,
      clearDateTo: clearDateTo,
      clearAmountMin: clearAmountMin,
      clearAmountMax: clearAmountMax,
    );
    load();
  }

  void clearAllFilters() {
    state = QuotationListState(
      paged: state.paged,
      search: state.search,
      tab: state.tab,
    );
    load();
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
    FutureProvider.autoDispose.family<Quotation, int>((ref, id) async {
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
        paged: state.paged.copyWith(isLoading: false, error: e),
      );
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

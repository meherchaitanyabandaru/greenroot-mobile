import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';

// ── Models ────────────────────────────────────────────────────

class MarketAd {
  final int id;
  final String code;
  final int nurseryId;
  final String nurseryName;
  final bool nurseryVerified;
  final String? nurseryMobile;
  final String plantName;
  final String? categoryName;
  final String title;
  final String? description;
  final int? quantity;
  final String? sizeDescription;
  final double? pricePerUnit;
  final String? priceUnit;
  final List<String> photos;
  final String status;
  final int viewCount;
  final int saveCount;
  final int enquiryCount;
  final bool isSavedByMe;
  final DateTime? expiresAt;
  final DateTime? publishedAt;
  final DateTime createdAt;

  const MarketAd({
    required this.id,
    required this.code,
    required this.nurseryId,
    required this.nurseryName,
    required this.nurseryVerified,
    this.nurseryMobile,
    required this.plantName,
    this.categoryName,
    required this.title,
    this.description,
    this.quantity,
    this.sizeDescription,
    this.pricePerUnit,
    this.priceUnit,
    required this.photos,
    required this.status,
    required this.viewCount,
    required this.saveCount,
    required this.enquiryCount,
    required this.isSavedByMe,
    this.expiresAt,
    this.publishedAt,
    required this.createdAt,
  });

  factory MarketAd.fromJson(Map<String, dynamic> j) => MarketAd(
        id: (j['id'] as num).toInt(),
        code: j['code'] as String,
        nurseryId: (j['nursery_id'] as num).toInt(),
        nurseryName: j['nursery_name'] as String,
        nurseryVerified: j['nursery_verified'] as bool? ?? false,
        nurseryMobile: j['nursery_mobile'] as String?,
        plantName: j['plant_name'] as String,
        categoryName: j['category_name'] as String?,
        title: j['title'] as String,
        description: j['description'] as String?,
        quantity: j['quantity'] != null ? (j['quantity'] as num).toInt() : null,
        sizeDescription: j['size_description'] as String?,
        pricePerUnit: j['price_per_unit'] != null ? (j['price_per_unit'] as num).toDouble() : null,
        priceUnit: j['price_unit'] as String?,
        photos: (j['photos'] as List?)?.map((e) => e as String).toList() ?? [],
        status: j['status'] as String,
        viewCount: (j['view_count'] as num?)?.toInt() ?? 0,
        saveCount: (j['save_count'] as num?)?.toInt() ?? 0,
        enquiryCount: (j['enquiry_count'] as num?)?.toInt() ?? 0,
        isSavedByMe: j['is_saved_by_me'] as bool? ?? false,
        expiresAt: j['expires_at'] != null ? DateTime.tryParse(j['expires_at'] as String) : null,
        publishedAt: j['published_at'] != null ? DateTime.tryParse(j['published_at'] as String) : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class MarketEnquiryMessage {
  final int id;
  final int sentByNurseryId;
  final String nurseryName;
  final String body;
  final DateTime createdAt;

  const MarketEnquiryMessage({
    required this.id,
    required this.sentByNurseryId,
    required this.nurseryName,
    required this.body,
    required this.createdAt,
  });

  factory MarketEnquiryMessage.fromJson(Map<String, dynamic> j) =>
      MarketEnquiryMessage(
        id: (j['id'] as num).toInt(),
        sentByNurseryId: (j['sent_by_nursery_id'] as num).toInt(),
        nurseryName: j['nursery_name'] as String,
        body: j['body'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class MarketEnquiry {
  final int id;
  final String code;
  final int adId;
  final String adTitle;
  final String adNurseryName;
  final String enquiryNurseryName;
  final String message;
  final int? quantityNeeded;
  final String status;
  final DateTime createdAt;
  final List<MarketEnquiryMessage> messages;

  const MarketEnquiry({
    required this.id,
    required this.code,
    required this.adId,
    required this.adTitle,
    required this.adNurseryName,
    required this.enquiryNurseryName,
    required this.message,
    this.quantityNeeded,
    required this.status,
    required this.createdAt,
    this.messages = const [],
  });

  factory MarketEnquiry.fromJson(Map<String, dynamic> j) => MarketEnquiry(
        id: (j['id'] as num).toInt(),
        code: j['code'] as String,
        adId: (j['ad_id'] as num).toInt(),
        adTitle: j['ad_title'] as String,
        adNurseryName: j['ad_nursery_name'] as String,
        enquiryNurseryName: j['enquiring_nursery_name'] as String,
        message: j['message'] as String,
        quantityNeeded: j['quantity_needed'] != null
            ? (j['quantity_needed'] as num).toInt()
            : null,
        status: j['status'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        messages: (j['messages'] as List?)
                ?.map((e) =>
                    MarketEnquiryMessage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ── Repository ────────────────────────────────────────────────

class MarketRepository {
  final ApiClient _client;
  const MarketRepository(this._client);

  Future<Map<String, dynamic>> getAds(Map<String, String> params) =>
      _client.get<Map<String, dynamic>>(
        ApiConstants.marketAds,
        queryParameters: params,
      );

  Future<Map<String, dynamic>> getMyAds() =>
      _client.get<Map<String, dynamic>>(ApiConstants.marketMyAds);

  Future<Map<String, dynamic>> getSavedAds() =>
      _client.get<Map<String, dynamic>>(ApiConstants.marketSavedAds);

  Future<Map<String, dynamic>> getEnquiries(Map<String, String> params) =>
      _client.get<Map<String, dynamic>>(
        ApiConstants.marketEnquiries,
        queryParameters: params,
      );

  Future<Map<String, dynamic>> getEnquiryById(int id) =>
      _client.get<Map<String, dynamic>>(ApiConstants.marketEnquiryById(id));

  Future<Map<String, dynamic>> replyToEnquiry(int enquiryId, String body) =>
      _client.post<Map<String, dynamic>>(
        ApiConstants.marketEnquiryAction(enquiryId, 'reply'),
        data: {'body': body},
      );

  Future<Map<String, dynamic>> toggleSaveAd(int adId) =>
      _client.post<Map<String, dynamic>>(
        ApiConstants.marketAdAction(adId, 'save'),
      );

  Future<void> sendEnquiry(int adId, String message, {int? qty}) =>
      _client.post<Map<String, dynamic>>(
        ApiConstants.marketAdAction(adId, 'enquiries'),
        data: {'message': message, if (qty != null) 'quantity_needed': qty},
      );

  Future<void> reportAd(int adId, String reason, {String? notes}) =>
      _client.post<Map<String, dynamic>>(
        ApiConstants.marketAdAction(adId, 'report'),
        data: {'reason': reason, if (notes != null) 'notes': notes},
      );

  Future<Map<String, dynamic>> createAd({
    required String plantName,
    required String title,
    String? categoryName,
    String? description,
    int? quantity,
    double? pricePerUnit,
    String? sizeDescription,
    List<String> photos = const [],
  }) =>
      _client.post<Map<String, dynamic>>(ApiConstants.marketAds, data: {
        'plant_name': plantName,
        'title': title,
        if (categoryName != null) 'category_name': categoryName,
        if (description != null) 'description': description,
        if (quantity != null) 'quantity': quantity,
        if (pricePerUnit != null) 'price_per_unit': pricePerUnit,
        if (sizeDescription != null) 'size_description': sizeDescription,
        'photos': photos,
      });

  Future<void> updateAd(
    int adId, {
    String? plantName,
    String? title,
    String? categoryName,
    String? description,
    int? quantity,
    double? pricePerUnit,
    String? sizeDescription,
    List<String>? photos,
  }) =>
      _client.patch<Map<String, dynamic>>(
        ApiConstants.marketAdById(adId),
        data: {
          if (plantName != null) 'plant_name': plantName,
          if (title != null) 'title': title,
          if (categoryName != null) 'category_name': categoryName,
          if (description != null) 'description': description,
          if (quantity != null) 'quantity': quantity,
          if (pricePerUnit != null) 'price_per_unit': pricePerUnit,
          if (sizeDescription != null) 'size_description': sizeDescription,
          if (photos != null) 'photos': photos,
        },
      );

  Future<void> performAdAction(int adId, String action) =>
      _client.post<Map<String, dynamic>>(
        ApiConstants.marketAdAction(adId, action),
      );

  Future<Map<String, dynamic>> presignUpload({
    required String bucket,
    required String fileName,
    required String contentType,
  }) =>
      _client.post<Map<String, dynamic>>(
        ApiConstants.storagePresign,
        data: {
          'bucket': bucket,
          'file_name': fileName,
          'content_type': contentType,
        },
      );
}

final marketRepositoryProvider = Provider<MarketRepository>(
  (ref) => MarketRepository(ref.watch(apiClientProvider)),
);

// ── Photo Upload ──────────────────────────────────────────────

// Raw Dio instance intentionally without auth headers — used only for S3
// presigned PUT requests which must not include the Authorization header.
final _rawDio = Dio();

/// Resizes to max 1200px, draws "GreenRoot" watermark, encodes as JPEG q80.
/// Falls back to raw bytes if decoding fails (e.g. unsupported HEIC on web).
Future<Uint8List> _processAdPhoto(Uint8List rawBytes) async {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) return rawBytes;

  // Resize — max 1200px on longest side
  const maxDim = 1200;
  final src = (decoded.width > maxDim || decoded.height > maxDim)
      ? (decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxDim,
              interpolation: img.Interpolation.linear)
          : img.copyResize(decoded, height: maxDim,
              interpolation: img.Interpolation.linear))
      : decoded;

  // Watermark: "GreenRoot" at bottom-right with drop-shadow
  const watermark = 'GreenRoot';
  final font = img.arial24;
  final textW = _bitmapTextWidth(font, watermark);
  final x = src.width - textW - 14;
  final y = src.height - font.lineHeight - 14;

  // Shadow (dark, offset 1px)
  img.drawString(src, watermark, font: font, x: x + 1, y: y + 1,
      color: img.ColorRgba8(0, 0, 0, 110));
  // Main text (white, semi-transparent)
  img.drawString(src, watermark, font: font, x: x, y: y,
      color: img.ColorRgba8(255, 255, 255, 200));

  return Uint8List.fromList(img.encodeJpg(src, quality: 80));
}

int _bitmapTextWidth(img.BitmapFont font, String text) => text.codeUnits
    .fold<int>(0, (w, c) => w + (font.characters[c]?.xAdvance ?? 0));

Future<String> uploadAdPhoto(XFile file, MarketRepository repo) async {
  final rawBytes = await file.readAsBytes();
  final processed = await _processAdPhoto(rawBytes);
  const contentType = 'image/jpeg';

  final presign = await repo.presignUpload(
    bucket: 'market-ads',
    fileName: '${file.name.split('.').first}.jpg',
    contentType: contentType,
  );

  final uploadUrl = presign['upload_url'] as String;
  final fileUrl = presign['file_url'] as String;

  await _rawDio.put<void>(
    uploadUrl,
    data: processed,
    options: Options(
      headers: {
        'Content-Type': contentType,
        'Content-Length': processed.length,
      },
      sendTimeout: const Duration(seconds: 60),
    ),
  );

  return fileUrl;
}

// ── Latest Ads (home screen) ──────────────────────────────────

final latestAdsProvider = FutureProvider<List<MarketAd>>((ref) async {
  final data = await ref.watch(marketRepositoryProvider).getAds(
    {'per_page': '6', 'page': '1'},
  );
  return (data['ads'] as List?)
          ?.map((e) => MarketAd.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [];
});

// ── Browse / Search / Sort / Pagination ──────────────────────

enum MarketSort {
  newest('newest', 'Newest First'),
  priceAsc('price_asc', 'Price: Low to High'),
  priceDesc('price_desc', 'Price: High to Low'),
  popular('popular', 'Most Popular');

  const MarketSort(this.value, this.label);
  final String value;
  final String label;
}

class BrowseAdsState {
  final List<MarketAd> ads;
  final int total;
  final int nextPage;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String query;
  final MarketSort sort;
  final String? error;
  final String? category;
  final double? minPrice;
  final double? maxPrice;

  const BrowseAdsState({
    this.ads = const [],
    this.total = 0,
    this.nextPage = 1,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.query = '',
    this.sort = MarketSort.newest,
    this.error,
    this.category,
    this.minPrice,
    this.maxPrice,
  });

  int get activeFilterCount =>
      (category != null ? 1 : 0) +
      (minPrice != null ? 1 : 0) +
      (maxPrice != null ? 1 : 0);

  BrowseAdsState copyWith({
    List<MarketAd>? ads,
    int? total,
    int? nextPage,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? query,
    MarketSort? sort,
    String? error,
    bool clearError = false,
    String? category,
    bool clearCategory = false,
    double? minPrice,
    bool clearMinPrice = false,
    double? maxPrice,
    bool clearMaxPrice = false,
  }) =>
      BrowseAdsState(
        ads: ads ?? this.ads,
        total: total ?? this.total,
        nextPage: nextPage ?? this.nextPage,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        query: query ?? this.query,
        sort: sort ?? this.sort,
        error: clearError ? null : (error ?? this.error),
        category: clearCategory ? null : (category ?? this.category),
        minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
        maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      );
}

class BrowseAdsNotifier extends StateNotifier<BrowseAdsState> {
  final MarketRepository _repo;
  Timer? _debounce;
  static const _perPage = 20;

  BrowseAdsNotifier(this._repo) : super(const BrowseAdsState()) {
    _load();
  }

  void onQueryChanged(String q) {
    _debounce?.cancel();
    state = BrowseAdsState(
      query: q,
      sort: state.sort,
      category: state.category,
      minPrice: state.minPrice,
      maxPrice: state.maxPrice,
    );
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void setSort(MarketSort sort) {
    if (sort == state.sort) return;
    state = BrowseAdsState(
      query: state.query,
      sort: sort,
      category: state.category,
      minPrice: state.minPrice,
      maxPrice: state.maxPrice,
    );
    _load();
  }

  void setFilters({String? category, double? minPrice, double? maxPrice}) {
    state = BrowseAdsState(
      query: state.query,
      sort: state.sort,
      category: category,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
    _load();
  }

  Future<void> refresh() {
    state = BrowseAdsState(
      query: state.query,
      sort: state.sort,
      category: state.category,
      minPrice: state.minPrice,
      maxPrice: state.maxPrice,
    );
    return _load();
  }

  Future<void> loadMore() {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) {
      return Future.value();
    }
    state = state.copyWith(isLoadingMore: true);
    return _load();
  }

  Future<void> _load() async {
    final q = state.query;
    final sort = state.sort;
    final page = state.nextPage;
    final category = state.category;
    final minPrice = state.minPrice;
    final maxPrice = state.maxPrice;

    try {
      final params = <String, String>{
        'per_page': '$_perPage',
        'page': '$page',
        if (q.isNotEmpty) 'q': q,
        if (sort != MarketSort.newest) 'sort': sort.value,
        if (category != null) 'category': category,
        if (minPrice != null) 'min_price': minPrice.toStringAsFixed(0),
        if (maxPrice != null) 'max_price': maxPrice.toStringAsFixed(0),
      };

      final data = await _repo.getAds(params);

      final fetched = (data['ads'] as List?)
              ?.map((e) => MarketAd.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final total = (data['total'] as num?)?.toInt() ?? 0;
      final combined = page == 1 ? fetched : [...state.ads, ...fetched];

      state = BrowseAdsState(
        ads: combined,
        total: total,
        nextPage: page + 1,
        isLoading: false,
        isLoadingMore: false,
        hasMore: combined.length < total,
        query: q,
        sort: sort,
        category: category,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final browseAdsProvider =
    StateNotifierProvider<BrowseAdsNotifier, BrowseAdsState>(
  (ref) => BrowseAdsNotifier(ref.watch(marketRepositoryProvider)),
);

// ── My Ads ────────────────────────────────────────────────────

final myAdsProvider = FutureProvider<List<MarketAd>>((ref) async {
  final data = await ref.watch(marketRepositoryProvider).getMyAds();
  final ads = (data['ads'] as List?) ?? [];
  return ads.map((e) => MarketAd.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Saved Ads ─────────────────────────────────────────────────

final savedAdsProvider = FutureProvider<List<MarketAd>>((ref) async {
  final data = await ref.watch(marketRepositoryProvider).getSavedAds();
  final ads = (data['ads'] as List?) ?? [];
  return ads.map((e) => MarketAd.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Enquiries ─────────────────────────────────────────────────

final receivedEnquiriesProvider =
    FutureProvider<List<MarketEnquiry>>((ref) async {
  final data = await ref.watch(marketRepositoryProvider).getEnquiries(
    {'direction': 'received', 'per_page': '50'},
  );
  return (data['enquiries'] as List?)
          ?.map((e) => MarketEnquiry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [];
});

final sentEnquiriesProvider = FutureProvider<List<MarketEnquiry>>((ref) async {
  final data = await ref.watch(marketRepositoryProvider).getEnquiries(
    {'direction': 'sent', 'per_page': '50'},
  );
  return (data['enquiries'] as List?)
          ?.map((e) => MarketEnquiry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [];
});

final enquiryDetailProvider =
    FutureProvider.family<MarketEnquiry, int>((ref, id) async {
  final data = await ref
      .watch(marketRepositoryProvider)
      .getEnquiryById(id);
  return MarketEnquiry.fromJson(data['enquiry'] as Map<String, dynamic>);
});

// ── Reply to Enquiry ──────────────────────────────────────────

class _ReplyEnquiryNotifier extends StateNotifier<AsyncValue<void>> {
  final int enquiryId;
  final Ref _ref;

  _ReplyEnquiryNotifier(this.enquiryId, this._ref)
      : super(const AsyncValue.data(null));

  Future<void> reply(String body) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(marketRepositoryProvider).replyToEnquiry(enquiryId, body);
      _ref.invalidate(enquiryDetailProvider(enquiryId));
      _ref.invalidate(receivedEnquiriesProvider);
      _ref.invalidate(sentEnquiriesProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }
}

final replyEnquiryProvider = StateNotifierProvider.family<_ReplyEnquiryNotifier,
    AsyncValue<void>, int>(
  (ref, id) => _ReplyEnquiryNotifier(id, ref),
);

// ── Per-ad Saved State ────────────────────────────────────────

final adSavedProvider = StateProvider.family<bool?, int>((ref, _) => null);

class _ToggleSaveNotifier extends StateNotifier<AsyncValue<void>> {
  final int adId;
  final Ref _ref;

  _ToggleSaveNotifier(this.adId, this._ref) : super(const AsyncValue.data(null));

  Future<void> toggle() async {
    state = const AsyncValue.loading();
    try {
      final data = await _ref.read(marketRepositoryProvider).toggleSaveAd(adId);
      final saved = data['saved'] as bool;
      _ref.read(adSavedProvider(adId).notifier).state = saved;
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final toggleSaveProvider = StateNotifierProvider.family<_ToggleSaveNotifier,
    AsyncValue<void>, int>(
  (ref, adId) => _ToggleSaveNotifier(adId, ref),
);

// ── Send Enquiry ──────────────────────────────────────────────

class _SendEnquiryNotifier extends StateNotifier<AsyncValue<void>> {
  final int adId;
  final Ref _ref;

  _SendEnquiryNotifier(this.adId, this._ref) : super(const AsyncValue.data(null));

  Future<void> send(String message, {int? qty}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(marketRepositoryProvider).sendEnquiry(adId, message, qty: qty);
      _ref.invalidate(receivedEnquiriesProvider);
      _ref.invalidate(sentEnquiriesProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }
}

final sendEnquiryProvider = StateNotifierProvider.family<_SendEnquiryNotifier,
    AsyncValue<void>, int>(
  (ref, adId) => _SendEnquiryNotifier(adId, ref),
);

// ── Report Ad ─────────────────────────────────────────────────

class _ReportNotifier extends StateNotifier<AsyncValue<void>> {
  final int adId;
  final Ref _ref;

  _ReportNotifier(this.adId, this._ref) : super(const AsyncValue.data(null));

  Future<void> report(String reason, {String? notes}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(marketRepositoryProvider).reportAd(adId, reason, notes: notes);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }
}

final reportAdProvider =
    StateNotifierProvider.family<_ReportNotifier, AsyncValue<void>, int>(
  (ref, adId) => _ReportNotifier(adId, ref),
);

// ── Post / Edit Ad ────────────────────────────────────────────

class _PostAdNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  _PostAdNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<int> create({
    required String plantName,
    required String title,
    String? categoryName,
    String? description,
    int? quantity,
    double? pricePerUnit,
    String? sizeDescription,
    List<String> photos = const [],
  }) async {
    state = const AsyncValue.loading();
    try {
      final resp = await _ref.read(marketRepositoryProvider).createAd(
        plantName: plantName,
        title: title,
        categoryName: categoryName,
        description: description,
        quantity: quantity,
        pricePerUnit: pricePerUnit,
        sizeDescription: sizeDescription,
        photos: photos,
      );
      final adId = (resp['ad']['id'] as num).toInt();
      _ref.invalidate(myAdsProvider);
      state = const AsyncValue.data(null);
      return adId;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }

  Future<void> update(
    int adId, {
    String? plantName,
    String? title,
    String? categoryName,
    String? description,
    int? quantity,
    double? pricePerUnit,
    String? sizeDescription,
    List<String>? photos,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(marketRepositoryProvider).updateAd(
        adId,
        plantName: plantName,
        title: title,
        categoryName: categoryName,
        description: description,
        quantity: quantity,
        pricePerUnit: pricePerUnit,
        sizeDescription: sizeDescription,
        photos: photos,
      );
      _ref.invalidate(myAdsProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }
}

final postAdProvider =
    StateNotifierProvider<_PostAdNotifier, AsyncValue<void>>(
  (ref) => _PostAdNotifier(ref),
);

// ── Ad Actions (publish / pause / resume / archive / renew) ──────────────────

class _AdActionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  _AdActionNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> perform(int adId, String action) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(marketRepositoryProvider).performAdAction(adId, action);
      _ref.invalidate(myAdsProvider);
      _ref.invalidate(latestAdsProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }
}

final adActionProvider =
    StateNotifierProvider<_AdActionNotifier, AsyncValue<void>>(
  (ref) => _AdActionNotifier(ref),
);

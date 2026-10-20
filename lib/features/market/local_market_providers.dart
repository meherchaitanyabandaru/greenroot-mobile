import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../../core/domain/lifecycle_models.dart';
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
  final int? plantId;
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

  /// The viewer's existing chat about this ad; open it instead of enquiring.
  final int? myEnquiryId;

  /// Why GreenRoot hid (SUSPENDED) or removed (REMOVED) the ad.
  final String? moderationNote;

  /// Who posted it and their camera selfie, shown on the ad.
  final String? postedByName;
  final String? postedByPhoto;
  final DateTime? expiresAt;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final BackendLifecycle? lifecycle;
  final MarketAdCapabilities? capabilities;
  final MarketAdSummary? summary;

  const MarketAd({
    required this.id,
    required this.code,
    required this.nurseryId,
    required this.nurseryName,
    required this.nurseryVerified,
    this.nurseryMobile,
    this.plantId,
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
    this.myEnquiryId,
    this.moderationNote,
    this.postedByName,
    this.postedByPhoto,
    this.expiresAt,
    this.publishedAt,
    required this.createdAt,
    this.lifecycle,
    this.capabilities,
    this.summary,
  });

  factory MarketAd.fromJson(Map<String, dynamic> j) => MarketAd(
        id: (j['id'] as num).toInt(),
        code: j['code'] as String,
        nurseryId: (j['nursery_id'] as num).toInt(),
        nurseryName: j['nursery_name'] as String,
        nurseryVerified: j['nursery_verified'] as bool? ?? false,
        nurseryMobile: j['nursery_mobile'] as String?,
        plantId: (j['plant_id'] as num?)?.toInt(),
        plantName: j['plant_name'] as String,
        categoryName: j['category_name'] as String?,
        title: j['title'] as String,
        description: j['description'] as String?,
        quantity: j['quantity'] != null ? (j['quantity'] as num).toInt() : null,
        sizeDescription: j['size_description'] as String?,
        pricePerUnit: j['price_per_unit'] != null
            ? (j['price_per_unit'] as num).toDouble()
            : null,
        priceUnit: j['price_unit'] as String?,
        photos: (j['photos'] as List?)?.map((e) => e as String).toList() ?? [],
        status: j['status'] as String,
        viewCount: (j['view_count'] as num?)?.toInt() ?? 0,
        saveCount: (j['save_count'] as num?)?.toInt() ?? 0,
        enquiryCount: (j['enquiry_count'] as num?)?.toInt() ?? 0,
        isSavedByMe: j['is_saved_by_me'] as bool? ?? false,
        myEnquiryId: (j['my_enquiry_id'] as num?)?.toInt(),
        moderationNote: j['moderation_note'] as String?,
        postedByName: j['posted_by_name'] as String?,
        postedByPhoto: j['posted_by_photo'] as String?,
        expiresAt: j['expires_at'] != null
            ? DateTime.tryParse(j['expires_at'] as String)
            : null,
        publishedAt: j['published_at'] != null
            ? DateTime.tryParse(j['published_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
        lifecycle: j['lifecycle'] is Map<String, dynamic>
            ? BackendLifecycle.fromJson(j['lifecycle'] as Map<String, dynamic>)
            : null,
        capabilities: j['capabilities'] is Map<String, dynamic>
            ? MarketAdCapabilities.fromJson(
                j['capabilities'] as Map<String, dynamic>,
              )
            : null,
        summary: j['summary'] is Map<String, dynamic>
            ? MarketAdSummary.fromJson(j['summary'] as Map<String, dynamic>)
            : null,
      );
}

class MarketAdCapabilities {
  final bool canEdit;
  final bool canPublish;
  final bool canPause;
  final bool canResume;
  final bool canRenew;
  final bool canArchive;
  final bool canSave;
  final bool canEnquire;
  final bool canReport;

  const MarketAdCapabilities({
    this.canEdit = false,
    this.canPublish = false,
    this.canPause = false,
    this.canResume = false,
    this.canRenew = false,
    this.canArchive = false,
    this.canSave = false,
    this.canEnquire = false,
    this.canReport = false,
  });

  factory MarketAdCapabilities.fromJson(Map<String, dynamic> j) =>
      MarketAdCapabilities(
        canEdit: j['can_edit'] as bool? ?? false,
        canPublish: j['can_publish'] as bool? ?? false,
        canPause: j['can_pause'] as bool? ?? false,
        canResume: j['can_resume'] as bool? ?? false,
        canRenew: j['can_renew'] as bool? ?? false,
        canArchive: j['can_archive'] as bool? ?? false,
        canSave: j['can_save'] as bool? ?? false,
        canEnquire: j['can_enquire'] as bool? ?? false,
        canReport: j['can_report'] as bool? ?? false,
      );
}

class MarketAdSummary {
  final bool isOwner;
  final bool isLive;
  final bool isExpired;
  final int? daysRemaining;

  const MarketAdSummary({
    this.isOwner = false,
    this.isLive = false,
    this.isExpired = false,
    this.daysRemaining,
  });

  factory MarketAdSummary.fromJson(Map<String, dynamic> j) => MarketAdSummary(
        isOwner: j['is_owner'] as bool? ?? false,
        isLive: j['is_live'] as bool? ?? false,
        isExpired: j['is_expired'] as bool? ?? false,
        daysRemaining: (j['days_remaining'] as num?)?.toInt(),
      );
}

/// A nursery's public market page, opened from the seller photo on an ad.
class SellerProfile {
  final int nurseryId;
  final String nurseryName;
  final bool verified;
  final String? description;
  final String? city;
  final String? ownerName;
  final String? ownerPhoto;
  final DateTime memberSince;
  final int adsPosted;
  final int liveAds;
  final int dealsAgreed;
  final List<MarketAd> ads;
  final List<SellerTopItem> topItems;

  const SellerProfile({
    required this.nurseryId,
    required this.nurseryName,
    required this.verified,
    this.description,
    this.city,
    this.ownerName,
    this.ownerPhoto,
    required this.memberSince,
    required this.adsPosted,
    required this.liveAds,
    required this.dealsAgreed,
    required this.ads,
    this.topItems = const [],
  });

  factory SellerProfile.fromJson(Map<String, dynamic> j) => SellerProfile(
        nurseryId: (j['nursery_id'] as num).toInt(),
        nurseryName: j['nursery_name'] as String,
        verified: j['verified'] as bool? ?? false,
        description: j['description'] as String?,
        city: j['city'] as String?,
        ownerName: j['owner_name'] as String?,
        ownerPhoto: j['owner_photo'] as String?,
        memberSince: DateTime.parse(j['member_since'] as String),
        adsPosted: (j['ads_posted'] as num?)?.toInt() ?? 0,
        liveAds: (j['live_ads'] as num?)?.toInt() ?? 0,
        dealsAgreed: (j['deals_agreed'] as num?)?.toInt() ?? 0,
        ads: (j['ads'] as List?)
                ?.map((e) => MarketAd.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        topItems: (j['top_items'] as List?)
                ?.map((e) => SellerTopItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// One plant a nursery showcases as a top item (up to 20 per nursery).
class SellerTopItem {
  final String plantName;
  final String? commonName;
  final String sizeName;
  final double? unitPrice;
  final String? qualityNotes;
  final String? photo;

  const SellerTopItem({
    required this.plantName,
    this.commonName,
    required this.sizeName,
    this.unitPrice,
    this.qualityNotes,
    this.photo,
  });

  factory SellerTopItem.fromJson(Map<String, dynamic> j) => SellerTopItem(
        plantName: j['plant_name'] as String,
        commonName: j['common_name'] as String?,
        sizeName: j['size_name'] as String? ?? '',
        unitPrice: (j['unit_price'] as num?)?.toDouble(),
        qualityNotes: j['quality_notes'] as String?,
        photo: j['photo'] as String?,
      );
}

class MarketEnquiryMessage {
  final int id;
  final int sentByNurseryId;
  final String nurseryName;
  final String senderName;

  /// TEXT, OFFER or SYSTEM (e.g. "Deal agreed …").
  final String type;
  final String body;
  final double? offerPrice;
  final int? offerQuantity;

  /// PENDING, ACCEPTED, DECLINED or WITHDRAWN (replaced by a newer offer).
  final String? offerStatus;
  final bool isMine;

  /// The viewer can accept or decline this offer.
  final bool canRespond;
  final DateTime createdAt;

  const MarketEnquiryMessage({
    required this.id,
    required this.sentByNurseryId,
    required this.nurseryName,
    this.senderName = '',
    this.type = 'TEXT',
    required this.body,
    this.offerPrice,
    this.offerQuantity,
    this.offerStatus,
    this.isMine = false,
    this.canRespond = false,
    required this.createdAt,
  });

  bool get isOffer => type == 'OFFER';
  bool get isSystem => type == 'SYSTEM';

  factory MarketEnquiryMessage.fromJson(Map<String, dynamic> j) =>
      MarketEnquiryMessage(
        id: (j['id'] as num).toInt(),
        sentByNurseryId: (j['sent_by_nursery_id'] as num).toInt(),
        nurseryName: j['nursery_name'] as String,
        senderName: j['sender_name'] as String? ?? '',
        type: j['type'] as String? ?? 'TEXT',
        body: j['body'] as String,
        offerPrice: (j['offer_price_per_unit'] as num?)?.toDouble(),
        offerQuantity: (j['offer_quantity'] as num?)?.toInt(),
        offerStatus: j['offer_status'] as String?,
        isMine: j['is_mine'] as bool? ?? false,
        canRespond: j['can_respond'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class MarketEnquiry {
  final int id;
  final String code;
  final int adId;
  final String adTitle;
  final String adStatus;
  final double? adPricePerUnit;
  final String? adPriceUnit;
  final String? adPhoto;
  final String adNurseryName;
  final String enquiryNurseryName;
  final String message;
  final int? quantityNeeded;
  final String status;
  final double? agreedPricePerUnit;
  final int? agreedQuantity;
  final DateTime createdAt;
  final List<MarketEnquiryMessage> messages;
  final BackendLifecycle? lifecycle;
  final MarketEnquiryCapabilities? capabilities;
  final MarketEnquirySummary? summary;

  const MarketEnquiry({
    required this.id,
    required this.code,
    required this.adId,
    required this.adTitle,
    this.adStatus = 'PUBLISHED',
    this.adPricePerUnit,
    this.adPriceUnit,
    this.adPhoto,
    required this.adNurseryName,
    required this.enquiryNurseryName,
    required this.message,
    this.quantityNeeded,
    required this.status,
    this.agreedPricePerUnit,
    this.agreedQuantity,
    required this.createdAt,
    this.messages = const [],
    this.lifecycle,
    this.capabilities,
    this.summary,
  });

  bool get isDealAgreed => status == 'DEAL_AGREED';

  factory MarketEnquiry.fromJson(Map<String, dynamic> j) => MarketEnquiry(
        id: (j['id'] as num).toInt(),
        code: j['code'] as String,
        adId: (j['ad_id'] as num).toInt(),
        adTitle: j['ad_title'] as String,
        adStatus: j['ad_status'] as String? ?? 'PUBLISHED',
        adPricePerUnit: (j['ad_price_per_unit'] as num?)?.toDouble(),
        adPriceUnit: j['ad_price_unit'] as String?,
        adPhoto: j['ad_photo'] as String?,
        adNurseryName: j['ad_nursery_name'] as String,
        enquiryNurseryName: j['enquiring_nursery_name'] as String,
        message: j['message'] as String,
        quantityNeeded: j['quantity_needed'] != null
            ? (j['quantity_needed'] as num).toInt()
            : null,
        status: j['status'] as String,
        agreedPricePerUnit: (j['agreed_price_per_unit'] as num?)?.toDouble(),
        agreedQuantity: (j['agreed_quantity'] as num?)?.toInt(),
        createdAt: DateTime.parse(j['created_at'] as String),
        messages: (j['messages'] as List?)
                ?.map((e) =>
                    MarketEnquiryMessage.fromJson(e as Map<String, dynamic>),)
                .toList() ??
            [],
        lifecycle: j['lifecycle'] is Map<String, dynamic>
            ? BackendLifecycle.fromJson(j['lifecycle'] as Map<String, dynamic>)
            : null,
        capabilities: j['capabilities'] is Map<String, dynamic>
            ? MarketEnquiryCapabilities.fromJson(
                j['capabilities'] as Map<String, dynamic>,
              )
            : null,
        summary: j['summary'] is Map<String, dynamic>
            ? MarketEnquirySummary.fromJson(
                j['summary'] as Map<String, dynamic>,)
            : null,
      );
}

class MarketEnquiryCapabilities {
  final bool canReply;
  final bool canOffer;
  final bool canClose;
  final bool canCancel;

  /// Why nobody can write, e.g. "this ad is no longer active".
  final String? readOnlyReason;

  const MarketEnquiryCapabilities({
    this.canReply = false,
    this.canOffer = false,
    this.canClose = false,
    this.canCancel = false,
    this.readOnlyReason,
  });

  factory MarketEnquiryCapabilities.fromJson(Map<String, dynamic> j) =>
      MarketEnquiryCapabilities(
        canReply: j['can_reply'] as bool? ?? false,
        canOffer: j['can_offer'] as bool? ?? false,
        canClose: j['can_close'] as bool? ?? false,
        canCancel: j['can_cancel'] as bool? ?? false,
        readOnlyReason: j['read_only_reason'] as String?,
      );
}

class MarketEnquirySummary {
  final bool isBuyer;
  final bool isSeller;
  final bool isOpen;

  const MarketEnquirySummary({
    this.isBuyer = false,
    this.isSeller = false,
    this.isOpen = false,
  });

  factory MarketEnquirySummary.fromJson(Map<String, dynamic> j) =>
      MarketEnquirySummary(
        isBuyer: j['is_buyer'] as bool? ?? false,
        isSeller: j['is_seller'] as bool? ?? false,
        isOpen: j['is_open'] as bool? ?? false,
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

  Future<SellerProfile> getSeller(int nurseryId) async {
    final data = await _client.get<Map<String, dynamic>>(
        '${ApiConstants.marketNurseries}/$nurseryId',);
    return SellerProfile.fromJson(data['seller'] as Map<String, dynamic>);
  }

  Future<MarketAd> getAd(int id) async {
    final data =
        await _client.get<Map<String, dynamic>>(ApiConstants.marketAdById(id));
    return MarketAd.fromJson(data['ad'] as Map<String, dynamic>);
  }

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

  /// Starts the chat about [adId] and returns its id.
  Future<int> sendEnquiry(int adId, String message, {int? qty}) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiConstants.marketAdAction(adId, 'enquiries'),
      data: {'message': message, if (qty != null) 'quantity_needed': qty},
    );
    return ((data['enquiry'] as Map<String, dynamic>)['id'] as num).toInt();
  }

  Future<void> makeOffer(int enquiryId, double price, {int? quantity}) =>
      _client.post<Map<String, dynamic>>(
        ApiConstants.marketEnquiryAction(enquiryId, 'offers'),
        data: {'price_per_unit': price, if (quantity != null) 'quantity': quantity},
      );

  Future<void> respondToOffer(int enquiryId, int messageId, {required bool accept}) =>
      _client.post<Map<String, dynamic>>(
        ApiConstants.marketEnquiryAction(
          enquiryId,
          'offers/$messageId/${accept ? 'accept' : 'decline'}',
        ),
      );

  /// [action] is `close` (seller) or `cancel` (buyer).
  Future<void> endEnquiry(int enquiryId, String action) =>
      _client.post<Map<String, dynamic>>(
        ApiConstants.marketEnquiryAction(enquiryId, action),
      );

  Future<void> reportAd(int adId, String reason, {String? notes}) =>
      _client.post<Map<String, dynamic>>(
        ApiConstants.marketAdAction(adId, 'report'),
        data: {'reason': reason, if (notes != null) 'notes': notes},
      );

  Future<Map<String, dynamic>> createAd({
    int? plantId,
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
        if (plantId != null) 'plant_id': plantId,
        'plant_name': plantName,
        'title': title,
        if (categoryName != null) 'category_name': categoryName,
        if (description != null) 'description': description,
        if (quantity != null) 'quantity': quantity,
        if (pricePerUnit != null) 'price_per_unit': pricePerUnit,
        if (sizeDescription != null) 'size_description': sizeDescription,
        'photos': photos,
      },);

  Future<void> updateAd(
    int adId, {
    int? plantId,
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
          if (plantId != null) 'plant_id': plantId,
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
          ? img.copyResize(decoded,
              width: maxDim, interpolation: img.Interpolation.linear,)
          : img.copyResize(decoded,
              height: maxDim, interpolation: img.Interpolation.linear,))
      : decoded;

  // Watermark: "GreenRoot" at bottom-right with drop-shadow
  const watermark = 'GreenRoot';
  final font = img.arial24;
  final textW = _bitmapTextWidth(font, watermark);
  final x = src.width - textW - 14;
  final y = src.height - font.lineHeight - 14;

  // Shadow (dark, offset 1px)
  img.drawString(src, watermark,
      font: font, x: x + 1, y: y + 1, color: img.ColorRgba8(0, 0, 0, 110),);
  // Main text (white, semi-transparent)
  img.drawString(src, watermark,
      font: font, x: x, y: y, color: img.ColorRgba8(255, 255, 255, 200),);

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

final latestAdsProvider = FutureProvider.autoDispose<List<MarketAd>>((ref) async {
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
  final double? nearLat;
  final double? nearLon;
  final double? radiusKm;

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
    this.nearLat,
    this.nearLon,
    this.radiusKm,
  });

  int get activeFilterCount =>
      (category != null ? 1 : 0) +
      (minPrice != null ? 1 : 0) +
      (maxPrice != null ? 1 : 0) +
      (nearLat != null ? 1 : 0);

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
    double? nearLat,
    bool clearNearby = false,
    double? nearLon,
    double? radiusKm,
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
        nearLat: clearNearby ? null : (nearLat ?? this.nearLat),
        nearLon: clearNearby ? null : (nearLon ?? this.nearLon),
        radiusKm: clearNearby ? null : (radiusKm ?? this.radiusKm),
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
      nearLat: state.nearLat,
      nearLon: state.nearLon,
      radiusKm: state.radiusKm,
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
      nearLat: state.nearLat,
      nearLon: state.nearLon,
      radiusKm: state.radiusKm,
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
      nearLat: state.nearLat,
      nearLon: state.nearLon,
      radiusKm: state.radiusKm,
    );
    _load();
  }

  void setNearby({double? lat, double? lon, double radiusKm = 50}) {
    state = BrowseAdsState(
      query: state.query,
      sort: state.sort,
      category: state.category,
      minPrice: state.minPrice,
      maxPrice: state.maxPrice,
      nearLat: lat,
      nearLon: lon,
      radiusKm: lat != null ? radiusKm : null,
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
      nearLat: state.nearLat,
      nearLon: state.nearLon,
      radiusKm: state.radiusKm,
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
    final nearLat = state.nearLat;
    final nearLon = state.nearLon;
    final radiusKm = state.radiusKm;

    try {
      final params = <String, String>{
        'per_page': '$_perPage',
        'page': '$page',
        if (q.isNotEmpty) 'q': q,
        if (sort != MarketSort.newest) 'sort': sort.value,
        if (category != null) 'category': category,
        if (minPrice != null) 'min_price': minPrice.toStringAsFixed(0),
        if (maxPrice != null) 'max_price': maxPrice.toStringAsFixed(0),
        if (nearLat != null) 'near_lat': nearLat.toStringAsFixed(6),
        if (nearLon != null) 'near_lon': nearLon.toStringAsFixed(6),
        if (radiusKm != null) 'radius_km': radiusKm.toStringAsFixed(1),
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
        nearLat: nearLat,
        nearLon: nearLon,
        radiusKm: radiusKm,
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

final myAdsProvider = FutureProvider.autoDispose<List<MarketAd>>((ref) async {
  final data = await ref.watch(marketRepositoryProvider).getMyAds();
  final ads = (data['ads'] as List?) ?? [];
  return ads.map((e) => MarketAd.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Saved Ads ─────────────────────────────────────────────────

final savedAdsProvider = FutureProvider.autoDispose<List<MarketAd>>((ref) async {
  final data = await ref.watch(marketRepositoryProvider).getSavedAds();
  final ads = (data['ads'] as List?) ?? [];
  return ads.map((e) => MarketAd.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Enquiries ─────────────────────────────────────────────────

// autoDispose: inboxes and chats reload each time they are opened, so a new
// chat or a chat that turned read-only never shows stale.
final receivedEnquiriesProvider =
    FutureProvider.autoDispose<List<MarketEnquiry>>((ref) async {
  final data = await ref.watch(marketRepositoryProvider).getEnquiries(
    {'direction': 'received', 'per_page': '50'},
  );
  return (data['enquiries'] as List?)
          ?.map((e) => MarketEnquiry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [];
});

final sentEnquiriesProvider =
    FutureProvider.autoDispose<List<MarketEnquiry>>((ref) async {
  final data = await ref.watch(marketRepositoryProvider).getEnquiries(
    {'direction': 'sent', 'per_page': '50'},
  );
  return (data['enquiries'] as List?)
          ?.map((e) => MarketEnquiry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [];
});

final sellerProfileProvider =
    FutureProvider.autoDispose.family<SellerProfile, int>(
  (ref, nurseryId) => ref.watch(marketRepositoryProvider).getSeller(nurseryId),
);

/// The full ad as the viewer sees it, including their existing chat id.
final adDetailProvider = FutureProvider.autoDispose.family<MarketAd, int>(
  (ref, id) => ref.watch(marketRepositoryProvider).getAd(id),
);

/// The chats other nurseries started about one of my ads.
final adEnquiriesProvider =
    FutureProvider.autoDispose.family<List<MarketEnquiry>, int>((ref, adId) async {
  final data = await ref.watch(marketRepositoryProvider).getEnquiries(
    {'direction': 'received', 'ad_id': '$adId', 'per_page': '50'},
  );
  return (data['enquiries'] as List?)
          ?.map((e) => MarketEnquiry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [];
});

final enquiryDetailProvider =
    FutureProvider.autoDispose.family<MarketEnquiry, int>((ref, id) async {
  final data = await ref.watch(marketRepositoryProvider).getEnquiryById(id);
  return MarketEnquiry.fromJson(data['enquiry'] as Map<String, dynamic>);
});

// ── Reply to Enquiry ──────────────────────────────────────────

class EnquiryChatNotifier extends StateNotifier<AsyncValue<void>> {
  final int enquiryId;
  final Ref _ref;

  EnquiryChatNotifier(this.enquiryId, this._ref)
      : super(const AsyncValue.data(null));

  MarketRepository get _repo => _ref.read(marketRepositoryProvider);

  Future<void> reply(String body) =>
      _run(() => _repo.replyToEnquiry(enquiryId, body));

  Future<void> offer(double price, {int? quantity}) =>
      _run(() => _repo.makeOffer(enquiryId, price, quantity: quantity));

  Future<void> respond(int messageId, {required bool accept}) =>
      _run(() => _repo.respondToOffer(enquiryId, messageId, accept: accept));

  Future<void> end(String action) =>
      _run(() => _repo.endEnquiry(enquiryId, action));

  /// Runs a chat action, then reloads the chat and both inbox lists.
  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
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

final replyEnquiryProvider =
    StateNotifierProvider.family<EnquiryChatNotifier, AsyncValue<void>, int>(
  (ref, id) => EnquiryChatNotifier(id, ref),
);

// ── Per-ad Saved State ────────────────────────────────────────

final adSavedProvider = StateProvider.family<bool?, int>((ref, _) => null);

class _ToggleSaveNotifier extends StateNotifier<AsyncValue<void>> {
  final int adId;
  final Ref _ref;

  _ToggleSaveNotifier(this.adId, this._ref)
      : super(const AsyncValue.data(null));

  Future<void> toggle() async {
    state = const AsyncValue.loading();
    try {
      final data = await _ref.read(marketRepositoryProvider).toggleSaveAd(adId);
      final saved = data['saved'] as bool;
      _ref.read(adSavedProvider(adId).notifier).state = saved;
      _ref.invalidate(savedAdsProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final toggleSaveProvider =
    StateNotifierProvider.family<_ToggleSaveNotifier, AsyncValue<void>, int>(
  (ref, adId) => _ToggleSaveNotifier(adId, ref),
);

// ── Send Enquiry ──────────────────────────────────────────────

class _SendEnquiryNotifier extends StateNotifier<AsyncValue<void>> {
  final int adId;
  final Ref _ref;

  _SendEnquiryNotifier(this.adId, this._ref)
      : super(const AsyncValue.data(null));

  /// Returns the new chat's id so the caller can open it.
  Future<int> send(String message, {int? qty}) async {
    state = const AsyncValue.loading();
    try {
      final enquiryId = await _ref
          .read(marketRepositoryProvider)
          .sendEnquiry(adId, message, qty: qty);
      _ref.invalidate(receivedEnquiriesProvider);
      _ref.invalidate(sentEnquiriesProvider);
      state = const AsyncValue.data(null);
      return enquiryId;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }
}

final sendEnquiryProvider =
    StateNotifierProvider.family<_SendEnquiryNotifier, AsyncValue<void>, int>(
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
      await _ref
          .read(marketRepositoryProvider)
          .reportAd(adId, reason, notes: notes);
      // A serious report hides the ad at once; drop it from the lists now.
      _ref.invalidate(browseAdsProvider);
      _ref.invalidate(latestAdsProvider);
      _ref.invalidate(adDetailProvider(adId));
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
    int? plantId,
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
            plantId: plantId,
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
      _ref.invalidate(latestAdsProvider);
      _ref.invalidate(browseAdsProvider);
      state = const AsyncValue.data(null);
      return adId;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }

  Future<void> update(
    int adId, {
    int? plantId,
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
            plantId: plantId,
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
      _ref.invalidate(browseAdsProvider);
      _ref.invalidate(savedAdsProvider);
      _ref.invalidate(latestAdsProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }
}

final postAdProvider = StateNotifierProvider<_PostAdNotifier, AsyncValue<void>>(
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

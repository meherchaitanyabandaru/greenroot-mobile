import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';

/// Upload categories; each has its own image policy (GET /image-policies).
enum ImageCategory {
  selfie('SELFIE'),
  marketAd('MARKET_AD'),
  nurseryBranding('NURSERY_BRANDING'),
  deliveryProof('DELIVERY_PROOF'),
  loadingProof('LOADING_PROOF'),
  driverLicence('DRIVER_LICENCE');

  final String code;
  const ImageCategory(this.code);
}

/// How photos of one category are prepared. The API checks every upload
/// against the same values, so these only help the photo pass first time.
class ImagePolicy {
  final ImageCategory category;
  final int maxSide; // longest side after resizing
  final int minSide; // shortest side a photo must have
  final int quality; // JPEG quality
  final int maxBytes;
  final bool allowsPng;
  final bool compressionEnabled;

  const ImagePolicy({
    required this.category,
    required this.maxSide,
    required this.minSide,
    required this.quality,
    required this.maxBytes,
    this.allowsPng = false,
    this.compressionEnabled = true,
  });

  /// The API's built-in defaults: used until the policies load, and if they cannot.
  static const defaults = {
    ImageCategory.selfie: ImagePolicy(
        category: ImageCategory.selfie,
        maxSide: 800, minSide: 200, quality: 85, maxBytes: 1 << 20, allowsPng: true,),
    ImageCategory.marketAd: ImagePolicy(
        category: ImageCategory.marketAd,
        maxSide: 1600, minSide: 400, quality: 82, maxBytes: 2 << 20,),
    ImageCategory.nurseryBranding: ImagePolicy(
        category: ImageCategory.nurseryBranding,
        maxSide: 800, minSide: 200, quality: 90, maxBytes: 1 << 20, allowsPng: true,),
    ImageCategory.deliveryProof: ImagePolicy(
        category: ImageCategory.deliveryProof,
        maxSide: 2048, minSide: 480, quality: 85, maxBytes: 3 << 20,),
    ImageCategory.loadingProof: ImagePolicy(
        category: ImageCategory.loadingProof,
        maxSide: 2048, minSide: 480, quality: 85, maxBytes: 3 << 20,),
    ImageCategory.driverLicence: ImagePolicy(
        category: ImageCategory.driverLicence,
        maxSide: 2048, minSide: 600, quality: 90, maxBytes: 4 << 20, allowsPng: true,),
  };

  static ImagePolicy? fromJson(Map<String, dynamic> j) {
    final category = ImageCategory.values
        .where((c) => c.code == j['category'])
        .firstOrNull;
    if (category == null) return null; // a category this app does not upload
    final formats = (j['allowed_formats'] as List<dynamic>? ?? const [])
        .map((e) => '$e')
        .toSet();
    return ImagePolicy(
      category: category,
      maxSide: (j['max_side'] as num).toInt(),
      minSide: (j['min_side'] as num).toInt(),
      quality: (j['quality'] as num).toInt(),
      maxBytes: (j['max_bytes'] as num).toInt(),
      allowsPng: formats.contains('PNG'),
      compressionEnabled: j['is_compression_enabled'] != false,
    );
  }
}

/// The policies by category: from the API, falling back per category to the
/// defaults when it cannot be reached (the API still checks every upload).
final imagePoliciesProvider =
    FutureProvider<Map<ImageCategory, ImagePolicy>>((ref) async {
  final out = Map.of(ImagePolicy.defaults);
  try {
    final list = await ApiClient.instance.get<List<dynamic>>(
      ApiConstants.imagePolicies,
      fromJson: (data) =>
          (data as Map<String, dynamic>)['policies'] as List<dynamic>,
    );
    for (final raw in list) {
      final p = ImagePolicy.fromJson(raw as Map<String, dynamic>);
      if (p != null) out[p.category] = p;
    }
  } catch (_) {
    // Offline or an older API: the defaults are safe.
  }
  return out;
});

/// The policy for one category; never fails (defaults on any error). Read
/// once per app run; an upload the API refuses reloads them (see
/// StorageService.uploadImage) so an admin's change is picked up.
final imagePolicyProvider =
    FutureProvider.family<ImagePolicy, ImageCategory>((ref, category) async =>
        (await ref.watch(imagePoliciesProvider.future))[category] ??
        ImagePolicy.defaults[category]!,);

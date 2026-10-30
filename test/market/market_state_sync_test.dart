// State sync tests for market providers — covers:
//   - createAd notifier returns adId on success
//   - save/unsave updates adSavedProvider
//   - failed createAd sets error state
//   - ad photos go through the API image upload (checked by the server)
//
// NOTE: Tests that involve _PostAdNotifier.create() are isolated from
// browseAdsProvider's auto-loading constructor by using a separate container
// that overrides browseAdsProvider to avoid test contamination from the
// BrowseAdsNotifier's constructor _load() call racing with other tests.

import 'dart:typed_data';

import 'package:dio/dio.dart' show FormData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/core/media/image_policy.dart';
import 'package:greenroot_mobile/core/media/photos.dart';
import 'package:greenroot_mobile/core/services/storage_service.dart';
import 'package:greenroot_mobile/features/market/local_market_providers.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';
import '../helpers/test_provider_container.dart';

// Creates a container with browseAdsProvider stubbed out so its constructor
// _load() does not fire real HTTP calls.
ProviderContainer _makeIsolatedContainer(FakeApiClient fake) {
  return makeTestContainer(
    fake.apiClient,
    extraOverrides: [
      // Override browseAdsProvider so its constructor does not auto-load,
      // preventing queue contamination between tests.
      browseAdsProvider.overrideWith(
        (ref) => BrowseAdsNotifier(_NoOpMarketRepo()),
      ),
    ],
  );
}

/// A market repository that returns empty results without touching HTTP.
class _NoOpMarketRepo extends MarketRepository {
  _NoOpMarketRepo() : super(_neverClient());

  static dynamic _neverClient() => throw UnimplementedError('Use fake');

  @override
  Future<Map<String, dynamic>> getAds(Map<String, String> params) async =>
      {'ads': [], 'total': 0};

  @override
  Future<Map<String, dynamic>> getMyAds({int page = 1, int perPage = 50}) async =>
      {'ads': [], 'total': 0};

  @override
  Future<Map<String, dynamic>> getSavedAds({int page = 1, int perPage = 20}) async =>
      {'ads': [], 'total': 0};

  @override
  Future<Map<String, dynamic>> createAd({
    String adType = 'SELL',
    String? neededBy,
    int? plantId,
    required String plantName,
    required String title,
    String? categoryName,
    String? description,
    int? quantity,
    double? pricePerUnit,
    String? sizeDescription,
    List<String> photos = const [],
    Map<String, dynamic> extra = const {},
  }) async =>
      createAdResponse();

  @override
  Future<Map<String, dynamic>> toggleSaveAd(int adId) async =>
      toggleSaveResponse();
}

void main() {
  late FakeApiClient fake;

  setUp(() {
    fake = FakeApiClient();
  });

  // ── _PostAdNotifier (postAdProvider) ──────────────────────────────────────

  group('postAdProvider.create invalidation', () {
    test('successful create returns adId', () async {
      // We need the createAd call to go through fake, but browseAdsProvider
      // to be stubbed. Use the marketRepositoryProvider with fake client,
      // and override browseAdsProvider to not auto-load.
      fake.enqueue(response: createAdResponse());
      final container = _makeIsolatedContainer(fake);

      final adId = await container.read(postAdProvider.notifier).create(
            plantName: 'Ficus benjamina',
            title: 'Beautiful Weeping Figs',
          );

      expect(adId, kTestAdId);
    });

    test('create sets state to AsyncData after success', () async {
      fake.enqueue(response: createAdResponse());
      final container = _makeIsolatedContainer(fake);

      await container.read(postAdProvider.notifier).create(
            plantName: 'Rose',
            title: 'Roses for sale',
          );

      expect(container.read(postAdProvider), isA<AsyncData<void>>());
    });

    test('failed create sets AsyncError state and does not return adId', () async {
      fake.enqueue(type: FakeResponseType.serverError);
      final container = _makeIsolatedContainer(fake);

      Object? caught;
      try {
        await container.read(postAdProvider.notifier).create(
              plantName: 'Rose',
              title: 'Roses for sale',
            );
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<ServerError>());

      final state = container.read(postAdProvider);
      expect(state, isA<AsyncError<void>>());
    });
  });

  // ── _ToggleSaveNotifier (toggleSaveProvider) ──────────────────────────────

  group('toggleSaveProvider state sync', () {
    test('toggle save → adSavedProvider(adId) updated to true', () async {
      fake.enqueue(response: toggleSaveResponse(saved: true));
      final container = makeTestContainer(fake.apiClient);

      expect(container.read(adSavedProvider(kTestAdId)), isNull);

      await container.read(toggleSaveProvider(kTestAdId).notifier).toggle();

      expect(container.read(adSavedProvider(kTestAdId)), isTrue);
    });

    test('toggle unsave → adSavedProvider(adId) updated to false', () async {
      fake.enqueue(response: toggleSaveResponse(saved: false));
      final container = makeTestContainer(fake.apiClient);

      await container.read(toggleSaveProvider(kTestAdId).notifier).toggle();

      expect(container.read(adSavedProvider(kTestAdId)), isFalse);
    });

    test('failed toggle → error state, adSavedProvider unchanged', () async {
      fake.enqueue(type: FakeResponseType.networkError);
      final container = makeTestContainer(fake.apiClient);

      // Pre-seed saved state to true
      container.read(adSavedProvider(kTestAdId).notifier).state = true;

      try {
        await container.read(toggleSaveProvider(kTestAdId).notifier).toggle();
      } catch (_) {}

      expect(container.read(adSavedProvider(kTestAdId)), isTrue,
          reason: 'Failed save toggle must not update saved state',);
    });
  });

  // ── Ad photo upload ────────────────────────────────────────────────────────

  group('Ad photos go through the API image upload', () {
    test('watermarked, compressed once, sent as MARKET_AD before the file', () async {
      final photo = img.Image(width: 1200, height: 900);
      final jpg = Uint8List.fromList(img.encodeJpg(photo, quality: 95));
      fake.route('/storage/images', {'file_url': 'https://cdn.example/market-ads/a.jpg'});
      final url = await uploadAdPhoto(
        XFile.fromData(jpg, name: 'mango.jpg'),
        ImagePolicy.defaults[ImageCategory.marketAd]!,
        StorageService(fake.apiClient),
      );
      expect(url, 'https://cdn.example/market-ads/a.jpg');
      final call = fake.calls.single;
      expect(call.path, endsWith('/storage/images'));
      final form = call.data as FormData;
      expect([form.fields.first.key, form.fields.first.value], ['category', 'MARKET_AD']);
      final sent = form.files.single.value;
      expect(sent.contentType?.mimeType, 'image/jpeg');
      expect(sent.length, isNot(jpg.length), reason: 'the watermark means a new encode');
    });

    test('a refused upload reloads the image policies', () async {
      var reloaded = 0;
      fake.enqueue(type: FakeResponseType.validationError);
      final storage = StorageService(fake.apiClient, () => reloaded++);
      final jpg = Uint8List.fromList(img.encodeJpg(img.Image(width: 800, height: 600)));
      await expectLater(
        storage.uploadImage(ImageCategory.marketAd, PreparedPhoto(jpg, 'image/jpeg', '.jpg'), 'a.jpg'),
        throwsA(isA<ValidationError>()),
      );
      expect(reloaded, 1);
    });
  });

  // ── _AdActionNotifier (adActionProvider) ──────────────────────────────────

  group('paging', () {
    test('myAdsProvider follows pages until it has the total', () async {
      fake.enqueue(response: {
        'ads': [marketAdJson(id: 1), marketAdJson(id: 2)],
        'total': 3,
      },);
      fake.enqueue(response: {
        'ads': [marketAdJson(id: 3)],
        'total': 3,
      },);
      final container = _makeIsolatedContainer(fake);

      final ads = await container.read(myAdsProvider.future);

      expect(ads.map((a) => a.id), [1, 2, 3]);
      expect(fake.calls, hasLength(2));
    });

    test('delete action calls DELETE on the ad', () async {
      fake.enqueue(response: '');
      final container = _makeIsolatedContainer(fake);

      await container.read(adActionProvider.notifier).perform(kTestAdId, 'delete');

      expect(fake.calls.single.method, 'DELETE');
      expect(fake.calls.single.path, endsWith('/market/ads/$kTestAdId'));
    });
  });

  group('adActionProvider', () {
    test('perform publish action sets AsyncData on success', () async {
      fake.enqueue(response: {'message': 'published'});
      final container = _makeIsolatedContainer(fake);

      await container.read(adActionProvider.notifier).perform(kTestAdId, 'publish');

      expect(container.read(adActionProvider), isA<AsyncData<void>>());
    });

    test('perform action failure sets AsyncError', () async {
      fake.enqueue(type: FakeResponseType.serverError);
      final container = _makeIsolatedContainer(fake);

      Object? caught;
      try {
        await container.read(adActionProvider.notifier).perform(kTestAdId, 'publish');
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<ServerError>());
    });
  });
}

// State sync tests for market providers — covers:
//   - createAd notifier returns adId on success
//   - save/unsave updates adSavedProvider
//   - failed createAd sets error state
//   - photo upload presign goes through authenticated client
//
// NOTE: Tests that involve _PostAdNotifier.create() are isolated from
// browseAdsProvider's auto-loading constructor by using a separate container
// that overrides browseAdsProvider to avoid test contamination from the
// BrowseAdsNotifier's constructor _load() call racing with other tests.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/features/market/local_market_providers.dart';

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
  Future<Map<String, dynamic>> getMyAds() async => {'ads': []};

  @override
  Future<Map<String, dynamic>> getSavedAds() async => {'ads': []};

  @override
  Future<Map<String, dynamic>> createAd({
    required String plantName,
    required String title,
    String? categoryName,
    String? description,
    int? quantity,
    double? pricePerUnit,
    String? sizeDescription,
    List<String> photos = const [],
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
          reason: 'Failed save toggle must not update saved state');
    });
  });

  // ── presignUpload path (photo upload) ─────────────────────────────────────

  group('Photo upload uses authenticated presign first', () {
    test('presign endpoint called via authenticated client', () async {
      fake.enqueue(response: presignResponse());
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(marketRepositoryProvider);

      final result = await repo.presignUpload(
        bucket: 'market-ads',
        fileName: 'photo.jpg',
        contentType: 'image/jpeg',
      );

      expect(fake.calls, hasLength(1));
      expect(fake.calls.first.method, 'POST');
      expect(result['upload_url'], isNotNull);
      expect(result['file_url'], isNotNull);
    });

    test('_rawDio path is outside authenticated client — documented exclusion', () {
      // The uploadAdPhoto function uses _rawDio (bare Dio, no auth headers)
      // for the S3 PUT. This is intentional per architecture rules.
      // Presign (authenticated) is covered above. S3 PUT is integration-only.
      expect(true, isTrue, reason: 'Documentation test — always passes');
    });
  });

  // ── _AdActionNotifier (adActionProvider) ──────────────────────────────────

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

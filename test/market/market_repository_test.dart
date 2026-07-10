// Unit tests for MarketRepository — covers:
//   - getAds parses response correctly
//   - createAd returns map with ad ID
//   - toggleSaveAd returns saved flag
//   - presignUpload returns upload_url + file_url
//   - error propagation (server / network / 403)

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/features/market/local_market_providers.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';
import '../helpers/test_provider_container.dart';

void main() {
  late FakeApiClient fake;

  setUp(() {
    fake = FakeApiClient();
  });

  group('MarketRepository.getAds', () {
    test('returns raw map with ads array', () async {
      fake.enqueue(response: adsListResponse());
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(marketRepositoryProvider);

      final result = await repo.getAds({'per_page': '6', 'page': '1'});

      expect(result['ads'], isA<List>());
      expect((result['ads'] as List).length, 1);
      expect((result['ads'] as List).first['id'], kTestAdId);
    });

    test('empty ads list does not throw', () async {
      fake.enqueue(response: adsListResponse(ads: [], total: 0));
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(marketRepositoryProvider);

      final result = await repo.getAds({});
      expect((result['ads'] as List), isEmpty);
    });

    test('server error propagates as ServerError', () async {
      fake.enqueue(type: FakeResponseType.serverError);
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(marketRepositoryProvider);

      expect(() => repo.getAds({}), throwsA(isA<ServerError>()));
    });
  });

  group('MarketRepository.createAd', () {
    test('returns map with ad object containing id', () async {
      fake.enqueue(response: createAdResponse());
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(marketRepositoryProvider);

      final result = await repo.createAd(
        plantName: 'Ficus benjamina',
        title: 'Beautiful Weeping Figs',
      );

      expect(result['ad'], isA<Map>());
      expect((result['ad'] as Map)['id'], kTestAdId);
    });

    test('403 on createAd throws ForbiddenError', () async {
      fake.enqueue(type: FakeResponseType.forbidden);
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(marketRepositoryProvider);

      expect(
        () => repo.createAd(plantName: 'Rose', title: 'Roses for sale'),
        throwsA(isA<ForbiddenError>()),
      );
    });
  });

  group('MarketRepository.toggleSaveAd', () {
    test('save returns saved=true', () async {
      fake.enqueue(response: toggleSaveResponse(saved: true));
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(marketRepositoryProvider);

      final result = await repo.toggleSaveAd(kTestAdId);
      expect(result['saved'], isTrue);
    });

    test('unsave returns saved=false', () async {
      fake.enqueue(response: toggleSaveResponse(saved: false));
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(marketRepositoryProvider);

      final result = await repo.toggleSaveAd(kTestAdId);
      expect(result['saved'], isFalse);
    });

    test('network error on toggleSave throws NetworkError', () async {
      fake.enqueue(type: FakeResponseType.networkError);
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(marketRepositoryProvider);

      expect(() => repo.toggleSaveAd(kTestAdId), throwsA(isA<NetworkError>()));
    });
  });

  group('MarketRepository.presignUpload', () {
    test('returns upload_url and file_url', () async {
      fake.enqueue(response: presignResponse());
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(marketRepositoryProvider);

      final result = await repo.presignUpload(
        bucket: 'market-ads',
        fileName: 'photo.jpg',
        contentType: 'image/jpeg',
      );

      expect(result['upload_url'], startsWith('https://'));
      expect(result['file_url'], startsWith('https://'));
    });

    test('presign server error throws ServerError', () async {
      fake.enqueue(type: FakeResponseType.serverError);
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(marketRepositoryProvider);

      expect(
        () => repo.presignUpload(bucket: 'market-ads', fileName: 'photo.jpg', contentType: 'image/jpeg'),
        throwsA(isA<ServerError>()),
      );
    });
  });
}

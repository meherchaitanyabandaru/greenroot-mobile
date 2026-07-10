// Tests for BrowseAdsNotifier — covers:
//   - initial load populates ads list
//   - sort change reloads with new sort
//   - API failure sets error string
//   - loadMore appends and stops when hasMore=false
//   - refresh replaces ads from page 1

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/market/local_market_providers.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';
import '../helpers/test_provider_container.dart';

// Pump the event loop until all pending microtasks and timers complete.
Future<void> _pump() => pumpEventQueue(times: 20);

void main() {
  late FakeApiClient fake;

  setUp(() {
    fake = FakeApiClient();
  });

  group('BrowseAdsNotifier initial load', () {
    test('constructor triggers load — ads populated after pump', () async {
      // BrowseAdsNotifier calls _load() in constructor.
      fake.enqueue(response: adsListResponse());
      final container = makeTestContainer(fake.apiClient);

      // Read the provider to instantiate — constructor kicks off _load()
      container.read(browseAdsProvider);
      await _pump();

      final state = container.read(browseAdsProvider);
      expect(state.ads, hasLength(1));
      expect(state.ads.first.id, kTestAdId);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('API failure sets error string', () async {
      fake.enqueue(type: FakeResponseType.serverError);
      final container = makeTestContainer(fake.apiClient);
      container.read(browseAdsProvider);
      await _pump();

      final state = container.read(browseAdsProvider);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
    });

    test('empty response gives empty ads list and hasMore=false', () async {
      fake.enqueue(response: adsListResponse(ads: [], total: 0));
      final container = makeTestContainer(fake.apiClient);
      container.read(browseAdsProvider);
      await _pump();

      final state = container.read(browseAdsProvider);
      expect(state.ads, isEmpty);
      expect(state.hasMore, isFalse);
    });
  });

  group('BrowseAdsNotifier.setSort', () {
    test('setSort triggers reload with new sort', () async {
      // Initial load
      fake.enqueue(response: adsListResponse());
      final container = makeTestContainer(fake.apiClient);
      container.read(browseAdsProvider);
      await _pump();

      // Sort change — enqueue sorted result
      fake.enqueue(response: adsListResponse(ads: [marketAdJson(id: 202)], total: 1));
      container.read(browseAdsProvider.notifier).setSort(MarketSort.priceAsc);
      await _pump();

      final state = container.read(browseAdsProvider);
      expect(state.sort, MarketSort.priceAsc);
      expect(state.ads.first.id, 202);
    });

    test('setSort with same sort is a no-op', () async {
      fake.enqueue(response: adsListResponse());
      final container = makeTestContainer(fake.apiClient);
      container.read(browseAdsProvider);
      await _pump();

      final callsBefore = fake.calls.length;
      container.read(browseAdsProvider.notifier).setSort(MarketSort.newest);
      await _pump();

      // No extra API call for same sort
      expect(fake.calls.length, callsBefore);
    });
  });

  group('BrowseAdsNotifier.loadMore', () {
    test('loadMore appends ads when hasMore=true', () async {
      final page1 = <String, dynamic>{
        'ads': [marketAdJson(id: 1)],
        'total': 2,
      };
      fake.enqueue(response: page1);
      final container = makeTestContainer(fake.apiClient);
      container.read(browseAdsProvider);
      await _pump();

      // With total=2 and 1 item loaded, hasMore should be true
      expect(container.read(browseAdsProvider).hasMore, isTrue);

      final page2 = <String, dynamic>{
        'ads': [marketAdJson(id: 2)],
        'total': 2,
      };
      fake.enqueue(response: page2);
      await container.read(browseAdsProvider.notifier).loadMore();

      final state = container.read(browseAdsProvider);
      expect(state.ads, hasLength(2));
      expect(state.ads.map((a) => a.id).toList(), containsAll([1, 2]));
    });

    test('loadMore when hasMore=false is a no-op', () async {
      fake.enqueue(response: adsListResponse(ads: [marketAdJson()], total: 1));
      final container = makeTestContainer(fake.apiClient);
      container.read(browseAdsProvider);
      await _pump();

      expect(container.read(browseAdsProvider).hasMore, isFalse);

      final callsBefore = fake.calls.length;
      await container.read(browseAdsProvider.notifier).loadMore();
      await _pump();

      expect(fake.calls.length, callsBefore);
    });
  });

  group('BrowseAdsNotifier.refresh', () {
    test('refresh reloads from page 1, replacing existing ads', () async {
      fake.enqueue(response: adsListResponse(ads: [marketAdJson(id: 1)], total: 1));
      final container = makeTestContainer(fake.apiClient);
      container.read(browseAdsProvider);
      await _pump();

      fake.enqueue(response: adsListResponse(ads: [marketAdJson(id: 2)], total: 1));
      await container.read(browseAdsProvider.notifier).refresh();

      final state = container.read(browseAdsProvider);
      expect(state.ads.length, 1);
      expect(state.ads.first.id, 2, reason: 'Refresh must replace ads, not append');
    });
  });

  group('BrowseAdsNotifier.setFilters', () {
    test('setFilters triggers reload', () async {
      fake.enqueue(response: adsListResponse());
      final container = makeTestContainer(fake.apiClient);
      container.read(browseAdsProvider);
      await _pump();

      fake.enqueue(response: adsListResponse(ads: [marketAdJson(id: 301)], total: 1));
      container.read(browseAdsProvider.notifier).setFilters(
            category: 'Tropical',
            minPrice: 100.0,
          );
      await _pump();

      final state = container.read(browseAdsProvider);
      expect(state.category, 'Tropical');
      expect(state.minPrice, 100.0);
      expect(state.ads.first.id, 301);
    });
  });
}

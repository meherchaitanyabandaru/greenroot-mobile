// Unit tests for OrderListNotifier — covers:
//   - load → populates state with orders from fake API
//   - load with status filter
//   - API failure preserves previous state / sets error
//   - loadMore appends items
//   - cancel order propagates through repository

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/features/orders/orders.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';
import '../helpers/test_provider_container.dart';

// Note: orderRepositoryProvider uses ApiClient.instance directly (not
// apiClientProvider ref.watch), so we override orderRepositoryProvider itself.
ProviderContainer _makeOrderContainer(FakeApiClient fake) {
  return makeTestContainer(
    fake.apiClient,
    extraOverrides: [
      orderRepositoryProvider.overrideWith(
        (ref) => OrderRepository(fake.apiClient),
      ),
    ],
  );
}

void main() {
  late FakeApiClient fake;

  setUp(() {
    fake = FakeApiClient();
  });

  // ── OrderListNotifier ─────────────────────────────────────────────────────

  group('OrderListNotifier.load', () {
    test('load returns orders and clears loading flag', () async {
      fake.enqueue(response: ordersListResponse());
      final container = _makeOrderContainer(fake);

      await container.read(orderListProvider.notifier).load();

      final state = container.read(orderListProvider);
      expect(state.paged.items, hasLength(1));
      expect(state.paged.items.first.id, kTestOrderId);
      expect(state.paged.isLoading, isFalse);
      expect(state.paged.error, isNull);
    });

    test('load with status filter passes filter to repository', () async {
      fake.enqueue(response: ordersListResponse());
      final container = _makeOrderContainer(fake);

      await container.read(orderListProvider.notifier).load(statusFilter: 'PENDING');

      final state = container.read(orderListProvider);
      expect(state.statusFilter, 'PENDING');
      expect(state.paged.items, hasLength(1));
    });

    test('load with empty result sets items to empty list', () async {
      fake.enqueue(response: ordersListResponse(orders: [], total: 0));
      final container = _makeOrderContainer(fake);

      await container.read(orderListProvider.notifier).load();

      final state = container.read(orderListProvider);
      expect(state.paged.items, isEmpty);
      expect(state.paged.hasMore, isFalse);
    });

    test('API failure sets error, preserves previous items', () async {
      // Load successfully first
      fake.enqueue(response: ordersListResponse());
      final container = _makeOrderContainer(fake);
      await container.read(orderListProvider.notifier).load();

      final prevItems = container.read(orderListProvider).paged.items;
      expect(prevItems, isNotEmpty);

      // Now fail
      fake.enqueue(type: FakeResponseType.serverError);
      await container.read(orderListProvider.notifier).load();

      final state = container.read(orderListProvider);
      // Items preserved from previous successful load
      expect(state.paged.items, equals(prevItems));
      expect(state.paged.error, isA<ServerError>());
      expect(state.paged.isLoading, isFalse);
    });

    test('network error on first load sets NetworkError in state', () async {
      fake.enqueue(type: FakeResponseType.networkError);
      final container = _makeOrderContainer(fake);

      await container.read(orderListProvider.notifier).load();

      final state = container.read(orderListProvider);
      expect(state.paged.error, isA<NetworkError>());
      expect(state.paged.items, isEmpty);
    });
  });

  group('OrderListNotifier.loadMore', () {
    test('loadMore appends items to existing list', () async {
      // First page
      final page1 = ordersListResponse(
        orders: [orderJson(id: 1)],
        total: 2,
      );
      // Adjust pagination to indicate more pages
      page1['pagination'] = {'page': 1, 'per_page': 1, 'total': 2, 'total_pages': 2};

      fake.enqueue(response: page1);
      final container = _makeOrderContainer(fake);
      await container.read(orderListProvider.notifier).load();

      expect(container.read(orderListProvider).paged.hasMore, isTrue);

      // Second page
      final page2 = ordersListResponse(orders: [orderJson(id: 2)], total: 2);
      page2['pagination'] = {'page': 2, 'per_page': 1, 'total': 2, 'total_pages': 2};
      fake.enqueue(response: page2);

      await container.read(orderListProvider.notifier).loadMore();

      final state = container.read(orderListProvider);
      expect(state.paged.items, hasLength(2));
      expect(state.paged.items.map((o) => o.id).toList(), containsAll([1, 2]));
    });

    test('loadMore is no-op when hasMore is false', () async {
      fake.enqueue(response: ordersListResponse(orders: [orderJson()], total: 1));
      final container = _makeOrderContainer(fake);
      await container.read(orderListProvider.notifier).load();

      final callsBefore = fake.calls.length;
      await container.read(orderListProvider.notifier).loadMore();

      // No additional API call should be made
      expect(fake.calls.length, callsBefore);
    });
  });

  // ── OrderRepository direct tests ─────────────────────────────────────────

  group('OrderRepository.cancelOrder', () {
    test('cancelOrder returns updated order with CANCELLED status', () async {
      fake.enqueue(response: orderDetailResponse(status: 'CANCELLED'));
      final container = _makeOrderContainer(fake);

      final repo = container.read(orderRepositoryProvider);
      final order = await repo.cancelOrder(kTestOrderId, reason: 'Changed mind');

      expect(order.status, 'CANCELLED');
      expect(order.id, kTestOrderId);
    });

    test('cancelOrder server error propagates as ServerError', () async {
      fake.enqueue(type: FakeResponseType.serverError);
      final container = _makeOrderContainer(fake);

      final repo = container.read(orderRepositoryProvider);
      expect(
        () => repo.cancelOrder(kTestOrderId),
        throwsA(isA<ServerError>()),
      );
    });
  });

  group('OrderRepository.updateStatus', () {
    test('updateStatus success returns order with new status', () async {
      fake.enqueue(response: orderDetailResponse(status: 'CONFIRMED'));
      final container = _makeOrderContainer(fake);

      final repo = container.read(orderRepositoryProvider);
      final order = await repo.updateStatus(kTestOrderId, 'CONFIRMED');

      expect(order.status, 'CONFIRMED');
    });

    test('403 on status update throws ForbiddenError', () async {
      fake.enqueue(type: FakeResponseType.forbidden);
      final container = _makeOrderContainer(fake);

      final repo = container.read(orderRepositoryProvider);
      expect(
        () => repo.updateStatus(kTestOrderId, 'CONFIRMED'),
        throwsA(isA<ForbiddenError>()),
      );
    });
  });
}

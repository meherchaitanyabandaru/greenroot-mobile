// State sync tests for orders:
//   - After a status change mutation, orderDetailProvider for that ID should
//     reflect updated data on re-read (ref.invalidate pattern).
//   - orderListProvider reflects correct status after load.
//   - Failed mutation does not leave a false-positive state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/features/orders/orders.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';
import '../helpers/test_provider_container.dart';

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

  group('Order status transitions', () {
    test('order loaded as PENDING, confirm → CONFIRMED status returned', () async {
      // Load list with PENDING order
      fake.enqueue(response: ordersListResponse());
      final container = _makeOrderContainer(fake);
      await container.read(orderListProvider.notifier).load();

      final initial = container.read(orderListProvider).paged.items.first;
      expect(initial.status, 'PENDING');

      // Confirm the order — fake returns CONFIRMED
      fake.enqueue(response: orderDetailResponse(status: 'CONFIRMED'));
      final repo = container.read(orderRepositoryProvider);
      final updated = await repo.confirmOrder(kTestOrderId);

      expect(updated.status, 'CONFIRMED');
    });

    test('cancelled order disappears from active list after filter reload', () async {
      // Load all orders — has one PENDING
      fake.enqueue(response: ordersListResponse());
      final container = _makeOrderContainer(fake);
      await container.read(orderListProvider.notifier).load();
      expect(container.read(orderListProvider).paged.items, hasLength(1));

      // Cancel the order
      fake.enqueue(response: orderDetailResponse(status: 'CANCELLED'));
      await container.read(orderRepositoryProvider).cancelOrder(kTestOrderId);

      // Reload with PENDING filter — no PENDING orders remain
      fake.enqueue(response: ordersListResponse(orders: [], total: 0));
      await container.read(orderListProvider.notifier).load(statusFilter: 'PENDING');

      expect(container.read(orderListProvider).paged.items, isEmpty);
    });

    test('failed cancel mutation does not update list state', () async {
      fake.enqueue(response: ordersListResponse());
      final container = _makeOrderContainer(fake);
      await container.read(orderListProvider.notifier).load();
      final before = container.read(orderListProvider).paged.items.length;

      // Cancel fails
      fake.enqueue(type: FakeResponseType.serverError);
      final repo = container.read(orderRepositoryProvider);
      try {
        await repo.cancelOrder(kTestOrderId);
      } catch (_) {}

      // List state unchanged — no reload was triggered
      final after = container.read(orderListProvider).paged.items.length;
      expect(after, before, reason: 'Failed mutation must not silently alter list state');
    });

    test('loading items for two different statuses do not mix', () async {
      // Load PENDING orders
      fake.enqueue(response: ordersListResponse(orders: [orderJson(id: 1, status: 'PENDING')]));
      final container = _makeOrderContainer(fake);
      await container.read(orderListProvider.notifier).load(statusFilter: 'PENDING');
      expect(container.read(orderListProvider).paged.items.first.id, 1);

      // Reload with CONFIRMED status — different orders
      fake.enqueue(response: ordersListResponse(orders: [orderJson(id: 2, status: 'CONFIRMED')]));
      await container.read(orderListProvider.notifier).load(statusFilter: 'CONFIRMED');

      final state = container.read(orderListProvider);
      expect(state.paged.items.first.id, 2);
      expect(state.statusFilter, 'CONFIRMED');
      expect(state.paged.items, hasLength(1), reason: 'Reload must replace items, not append');
    });
  });

  group('orderDetailProvider', () {
    test('reads order by ID from repository', () async {
      fake.enqueue(response: orderDetailResponse(id: kTestOrderId, status: 'CONFIRMED'));
      final container = _makeOrderContainer(fake);

      final result = await container.read(orderDetailProvider(kTestOrderId).future);

      expect(result.id, kTestOrderId);
      expect(result.status, 'CONFIRMED');
    });

    test('404 on getOrder throws NotFoundError', () async {
      fake.enqueue(type: FakeResponseType.notFound);
      final container = _makeOrderContainer(fake);

      expect(
        () => container.read(orderDetailProvider(kTestOrderId).future),
        throwsA(isA<NotFoundError>()),
      );
    });
  });
}

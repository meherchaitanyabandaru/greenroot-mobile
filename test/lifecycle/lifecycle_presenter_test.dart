import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/domain/lifecycle_presenter.dart';
import 'package:greenroot_mobile/features/dispatches/dispatches.dart';
import 'package:greenroot_mobile/features/orders/orders.dart';

void main() {
  group('LifecyclePresenter.forOrder', () {
    test('buyer sees in-transit dispatch as on the way', () {
      final display = LifecyclePresenter.forOrder(
        order: _order('LOADED'),
        dispatch: _dispatch('IN_TRANSIT'),
        role: LifecycleRole.buyer,
      );

      expect(display.label, 'On the Way');
      expect(display.title, 'On the Way');
    });

    test('buyer sees delivered dispatch as delivered before refresh completes',
        () {
      final display = LifecyclePresenter.forOrder(
        order: _order('LOADED'),
        dispatch: _dispatch('DELIVERED'),
        role: LifecycleRole.buyer,
      );

      expect(display.label, 'Delivered');
      expect(display.title, 'Delivered');
    });

    test('operator sees delivered dispatch as an order close prompt', () {
      final display = LifecyclePresenter.forOrder(
        order: _order('LOADED'),
        dispatch: _dispatch('DELIVERED'),
        role: LifecycleRole.operator,
      );

      expect(display.label, 'Delivered');
      expect(display.title, 'Delivery Delivered');
    });

    test('completed buyer order renders as delivered', () {
      final display = LifecyclePresenter.forOrder(
        order: _order('COMPLETED'),
        role: LifecycleRole.buyer,
      );

      expect(display.label, 'Delivered');
    });

    test('active dispatch prefers progressed state over older pending state',
        () {
      final dispatch = LifecyclePresenter.activeDispatchForOrder(
        [
          _dispatch('PENDING', id: 1, updatedAt: '2026-07-19T01:00:00Z'),
          _dispatch('IN_TRANSIT', id: 2, updatedAt: '2026-07-19T00:00:00Z'),
        ],
        1,
      );

      expect(dispatch?.id, 2);
    });

    test('active dispatch ignores cancelled dispatches', () {
      final dispatch = LifecyclePresenter.activeDispatchForOrder(
        [
          _dispatch('CANCELLED', id: 2, updatedAt: '2026-07-19T02:00:00Z'),
          _dispatch('ACCEPTED', id: 1, updatedAt: '2026-07-19T01:00:00Z'),
        ],
        1,
      );

      expect(dispatch?.id, 1);
    });
  });
}

Order _order(String status) => Order(
      id: 1,
      orderCode: 'ORD-1',
      orderNumber: 'GR-ORD-1',
      status: status,
      totalAmount: 100,
      orderDate: '2026-07-19T00:00:00Z',
      items: const [],
    );

Dispatch _dispatch(
  String status, {
  int id = 1,
  String? updatedAt,
}) =>
    Dispatch(
      id: id,
      dispatchCode: 'DSP-1',
      orderId: 1,
      status: status,
      createdAt: '2026-07-19T00:00:00Z',
      updatedAt: updatedAt,
      items: const [],
    );

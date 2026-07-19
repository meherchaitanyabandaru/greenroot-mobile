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

Dispatch _dispatch(String status) => Dispatch(
      id: 1,
      dispatchCode: 'DSP-1',
      orderId: 1,
      status: status,
      createdAt: '2026-07-19T00:00:00Z',
      items: const [],
    );

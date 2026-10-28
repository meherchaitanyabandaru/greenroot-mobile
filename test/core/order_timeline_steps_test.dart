import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/domain/workflow.dart';
import 'package:greenroot_mobile/core/utilities/step_time.dart';
import 'package:greenroot_mobile/features/dispatches/dispatches.dart';
import 'package:greenroot_mobile/features/orders/orders.dart';

import '../helpers/test_data.dart';

void main() {
  final order = Order.fromJson({
    ...orderJson(status: 'LOADED'),
    'confirmed_at': '2026-10-28T04:49:32Z',
    'loading_started_at': '2026-10-28T04:52:06Z',
    'loading_completed_at': '2026-10-28T04:52:17Z',
    'assigned_manager_user_id': 3,
    'assigned_manager_name': 'Lakshmi',
  });
  final trip = Dispatch.fromJson({
    'id': 1,
    'dispatch_code': 'DSP-1',
    'order_id': order.id,
    'dispatch_status': 'DELIVERED',
    'created_at': '2026-10-28T04:52:39Z',
    'driver_name': 'Raju',
    'driver_accepted_at': '2026-10-28T04:53:20Z',
    'trip_started_at': '2026-10-28T04:55:01Z',
    'delivery_date': '2026-10-28T04:58:05Z',
  });

  test('the trip steps follow loading, each with its own time', () {
    final steps =
        OrderWorkflow.stepsFor(order, OrderTimelineRole.seller, trip: trip);
    expect(steps.map((s) => s.title).toList(), [
      'New Order',
      'Order Accepted',
      'Loading Started',
      'Loading Complete',
      'Trip Created',
      'Driver Assigned',
      'On the Way',
      'Delivered',
    ]);
    final sub = {for (final s in steps) s.title: s.subtitle ?? ''};
    expect(
      sub['Driver Assigned'],
      '${stepTime('2026-10-28T04:53:20Z')} · Raju',
    );
    expect(sub['On the Way'], stepTime('2026-10-28T04:55:01Z'));
    expect(sub['Delivered'], stepTime('2026-10-28T04:58:05Z'));
  });

  test('times carry the weekday, e.g. "Wed, 28 Oct · 10:23 AM"', () {
    expect(
      stepTime('2026-10-28T04:53:20Z'),
      matches(r'^Wed, 28 Oct · \d{1,2}:\d\d (AM|PM)$'),
    );
  });

  test('the buyer sees a time on every step that happened', () {
    final done = Order.fromJson({
      ...orderJson(status: 'COMPLETED'),
      'confirmed_at': '2026-10-28T04:49:32Z',
      'loading_started_at': '2026-10-28T04:52:06Z',
      'loading_completed_at': '2026-10-28T04:52:17Z',
    });
    final steps =
        OrderWorkflow.stepsFor(done, OrderTimelineRole.buyer, trip: trip);
    for (final s in steps) {
      expect(
        s.subtitle,
        contains(RegExp(r'^\w{3}, \d{1,2} \w{3} · ')),
        reason: s.title,
      );
    }
  });

  test('a trip from before times were recorded shows no invented time', () {
    final old = Dispatch.fromJson({
      'id': 9,
      'dispatch_code': 'DSP-9',
      'order_id': order.id,
      'dispatch_status': 'DELIVERED',
      'created_at': '2026-10-28T04:52:39Z',
      'driver_name': 'Raju',
      'delivery_date': '2026-10-28T04:58:05Z',
    });
    final sub = {
      for (final s
          in OrderWorkflow.stepsFor(order, OrderTimelineRole.seller, trip: old))
        s.title: s.subtitle ?? '',
    };
    expect(sub['Driver Assigned'], 'Raju');
    expect(sub['On the Way'], isEmpty);
    expect(sub['Delivered'], stepTime('2026-10-28T04:58:05Z'));
  });

  test('steps are not credited to whoever is assigned now', () {
    final steps = OrderWorkflow.stepsFor(order, OrderTimelineRole.seller);
    final accepted = steps.firstWhere((s) => s.title == 'Order Accepted');
    expect(accepted.subtitle, contains('By the nursery'));
    expect(
      steps.map((s) => s.subtitle ?? '').join(),
      isNot(contains('Lakshmi')),
    );
  });
}

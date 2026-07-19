import 'package:flutter/material.dart';

import '../../features/dispatches/dispatches.dart';
import '../../features/orders/orders.dart';
import '../theme/app_colors.dart';
import '../widgets/status_badge.dart';

enum LifecycleRole { buyer, operator, driver }

class LifecycleDisplay {
  final String label;
  final String title;
  final String subtitle;
  final Color color;
  final BadgeVariant variant;

  const LifecycleDisplay({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.variant,
  });
}

class LifecyclePresenter {
  static LifecycleDisplay forOrder({
    required Order order,
    Dispatch? dispatch,
    required LifecycleRole role,
  }) {
    final orderStatus = order.status.toUpperCase();
    final dispatchStatus = dispatch?.status.toUpperCase();
    if (role == LifecycleRole.buyer &&
        orderStatus != 'COMPLETED' &&
        dispatchStatus != null &&
        dispatchStatus != 'CANCELLED') {
      return _buyerDelivery(dispatchStatus);
    }
    if (role == LifecycleRole.operator &&
        orderStatus != 'COMPLETED' &&
        dispatchStatus == 'DELIVERED') {
      return const LifecycleDisplay(
        label: 'Delivered',
        title: 'Delivery Delivered',
        subtitle: 'Review and close the order.',
        color: AppColors.primaryMain,
        variant: BadgeVariant.success,
      );
    }
    return _order(orderStatus, role);
  }

  static LifecycleDisplay forOrderStatus(
    String status, {
    LifecycleRole role = LifecycleRole.operator,
  }) =>
      _order(status.toUpperCase(), role);

  static LifecycleDisplay forDispatchStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const LifecycleDisplay(
          label: 'Pending',
          title: 'Dispatch Created',
          subtitle: 'Awaiting driver.',
          color: AppColors.amber600,
          variant: BadgeVariant.warning,
        );
      case 'ACCEPTED':
        return const LifecycleDisplay(
          label: 'Accepted',
          title: 'Driver Accepted',
          subtitle: 'Driver has accepted the trip.',
          color: AppColors.blue600,
          variant: BadgeVariant.info,
        );
      case 'DISPATCHED':
        return const LifecycleDisplay(
          label: 'Dispatched',
          title: 'Out for Delivery',
          subtitle: 'Order has left the nursery.',
          color: AppColors.blue600,
          variant: BadgeVariant.info,
        );
      case 'IN_TRANSIT':
        return const LifecycleDisplay(
          label: 'In Transit',
          title: 'In Transit',
          subtitle: 'Delivery is on the way.',
          color: AppColors.amber700,
          variant: BadgeVariant.warning,
        );
      case 'DELIVERED':
        return const LifecycleDisplay(
          label: 'Delivered',
          title: 'Delivered',
          subtitle: 'Delivery is complete.',
          color: AppColors.primaryMain,
          variant: BadgeVariant.success,
        );
      case 'CANCELLED':
        return const LifecycleDisplay(
          label: 'Cancelled',
          title: 'Dispatch Cancelled',
          subtitle: 'Delivery was cancelled.',
          color: AppColors.red600,
          variant: BadgeVariant.error,
        );
      default:
        return LifecycleDisplay(
          label: pretty(status),
          title: pretty(status),
          subtitle: '',
          color: AppColors.textSecondary,
          variant: BadgeVariant.neutral,
        );
    }
  }

  static LifecycleDisplay _buyerDelivery(String status) {
    switch (status) {
      case 'PENDING':
        return const LifecycleDisplay(
          label: 'Delivery Pending',
          title: 'Delivery Being Arranged',
          subtitle: 'The nursery is arranging your delivery.',
          color: AppColors.textSecondary,
          variant: BadgeVariant.neutral,
        );
      case 'ACCEPTED':
        return const LifecycleDisplay(
          label: 'Driver Assigned',
          title: 'Driver Assigned',
          subtitle: 'A driver has accepted your delivery.',
          color: AppColors.blue600,
          variant: BadgeVariant.info,
        );
      case 'DISPATCHED':
        return const LifecycleDisplay(
          label: 'Out for Delivery',
          title: 'Out for Delivery',
          subtitle: 'Your order has left the nursery.',
          color: AppColors.blue600,
          variant: BadgeVariant.info,
        );
      case 'IN_TRANSIT':
        return const LifecycleDisplay(
          label: 'On the Way',
          title: 'On the Way',
          subtitle: 'Your delivery is on the way.',
          color: AppColors.amber700,
          variant: BadgeVariant.warning,
        );
      case 'DELIVERED':
        return const LifecycleDisplay(
          label: 'Delivered',
          title: 'Delivered',
          subtitle: 'Your order has been delivered.',
          color: AppColors.primaryMain,
          variant: BadgeVariant.success,
        );
      default:
        return forDispatchStatus(status);
    }
  }

  static LifecycleDisplay _order(String status, LifecycleRole role) {
    switch (status) {
      case 'PENDING':
        return LifecycleDisplay(
          label: 'Pending',
          title: role == LifecycleRole.buyer
              ? 'Waiting for Confirmation'
              : 'New Order',
          subtitle: role == LifecycleRole.buyer
              ? 'The nursery will review and confirm your order.'
              : 'Confirm this order to begin preparation.',
          color: AppColors.amber600,
          variant: BadgeVariant.warning,
        );
      case 'CONFIRMED':
        return LifecycleDisplay(
          label: 'Confirmed',
          title: role == LifecycleRole.buyer
              ? 'Order Confirmed'
              : 'Confirmed - Ready to Load',
          subtitle: role == LifecycleRole.buyer
              ? 'The nursery has confirmed your order.'
              : 'Start loading items to prepare for dispatch.',
          color: AppColors.blue600,
          variant: BadgeVariant.info,
        );
      case 'LOADING':
        return const LifecycleDisplay(
          label: 'Loading',
          title: 'Loading in Progress',
          subtitle: 'Items are being prepared.',
          color: AppColors.blue600,
          variant: BadgeVariant.warning,
        );
      case 'LOADED':
        return const LifecycleDisplay(
          label: 'Loaded',
          title: 'Order Loaded',
          subtitle: 'Ready for delivery.',
          color: AppColors.primaryMain,
          variant: BadgeVariant.success,
        );
      case 'PARTIALLY_FULFILLED':
        return const LifecycleDisplay(
          label: 'Partially Fulfilled',
          title: 'Partially Fulfilled',
          subtitle: 'Some items had reduced quantities.',
          color: AppColors.amber700,
          variant: BadgeVariant.accent,
        );
      case 'COMPLETED':
        return LifecycleDisplay(
          label: role == LifecycleRole.buyer ? 'Delivered' : 'Completed',
          title: role == LifecycleRole.buyer ? 'Delivered' : 'Order Completed',
          subtitle: 'Order delivered and completed.',
          color: AppColors.primaryMain,
          variant: BadgeVariant.success,
        );
      case 'CANCELLED':
        return const LifecycleDisplay(
          label: 'Cancelled',
          title: 'Order Cancelled',
          subtitle: 'This order has been cancelled.',
          color: AppColors.red600,
          variant: BadgeVariant.error,
        );
      default:
        return LifecycleDisplay(
          label: pretty(status),
          title: pretty(status),
          subtitle: '',
          color: AppColors.textSecondary,
          variant: BadgeVariant.neutral,
        );
    }
  }

  static String pretty(String status) => status
      .toLowerCase()
      .split('_')
      .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

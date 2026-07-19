import 'package:flutter/material.dart';

import '../../features/dispatches/dispatches.dart';
import '../../features/orders/orders.dart';
import 'lifecycle_models.dart';
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
  static Dispatch? activeDispatchForOrder(
    Iterable<Dispatch> dispatches,
    int orderId,
  ) {
    final candidates = dispatches
        .where((dispatch) =>
            dispatch.orderId == orderId && dispatch.status != 'CANCELLED')
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort(_compareDispatches);
    return candidates.first;
  }

  static LifecycleDisplay forOrder({
    required Order order,
    Dispatch? dispatch,
    required LifecycleRole role,
  }) {
    final backend = _displayForRole(order.lifecycle, role);
    if (backend != null) return _fromBackend(backend);
    final orderStatus = order.status.toUpperCase();
    final dispatchStatus =
        dispatch?.status.toUpperCase() ?? order.activeDispatchStatus;
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

  static LifecycleDisplay forDispatch({
    required Dispatch dispatch,
    required LifecycleRole role,
  }) {
    final backend = _displayForRole(dispatch.lifecycle, role);
    if (backend != null) return _fromBackend(backend);
    if (role == LifecycleRole.buyer) {
      return forBuyerDispatchStatus(dispatch.status);
    }
    return forDispatchStatus(dispatch.status);
  }

  static LifecycleDisplay forBuyerDispatchStatus(String status) =>
      _buyerDelivery(status.toUpperCase());

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

  static int _compareDispatches(Dispatch a, Dispatch b) {
    final aRank = _dispatchRank(a.status);
    final bRank = _dispatchRank(b.status);
    if (aRank != bRank) return bRank.compareTo(aRank);

    final aTime = _dispatchTime(a);
    final bTime = _dispatchTime(b);
    if (aTime != null && bTime != null) return bTime.compareTo(aTime);
    if (aTime != null) return -1;
    if (bTime != null) return 1;
    return b.id.compareTo(a.id);
  }

  static int _dispatchRank(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return 5;
      case 'IN_TRANSIT':
        return 4;
      case 'DISPATCHED':
        return 3;
      case 'ACCEPTED':
        return 2;
      case 'PENDING':
        return 1;
      default:
        return 0;
    }
  }

  static DateTime? _dispatchTime(Dispatch dispatch) =>
      DateTime.tryParse(dispatch.updatedAt ?? '') ??
      DateTime.tryParse(dispatch.deliveryDate ?? '') ??
      DateTime.tryParse(dispatch.dispatchDate ?? '') ??
      DateTime.tryParse(dispatch.createdAt);

  static BackendLifecycleDisplay? _displayForRole(
    BackendLifecycle? lifecycle,
    LifecycleRole role,
  ) {
    if (lifecycle == null) return null;
    switch (role) {
      case LifecycleRole.buyer:
        return lifecycle.customer;
      case LifecycleRole.operator:
        return lifecycle.operator;
      case LifecycleRole.driver:
        return lifecycle.driver;
    }
  }

  static LifecycleDisplay _fromBackend(BackendLifecycleDisplay backend) {
    final variant = backend.variant;
    final label = backend.label.isNotEmpty ? backend.label : backend.title;
    return LifecycleDisplay(
      label: label,
      title: backend.title.isNotEmpty ? backend.title : label,
      subtitle: backend.subtitle,
      color: _colorForVariant(variant),
      variant: variant,
    );
  }

  static Color _colorForVariant(BadgeVariant variant) {
    switch (variant) {
      case BadgeVariant.success:
        return AppColors.primaryMain;
      case BadgeVariant.warning:
        return AppColors.amber700;
      case BadgeVariant.error:
        return AppColors.red600;
      case BadgeVariant.info:
        return AppColors.blue600;
      case BadgeVariant.accent:
        return AppColors.amber700;
      case BadgeVariant.neutral:
        return AppColors.textSecondary;
    }
  }
}

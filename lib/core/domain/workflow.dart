// Central frontend translation layer.
// Maps backend state machine → role-specific UX steps.
// Business rules source: BUSINESS_RULES.md + API.md
//
// RBAC Cancel Matrix (from BUSINESS_RULES.md §Order Cancel Rules):
//   PENDING:             buyer (own) | manager | owner
//   CONFIRMED:           manager | owner
//   LOADING:             manager | owner
//   LOADED/PARTIALLY:    BLOCKED for all
//   COMPLETED:           BLOCKED for all
//
// ORDER STATE MACHINE:
//   PENDING → CONFIRMED → LOADING → LOADED → COMPLETED
//                                 ↘ PARTIALLY_FULFILLED → COMPLETED
//   Cancel: POST /orders/:id/cancel  (not a status update)
//
// DISPATCH STATE MACHINE:
//   PENDING → ACCEPTED → DISPATCHED → IN_TRANSIT → DELIVERED

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../features/orders/orders.dart';
import '../../features/dispatches/dispatches.dart';

// ── Step rendering state ───────────────────────────────────────────────────────

enum WorkflowStepState { completed, current, pending, cancelled }

class WorkflowStep {
  final String title;
  final String? subtitle;
  final WorkflowStepState state;
  final IconData icon;

  const WorkflowStep({
    required this.title,
    this.subtitle,
    required this.state,
    required this.icon,
  });
}

// ── Role enum for timeline ────────────────────────────────────────────────────

enum OrderTimelineRole { buyer, seller }

// ── Order workflow ─────────────────────────────────────────────────────────────

class OrderWorkflow {
  // Returns role-appropriate step list for the order timeline.
  static List<WorkflowStep> stepsFor(Order order, OrderTimelineRole role) {
    return role == OrderTimelineRole.buyer
        ? _buyerSteps(order)
        : _sellerSteps(order);
  }

  // Returns which statuses allow cancel for each role.
  // Derived from BUSINESS_RULES.md §Order Cancel Rules.
  static bool canBuyerCancel(String status) => status == 'PENDING';
  static bool canSellerCancel(String status) =>
      {'PENDING', 'CONFIRMED', 'LOADING'}.contains(status);

  // ── Buyer: 5 simple customer-facing steps ──────────────────────────────────
  // Hides all internal loading/operational states from the buyer.
  static List<WorkflowStep> _buyerSteps(Order order) {
    final s = order.status;
    final cancelled = s == 'CANCELLED';

    // Derive milestone booleans in order
    final accepted = !cancelled && s != 'PENDING';
    final preparing = !cancelled &&
        {'LOADING', 'LOADED', 'PARTIALLY_FULFILLED', 'COMPLETED'}.contains(s);
    final readyOrBeyond = !cancelled &&
        {'LOADED', 'PARTIALLY_FULFILLED', 'COMPLETED'}.contains(s);
    final delivered = !cancelled && s == 'COMPLETED';

    WorkflowStepState _s(bool done, bool active) => cancelled
        ? WorkflowStepState.pending
        : (done ? WorkflowStepState.completed : (active ? WorkflowStepState.current : WorkflowStepState.pending));

    final steps = <WorkflowStep>[
      WorkflowStep(
        title: 'Order Placed',
        subtitle: _fmt(order.createdAt ?? order.orderDate),
        state: WorkflowStepState.completed,
        icon: Icons.receipt_long_rounded,
      ),
      WorkflowStep(
        title: 'Accepted by Nursery',
        subtitle: accepted
            ? 'Your order was confirmed'
            : 'Awaiting nursery confirmation',
        state: _s(accepted, !accepted && !cancelled),
        icon: Icons.verified_user_outlined,
      ),
      WorkflowStep(
        title: 'Being Prepared',
        subtitle: s == 'LOADING'
            ? 'Items are being loaded'
            : (preparing && s != 'LOADING' ? 'Items loaded and ready' : null),
        state: cancelled
            ? WorkflowStepState.pending
            : (preparing
                ? (s == 'LOADING' ? WorkflowStepState.current : WorkflowStepState.completed)
                : (accepted ? WorkflowStepState.current : WorkflowStepState.pending)),
        icon: Icons.inventory_2_outlined,
      ),
      WorkflowStep(
        title: 'On the Way',
        subtitle: readyOrBeyond && !delivered
            ? 'Your order is dispatched'
            : null,
        state: cancelled
            ? WorkflowStepState.pending
            : (delivered
                ? WorkflowStepState.completed
                : (readyOrBeyond ? WorkflowStepState.current : WorkflowStepState.pending)),
        icon: Icons.local_shipping_rounded,
      ),
      WorkflowStep(
        title: 'Delivered',
        subtitle: delivered ? 'Order complete — thank you!' : null,
        state: delivered ? WorkflowStepState.completed : WorkflowStepState.pending,
        icon: Icons.check_circle_rounded,
      ),
    ];

    if (cancelled) {
      steps.add(WorkflowStep(
        title: 'Cancelled',
        subtitle: order.cancelReason?.isNotEmpty == true
            ? order.cancelReason
            : null,
        state: WorkflowStepState.cancelled,
        icon: Icons.cancel_rounded,
      ));
    }

    return steps;
  }

  // ── Seller/Manager: 5 operational steps ────────────────────────────────────
  // Shows internal state labels that are meaningful for nursery operations.
  // Includes manager attribution and timestamps from API.
  static List<WorkflowStep> _sellerSteps(Order order) {
    final s = order.status;
    final cancelled = s == 'CANCELLED';

    final accepted = !cancelled && s != 'PENDING';
    final loadingStarted = !cancelled &&
        {'LOADING', 'LOADED', 'PARTIALLY_FULFILLED', 'COMPLETED'}.contains(s);
    final loadingDone = !cancelled &&
        {'LOADED', 'PARTIALLY_FULFILLED', 'COMPLETED'}.contains(s);
    final completed = !cancelled && s == 'COMPLETED';
    final partial = s == 'PARTIALLY_FULFILLED';

    final byLine = _byLine(
      order.assignedManagerName,
      order.assignedManagerUserId,
      'Manager',
      'Nursery Owner',
    );

    final steps = <WorkflowStep>[
      WorkflowStep(
        title: 'New Order',
        subtitle: _fmt(order.createdAt ?? order.orderDate),
        state: WorkflowStepState.completed,
        icon: Icons.receipt_long_rounded,
      ),
      WorkflowStep(
        title: 'Order Accepted',
        subtitle: accepted ? byLine : 'Awaiting confirmation',
        state: cancelled
            ? WorkflowStepState.pending
            : (accepted ? WorkflowStepState.completed : WorkflowStepState.current),
        icon: Icons.verified_user_outlined,
      ),
      WorkflowStep(
        title: 'Loading Started',
        subtitle: loadingStarted
            ? (order.loadingStartedAt != null
                ? '${_fmt(order.loadingStartedAt)} · $byLine'
                : byLine)
            : (accepted ? 'Ready to begin loading' : null),
        state: cancelled
            ? WorkflowStepState.pending
            : (loadingStarted
                ? (s == 'LOADING' ? WorkflowStepState.current : WorkflowStepState.completed)
                : (accepted ? WorkflowStepState.current : WorkflowStepState.pending)),
        icon: Icons.inventory_2_outlined,
      ),
      WorkflowStep(
        title: partial ? 'Partially Loaded' : 'Loading Complete',
        subtitle: loadingDone
            ? (partial
                ? 'Some items had reduced quantities'
                : (order.loadingCompletedAt != null
                    ? _fmt(order.loadingCompletedAt)
                    : null))
            : (s == 'LOADING' ? 'Loading in progress…' : null),
        state: cancelled
            ? WorkflowStepState.pending
            : (completed
                ? WorkflowStepState.completed
                : (loadingDone ? WorkflowStepState.current : WorkflowStepState.pending)),
        icon: Icons.done_all_rounded,
      ),
      WorkflowStep(
        title: 'Delivered',
        subtitle: loadingDone && !completed
            ? 'Create dispatch from order actions'
            : (completed ? 'Order fulfilled' : null),
        state: completed ? WorkflowStepState.completed : WorkflowStepState.pending,
        icon: Icons.check_circle_rounded,
      ),
    ];

    if (cancelled) {
      steps.add(WorkflowStep(
        title: 'Cancelled',
        subtitle: order.cancelledAt != null
            ? _fmt(order.cancelledAt)
            : (order.cancelReason?.isNotEmpty == true
                ? order.cancelReason
                : null),
        state: WorkflowStepState.cancelled,
        icon: Icons.cancel_rounded,
      ));
    }

    return steps;
  }

  static String _fmt(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('dd MMM, h:mm a').format(dt.toLocal());
  }

  static String _byLine(
    String? name,
    int? userId,
    String designation,
    String fallback,
  ) {
    if (name != null && name.isNotEmpty) return 'By $name ($designation)';
    if (userId != null) return 'By $designation';
    return 'By $fallback';
  }
}

// ── Dispatch workflow ─────────────────────────────────────────────────────────

enum DispatchTimelineRole { seller, driver, buyer }

class DispatchWorkflow {
  static List<WorkflowStep> stepsFor(
      Dispatch dispatch, DispatchTimelineRole role) {
    switch (role) {
      case DispatchTimelineRole.buyer:
        return _buyerSteps(dispatch);
      case DispatchTimelineRole.driver:
        return _driverSteps(dispatch);
      case DispatchTimelineRole.seller:
        return _sellerSteps(dispatch);
    }
  }

  // RBAC — what each role can do on a dispatch:
  // Owner/Manager: create dispatch, mark DISPATCHED, confirm delivery, track
  // Driver:        accept (via QR), start trip (IN_TRANSIT), mark DELIVERED
  // Buyer:         track only, view driver info, call driver

  static List<WorkflowStep> _buyerSteps(Dispatch d) {
    final s = d.status;
    final accepted = {'ACCEPTED', 'DISPATCHED', 'IN_TRANSIT', 'DELIVERED'}.contains(s);
    final onWay = {'IN_TRANSIT', 'DELIVERED'}.contains(s);
    final delivered = s == 'DELIVERED';
    final cancelled = s == 'CANCELLED';

    return _buildSteps(cancelled, [
      WorkflowStep(
        title: 'Dispatch Created',
        subtitle: 'Your order is packed and ready',
        state: WorkflowStepState.completed,
        icon: Icons.inventory_2_outlined,
      ),
      WorkflowStep(
        title: 'Driver Assigned',
        subtitle: accepted
            ? (d.driverName != null ? 'Driver: ${d.driverName}' : 'Driver accepted')
            : 'Awaiting driver',
        state: accepted
            ? WorkflowStepState.completed
            : (cancelled ? WorkflowStepState.pending : WorkflowStepState.current),
        icon: Icons.person_outline_rounded,
      ),
      WorkflowStep(
        title: 'On the Way',
        subtitle: onWay && !delivered
            ? (d.vehicleNumber != null ? 'Vehicle: ${d.vehicleNumber}' : 'In transit')
            : null,
        state: cancelled
            ? WorkflowStepState.pending
            : (delivered
                ? WorkflowStepState.completed
                : (onWay ? WorkflowStepState.current : WorkflowStepState.pending)),
        icon: Icons.local_shipping_rounded,
      ),
      WorkflowStep(
        title: 'Delivered',
        subtitle: delivered ? 'Your order has arrived!' : null,
        state: delivered ? WorkflowStepState.completed : WorkflowStepState.pending,
        icon: Icons.check_circle_rounded,
      ),
    ], cancelled, 'Dispatch cancelled');
  }

  static List<WorkflowStep> _driverSteps(Dispatch d) {
    final s = d.status;
    final accepted = {'ACCEPTED', 'DISPATCHED', 'IN_TRANSIT', 'DELIVERED'}.contains(s);
    final dispatched = {'DISPATCHED', 'IN_TRANSIT', 'DELIVERED'}.contains(s);
    final inTransit = {'IN_TRANSIT', 'DELIVERED'}.contains(s);
    final delivered = s == 'DELIVERED';
    final cancelled = s == 'CANCELLED';

    return _buildSteps(cancelled, [
      WorkflowStep(
        title: 'Assigned',
        subtitle: d.orderNumber != null ? 'Order ${d.orderNumber}' : null,
        state: WorkflowStepState.completed,
        icon: Icons.assignment_rounded,
      ),
      WorkflowStep(
        title: 'Accepted',
        subtitle: accepted ? 'Trip accepted via QR' : 'Scan QR code to accept',
        state: accepted
            ? WorkflowStepState.completed
            : (cancelled ? WorkflowStepState.pending : WorkflowStepState.current),
        icon: Icons.qr_code_scanner_rounded,
      ),
      WorkflowStep(
        title: 'Pickup Ready',
        subtitle: dispatched ? 'Items ready at nursery' : null,
        state: cancelled
            ? WorkflowStepState.pending
            : (dispatched
                ? (s == 'DISPATCHED' ? WorkflowStepState.current : WorkflowStepState.completed)
                : WorkflowStepState.pending),
        icon: Icons.store_outlined,
      ),
      WorkflowStep(
        title: 'In Transit',
        subtitle: inTransit && !delivered ? 'Delivering to customer' : null,
        state: cancelled
            ? WorkflowStepState.pending
            : (delivered
                ? WorkflowStepState.completed
                : (inTransit ? WorkflowStepState.current : WorkflowStepState.pending)),
        icon: Icons.local_shipping_rounded,
      ),
      WorkflowStep(
        title: 'Delivered',
        subtitle: delivered ? 'Trip completed' : null,
        state: delivered ? WorkflowStepState.completed : WorkflowStepState.pending,
        icon: Icons.check_circle_rounded,
      ),
    ], cancelled, 'Trip cancelled');
  }

  static List<WorkflowStep> _sellerSteps(Dispatch d) {
    final s = d.status;
    final accepted = {'ACCEPTED', 'DISPATCHED', 'IN_TRANSIT', 'DELIVERED'}.contains(s);
    final dispatched = {'DISPATCHED', 'IN_TRANSIT', 'DELIVERED'}.contains(s);
    final inTransit = {'IN_TRANSIT', 'DELIVERED'}.contains(s);
    final delivered = s == 'DELIVERED';
    final cancelled = s == 'CANCELLED';

    return _buildSteps(cancelled, [
      WorkflowStep(
        title: 'Dispatch Created',
        subtitle: d.orderNumber != null ? 'Order ${d.orderNumber}' : null,
        state: WorkflowStepState.completed,
        icon: Icons.local_shipping_outlined,
      ),
      WorkflowStep(
        title: 'Driver Accepted',
        subtitle: accepted
            ? (d.driverName != null ? d.driverName : 'Driver accepted trip')
            : 'Awaiting driver to scan QR',
        state: accepted
            ? WorkflowStepState.completed
            : (cancelled ? WorkflowStepState.pending : WorkflowStepState.current),
        icon: Icons.person_outline_rounded,
      ),
      WorkflowStep(
        title: 'Dispatched',
        subtitle: dispatched ? 'Items handed to driver' : null,
        state: cancelled
            ? WorkflowStepState.pending
            : (dispatched
                ? (s == 'DISPATCHED' ? WorkflowStepState.current : WorkflowStepState.completed)
                : WorkflowStepState.pending),
        icon: Icons.handshake_outlined,
      ),
      WorkflowStep(
        title: 'In Transit',
        subtitle: inTransit && !delivered
            ? (d.vehicleNumber != null ? 'Vehicle: ${d.vehicleNumber}' : null)
            : null,
        state: cancelled
            ? WorkflowStepState.pending
            : (delivered
                ? WorkflowStepState.completed
                : (inTransit ? WorkflowStepState.current : WorkflowStepState.pending)),
        icon: Icons.route_rounded,
      ),
      WorkflowStep(
        title: 'Delivered',
        subtitle: delivered ? 'Delivery confirmed' : null,
        state: delivered ? WorkflowStepState.completed : WorkflowStepState.pending,
        icon: Icons.check_circle_rounded,
      ),
    ], cancelled, 'Dispatch cancelled');
  }

  static List<WorkflowStep> _buildSteps(
    bool cancelled,
    List<WorkflowStep> steps,
    bool isCancelled,
    String cancelLabel,
  ) {
    if (isCancelled) {
      steps.add(WorkflowStep(
        title: cancelLabel,
        state: WorkflowStepState.cancelled,
        icon: Icons.cancel_rounded,
      ));
    }
    return steps;
  }
}

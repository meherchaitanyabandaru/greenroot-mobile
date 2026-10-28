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
import '../../features/quotations/quotations.dart';
import '../utilities/step_time.dart';

// ── Step rendering state ───────────────────────────────────────────────────────

enum WorkflowStepState { completed, current, pending, cancelled }

class WorkflowStep {
  final String title;
  final String? subtitle;
  final WorkflowStepState state;
  final IconData icon;
  /// The "loading done" step: the timeline offers its photos and truck.
  final bool hasLoadingProof;

  const WorkflowStep({
    required this.title,
    this.subtitle,
    required this.state,
    required this.icon,
    this.hasLoadingProof = false,
  });
}

// ── Role enum for timeline ────────────────────────────────────────────────────

enum OrderTimelineRole { buyer, seller }

// ── Order workflow ─────────────────────────────────────────────────────────────

class OrderWorkflow {
  // Returns role-appropriate step list for the order timeline.
  // [trip]: the order's active trip, for the delivery steps and their times.
  static List<WorkflowStep> stepsFor(
    Order order,
    OrderTimelineRole role, {
    Dispatch? trip,
  }) {
    return role == OrderTimelineRole.buyer
        ? _buyerSteps(order, trip)
        : _sellerSteps(order, trip);
  }

  // Returns which statuses allow cancel for each role.
  // Derived from BUSINESS_RULES.md §Order Cancel Rules.
  static bool canBuyerCancel(String status) => status == 'PENDING';
  static bool canSellerCancel(String status) =>
      {'PENDING', 'CONFIRMED', 'LOADING'}.contains(status);

  // ── Buyer: 5 simple customer-facing steps ──────────────────────────────────
  // Hides all internal loading/operational states from the buyer.
  static List<WorkflowStep> _buyerSteps(Order order, Dispatch? trip) {
    final s = order.status;
    final cancelled = s == 'CANCELLED';

    // Derive milestone booleans in order
    final accepted = !cancelled && s != 'PENDING';
    final preparing = !cancelled &&
        {'LOADING', 'LOADED', 'PARTIALLY_FULFILLED', 'COMPLETED'}.contains(s);
    final readyOrBeyond = !cancelled &&
        {'LOADED', 'PARTIALLY_FULFILLED', 'COMPLETED'}.contains(s);
    final delivered = !cancelled && s == 'COMPLETED';

    WorkflowStepState s0(bool done, bool active) => cancelled
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
            ? (_fmt(order.confirmedAt).isNotEmpty
                ? _fmt(order.confirmedAt)
                : 'Your order was confirmed')
            : 'Awaiting nursery confirmation',
        state: s0(accepted, !accepted && !cancelled),
        icon: Icons.verified_user_outlined,
      ),
      WorkflowStep(
        title: 'Being Prepared',
        subtitle: s == 'LOADING'
            ? [_fmt(order.loadingStartedAt), 'Plants are being loaded']
                .where((p) => p.isNotEmpty).join(' · ')
            : (preparing
                ? [_fmt(order.loadingCompletedAt), 'Plants loaded']
                    .where((p) => p.isNotEmpty).join(' · ')
                : null),
        state: cancelled
            ? WorkflowStepState.pending
            : (preparing
                ? (s == 'LOADING' ? WorkflowStepState.current : WorkflowStepState.completed)
                : (accepted ? WorkflowStepState.current : WorkflowStepState.pending)),
        icon: Icons.inventory_2_outlined,
      ),
      WorkflowStep(
        title: 'On the Way',
        subtitle: trip?.tripStartedAt != null || trip?.dispatchDate != null
            ? [stepTime(trip!.tripStartedAt ?? trip.dispatchDate), trip.driverName]
                .whereType<String>().where((p) => p.isNotEmpty).join(' · ')
            : (readyOrBeyond && !delivered
                ? (trip?.driverAcceptedAt != null
                    ? 'Driver assigned, leaving soon'
                    : 'Waiting for the driver')
                : null),
        state: cancelled
            ? WorkflowStepState.pending
            : (delivered
                ? WorkflowStepState.completed
                : (readyOrBeyond ? WorkflowStepState.current : WorkflowStepState.pending)),
        icon: Icons.local_shipping_rounded,
      ),
      WorkflowStep(
        title: 'Delivered',
        subtitle: delivered
            ? (stepTime(trip?.deliveryDate).isNotEmpty
                ? stepTime(trip?.deliveryDate)
                : 'Order complete — thank you!')
            : null,
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
      ),);
    }

    return steps;
  }

  // ── Seller/Manager: 5 operational steps ────────────────────────────────────
  // Shows internal state labels that are meaningful for nursery operations.
  // Includes manager attribution and timestamps from API.
  static List<WorkflowStep> _sellerSteps(Order order, Dispatch? trip) {
    final s = order.status;
    final cancelled = s == 'CANCELLED';

    final accepted = !cancelled && s != 'PENDING';
    final loadingStarted = !cancelled &&
        {'LOADING', 'LOADED', 'PARTIALLY_FULFILLED', 'COMPLETED'}.contains(s);
    final loadingDone = !cancelled &&
        {'LOADED', 'PARTIALLY_FULFILLED', 'COMPLETED'}.contains(s);
    final completed = !cancelled && s == 'COMPLETED';
    final partial = s == 'PARTIALLY_FULFILLED';

    // Who confirmed or started loading is not recorded: naming the manager
    // assigned *now* credited steps they never did (owner confirmed, then assigned).
    const byLine = 'By the nursery';

    final steps = <WorkflowStep>[
      WorkflowStep(
        title: 'New Order',
        subtitle: _fmt(order.createdAt ?? order.orderDate),
        state: WorkflowStepState.completed,
        icon: Icons.receipt_long_rounded,
      ),
      WorkflowStep(
        title: 'Order Accepted',
        subtitle: accepted
            ? (order.confirmedAt != null
                ? '${_fmt(order.confirmedAt)} · $byLine'
                : byLine)
            : 'Awaiting confirmation',
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
            ? [
                _fmt(order.loadingCompletedAt),
                if (partial) 'Some items had reduced quantities',
              ].where((p) => p.isNotEmpty).join(' · ')
            : (s == 'LOADING' ? 'Loading in progress…' : null),
        state: cancelled
            ? WorkflowStepState.pending
            : (completed
                ? WorkflowStepState.completed
                : (loadingDone ? WorkflowStepState.current : WorkflowStepState.pending)),
        icon: Icons.done_all_rounded,
        hasLoadingProof: loadingDone,
      ),
      if (trip == null || trip.status == 'CANCELLED')
        WorkflowStep(
          title: 'Delivered',
          subtitle: loadingDone && !completed
              ? 'Create a trip from order actions'
              : (completed ? 'Order fulfilled' : null),
          state: completed ? WorkflowStepState.completed : WorkflowStepState.pending,
          icon: Icons.check_circle_rounded,
        )
      else
        ..._tripSteps(trip),
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
      ),);
    }

    return steps;
  }

  static String _fmt(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('EEE, d MMM · h:mm a').format(dt.toLocal());
  }

  // Driver Assigned → On the Way → Delivered, each with when it happened.
  static List<WorkflowStep> _tripSteps(Dispatch t) {
    final s = t.status;
    final assigned = {'ACCEPTED', 'DISPATCHED', 'IN_TRANSIT', 'DELIVERED'}.contains(s);
    final onWay = {'DISPATCHED', 'IN_TRANSIT', 'DELIVERED'}.contains(s);
    final delivered = s == 'DELIVERED';
    String join(String time, String? detail) =>
        [time, if (detail != null && detail.isNotEmpty) detail]
            .where((p) => p.isNotEmpty)
            .join(' · ');
    WorkflowStepState state(bool done, bool current) => done
        ? WorkflowStepState.completed
        : (current ? WorkflowStepState.current : WorkflowStepState.pending);
    final vehicle = t.vehicleNumber ?? t.outsideVehicleNumber;
    return [
      WorkflowStep(
        title: 'Trip Created',
        subtitle: join(stepTime(t.createdAt),
            t.isOutsideTransport ? 'Outside lorry' : 'Trip QR ready for the driver',),
        state: WorkflowStepState.completed,
        icon: Icons.qr_code_2_rounded,
      ),
      WorkflowStep(
        title: 'Driver Assigned',
        subtitle: assigned
            ? join(stepTime(t.driverAcceptedAt), t.driverName ?? t.outsideDriverName)
            : 'Waiting for a driver to scan the trip QR',
        state: state(assigned, !assigned),
        icon: Icons.person_outline_rounded,
      ),
      WorkflowStep(
        title: 'On the Way',
        subtitle: onWay
            ? join(stepTime(t.tripStartedAt ?? t.dispatchDate), vehicle)
            : null,
        state: state(delivered, onWay && !delivered),
        icon: Icons.local_shipping_rounded,
      ),
      WorkflowStep(
        title: 'Delivered',
        subtitle: delivered ? stepTime(t.deliveryDate) : null,
        state: state(delivered, false),
        icon: Icons.check_circle_rounded,
      ),
    ];
  }
}

// ── Quotation workflow ────────────────────────────────────────────────────────
//
// QUOTATION STATE MACHINE:
//   CUSTOMER_DRAFT → CUSTOMER_SENT → CUSTOMER_ACCEPTED → CONVERTED
//                                  ↘ CUSTOMER_REJECTED
//   INTERNAL_DRAFT quotations skip the send/accept steps entirely -- they
//   convert directly from draft, with no customer round trip.

class QuotationWorkflow {
  static List<WorkflowStep> stepsFor(Quotation quotation) {
    final s = quotation.status;
    final isInternal = quotation.quotationType == 'INTERNAL';
    final rejected = s == 'CUSTOMER_REJECTED';
    final sent = !rejected &&
        {'CUSTOMER_SENT', 'SENT', 'CUSTOMER_ACCEPTED', 'ACCEPTED', 'CONVERTED'}
            .contains(s);
    final accepted = !rejected &&
        {'CUSTOMER_ACCEPTED', 'ACCEPTED', 'CONVERTED'}.contains(s);
    final converted = s == 'CONVERTED';
    // Sent but never answered before valid-until: it can no longer be answered.
    final expired = quotation.displayStatus == 'EXPIRED' || s == 'EXPIRED';

    final steps = <WorkflowStep>[
      WorkflowStep(
        title: 'Quotation Created',
        subtitle: _fmt(quotation.createdAt),
        state: WorkflowStepState.completed,
        icon: Icons.description_outlined,
      ),
    ];

    if (!isInternal) {
      steps.add(WorkflowStep(
        title: 'Sent to Customer',
        subtitle: quotation.sentAt != null
            ? _fmtDt(quotation.sentAt)
            : (sent ? null : 'Not sent yet'),
        state: rejected
            ? WorkflowStepState.completed
            : (sent
                ? WorkflowStepState.completed
                : WorkflowStepState.current),
        icon: Icons.send_outlined,
      ),);
      steps.add(WorkflowStep(
        title: rejected
            ? 'Rejected by Customer'
            : (expired ? 'Expired' : 'Customer Response'),
        subtitle: expired
            ? 'Not answered in time${quotation.validUntil != null ? ' (valid until ${_fmt(quotation.validUntil!.toIso8601String())})' : ''}. Ask for a new quotation.'
            : rejected
            ? (quotation.rejectionReason?.isNotEmpty == true
                ? quotation.rejectionReason
                : (quotation.customerRespondedAt != null
                    ? _fmtDt(quotation.customerRespondedAt)
                    : null))
            : (accepted
                ? (quotation.customerRespondedAt != null
                    ? _fmtDt(quotation.customerRespondedAt)
                    : 'Accepted')
                : (sent ? 'Awaiting customer response' : null)),
        state: rejected || expired
            ? WorkflowStepState.cancelled
            : (accepted
                ? WorkflowStepState.completed
                : (sent ? WorkflowStepState.current : WorkflowStepState.pending)),
        icon: rejected || expired ? Icons.cancel_rounded : Icons.task_alt_rounded,
      ),);
    }

    if (!rejected && !expired) {
      steps.add(WorkflowStep(
        title: 'Converted to Order',
        subtitle: converted
            ? (quotation.convertedOrderCode ?? _fmtDt(quotation.convertedAt))
            : null,
        state: converted
            ? WorkflowStepState.completed
            : ((isInternal || accepted)
                ? WorkflowStepState.current
                : WorkflowStepState.pending),
        icon: Icons.receipt_long_rounded,
      ),);
    }

    return steps;
  }

  static String? _fmt(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return null;
    return DateFormat('EEE, d MMM · h:mm a').format(dt.toLocal());
  }

  static String? _fmtDt(DateTime? dt) {
    if (dt == null) return null;
    return DateFormat('EEE, d MMM · h:mm a').format(dt.toLocal());
  }
}

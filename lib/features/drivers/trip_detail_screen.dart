import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/domain/lifecycle_presenter.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dispatches/dispatches.dart';
import '../orders/orders.dart';

class DriverTripDetailScreen extends ConsumerWidget {
  final int dispatchId;
  const DriverTripDetailScreen({super.key, required this.dispatchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dispatchDetailProvider(dispatchId));
    final session = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trip Details'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(dispatchDetailProvider(dispatchId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryMain)),
        error: (err, _) => _ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(dispatchDetailProvider(dispatchId)),
        ),
        data: (dispatch) => _TripDetailBody(
          dispatch: dispatch,
          dispatchId: dispatchId,
          currentUserId: session.user?.id,
        ),
      ),
    );
  }
}

class _TripDetailBody extends ConsumerStatefulWidget {
  final Dispatch dispatch;
  final int dispatchId;
  final int? currentUserId;

  const _TripDetailBody({
    required this.dispatch,
    required this.dispatchId,
    required this.currentUserId,
  });

  @override
  ConsumerState<_TripDetailBody> createState() => _TripDetailBodyState();
}

class _TripDetailBodyState extends ConsumerState<_TripDetailBody> {
  bool _busy = false;

  Future<void> _startTrip() async {
    if (widget.dispatch.status != 'DISPATCHED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Cannot start journey. Nursery loading is not yet complete.'),
          backgroundColor: AppColors.amber600,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(dispatchRepositoryProvider)
          .updateStatus(widget.dispatchId, 'IN_TRANSIT');
      ref.invalidate(dispatchDetailProvider(widget.dispatchId));
      ref.invalidate(orderDetailProvider(widget.dispatch.orderId));
      ref.invalidate(activeDriverTripProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip started. GPS tracking is now active.'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeDelivery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Complete Delivery'),
        content: const Text(
            'Are you sure you want to mark this delivery as completed? Make sure you have uploaded the delivery proof.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.primaryMain),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(dispatchRepositoryProvider)
          .updateStatus(widget.dispatchId, 'DELIVERED');
      ref.invalidate(dispatchDetailProvider(widget.dispatchId));
      ref.invalidate(orderDetailProvider(widget.dispatch.orderId));
      ref.invalidate(orderListProvider);
      ref.invalidate(buyingOrderListProvider);
      ref.invalidate(activeDriverTripProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery completed. Well done!'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refreshStatus() {
    ref.invalidate(dispatchDetailProvider(widget.dispatchId));
    ref.invalidate(activeDriverTripProvider);
  }

  Future<void> _acceptTrip() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(dispatchRepositoryProvider)
          .acceptDispatch(widget.dispatchId);
      ref.invalidate(dispatchDetailProvider(widget.dispatchId));
      ref.invalidate(activeDriverTripProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip accepted!'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ServerError && e.statusCode == 409
                  ? 'You already have an active trip.'
                  : e.message,
            ),
            backgroundColor: AppColors.red600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dispatch = widget.dispatch;
    final status = dispatch.status;
    final display = LifecyclePresenter.forDispatchStatus(status);
    // Verify this trip is assigned to the logged-in driver before showing actions.
    final isAssignedDriver = widget.currentUserId != null &&
        (dispatch.driverUserId == widget.currentUserId ||
            dispatch.driverUserId == null);
    final dispatchDate = dispatch.dispatchDate != null
        ? DateTime.tryParse(dispatch.dispatchDate!)
        : null;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // ── Status header ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryMain, AppColors.primaryHover],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.cardRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text('Trip',
                      style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.8))),
                  const Spacer(),
                  StatusBadge(
                    label: display.label,
                    variant: display.variant,
                    dot: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                dispatch.dispatchCode,
                style: AppTypography.h2
                    .copyWith(color: Colors.white, letterSpacing: 0.5),
              ),
              if (dispatchDate != null)
                Text(
                  DateFormat('dd MMM yyyy').format(dispatchDate.toLocal()),
                  style: AppTypography.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Status timeline ───────────────────────────────────────────────────
        _StatusTimeline(status: status),
        const SizedBox(height: AppSpacing.md),

        // ── Route info ────────────────────────────────────────────────────────
        // PRIVACY: Never show customer name, mobile, or financial totals.
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.store_outlined,
                iconBg: AppColors.forest100,
                iconColor: AppColors.primaryMain,
                label: 'Pickup',
                value: 'Nursery',
              ),
              const Divider(height: 1, indent: 56),
              _InfoRow(
                icon: Icons.location_on_rounded,
                iconBg: AppColors.blue100,
                iconColor: AppColors.blue600,
                label: 'Delivery destination',
                value: dispatch.destinationAddress ?? 'Not specified',
              ),
              if (dispatch.vehicleNumber?.isNotEmpty == true) ...[
                const Divider(height: 1, indent: 56),
                _InfoRow(
                  icon: Icons.directions_car_outlined,
                  iconBg: AppColors.amber100,
                  iconColor: AppColors.amber600,
                  label: 'Vehicle',
                  value: dispatch.vehicleNumber!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Items (plant summary — no prices) ─────────────────────────────────
        if (dispatch.items.isNotEmpty) ...[
          Text('Items (${dispatch.items.length})', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: dispatch.items.asMap().entries.map((e) {
                final isLast = e.key == dispatch.items.length - 1;
                return Column(
                  children: [
                    if (e.key > 0) const Divider(height: 1, indent: 16),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.cardPadding),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.value.plantName ?? 'Item ${e.key + 1}',
                              style: AppTypography.body,
                            ),
                          ),
                          // Show quantity only — never show prices.
                          Text(
                            'Qty: ${e.value.quantity.toInt()}',
                            style: AppTypography.label
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (isLast) const SizedBox.shrink(),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Contextual actions ─────────────────────────────────────────────────
        if (isAssignedDriver) ...[
          _ContextualActions(
            status: status,
            dispatchId: widget.dispatchId,
            busy: _busy,
            onAccept: _acceptTrip,
            onStartTrip: _startTrip,
            onAddEvent: () =>
                context.push('/driver/trips/${widget.dispatchId}/event'),
            onUploadProof: () =>
                context.push('/driver/trips/${widget.dispatchId}/proof'),
            onCompleteDelivery: _completeDelivery,
            onRefresh: _refreshStatus,
          ),
          const SizedBox(height: AppSpacing.x2l),
        ],
      ],
    );
  }
}

// ── Status timeline ────────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final String status;
  const _StatusTimeline({required this.status});

  static const _steps = [
    ('PENDING', 'Assigned', Icons.assignment_outlined),
    ('ACCEPTED', 'Accepted', Icons.check_circle_outline_rounded),
    ('DISPATCHED', 'Dispatched', Icons.inventory_2_outlined),
    ('IN_TRANSIT', 'In Transit', Icons.local_shipping_rounded),
    ('DELIVERED', 'Delivered', Icons.where_to_vote_outlined),
  ];

  static const _order = [
    'PENDING',
    'ACCEPTED',
    'DISPATCHED',
    'IN_TRANSIT',
    'DELIVERED'
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx = _order.indexOf(status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: _steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final (_, label, icon) = entry.value;
          final isLast = idx == _steps.length - 1;
          final done = idx < currentIdx;
          final current = idx == currentIdx;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: done || current
                              ? AppColors.primaryMain
                              : AppColors.border,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          done ? Icons.check_rounded : icon,
                          color: done || current
                              ? Colors.white
                              : AppColors.textMuted,
                          size: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: AppTypography.caption.copyWith(
                          color: done || current
                              ? AppColors.primaryMain
                              : AppColors.textMuted,
                          fontWeight:
                              current ? FontWeight.w700 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 16,
                    height: 2,
                    color: done
                        ? AppColors.primaryMain.withValues(alpha: 0.5)
                        : AppColors.border,
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Contextual actions ─────────────────────────────────────────────────────────

class _ContextualActions extends StatelessWidget {
  final String status;
  final int dispatchId;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onStartTrip;
  final VoidCallback onAddEvent;
  final VoidCallback onUploadProof;
  final VoidCallback onCompleteDelivery;
  final VoidCallback onRefresh;

  const _ContextualActions({
    required this.status,
    required this.dispatchId,
    required this.busy,
    required this.onAccept,
    required this.onStartTrip,
    required this.onAddEvent,
    required this.onUploadProof,
    required this.onCompleteDelivery,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'DELIVERED' || status == 'CANCELLED') {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.forest100,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'DELIVERED'
                  ? Icons.check_circle_rounded
                  : Icons.cancel_outlined,
              color: AppColors.primaryMain,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              status == 'DELIVERED' ? 'Trip completed' : 'Trip cancelled',
              style: AppTypography.label.copyWith(color: AppColors.primaryMain),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // PENDING: driver hasn't accepted yet
        if (status == 'PENDING') ...[
          _ActionButton(
            icon: Icons.check_circle_outline_rounded,
            label: 'Accept Trip',
            busy: busy,
            onPressed: onAccept,
          ),
        ],

        // ACCEPTED: nursery is loading — driver cannot start yet
        if (status == 'ACCEPTED') ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.amber100,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(
                color: AppColors.amber600.withValues(alpha: 0.30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        color: AppColors.amber600, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    const Text(
                      'Waiting for Nursery Loading',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.amber600,
                        fontFamily: 'Inter',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'The nursery is preparing your plants. You cannot start the journey until loading is completed and the trip is dispatched.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.amber600,
                    fontFamily: 'Inter',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onRefresh,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonRadius,
                ),
              ),
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textMuted,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Refresh Status'),
            ),
          ),
        ],

        // DISPATCHED: loading done, driver starts journey
        if (status == 'DISPATCHED') ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.forest100,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primaryMain, size: 16),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'Loading complete! Plants are loaded. Start your journey.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryMain,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _ActionButton(
            icon: Icons.navigation_rounded,
            label: 'Start Journey',
            busy: busy,
            onPressed: onStartTrip,
          ),
        ],

        // IN_TRANSIT: driver is on the road
        if (status == 'IN_TRANSIT') ...[
          _ActionButton(
            icon: Icons.add_circle_outline_rounded,
            label: 'Add Trip Event',
            busy: false,
            onPressed: onAddEvent,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ActionButton(
            icon: Icons.photo_camera_outlined,
            label: 'Upload Delivery Proof',
            busy: false,
            onPressed: onUploadProof,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CompleteButton(busy: busy, onPressed: onCompleteDelivery),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(backgroundColor: AppColors.primaryMain),
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon),
        label: Text(label, style: AppTypography.label),
      ),
    );
  }
}

class _CompleteButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;

  const _CompleteButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryHover,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
        ),
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.where_to_vote_outlined),
        label: Text('Complete Delivery', style: AppTypography.label),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
                Text(value, style: AppTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                style: AppTypography.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryMain),
            ),
          ],
        ),
      ),
    );
  }
}

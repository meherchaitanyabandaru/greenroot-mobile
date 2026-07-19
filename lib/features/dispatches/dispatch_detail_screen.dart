import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../orders/orders.dart';
import 'dispatches.dart';

class DispatchDetailScreen extends ConsumerWidget {
  final int dispatchId;
  const DispatchDetailScreen({super.key, required this.dispatchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dispatchDetailProvider(dispatchId));
    final caps = ref.watch(sessionProvider).capabilities;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trip Details'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryMain)),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              Text(err.toString(), style: AppTypography.body),
              TextButton(
                onPressed: () =>
                    ref.invalidate(dispatchDetailProvider(dispatchId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (dispatch) => _DetailView(
          dispatch: dispatch,
          dispatchId: dispatchId,
          isDriver:
              caps.hasDriverProfile && !caps.isNurseryOwner && !caps.isManager,
          isManager: caps.isManager,
        ),
      ),
    );
  }
}

class _DetailView extends ConsumerStatefulWidget {
  final Dispatch dispatch;
  final int dispatchId;
  final bool isDriver;
  final bool isManager;
  const _DetailView({
    required this.dispatch,
    required this.dispatchId,
    required this.isDriver,
    this.isManager = false,
  });

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> {
  bool _busy = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(dispatchRepositoryProvider)
          .updateStatus(widget.dispatchId, newStatus);
      ref.invalidate(dispatchDetailProvider(widget.dispatchId));
      ref.invalidate(orderDetailProvider(widget.dispatch.orderId));
      ref.invalidate(orderListProvider);
      ref.invalidate(buyingOrderListProvider);
      if (mounted) {
        final msg = switch (newStatus) {
          'DISPATCHED' => 'Marked as dispatched.',
          'IN_TRANSIT' => 'Trip started! Share your location.',
          'DELIVERED' => 'Delivery confirmed.',
          'CANCELLED' => 'Dispatch cancelled.',
          _ => 'Status updated.',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.primaryMain),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red600),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ackDeliveryUpdate() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(dispatchRepositoryProvider)
          .acknowledgeDeliveryUpdate(widget.dispatchId);
      ref.invalidate(dispatchDetailProvider(widget.dispatchId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery update acknowledged.'),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DetailContent(
      dispatch: widget.dispatch,
      isDriver: widget.isDriver,
      isManager: widget.isManager,
      busy: _busy,
      onUpdateStatus: _updateStatus,
      onAckDeliveryUpdate: _ackDeliveryUpdate,
    );
  }
}

// Keep the old class name for internal use
class _DetailContent extends StatelessWidget {
  final Dispatch dispatch;
  final bool isDriver;
  final bool isManager;
  final bool busy;
  final void Function(String) onUpdateStatus;
  final VoidCallback onAckDeliveryUpdate;

  const _DetailContent({
    required this.dispatch,
    required this.isDriver,
    this.isManager = false,
    required this.busy,
    required this.onUpdateStatus,
    required this.onAckDeliveryUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final dispDate = dispatch.dispatchDate != null
        ? DateTime.tryParse(dispatch.dispatchDate!)
        : null;
    final delDate = dispatch.deliveryDate != null
        ? DateTime.tryParse(dispatch.deliveryDate!)
        : null;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.amber100,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.local_shipping_rounded,
                        color: AppColors.amber600, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dispatch.dispatchCode, style: AppTypography.h3),
                        if (dispatch.orderNumber != null)
                          Text('Order: ${dispatch.orderNumber}',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: dispatch.status.replaceAll('_', ' '),
                    variant: badgeVariantFromStatus(dispatch.status),
                    dot: true,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.x2l),

        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              if (dispatch.driverName != null)
                _PersonRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Driver',
                  name: dispatch.driverName!,
                  phone: dispatch.driverMobile,
                ),
              if (dispatch.vehicleNumber != null) ...[
                if (dispatch.driverName != null)
                  const Divider(height: 1, indent: 56),
                _Row(
                    icon: Icons.directions_car_outlined,
                    label: 'Vehicle',
                    value: dispatch.vehicleNumber!),
              ],
              if (dispatch.destinationAddress != null) ...[
                const Divider(height: 1, indent: 56),
                _Row(
                    icon: Icons.location_on_outlined,
                    label: 'Destination',
                    value: dispatch.destinationAddress!),
              ],
              if (dispDate != null) ...[
                const Divider(height: 1, indent: 56),
                _Row(
                    icon: Icons.calendar_today_outlined,
                    label: 'Dispatch Date',
                    value:
                        DateFormat('dd MMM yyyy').format(dispDate.toLocal())),
              ],
              if (delDate != null) ...[
                const Divider(height: 1, indent: 56),
                _Row(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Delivery Date',
                    value: DateFormat('dd MMM yyyy').format(delDate.toLocal())),
              ],
            ],
          ),
        ),

        if (dispatch.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x2l),
          Text('Items (${dispatch.items.length})', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: dispatch.items
                  .asMap()
                  .entries
                  .map((e) => Column(
                        children: [
                          if (e.key > 0) const Divider(height: 1, indent: 16),
                          Padding(
                            padding:
                                const EdgeInsets.all(AppSpacing.cardPadding),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    e.value.plantName ?? 'Item ${e.key + 1}',
                                    style: AppTypography.body,
                                  ),
                                ),
                                Text(
                                  'Qty: ${e.value.quantity.toInt()}',
                                  style: AppTypography.label,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ],

        if (dispatch.notes != null) ...[
          const SizedBox(height: AppSpacing.x2l),
          const Text('Notes', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(dispatch.notes!,
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary, height: 1.5)),
          ),
        ],

        const SizedBox(height: AppSpacing.x2l),

        if (isDriver && dispatch.requiresDriverAck) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.amber100,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.amber600),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.amber700),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text('Delivery Address Updated',
                          style: AppTypography.h4
                              .copyWith(color: AppColors.amber700)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Please review the destination before continuing the trip.',
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : onAckDeliveryUpdate,
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Acknowledge Update'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMain,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.buttonRadius),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
        ],

        // ── Driver: Trip Progress + Actions ───────────────────────────────────
        if (isDriver) ...[
          _DriverTripProgress(status: dispatch.status),
          const SizedBox(height: AppSpacing.md),
          if (dispatch.status == 'PENDING' || dispatch.status == 'ACCEPTED')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.amber100,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                  color: AppColors.amber600.withValues(alpha: 0.30),
                ),
              ),
              child: Text(
                dispatch.status == 'PENDING'
                    ? 'Accept this trip first. The nursery will dispatch it after loading is ready.'
                    : 'Waiting for nursery dispatch confirmation. You can start the trip after it is marked dispatched.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.amber700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (dispatch.status == 'DISPATCHED')
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => onUpdateStatus('IN_TRANSIT'),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Trip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius),
                  elevation: 0,
                ),
              ),
            ),
          if (dispatch.status == 'IN_TRANSIT')
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => onUpdateStatus('DELIVERED'),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: const Text('Mark Delivered'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius),
                  elevation: 0,
                ),
              ),
            ),
          if (dispatch.status == 'DELIVERED')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: AppRadius.buttonRadius,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.primaryMain),
                  SizedBox(width: AppSpacing.sm),
                  Text('Trip Completed',
                      style: TextStyle(
                          color: AppColors.primaryMain,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Manager: Dispatch status actions ───────────────────────────────────
        if (!isDriver && isManager) ...[
          if (dispatch.status == 'ACCEPTED' || dispatch.status == 'PENDING')
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => onUpdateStatus('DISPATCHED'),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.local_shipping_rounded),
                label: const Text('Mark Dispatched'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius),
                  elevation: 0,
                ),
              ),
            ),
          if (dispatch.status == 'IN_TRANSIT')
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => onUpdateStatus('DELIVERED'),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: const Text('Confirm Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius),
                  elevation: 0,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Owner: Status actions + Share QR + Track ──────────────────────────
        if (!isDriver) ...[
          // Owner-only: Mark Dispatched (PENDING or ACCEPTED → DISPATCHED)
          if (!isManager &&
              (dispatch.status == 'PENDING' ||
                  dispatch.status == 'ACCEPTED')) ...[
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => onUpdateStatus('DISPATCHED'),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.local_shipping_rounded),
                label: const Text('Mark Dispatched'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Owner: confirm delivery when IN_TRANSIT
          if (!isManager && dispatch.status == 'IN_TRANSIT') ...[
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => onUpdateStatus('DELIVERED'),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: const Text('Confirm Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Share dispatch code as QR
          if (dispatch.status != 'DELIVERED' && dispatch.status != 'CANCELLED')
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => QrShareSheet.show(
                  context,
                  code: dispatch.dispatchCode,
                  qrType: QrCodeType.tripQr,
                  shareMessage:
                      'GreenRoot Trip QR — ${dispatch.dispatchCode}\n\nShare with your driver to start the trip.\nOrder: ${dispatch.orderNumber ?? '-'}',
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryMain),
                  foregroundColor: AppColors.primaryMain,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius),
                ),
                icon: const Icon(Icons.qr_code_rounded, size: 20),
                label: Text('Share Dispatch QR', style: AppTypography.label),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          if (dispatch.status != 'DELIVERED' && dispatch.status != 'CANCELLED')
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => context.push(
                  '/dispatches/${dispatch.id}/track',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius),
                ),
                icon: const Icon(Icons.location_on_rounded, size: 20),
                label: Text('Track Shipment', style: AppTypography.label),
              ),
            ),
          if (!isManager && dispatch.status == 'DELIVERED') ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/ratings/trip/${dispatch.id}?code=${dispatch.dispatchCode}',
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryMain),
                  foregroundColor: AppColors.primaryMain,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius),
                ),
                icon: const Icon(Icons.star_outline_rounded, size: 20),
                label: Text('Rate This Delivery', style: AppTypography.label),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.x2l),
        ], // end if (!isDriver)
      ],
    );
  }
}

// ── Driver Trip Progress ────────────────────────────────────────────────────────

class _DriverTripProgress extends StatelessWidget {
  final String status;
  const _DriverTripProgress({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _TripStep(
        label: 'Loading',
        icon: Icons.inventory_2_outlined,
        done: true,
        current: status == 'PENDING',
      ),
      _TripStep(
        label: 'Loaded',
        icon: Icons.done_all_rounded,
        done: status != 'PENDING',
        current: false,
      ),
      _TripStep(
        label: 'In Transit',
        icon: Icons.local_shipping_rounded,
        done: status == 'IN_TRANSIT' || status == 'DELIVERED',
        current: status == 'PENDING',
      ),
      _TripStep(
        label: 'Delivered',
        icon: Icons.check_circle_rounded,
        done: status == 'DELIVERED',
        current: status == 'IN_TRANSIT',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trip Progress', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: steps.asMap().entries.map((entry) {
              final step = entry.value;
              final isLast = entry.key == steps.length - 1;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: step.done
                                  ? AppColors.primaryMain
                                  : (step.current
                                      ? AppColors.primaryMain
                                      : AppColors.border),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              step.done ? Icons.check_rounded : step.icon,
                              color: step.done || step.current
                                  ? Colors.white
                                  : AppColors.textMuted,
                              size: 16,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            step.label,
                            style: AppTypography.caption.copyWith(
                              color: step.done
                                  ? AppColors.primaryMain
                                  : (step.current
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted),
                              fontWeight: step.current
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 20,
                        height: 2,
                        color: step.done
                            ? AppColors.primaryMain.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TripStep {
  final String label;
  final IconData icon;
  final bool done;
  final bool current;

  const _TripStep({
    required this.label,
    required this.icon,
    required this.done,
    required this.current,
  });
}

class _PersonRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String name;
  final String? phone;

  const _PersonRow({
    required this.icon,
    required this.label,
    required this.name,
    this.phone,
  });

  Future<void> _call() async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: AppColors.forest100, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: AppColors.primaryMain),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
                Text(name, style: AppTypography.body),
                if (phone != null)
                  Text(phone!,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          if (phone != null)
            GestureDetector(
              onTap: _call,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.phone_rounded,
                    size: 20, color: AppColors.primaryMain),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: AppColors.forest100, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: AppColors.primaryMain),
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

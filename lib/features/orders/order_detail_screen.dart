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
import '../../core/widgets/order_timeline.dart';
import '../../core/domain/lifecycle_presenter.dart';
import '../../core/domain/workflow.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dispatches/dispatches.dart';
import '../plants/plants.dart';
import 'orders.dart';

// Fetches dispatches for a single order, shown inline in the order detail.
final _orderDispatchesProvider =
    FutureProvider.autoDispose.family<List<Dispatch>, int>(
  (ref, orderId) => ref.watch(dispatchRepositoryProvider).listByOrder(orderId),
);

class OrderDetailScreen extends ConsumerWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderDetailProvider(orderId));
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final caps = ref.watch(sessionProvider).capabilities;
    final canManage = caps.isNurseryOwner || caps.isManager;
    final isOwner = caps.isNurseryOwner;
    final isBuyer = !canManage && !caps.hasDriverProfile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: async.maybeWhen(
          data: (o) => Text(o.orderNumber, style: AppTypography.h4),
          orElse: () => const Text('Order Details'),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
                onPressed: () => ref.refresh(orderDetailProvider(orderId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (order) => _OrderDetailBody(
          order: order,
          orderId: orderId,
          fmt: fmt,
          canManage: canManage,
          isOwner: isOwner,
          isBuyer: isBuyer,
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _OrderDetailBody extends StatelessWidget {
  final Order order;
  final int orderId;
  final NumberFormat fmt;
  final bool canManage;
  final bool isOwner;
  final bool isBuyer;

  const _OrderDetailBody({
    required this.order,
    required this.orderId,
    required this.fmt,
    required this.canManage,
    required this.isOwner,
    required this.isBuyer,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // ── Hero: status + amount + action — always first ─────────────────
        _HeroCard(
          order: order,
          orderId: orderId,
          fmt: fmt,
          canManage: canManage,
          isOwner: isOwner,
          isBuyer: isBuyer,
        ),

        const SizedBox(height: AppSpacing.x2l),

        if (isBuyer) ...[
          // ── BUYER VIEW ───────────────────────────────────────────────────
          // No operational timeline — buyers don't care about loading steps.
          // Just: delivery tracking (if a dispatch exists) → info → items.
          _BuyerDeliverySection(orderId: orderId),
          const SizedBox(height: AppSpacing.x2l),
        ] else ...[
          // ── SELLER / MANAGER VIEW ────────────────────────────────────────
          // Operational timeline (loading steps matter here).
          _SectionCard(
            title: 'Order Timeline',
            child: OrderTimeline(order: order, role: OrderTimelineRole.seller),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Dispatch cards below timeline
          _SellerDispatchSection(orderId: orderId),
        ],

        // ── Collapsible order info (buyer + seller) ───────────────────────
        _CollapsibleInfoCard(order: order),

        if (order.deliverySnapshot != null || canManage) ...[
          const SizedBox(height: AppSpacing.x2l),
          _DeliverySnapshotCard(
            order: order,
            canManage: canManage,
          ),
        ],

        // ── Items ─────────────────────────────────────────────────────────
        if (order.items.isNotEmpty ||
            (order.status == 'LOADING' && canManage)) ...[
          const SizedBox(height: AppSpacing.x2l),
          _ItemsCard(order: order, fmt: fmt, canManage: canManage),
        ],

        // ── Rate this order (buyer only, after completion) ────────────────
        if (isBuyer && order.status == 'COMPLETED') ...[
          const SizedBox(height: AppSpacing.x2l),
          _RateOrderCard(order: order),
        ],

        const SizedBox(height: AppSpacing.x3l),
      ],
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────
// Combines order summary + current status + role-appropriate actions.
// The user sees their next step immediately — no scrolling required.

class _StatusConfig {
  final Color color;
  final IconData icon;
  final String headline;
  final String message;
  final String? label;
  const _StatusConfig({
    required this.color,
    required this.icon,
    required this.headline,
    required this.message,
    this.label,
  });
}

class _HeroCard extends ConsumerStatefulWidget {
  final Order order;
  final int orderId;
  final NumberFormat fmt;
  final bool canManage;
  final bool isOwner;
  final bool isBuyer;

  const _HeroCard({
    required this.order,
    required this.orderId,
    required this.fmt,
    required this.canManage,
    required this.isOwner,
    required this.isBuyer,
  });

  @override
  ConsumerState<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends ConsumerState<_HeroCard> {
  bool _busy = false;

  Order get _order => widget.order;
  String get _status => _order.status;
  bool get _hasDeliveryAddress =>
      _order.deliverySnapshot?.addressLine1?.trim().isNotEmpty == true;

  // ── Status visual config ───────────────────────────────────────────────────

  _StatusConfig _cfgFor(Dispatch? dispatch) {
    final display = LifecyclePresenter.forOrder(
      order: _order,
      dispatch: dispatch,
      role: widget.isBuyer ? LifecycleRole.buyer : LifecycleRole.operator,
    );
    final message =
        _status == 'CANCELLED' && _order.cancelReason?.isNotEmpty == true
            ? 'Reason: ${_order.cancelReason}'
            : display.subtitle;
    return _StatusConfig(
      color: display.color,
      icon: _iconFor(display, dispatch),
      headline: display.title,
      message: message,
      label: display.label,
    );
  }

  IconData _iconFor(LifecycleDisplay display, Dispatch? dispatch) {
    final dispatchStatus = dispatch?.status.toUpperCase();
    if (display.variant == BadgeVariant.error) return Icons.cancel_rounded;
    if (dispatchStatus == 'IN_TRANSIT' || dispatchStatus == 'DISPATCHED') {
      return Icons.local_shipping_rounded;
    }
    if (dispatchStatus == 'ACCEPTED') return Icons.person_rounded;
    if (display.variant == BadgeVariant.success) {
      return Icons.check_circle_rounded;
    }
    if (_status == 'CONFIRMED' || _status == 'LOADING') {
      return Icons.inventory_2_outlined;
    }
    return Icons.schedule_rounded;
  }

  // ── API actions ────────────────────────────────────────────────────────────

  Future<void> _doAction(Future<Order> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(orderListProvider);
      ref.invalidate(buyingOrderListProvider);
    } on AppError catch (e) {
      if (mounted) _snack(e.message, AppColors.red600);
    } catch (e) {
      if (mounted) _snack(e.toString(), AppColors.red600);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (!_hasDeliveryAddress) {
      _snack('Add a delivery address before confirming this order.',
          AppColors.amber700);
      return;
    }
    await _doAction(
        () => ref.read(orderRepositoryProvider).confirmOrder(widget.orderId));
    if (mounted) _snack('Order confirmed', AppColors.primaryMain);
  }

  Future<void> _startLoading() async {
    await _doAction(
        () => ref.read(orderRepositoryProvider).startLoading(widget.orderId));
    if (mounted) _snack('Loading started', AppColors.blue600);
  }

  Future<void> _completeLoading() async {
    await _doAction(() =>
        ref.read(orderRepositoryProvider).completeLoading(widget.orderId));
    if (mounted) _snack('Loading completed', AppColors.primaryMain);
  }

  Future<void> _markCompleted() async {
    await _doAction(() => ref
        .read(orderRepositoryProvider)
        .updateStatus(widget.orderId, 'COMPLETED'));
    if (mounted) _snack('Order marked as completed', AppColors.primaryMain);
  }

  Future<void> _createDispatch() async {
    String? dest;
    String? notes;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateDispatchSheet(
        onSubmit: (d, n) {
          dest = d;
          notes = n;
          Navigator.pop(ctx, true);
        },
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final dispatch =
          await ref.read(dispatchRepositoryProvider).createDispatch(
                widget.orderId,
                destinationAddress: dest,
                notes: notes,
              );
      if (mounted) {
        await QrShareSheet.show(
          context,
          code: dispatch.dispatchCode,
          qrType: QrCodeType.tripQr,
          shareMessage:
              'GreenRoot Trip QR — ${dispatch.dispatchCode}\n\nShare with your driver to start the trip.\nOrder: ${_order.orderNumber}',
        );
        if (mounted) {
          ref.invalidate(orderDetailProvider(widget.orderId));
          ref.invalidate(_orderDispatchesProvider(widget.orderId));
          context.push('/dispatches/${dispatch.id}');
        }
      }
    } on AppError catch (e) {
      if (mounted) _snack(e.message, AppColors.red600);
    } catch (e) {
      if (mounted) _snack(e.toString(), AppColors.red600);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _viewDispatch(Dispatch dispatch) {
    context.push('/dispatches/${dispatch.id}');
  }

  Future<void> _assignManager() async {
    final nurseryId = _order.sellerNurseryId;
    if (nurseryId == null) return;
    List<NurseryManager> managers;
    try {
      managers =
          await ref.read(orderRepositoryProvider).getNurseryManagers(nurseryId);
    } catch (_) {
      managers = [];
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<NurseryManager>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssignManagerSheet(managers: managers),
    );
    if (selected == null || !mounted) return;
    await _doAction(() => ref
        .read(orderRepositoryProvider)
        .assignManager(widget.orderId, selected.userId));
    if (mounted) _snack('${selected.name} assigned', AppColors.primaryMain);
  }

  Future<void> _confirmCancel() async {
    String? reason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Cancel Order', style: AppTypography.h3),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Reason (optional)'),
            onChanged: (v) => reason = v,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Back')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel Order',
                  style: TextStyle(color: AppColors.red600)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _doAction(() => ref
        .read(orderRepositoryProvider)
        .cancelOrder(widget.orderId, reason: reason));
    if (mounted) _snack('Order cancelled', AppColors.red600);
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canManage = widget.canManage;
    final isOwner = widget.isOwner;
    final status = _status;
    final dispatchesAsync = ref.watch(_orderDispatchesProvider(widget.orderId));
    final dispatches = dispatchesAsync.valueOrNull ?? [];
    final isCheckingDispatches = dispatchesAsync.isLoading;
    final needsDeliveryBeforeConfirm =
        canManage && status == 'PENDING' && !_hasDeliveryAddress;
    final existingDispatch =
        LifecyclePresenter.activeDispatchForOrder(dispatches, widget.orderId);
    final cfg = _cfgFor(existingDispatch);
    final statusLabel = cfg.label ?? status.replaceAll('_', ' ');

    // Determine primary + secondary buttons for this role × state
    Widget? primaryBtn;
    Widget? secondaryBtn;
    Widget? tertiaryBtn;

    if (canManage) {
      switch (status) {
        case 'PENDING':
          primaryBtn = _BigButton(
            label: needsDeliveryBeforeConfirm
                ? 'Add Delivery Address First'
                : 'Confirm Order',
            icon: needsDeliveryBeforeConfirm
                ? Icons.location_on_outlined
                : Icons.check_circle_outline_rounded,
            color: needsDeliveryBeforeConfirm
                ? AppColors.amber700
                : AppColors.primaryMain,
            onTap: _busy ? null : _confirm,
          );
          secondaryBtn = _OutlineButton(
            label: 'Cancel Order',
            color: AppColors.red600,
            onTap: _busy ? null : _confirmCancel,
          );
        case 'CONFIRMED':
          primaryBtn = _BigButton(
            label: 'Start Loading',
            icon: Icons.inventory_2_outlined,
            color: AppColors.blue600,
            onTap: _busy ? null : _startLoading,
          );
        case 'LOADING':
          primaryBtn = _BigButton(
            label: 'Complete Loading',
            icon: Icons.done_all_rounded,
            color: AppColors.primaryMain,
            onTap: _busy ? null : _completeLoading,
          );
        case 'LOADED':
        case 'PARTIALLY_FULFILLED':
          final hasDeliveredDispatch = existingDispatch?.status == 'DELIVERED';
          if (existingDispatch != null) {
            primaryBtn = _BigButton(
              label: 'View Dispatch',
              icon: Icons.local_shipping_rounded,
              color: AppColors.blue600,
              onTap: _busy ? null : () => _viewDispatch(existingDispatch),
            );
          } else if (isCheckingDispatches) {
            primaryBtn = _BigButton(
              label: 'Checking Dispatch',
              icon: Icons.sync_rounded,
              color: AppColors.textSecondary,
              onTap: null,
            );
          } else {
            primaryBtn = _BigButton(
              label: 'Create Dispatch',
              icon: Icons.local_shipping_rounded,
              color: AppColors.blue600,
              onTap: _busy ? null : _createDispatch,
            );
          }
          if (hasDeliveredDispatch) {
            secondaryBtn = _OutlineButton(
              label: 'Mark as Completed',
              color: AppColors.primaryMain,
              onTap: _busy ? null : _markCompleted,
            );
          }
      }

      // Owner-only: assign manager — shown as a subtle tertiary link
      final canAssignMgr = isOwner &&
          _order.sellerNurseryId != null &&
          !{'CANCELLED', 'COMPLETED', 'LOADED', 'PARTIALLY_FULFILLED'}
              .contains(status);
      if (canAssignMgr) {
        tertiaryBtn = TextButton.icon(
          onPressed: _busy ? null : _assignManager,
          icon: const Icon(Icons.manage_accounts_rounded, size: 16),
          label: Text(
            _order.assignedManagerUserId != null
                ? 'Re-assign Manager'
                : 'Assign Manager',
          ),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          ),
        );
      }
    } else if (widget.isBuyer && status == 'PENDING') {
      // Buyer can only cancel their own PENDING order
      secondaryBtn = _OutlineButton(
        label: 'Cancel Order',
        color: AppColors.red600,
        onTap: _busy ? null : _confirmCancel,
      );
    }

    final hasActions =
        primaryBtn != null || secondaryBtn != null || tertiaryBtn != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored status strip at the very top
          Container(height: 4, color: cfg.color),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order amount + item count
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fmt.format(_order.totalAmount),
                            style: AppTypography.h1
                                .copyWith(color: AppColors.textPrimary),
                          ),
                          if (_order.items.isNotEmpty)
                            Text(
                              '${_order.items.length} item${_order.items.length == 1 ? '' : 's'}',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                    // Status badge pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cfg.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: cfg.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel,
                            style: AppTypography.caption.copyWith(
                              color: cfg.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Status icon + headline + message
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cfg.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(cfg.icon, color: cfg.color, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cfg.headline, style: AppTypography.label),
                          if (cfg.message.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                cfg.message,
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Action buttons — only shown when there's something to do
                if (hasActions) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: AppSpacing.md),
                  if (_busy)
                    const Center(
                      child: SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.primaryMain),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (primaryBtn != null) ...[
                          primaryBtn,
                          if (secondaryBtn != null)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                        if (secondaryBtn != null) secondaryBtn,
                        if (tertiaryBtn != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          tertiaryBtn,
                        ],
                      ],
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable button helpers ────────────────────────────────────────────────────

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.sm)),
          elevation: 0,
          textStyle: AppTypography.label.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _OutlineButton({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeightSm),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.sm)),
          textStyle: AppTypography.label,
        ),
        child: Text(label),
      ),
    );
  }
}

// ── Section card wrapper ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h4),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

// ── Buyer delivery section ────────────────────────────────────────────────────
// Shown only to buyers. No operational timeline — just: "is it coming and who?"
// Large, prominent card with driver info and call button when a dispatch exists.

class _BuyerDeliverySection extends ConsumerWidget {
  final int orderId;
  const _BuyerDeliverySection({required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_orderDispatchesProvider(orderId)).maybeWhen(
          data: (dispatches) {
            if (dispatches.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Delivery', style: AppTypography.h4),
                const SizedBox(height: AppSpacing.md),
                ...dispatches.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _BuyerDeliveryCard(dispatch: d),
                    )),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}

class _BuyerDeliveryCard extends StatelessWidget {
  final Dispatch dispatch;
  const _BuyerDeliveryCard({required this.dispatch});

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final d = dispatch;
    final isOnWay = {'DISPATCHED', 'IN_TRANSIT'}.contains(d.status);
    final isDelivered = d.status == 'DELIVERED';
    final hasDriver = d.driverName?.isNotEmpty == true;
    final hasPhone = d.driverMobile?.isNotEmpty == true;
    final display = LifecyclePresenter.forDispatch(
      dispatch: d,
      role: LifecycleRole.buyer,
    );
    final statusColor = display.color;
    final statusBg = display.color.withValues(alpha: 0.12);
    final statusIcon = switch (d.status.toUpperCase()) {
      'DELIVERED' => Icons.check_circle_rounded,
      'DISPATCHED' || 'IN_TRANSIT' => Icons.local_shipping_rounded,
      'ACCEPTED' => Icons.person_rounded,
      _ => Icons.schedule_rounded,
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: isOnWay ? AppColors.amber500 : AppColors.border,
          width: isOnWay ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          // Status strip + icon row
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 26),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(display.label,
                          style: AppTypography.h4.copyWith(color: statusColor)),
                      if (isOnWay)
                        Text(
                          'Your order is on its way to you',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        )
                      else if (isDelivered)
                        Text(
                          'Successfully delivered',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        )
                      else if (hasDriver)
                        Text(
                          'Driver will pick up your order soon',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Driver + vehicle details with call button
          if (hasDriver || d.vehicleNumber?.isNotEmpty == true) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardPadding, vertical: AppSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 18, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasDriver)
                          Text(d.driverName!, style: AppTypography.label),
                        if (d.vehicleNumber?.isNotEmpty == true)
                          Text(d.vehicleNumber!,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  // Call driver button — the most useful thing for a buyer
                  if (hasPhone)
                    GestureDetector(
                      onTap: () => _call(d.driverMobile!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_rounded,
                                size: 15, color: AppColors.primaryMain),
                            const SizedBox(width: 5),
                            Text('Call Driver',
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.primaryMain,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Track / View details footer
          GestureDetector(
            onTap: () => context.push('/dispatches/${d.id}'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(AppRadius.xl)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isOnWay ? 'Track Shipment' : 'View Details',
                    style: AppTypography.label
                        .copyWith(color: AppColors.primaryMain),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 16, color: AppColors.primaryMain),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Seller dispatch section ────────────────────────────────────────────────────
// Compact dispatch cards for seller/manager, shown below the operational timeline.

class _SellerDispatchSection extends ConsumerWidget {
  final int orderId;
  const _SellerDispatchSection({required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_orderDispatchesProvider(orderId)).maybeWhen(
          data: (dispatches) {
            if (dispatches.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dispatches', style: AppTypography.h4),
                const SizedBox(height: AppSpacing.md),
                ...dispatches.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _SellerDispatchRow(dispatch: d),
                    )),
                const SizedBox(height: AppSpacing.md),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}

class _SellerDispatchRow extends StatelessWidget {
  final Dispatch dispatch;
  const _SellerDispatchRow({required this.dispatch});

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final d = dispatch;
    final display = LifecyclePresenter.forDispatch(
      dispatch: d,
      role: LifecycleRole.operator,
    );
    final isActive =
        {'ACCEPTED', 'DISPATCHED', 'IN_TRANSIT'}.contains(d.status);
    final isDelivered = d.status == 'DELIVERED';

    final chipColor = isDelivered
        ? AppColors.primaryMain
        : isActive
            ? AppColors.amber700
            : AppColors.textSecondary;
    final chipBg = isDelivered
        ? AppColors.primaryLight
        : isActive
            ? AppColors.amber100
            : AppColors.slate50;

    return GestureDetector(
      onTap: () => context.push('/dispatches/${d.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: isActive ? AppColors.amber500 : AppColors.border,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: chipBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.local_shipping_rounded,
                  color: chipColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.dispatchCode, style: AppTypography.label),
                  if (d.driverName?.isNotEmpty == true)
                    Text(d.driverName!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary)),
                  if (d.vehicleNumber?.isNotEmpty == true)
                    Text(d.vehicleNumber!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            // Call driver pill for seller too
            if (d.driverMobile?.isNotEmpty == true) ...[
              GestureDetector(
                onTap: () => _call(d.driverMobile!),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.phone_rounded,
                      size: 16, color: AppColors.primaryMain),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: chipBg, borderRadius: BorderRadius.circular(20)),
              child: Text(
                display.label,
                style: AppTypography.caption
                    .copyWith(color: chipColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Collapsible info card ─────────────────────────────────────────────────────
// Collapsed by default — progressive disclosure for order metadata.

class _CollapsibleInfoCard extends StatefulWidget {
  final Order order;
  const _CollapsibleInfoCard({required this.order});

  @override
  State<_CollapsibleInfoCard> createState() => _CollapsibleInfoCardState();
}

class _CollapsibleInfoCardState extends State<_CollapsibleInfoCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _turn;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _turn = Tween(begin: 0.0, end: 0.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final date = DateTime.tryParse(o.orderDate);
    final dateStr =
        date != null ? DateFormat('dd MMM yyyy').format(date.toLocal()) : '';
    final buyerLabel = o.buyerName ?? o.customerName ?? 'Unknown Buyer';
    final responsibleLabel = o.assignedManagerName ??
        (o.assignedManagerUserId != null
            ? 'Manager #${o.assignedManagerUserId}'
            : 'Nursery Owner');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Tappable header
          InkWell(
            onTap: _toggle,
            borderRadius: AppRadius.cardRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardPadding, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                        color: AppColors.forest100, shape: BoxShape.circle),
                    child: const Icon(Icons.info_outline_rounded,
                        size: 17, color: AppColors.primaryMain),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text('Order Details', style: AppTypography.label),
                  ),
                  RotationTransition(
                    turns: _turn,
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMuted, size: 20),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            _InfoRow(
                icon: Icons.person_outline_rounded,
                label: 'Buyer',
                value: buyerLabel),
            if (o.sellerNursery != null) ...[
              const Divider(height: 1, indent: 56),
              _InfoRow(
                  icon: Icons.store_outlined,
                  label: 'Seller',
                  value: o.sellerNursery!),
            ],
            const Divider(height: 1, indent: 56),
            _InfoRow(
                icon: Icons.manage_accounts_outlined,
                label: 'Responsible',
                value: responsibleLabel),
            if (dateStr.isNotEmpty) ...[
              const Divider(height: 1, indent: 56),
              _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Order Date',
                  value: dateStr),
            ],
            if (o.notes?.isNotEmpty == true) ...[
              const Divider(height: 1, indent: 56),
              _InfoRow(
                  icon: Icons.notes_outlined, label: 'Notes', value: o.notes!),
            ],
            if (o.cancelReason?.isNotEmpty == true) ...[
              const Divider(height: 1, indent: 56),
              _InfoRow(
                  icon: Icons.cancel_outlined,
                  label: 'Cancel Reason',
                  value: o.cancelReason!,
                  valueColor: AppColors.red600),
            ],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: AppColors.forest100, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: AppColors.primaryMain),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
                Text(value,
                    style: AppTypography.body
                        .copyWith(color: valueColor ?? AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliverySnapshotCard extends ConsumerStatefulWidget {
  final Order order;
  final bool canManage;

  const _DeliverySnapshotCard({
    required this.order,
    required this.canManage,
  });

  @override
  ConsumerState<_DeliverySnapshotCard> createState() =>
      _DeliverySnapshotCardState();
}

class _DeliverySnapshotCardState extends ConsumerState<_DeliverySnapshotCard> {
  bool _busy = false;

  Future<void> _edit() async {
    final profile = ref.read(sessionProvider).user;
    final profileName = profile?.name?.trim();
    final profileMobile = profile?.mobile?.trim();
    final result = await showModalBottomSheet<DeliverySnapshotRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliveryEditSheet(
        snapshot: widget.order.deliverySnapshot,
        profileName: profileName,
        profileMobile: profileMobile,
      ),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(orderRepositoryProvider)
          .updateDeliverySnapshot(widget.order.id, result);
      ref.invalidate(orderDetailProvider(widget.order.id));
      ref.invalidate(_orderDispatchesProvider(widget.order.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.emergencyUpdate
                ? 'Emergency delivery update sent to driver.'
                : 'Delivery address updated.'),
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
    final delivery = widget.order.deliverySnapshot;
    final profile = ref.watch(sessionProvider).user;
    final profileName = profile?.name?.trim();
    final profileMobile = profile?.mobile?.trim();
    final profileContact = [
      if (profileName?.isNotEmpty == true) profileName,
      if (profileMobile?.isNotEmpty == true) '+91 $profileMobile',
    ].whereType<String>().join(' | ');
    final snapshotContact = [
      if (delivery?.contactName?.isNotEmpty == true) delivery!.contactName,
      if (delivery?.contactMobile?.isNotEmpty == true) delivery!.contactMobile,
    ].whereType<String>().join(' | ');
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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: AppColors.forest100, shape: BoxShape.circle),
                child: const Icon(Icons.location_on_outlined,
                    size: 18, color: AppColors.primaryMain),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Text('Delivery Snapshot', style: AppTypography.h4)),
              if (widget.canManage)
                TextButton.icon(
                  onPressed: _busy ? null : _edit,
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_location_alt_outlined, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (delivery == null)
            Text(
              'No delivery address snapshot saved yet.',
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            )
          else ...[
            Text(delivery.displayAddress, style: AppTypography.body),
            if (snapshotContact.isNotEmpty || profileContact.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                snapshotContact.isNotEmpty ? snapshotContact : profileContact,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (delivery.deliveryInstructions?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                delivery.deliveryInstructions!,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (delivery.requiresDriverAck) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.amber100,
                  borderRadius: AppRadius.buttonRadius,
                  border: Border.all(color: AppColors.amber600),
                ),
                child: Text(
                  'Driver acknowledgement pending for latest delivery update.',
                  style:
                      AppTypography.caption.copyWith(color: AppColors.amber700),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DeliveryEditSheet extends StatefulWidget {
  final DeliverySnapshot? snapshot;
  final String? profileName;
  final String? profileMobile;

  const _DeliveryEditSheet({
    required this.snapshot,
    required this.profileName,
    required this.profileMobile,
  });

  @override
  State<_DeliveryEditSheet> createState() => _DeliveryEditSheetState();
}

class _DeliveryEditSheetState extends State<_DeliveryEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _country;
  late final TextEditingController _postal;
  late final TextEditingController _landmark;
  late final TextEditingController _instructions;
  bool _emergency = false;
  bool _useProfileContact = true;

  @override
  void initState() {
    super.initState();
    final s = widget.snapshot;
    _name = TextEditingController(text: s?.contactName ?? '');
    _mobile = TextEditingController(text: s?.contactMobile ?? '');
    final profileName = widget.profileName?.trim();
    final profileMobile = widget.profileMobile?.trim();
    final hasSnapshotContact = (s?.contactName?.trim().isNotEmpty ?? false) ||
        (s?.contactMobile?.trim().isNotEmpty ?? false);
    final snapshotMatchesProfile = (s?.contactName?.trim().isEmpty ?? true) ||
        s?.contactName?.trim() == profileName;
    final snapshotMobileMatchesProfile =
        (s?.contactMobile?.trim().isEmpty ?? true) ||
            s?.contactMobile?.trim() == profileMobile;
    _useProfileContact = !hasSnapshotContact ||
        (snapshotMatchesProfile && snapshotMobileMatchesProfile);
    _line1 = TextEditingController(text: s?.addressLine1 ?? '');
    _line2 = TextEditingController(text: s?.addressLine2 ?? '');
    _city = TextEditingController(text: s?.city ?? '');
    _state = TextEditingController(text: s?.state ?? '');
    _country = TextEditingController(text: s?.country ?? 'India');
    _postal = TextEditingController(text: s?.postalCode ?? '');
    _landmark = TextEditingController(text: s?.landmark ?? '');
    _instructions = TextEditingController(text: s?.deliveryInstructions ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _state.dispose();
    _country.dispose();
    _postal.dispose();
    _landmark.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _submit() {
    if (_line1.text.trim().isEmpty) return;
    final contactName =
        _useProfileContact ? widget.profileName?.trim() : _name.text.trim();
    final contactMobile =
        _useProfileContact ? widget.profileMobile?.trim() : _mobile.text.trim();
    Navigator.pop(
      context,
      DeliverySnapshotRequest(
        contactName: contactName,
        contactMobile: contactMobile,
        addressLine1: _line1.text,
        addressLine2: _line2.text,
        city: _city.text,
        state: _state.text,
        country: _country.text,
        postalCode: _postal.text,
        landmark: _landmark.text,
        deliveryInstructions: _instructions.text,
        emergencyUpdate: _emergency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Delivery Address', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.md),
            _DeliveryContactToggle(
              value: _useProfileContact,
              profileName: widget.profileName,
              profileMobile: widget.profileMobile,
              onChanged: (v) => setState(() => _useProfileContact = v),
            ),
            if (!_useProfileContact) ...[
              const SizedBox(height: AppSpacing.sm),
              _SheetField(controller: _name, label: 'Alternate contact name'),
              _SheetField(
                controller: _mobile,
                label: 'Alternate contact mobile',
                keyboardType: TextInputType.phone,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            _SheetField(controller: _line1, label: 'Address line 1'),
            _SheetField(controller: _line2, label: 'Address line 2'),
            Row(
              children: [
                Expanded(child: _SheetField(controller: _city, label: 'City')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: _SheetField(controller: _state, label: 'State')),
              ],
            ),
            Row(
              children: [
                Expanded(
                    child: _SheetField(controller: _postal, label: 'PIN code')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: _SheetField(controller: _country, label: 'Country')),
              ],
            ),
            _SheetField(controller: _landmark, label: 'Landmark'),
            _SheetField(
              controller: _instructions,
              label: 'Delivery instructions',
              maxLines: 3,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _emergency,
              onChanged: (v) => setState(() => _emergency = v),
              title: const Text('Emergency update'),
              subtitle:
                  const Text('Use after trip starts. Driver must acknowledge.'),
              activeThumbColor: AppColors.primaryMain,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius),
                ),
                child: const Text('Save Delivery Address'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryContactToggle extends StatelessWidget {
  final bool value;
  final String? profileName;
  final String? profileMobile;
  final ValueChanged<bool> onChanged;

  const _DeliveryContactToggle({
    required this.value,
    required this.profileName,
    required this.profileMobile,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final profileLabel = [
      if (profileName?.trim().isNotEmpty == true) profileName!.trim(),
      if (profileMobile?.trim().isNotEmpty == true)
        '+91 ${profileMobile!.trim()}',
    ].join(' - ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: AppRadius.inputRadius,
        border: Border.all(color: AppColors.primaryMain.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_pin_circle_outlined,
            color: AppColors.primaryMain,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Use profile contact',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profileLabel.isEmpty
                      ? 'Saved profile contact details'
                      : profileLabel,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryMain,
          ),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;

  const _SheetField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: AppRadius.inputRadius),
        ),
      ),
    );
  }
}

// ── Rate Order Card (shown for buyers on COMPLETED orders) ───────────────────

class _RateOrderCard extends ConsumerWidget {
  final Order order;
  const _RateOrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.primaryMid.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded,
                  color: AppColors.amber500, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text('Rate your experience',
                  style:
                      AppTypography.label.copyWith(color: AppColors.forest800)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'How was the plant quality and service for this order?',
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                      '/ratings/order/${order.id}?code=${order.orderNumber}'),
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Rate Order'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Items card ────────────────────────────────────────────────────────────────

class _ItemsCard extends ConsumerStatefulWidget {
  final Order order;
  final NumberFormat fmt;
  final bool canManage;
  const _ItemsCard(
      {required this.order, required this.fmt, required this.canManage});

  @override
  ConsumerState<_ItemsCard> createState() => _ItemsCardState();
}

class _ItemsCardState extends ConsumerState<_ItemsCard> {
  bool _expanded = false;

  bool get _editable => widget.order.status == 'LOADING' && widget.canManage;

  void _refresh() => ref.invalidate(orderDetailProvider(widget.order.id));

  Future<void> _deleteItem(OrderItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove "${item.displayName}" from this order?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  Text('Remove', style: TextStyle(color: AppColors.errorText))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(orderRepositoryProvider)
          .deleteOrderItem(widget.order.id, item.id);
      _refresh();
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message), backgroundColor: AppColors.errorText),
      );
    }
  }

  Future<void> _showItemSheet({OrderItem? existing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ItemEditSheet(
        orderId: widget.order.id,
        existing: existing,
        onSaved: _refresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order.items;
    final preview = _expanded ? items : items.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Items (${items.length})', style: AppTypography.h4),
            if (widget.order.status == 'LOADING')
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.amber100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Editable',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.amber700)),
                ),
              ),
          ],
        ),
        if (widget.order.status == 'LOADING') ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Items can be added, removed, or updated until Loading Completed.',
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (items.isEmpty && _editable)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'No items yet. Tap "Add Item" to add plants to this order.',
              textAlign: TextAlign.center,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ...preview.asMap().entries.map((entry) {
                  final item = entry.value;
                  return Column(
                    children: [
                      if (entry.key > 0) const Divider(height: 1, indent: 16),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.cardPadding),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.displayName,
                                      style: AppTypography.body),
                                  if (item.sizeName != null)
                                    Text(item.sizeName!,
                                        style: AppTypography.caption.copyWith(
                                            color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(widget.fmt.format(item.totalPrice),
                                    style: AppTypography.label),
                                Text('Qty: ${item.quantity.toInt()}',
                                    style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                            if (_editable) ...[
                              const SizedBox(width: AppSpacing.sm),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: AppColors.primaryMain,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showItemSheet(existing: item),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                color: AppColors.errorText,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deleteItem(item),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }),
                if (items.length > 3)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: const BoxDecoration(
                        border:
                            Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: Text(
                        _expanded
                            ? 'Show less'
                            : 'Show ${items.length - 3} more items',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.primaryMain,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (_editable) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showItemSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Item Edit Sheet ───────────────────────────────────────────────────────────

class _ItemEditSheet extends ConsumerStatefulWidget {
  final int orderId;
  final OrderItem? existing;
  final VoidCallback onSaved;

  const _ItemEditSheet(
      {required this.orderId, this.existing, required this.onSaved});

  @override
  ConsumerState<_ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends ConsumerState<_ItemEditSheet> {
  Plant? _plant;
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _qtyCtrl.text = e.quantity == e.quantity.roundToDouble()
          ? e.quantity.toInt().toString()
          : e.quantity.toStringAsFixed(2);
      _priceCtrl.text = e.unitPrice == e.unitPrice.roundToDouble()
          ? e.unitPrice.toInt().toString()
          : e.unitPrice.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPlant() async {
    final result = await showModalBottomSheet<Plant>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _PlantSearchSheet(),
    );
    if (result != null) setState(() => _plant = result);
  }

  Future<void> _save() async {
    final plantId = _plant?.id ?? widget.existing?.plantId;
    final qty = double.tryParse(_qtyCtrl.text.trim());
    final price = double.tryParse(_priceCtrl.text.trim());

    if (plantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a plant')),
      );
      return;
    }
    if (qty == null || qty <= 0 || price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid quantity and price')),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(orderRepositoryProvider);
    final req = OrderItemRequest(
      plantId: plantId,
      quantity: qty,
      unitPrice: price,
      totalPrice: qty * price,
    );
    try {
      if (widget.existing != null) {
        await repo.updateOrderItem(widget.orderId, widget.existing!.id, req);
      } else {
        await repo.createOrderItem(widget.orderId, req);
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message), backgroundColor: AppColors.errorText),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final plantName =
        _plant?.displayName ?? (isEdit ? widget.existing!.displayName : null);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding, 12, AppSpacing.screenPadding, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(isEdit ? 'Edit Item' : 'Add Item', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.lg),
            // Plant picker
            GestureDetector(
              onTap: _pickPlant,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        plantName ?? 'Select plant…',
                        style: AppTypography.body.copyWith(
                          color: plantName != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Unit Price (₹)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Save Changes' : 'Add Item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Plant search sheet (reused for item add/edit) ─────────────────────────────

class _PlantSearchSheet extends ConsumerStatefulWidget {
  const _PlantSearchSheet();

  @override
  ConsumerState<_PlantSearchSheet> createState() => _PlantSearchSheetState();
}

class _PlantSearchSheetState extends ConsumerState<_PlantSearchSheet> {
  final _ctrl = TextEditingController();
  List<Plant> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch('');
    _ctrl.addListener(() => _fetch(_ctrl.text.trim()));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _fetch(String q) async {
    setState(() => _loading = true);
    try {
      final (plants, _) = await ref
          .read(plantRepositoryProvider)
          .listPlants(search: q.isEmpty ? null : q);
      if (mounted) setState(() => _results = plants);
    } catch (_) {
      // leave results as-is
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search plants…',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primaryMain))
                : _results.isEmpty
                    ? Center(
                        child: Text('No plants found',
                            style: AppTypography.body
                                .copyWith(color: AppColors.textSecondary)))
                    : ListView.separated(
                        controller: controller,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = _results[i];
                          return ListTile(
                            title: Text(p.displayName),
                            subtitle: p.commonName != null &&
                                    p.commonName != p.scientificName
                                ? Text(p.scientificName,
                                    style: AppTypography.caption)
                                : null,
                            onTap: () => Navigator.pop(context, p),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Assign Manager Sheet ──────────────────────────────────────────────────────

class _AssignManagerSheet extends StatelessWidget {
  final List<NurseryManager> managers;
  const _AssignManagerSheet({required this.managers});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
          AppSpacing.lg, AppSpacing.screenPadding, AppSpacing.x3l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Assign Manager', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Select a manager to handle loading for this order.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x2l),
          if (managers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: AppRadius.cardRadius,
              ),
              child: Column(
                children: [
                  const Icon(Icons.person_search_rounded,
                      size: 40, color: AppColors.primaryMain),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No managers found for this nursery.\nInvite a manager from Connections.',
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...managers.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(m),
                  borderRadius: AppRadius.cardRadius,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: AppRadius.cardRadius,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              m.name.isNotEmpty ? m.name[0].toUpperCase() : 'M',
                              style: AppTypography.h3
                                  .copyWith(color: AppColors.primaryMain),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name, style: AppTypography.label),
                              Text(m.identityLabel,
                                  style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create Dispatch Sheet ──────────────────────────────────────────────────────

class _CreateDispatchSheet extends StatefulWidget {
  final void Function(String? dest, String? notes) onSubmit;
  final VoidCallback onCancel;
  const _CreateDispatchSheet({required this.onSubmit, required this.onCancel});

  @override
  State<_CreateDispatchSheet> createState() => _CreateDispatchSheetState();
}

class _CreateDispatchSheetState extends State<_CreateDispatchSheet> {
  final _destCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _destCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.x3l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Create Dispatch', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Optionally add a destination address and notes. After creating, share the dispatch QR with your driver.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x2l),
          TextField(
            controller: _destCtrl,
            decoration: const InputDecoration(
              labelText: 'Destination Address (optional)',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.x2l),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: () => widget.onSubmit(
                _destCtrl.text.trim().isEmpty ? null : _destCtrl.text.trim(),
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
              ),
              icon: const Icon(Icons.local_shipping_rounded),
              label: const Text('Create Dispatch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonRadius),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

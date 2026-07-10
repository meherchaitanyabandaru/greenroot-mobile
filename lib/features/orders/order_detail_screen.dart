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
import '../../core/domain/workflow.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dispatches/dispatches.dart';
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

        // ── Items ─────────────────────────────────────────────────────────
        if (order.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x2l),
          _ItemsCard(order: order, fmt: fmt),
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
  const _StatusConfig({
    required this.color,
    required this.icon,
    required this.headline,
    required this.message,
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

  // ── Status visual config ───────────────────────────────────────────────────

  _StatusConfig get _cfg {
    switch (_status) {
      case 'PENDING':
        return widget.isBuyer
            ? const _StatusConfig(
                color: AppColors.amber600,
                icon: Icons.schedule_rounded,
                headline: 'Waiting for Confirmation',
                message: 'The nursery will review and confirm your order.',
              )
            : const _StatusConfig(
                color: AppColors.amber600,
                icon: Icons.notifications_active_rounded,
                headline: 'New Order',
                message: 'Confirm this order to begin preparation.',
              );
      case 'CONFIRMED':
        return widget.isBuyer
            ? const _StatusConfig(
                color: AppColors.blue600,
                icon: Icons.verified_rounded,
                headline: 'Order Confirmed',
                message:
                    'The nursery has confirmed your order and is preparing it.',
              )
            : const _StatusConfig(
                color: AppColors.blue600,
                icon: Icons.inventory_2_outlined,
                headline: 'Confirmed — Ready to Load',
                message: 'Start loading items to prepare for dispatch.',
              );
      case 'LOADING':
        return _StatusConfig(
          color: AppColors.blue600,
          icon: Icons.inventory_2_outlined,
          headline: 'Loading in Progress',
          message: widget.isBuyer
              ? 'Your items are being carefully loaded.'
              : 'Mark loading complete when all items are ready.',
        );
      case 'LOADED':
        return _StatusConfig(
          color: AppColors.primaryMain,
          icon: Icons.done_all_rounded,
          headline: 'Order Loaded',
          message: widget.isBuyer
              ? 'Your order is ready — dispatch is being arranged.'
              : 'Create a dispatch to assign a driver.',
        );
      case 'PARTIALLY_FULFILLED':
        return _StatusConfig(
          color: AppColors.amber700,
          icon: Icons.warning_amber_rounded,
          headline: 'Partially Fulfilled',
          message: widget.isBuyer
              ? 'Some items had reduced quantities. Dispatch is being arranged.'
              : 'Some items had reduced quantities. Create dispatch or mark complete.',
        );
      case 'COMPLETED':
        return _StatusConfig(
          color: AppColors.primaryMain,
          icon: Icons.check_circle_rounded,
          headline: widget.isBuyer ? 'Delivered' : 'Order Completed',
          message: widget.isBuyer
              ? 'Your order has been delivered. Thank you!'
              : 'Order delivered and completed successfully.',
        );
      case 'CANCELLED':
        return _StatusConfig(
          color: AppColors.red600,
          icon: Icons.cancel_rounded,
          headline: 'Order Cancelled',
          message: _order.cancelReason?.isNotEmpty == true
              ? 'Reason: ${_order.cancelReason}'
              : 'This order has been cancelled.',
        );
      default:
        return _StatusConfig(
          color: AppColors.textSecondary,
          icon: Icons.help_outline,
          headline: _status,
          message: '',
        );
    }
  }

  // ── API actions ────────────────────────────────────────────────────────────

  Future<void> _doAction(Future<Order> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(orderDetailProvider(widget.orderId));
    } on AppError catch (e) {
      if (mounted) _snack(e.message, AppColors.red600);
    } catch (e) {
      if (mounted) _snack(e.toString(), AppColors.red600);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
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
    final cfg = _cfg;
    final canManage = widget.canManage;
    final isOwner = widget.isOwner;
    final status = _status;

    // Determine primary + secondary buttons for this role × state
    Widget? primaryBtn;
    Widget? secondaryBtn;
    Widget? tertiaryBtn;

    if (canManage) {
      switch (status) {
        case 'PENDING':
          primaryBtn = _BigButton(
            label: 'Confirm Order',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.primaryMain,
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
          secondaryBtn = _OutlineButton(
            label: 'Cancel Order',
            color: AppColors.red600,
            onTap: _busy ? null : _confirmCancel,
          );
        case 'LOADING':
          primaryBtn = _BigButton(
            label: 'Complete Loading',
            icon: Icons.done_all_rounded,
            color: AppColors.primaryMain,
            onTap: _busy ? null : _completeLoading,
          );
          secondaryBtn = _OutlineButton(
            label: 'Cancel Order',
            color: AppColors.red600,
            onTap: _busy ? null : _confirmCancel,
          );
        case 'LOADED':
        case 'PARTIALLY_FULFILLED':
          primaryBtn = _BigButton(
            label: 'Create Dispatch',
            icon: Icons.local_shipping_rounded,
            color: AppColors.blue600,
            onTap: _busy ? null : _createDispatch,
          );
          secondaryBtn = _OutlineButton(
            label: 'Mark as Completed',
            color: AppColors.primaryMain,
            onTap: _busy ? null : _markCompleted,
          );
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
                            status.replaceAll('_', ' '),
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

    final Color statusColor;
    final Color statusBg;
    final IconData statusIcon;
    final String statusLabel;

    if (isDelivered) {
      statusColor = AppColors.primaryMain;
      statusBg = AppColors.primaryLight;
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'Delivered';
    } else if (isOnWay) {
      statusColor = AppColors.amber700;
      statusBg = AppColors.amber100;
      statusIcon = Icons.local_shipping_rounded;
      statusLabel = 'On the Way';
    } else if (d.status == 'ACCEPTED') {
      statusColor = AppColors.blue600;
      statusBg = const Color(0xFFEFF6FF);
      statusIcon = Icons.person_rounded;
      statusLabel = 'Driver Assigned';
    } else {
      statusColor = AppColors.textSecondary;
      statusBg = AppColors.slate50;
      statusIcon = Icons.schedule_rounded;
      statusLabel = d.status.replaceAll('_', ' ');
    }

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
                      Text(statusLabel,
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
                d.status.replaceAll('_', ' '),
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

// ── Items card ────────────────────────────────────────────────────────────────

class _ItemsCard extends StatefulWidget {
  final Order order;
  final NumberFormat fmt;
  const _ItemsCard({required this.order, required this.fmt});

  @override
  State<_ItemsCard> createState() => _ItemsCardState();
}

class _ItemsCardState extends State<_ItemsCard> {
  bool _expanded = false;

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
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              ...preview.asMap().entries.map((entry) => Column(
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
                                  Text(entry.value.displayName,
                                      style: AppTypography.body),
                                  if (entry.value.sizeName != null)
                                    Text(entry.value.sizeName!,
                                        style: AppTypography.caption.copyWith(
                                            color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(widget.fmt.format(entry.value.totalPrice),
                                    style: AppTypography.label),
                                Text('Qty: ${entry.value.quantity.toInt()}',
                                    style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  )),
              if (items.length > 3)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border)),
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
      ],
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/order_timeline.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dispatches/dispatches.dart';
import 'orders.dart';

class OrderDetailScreen extends ConsumerWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderDetailProvider(orderId));
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final caps = ref.watch(sessionProvider).capabilities;
    final canManage = caps.isNurseryOwner || caps.isManager;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: async.when(
          data: (o) => Text(o.orderNumber, style: AppTypography.h4),
          loading: () => const Text('Order Details'),
          error: (_, __) => const Text('Order Details'),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          async.when(
            data: (o) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: StatusBadge(
                label: o.status.replaceAll('_', ' '),
                variant: badgeVariantFromStatus(o.status),
                dot: true,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
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

  const _OrderDetailBody({
    required this.order,
    required this.orderId,
    required this.fmt,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // ── Order summary header ──────────────────────────────────────────
        _SummaryCard(order: order, fmt: fmt),

        const SizedBox(height: AppSpacing.x2l),

        // ── Timeline ─────────────────────────────────────────────────────
        _SectionCard(
          title: 'Order Timeline',
          child: OrderTimeline(order: order),
        ),

        const SizedBox(height: AppSpacing.x2l),

        // ── Buyer / Seller details ────────────────────────────────────────
        _InfoCard(order: order),

        // ── Action card ───────────────────────────────────────────────────
        if (canManage || order.status == 'PENDING') ...[
          const SizedBox(height: AppSpacing.x2l),
          _SectionCard(
            title: 'Actions',
            child: _OrderActions(order: order, orderId: orderId, canManage: canManage),
          ),
        ],

        // ── Items card ────────────────────────────────────────────────────
        if (order.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x2l),
          _ItemsCard(order: order, fmt: fmt),
        ],

        const SizedBox(height: AppSpacing.x3l),
      ],
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final Order order;
  final NumberFormat fmt;

  const _SummaryCard({required this.order, required this.fmt});

  @override
  Widget build(BuildContext context) {
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: AppColors.primaryMain, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.orderNumber, style: AppTypography.h3),
                    Text(order.orderCode,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            fmt.format(order.totalAmount),
            style: AppTypography.h2.copyWith(color: AppColors.primaryMain),
          ),
          if (order.items.isNotEmpty)
            Text(
              '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Order order;

  const _InfoCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(order.orderDate);
    final dateStr =
        date != null ? DateFormat('dd MMM yyyy').format(date.toLocal()) : '';

    final buyerLabel = order.buyerName ?? order.customerName ?? 'Unknown Buyer';
    final responsibleLabel = order.assignedManagerName != null
        ? order.assignedManagerName!
        : (order.assignedManagerUserId != null
            ? 'Manager #${order.assignedManagerUserId}'
            : 'Nursery Owner');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Buyer',
            value: buyerLabel,
          ),
          if (order.sellerNursery != null) ...[
            const Divider(height: 1, indent: 56),
            _InfoRow(
              icon: Icons.store_outlined,
              label: 'Seller',
              value: order.sellerNursery!,
            ),
          ],
          const Divider(height: 1, indent: 56),
          _InfoRow(
            icon: Icons.manage_accounts_outlined,
            label: 'Responsible',
            value: responsibleLabel,
          ),
          if (dateStr.isNotEmpty) ...[
            const Divider(height: 1, indent: 56),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Order Date',
              value: dateStr,
            ),
          ],
          if (order.notes?.isNotEmpty == true) ...[
            const Divider(height: 1, indent: 56),
            _InfoRow(
              icon: Icons.notes_outlined,
              label: 'Notes',
              value: order.notes!,
            ),
          ],
          if (order.cancelReason?.isNotEmpty == true) ...[
            const Divider(height: 1, indent: 56),
            _InfoRow(
              icon: Icons.cancel_outlined,
              label: 'Cancel Reason',
              value: order.cancelReason!,
              valueColor: AppColors.red600,
            ),
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

// ── Order action buttons ───────────────────────────────────────────────────────

class _OrderActions extends ConsumerStatefulWidget {
  final Order order;
  final int orderId;
  final bool canManage;
  const _OrderActions({required this.order, required this.orderId, required this.canManage});

  @override
  ConsumerState<_OrderActions> createState() => _OrderActionsState();
}

class _OrderActionsState extends ConsumerState<_OrderActions> {
  bool _busy = false;

  Future<void> _doAction(Future<Order> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(orderDetailProvider(widget.orderId));
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

  Future<void> _assignManager() async {
    final nurseryId = widget.order.sellerNurseryId;
    if (nurseryId == null) return;

    final repo = ref.read(orderRepositoryProvider);
    List<NurseryManager> managers;
    try {
      managers = await repo.getNurseryManagers(nurseryId);
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

    await _doAction(() => repo.assignManager(widget.orderId, selected.userId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selected.name} assigned as manager'),
          backgroundColor: AppColors.primaryMain,
        ),
      );
    }
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
      final dispatch = await ref
          .read(dispatchRepositoryProvider)
          .createDispatch(widget.orderId,
              destinationAddress: dest, notes: notes);
      if (mounted) {
        await QrShareSheet.show(
          context,
          code: dispatch.dispatchCode,
          qrType: QrCodeType.tripQr,
          shareMessage:
              'GreenRoot Trip QR — ${dispatch.dispatchCode}\n\nShare with your driver to start the trip.\nOrder: ${widget.order.orderNumber}',
        );
        if (mounted) context.push('/dispatches/${dispatch.id}');
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

  Future<void> _confirmCancel() async {
    String? reason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Cancel Order'),
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
              child: Text('Cancel Order',
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Order cancelled'),
            backgroundColor: AppColors.red600),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.order.status;
    final repo = ref.read(orderRepositoryProvider);
    final actions = <_ActionDef>[];

    if (widget.canManage) {
      // ── Owner / Manager actions ──────────────────────────────────────────
      final caps = ref.read(sessionProvider).capabilities;
      final isOwner = caps.isNurseryOwner;
      // Assign manager: owner-only, not yet completed/cancelled/loaded
      final canAssignManager = isOwner &&
          widget.order.sellerNurseryId != null &&
          !['CANCELLED', 'COMPLETED', 'LOADED', 'PARTIALLY_FULFILLED'].contains(status);

      if (status == 'PENDING') {
        actions.add(_ActionDef(
          label: 'Confirm Order',
          icon: Icons.check_circle_outline,
          color: AppColors.primaryMain,
          onTap: () async {
            await _doAction(() => repo.updateStatus(widget.orderId, 'CONFIRMED'));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order confirmed'), backgroundColor: AppColors.primaryMain),
              );
            }
          },
        ));
      }

      if (canAssignManager) {
        actions.add(_ActionDef(
          label: widget.order.assignedManagerUserId != null ? 'Re-assign Manager' : 'Assign Manager',
          icon: Icons.manage_accounts_rounded,
          color: const Color(0xFF1565C0),
          onTap: _assignManager,
        ));
      }

      if (status == 'CONFIRMED') {
        actions.add(_ActionDef(
          label: 'Start Loading',
          icon: Icons.inventory_outlined,
          color: AppColors.primaryMain,
          onTap: () async {
            await _doAction(() => repo.startLoading(widget.orderId));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Loading started'), backgroundColor: AppColors.primaryMain),
              );
            }
          },
        ));
      }

      if (status == 'LOADING') {
        actions.add(_ActionDef(
          label: 'Complete Loading',
          icon: Icons.done_all_rounded,
          color: AppColors.primaryMain,
          onTap: () async {
            await _doAction(() => repo.completeLoading(widget.orderId));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Loading completed'), backgroundColor: AppColors.primaryMain),
              );
            }
          },
        ));
      }

      if (status == 'LOADED' || status == 'PARTIALLY_FULFILLED') {
        actions.add(_ActionDef(
          label: 'Create Dispatch (Link Driver)',
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF1565C0),
          onTap: _createDispatch,
        ));
        actions.add(_ActionDef(
          label: 'Mark as Completed',
          icon: Icons.check_circle_outline,
          color: AppColors.primaryMain,
          outlined: true,
          onTap: () async {
            await _doAction(() => repo.updateStatus(widget.orderId, 'COMPLETED'));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order marked as completed'), backgroundColor: AppColors.primaryMain),
              );
            }
          },
        ));
      }

      // Cancel order: owner-only per Mobile UI plan (§7 Manager Must Never See: cancel order)
      if (isOwner && ['PENDING', 'CONFIRMED', 'LOADING'].contains(status)) {
        actions.add(_ActionDef(
          label: 'Cancel Order',
          icon: Icons.cancel_outlined,
          color: AppColors.red600,
          outlined: true,
          onTap: _confirmCancel,
        ));
      }
    } else {
      // ── Buyer: cancel own PENDING order only (test-api.sh confirms buyer cancel PENDING → 200)
      if (status == 'PENDING') {
        actions.add(_ActionDef(
          label: 'Cancel Order',
          icon: Icons.cancel_outlined,
          color: AppColors.red600,
          outlined: true,
          onTap: _confirmCancel,
        ));
      }
    }

    if (actions.isEmpty) {
      return Text(
        status == 'CANCELLED'
            ? 'This order has been cancelled.'
            : status == 'COMPLETED'
                ? 'Order completed.'
                : 'No actions available.',
        style: AppTypography.body.copyWith(color: AppColors.textMuted),
      );
    }

    return Column(
      children: [
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SizedBox(
              width: double.infinity,
              child: action.outlined
                  ? OutlinedButton.icon(
                      onPressed: _busy ? null : action.onTap,
                      icon: _busy
                          ? SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: action.color))
                          : Icon(action.icon),
                      label: Text(action.label),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: action.color,
                        side: BorderSide(color: action.color),
                        minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _busy ? null : action.onTap,
                      icon: _busy
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(action.icon),
                      label: Text(action.label),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: action.color,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

class _ActionDef {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _ActionDef({
    required this.label,
    required this.icon,
    required this.color,
    this.outlined = false,
    required this.onTap,
  });
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
            ...managers.map((m) => Padding(
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
                                m.name.isNotEmpty
                                    ? m.name[0].toUpperCase()
                                    : 'M',
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
                                Text(m.mobile,
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
                )),
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
                borderRadius: BorderRadius.circular(2),
              ),
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

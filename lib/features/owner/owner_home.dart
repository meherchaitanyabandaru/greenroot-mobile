// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — OWNER HOME SECTION                                              ║
// ║  Role:  NURSERY_OWNER                                                        ║
// ║  Guard: rendered only when caps.isNurseryOwner == true                       ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/main_shell.dart';
import '../../core/domain/lifecycle_presenter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dispatches/dispatches.dart';
import '../orders/orders.dart';
import '../quotations/quotations.dart';
import 'nursery_setup_prompt.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

final ownerHomeProvider =
    FutureProvider.autoDispose<_OwnerHomeData>((ref) async {
  final orderRepo = ref.watch(orderRepositoryProvider);
  final dispatchRepo = ref.watch(dispatchRepositoryProvider);
  final quotationRepo = ref.watch(quotationRepositoryProvider);
  var orders = <Order>[];
  var dispatches = <Dispatch>[];
  var pendingQuotations = <Quotation>[];
  try {
    final (items, _) = await orderRepo.listOrders(page: 1, perPage: 30);
    orders = items;
  } catch (_) {}
  try {
    final (items, _) = await dispatchRepo.listDispatches(page: 1, perPage: 50);
    dispatches = items;
  } catch (_) {}
  try {
    final (items, _) = await quotationRepo.listQuotations(page: 1, perPage: 10);
    pendingQuotations = items
        .where((q) => q.status == 'DRAFT' || q.status == 'CUSTOMER_ACCEPTED')
        .toList();
  } catch (_) {}
  return _OwnerHomeData(
    orders: orders,
    dispatches: dispatches,
    pendingQuotations: pendingQuotations,
  );
});

class _OwnerHomeData {
  final List<Order> orders;
  final List<Dispatch> dispatches;
  final List<Quotation> pendingQuotations;

  const _OwnerHomeData({
    required this.orders,
    this.dispatches = const [],
    required this.pendingQuotations,
  });

  List<Order> get activeOrders => orders
      .where(
          (o) => !{'COMPLETED', 'CANCELLED'}.contains(o.status.toUpperCase()))
      .toList();

  int get completedCount =>
      orders.where((o) => o.status.toUpperCase() == 'COMPLETED').length;

  int get pendingCount =>
      orders.where((o) => o.status.toUpperCase() == 'PENDING').length;

  Dispatch? dispatchForOrder(int orderId) =>
      LifecyclePresenter.activeDispatchForOrder(dispatches, orderId);
}

// ── Root widget ───────────────────────────────────────────────────────────────

class OwnerHome extends ConsumerWidget {
  const OwnerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NurserySetupPrompt(),
        _OwnerActionGrid(
          onConnections: () => context.push('/connections'),
        ),
      ],
    );
  }
}

// ── KPI summary row ───────────────────────────────────────────────────────────

class _OwnerSummaryRow extends StatelessWidget {
  final int totalCount;
  final int activeCount;
  final int pendingCount;
  final VoidCallback onTap;

  const _OwnerSummaryRow({
    required this.totalCount,
    required this.activeCount,
    required this.pendingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _KpiCell(
            icon: Icons.receipt_long_outlined,
            value: '$totalCount',
            label: 'Total',
            color: AppColors.primaryMain,
            onTap: onTap,
          ),
          const SizedBox(
            height: 80,
            child: VerticalDivider(width: 1, color: AppColors.border),
          ),
          _KpiCell(
            icon: Icons.pending_outlined,
            value: '$activeCount',
            label: 'Active',
            color: AppColors.blue600,
            onTap: onTap,
          ),
          const SizedBox(
            height: 80,
            child: VerticalDivider(width: 1, color: AppColors.border),
          ),
          _KpiCell(
            icon: Icons.hourglass_top_rounded,
            value: '$pendingCount',
            label: 'Pending',
            color: AppColors.amber600,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _KpiCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _KpiCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(
                value,
                style: AppTypography.h2.copyWith(color: color, height: 1),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTypography.h3)),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: AppColors.primaryMain,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: AppColors.primaryMain,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _OwnerOrderCard extends StatelessWidget {
  final Order order;
  final Dispatch? dispatch;
  final VoidCallback onTap;

  const _OwnerOrderCard({
    required this.order,
    required this.onTap,
    this.dispatch,
  });

  @override
  Widget build(BuildContext context) {
    final display = LifecyclePresenter.forOrder(
      order: order,
      dispatch: dispatch,
      role: LifecycleRole.operator,
    );
    final fmt = NumberFormat('#,##0.00');

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primaryMain,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    order.customerName ?? order.buyerName ?? 'Customer',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: display.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    display.label,
                    style: AppTypography.caption.copyWith(
                      color: display.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '₹${fmt.format(order.totalAmount)}',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quotation alert card ──────────────────────────────────────────────────────

class _QuotationAlertCard extends StatelessWidget {
  final Quotation quotation;
  final VoidCallback onTap;

  const _QuotationAlertCard({required this.quotation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDraft = quotation.status == 'DRAFT';
    final color = isDraft ? AppColors.amber600 : AppColors.blue600;
    final bg = isDraft ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD);
    final actionLabel = isDraft ? 'Approve & Send' : 'Convert to Order';

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(accent: bg.withValues(alpha: 0.4)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDraft ? Icons.description_outlined : Icons.task_alt_rounded,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quotation.quotationCode,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    quotation.recipientName ?? 'Customer',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                actionLabel,
                style: AppTypography.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick-action grid ─────────────────────────────────────────────────────────

class _OwnerActionGrid extends StatelessWidget {
  final VoidCallback onConnections;

  const _OwnerActionGrid({required this.onConnections});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCell(
            icon: Icons.people_outline_rounded,
            label: 'People',
            color: AppColors.amber600,
            onTap: onConnections,
          ),
        ),
      ],
    );
  }
}

class _ActionCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCell({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyOwnerState extends StatelessWidget {
  final VoidCallback onAddOrder;

  const _EmptyOwnerState({required this.onAddOrder});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: _cardDecoration(accent: AppColors.forest50),
      child: Column(
        children: [
          const Icon(Icons.storefront_rounded,
              size: 54, color: AppColors.primaryMain),
          const SizedBox(height: 16),
          Text(
            'Ready to take orders',
            style: AppTypography.h3.copyWith(color: AppColors.primaryMain),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Invite customers or create a quotation to get started.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAddOrder,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Go to Selling'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

BoxDecoration _cardDecoration({Color? accent}) => BoxDecoration(
      color: accent ?? AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );

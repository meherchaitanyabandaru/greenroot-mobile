// Shared action buttons for seller order cards.
// Used by owner_tab.dart and manager_work_tab.dart to avoid duplicate logic.
//
// RBAC cancel matrix (BUSINESS_RULES.md §Order Cancel Rules):
//   PENDING:   owner + manager + buyer (own)
//   CONFIRMED: owner + manager
//   LOADING:   owner + manager
//   LOADED/PARTIALLY_FULFILLED/COMPLETED: BLOCKED
//
// Both owner and manager share the same cancel permissions on the card.
// The API enforces the actual guard — UI just matches the spec.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../features/orders/orders.dart';
import '../domain/workflow.dart';

class SellerOrderCardActions extends ConsumerStatefulWidget {
  final Order order;

  /// Called after any successful action with the updated order.
  /// Caller uses this to update their local list state.
  final void Function(Order updated) onUpdated;

  const SellerOrderCardActions({
    super.key,
    required this.order,
    required this.onUpdated,
  });

  @override
  ConsumerState<SellerOrderCardActions> createState() =>
      _SellerOrderCardActionsState();
}

class _SellerOrderCardActionsState
    extends ConsumerState<SellerOrderCardActions> {
  bool _acting = false;

  Order get _order => widget.order;

  // Per BUSINESS_RULES.md: seller can cancel PENDING, CONFIRMED, LOADING
  bool get _canConfirm => _order.status == 'PENDING';
  bool get _canStartLoading => _order.status == 'CONFIRMED';
  bool get _canCancel => OrderWorkflow.canSellerCancel(_order.status);

  bool get _hasAnyAction => _canConfirm || _canStartLoading || _canCancel;

  Future<void> _confirm() async {
    setState(() => _acting = true);
    try {
      final updated = await ref
          .read(orderRepositoryProvider)
          .confirmOrder(_order.id);
      widget.onUpdated(updated);
      if (mounted) _snack('Order confirmed', AppColors.primaryMain);
    } catch (e) {
      if (mounted) _snack(_msg(e), AppColors.red600);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _startLoading() async {
    setState(() => _acting = true);
    try {
      final updated = await ref
          .read(orderRepositoryProvider)
          .startLoading(_order.id);
      widget.onUpdated(updated);
      if (mounted) {
        _snack('Loading started', AppColors.blue600);
        context.push('/orders/${_order.id}');
      }
    } catch (e) {
      if (mounted) _snack(_msg(e), AppColors.red600);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order', style: AppTypography.h3),
        content: Text(
          'Cancel ${_order.orderNumber}? This cannot be undone.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancel Order',
              style: TextStyle(color: AppColors.red600),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _acting = true);
    try {
      final updated = await ref
          .read(orderRepositoryProvider)
          .cancelOrder(_order.id);
      widget.onUpdated(updated);
      if (mounted) _snack('Order cancelled', AppColors.slate700);
    } catch (e) {
      if (mounted) _snack(_msg(e), AppColors.red600);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  String _msg(Object e) =>
      e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();

  @override
  Widget build(BuildContext context) {
    if (!_hasAnyAction) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: AppSpacing.md),
        _acting
            ? const Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Row(
                children: [
                  if (_canCancel)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red600,
                          side: const BorderSide(color: AppColors.red600),
                          minimumSize:
                              const Size.fromHeight(AppSpacing.buttonHeightSm),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  if (_canCancel && (_canConfirm || _canStartLoading))
                    const SizedBox(width: AppSpacing.sm),
                  if (_canConfirm)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryMain,
                          foregroundColor: Colors.white,
                          minimumSize:
                              const Size.fromHeight(AppSpacing.buttonHeightSm),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Confirm'),
                      ),
                    ),
                  if (_canStartLoading)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _startLoading,
                        icon: const Icon(Icons.inventory_2_outlined, size: 16),
                        label: const Text('Start Loading'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue600,
                          foregroundColor: Colors.white,
                          minimumSize:
                              const Size.fromHeight(AppSpacing.buttonHeightSm),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                ],
              ),
      ],
    );
  }
}

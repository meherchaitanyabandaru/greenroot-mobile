import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_badge.dart';
import 'orders.dart';

class OrderDetailScreen extends ConsumerWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderDetailProvider(orderId));
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Order Details'),
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
              const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              Text(err.toString(), style: AppTypography.body),
              TextButton(
                onPressed: () => ref.refresh(orderDetailProvider(orderId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (order) {
          final date = DateTime.tryParse(order.orderDate);
          final dateStr = date != null
              ? DateFormat('dd MMM yyyy').format(date.toLocal())
              : '';

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
                        StatusBadge(
                          label: order.status,
                          variant: badgeVariantFromStatus(order.status),
                          dot: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      fmt.format(order.totalAmount),
                      style: AppTypography.h2
                          .copyWith(color: AppColors.primaryMain),
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
                    if (order.buyerName != null)
                      _Row(label: 'Buyer', value: order.buyerName!),
                    if (order.sellerNursery != null) ...[
                      if (order.buyerName != null)
                        const Divider(height: 1, indent: 16),
                      _Row(label: 'Seller', value: order.sellerNursery!),
                    ],
                    if (dateStr.isNotEmpty) ...[
                      const Divider(height: 1, indent: 16),
                      _Row(label: 'Order Date', value: dateStr),
                    ],
                    if (order.notes != null) ...[
                      const Divider(height: 1, indent: 16),
                      _Row(label: 'Notes', value: order.notes!),
                    ],
                  ],
                ),
              ),

              if (order.items.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x2l),
                Text('Items (${order.items.length})', style: AppTypography.h4),
                const SizedBox(height: AppSpacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: order.items
                        .asMap()
                        .entries
                        .map((entry) => Column(
                              children: [
                                if (entry.key > 0)
                                  const Divider(height: 1, indent: 16),
                                Padding(
                                  padding: const EdgeInsets.all(
                                      AppSpacing.cardPadding),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(entry.value.displayName,
                                                style: AppTypography.body),
                                            if (entry.value.sizeName != null)
                                              Text(entry.value.sizeName!,
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                          color: AppColors
                                                              .textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            fmt.format(entry.value.totalPrice),
                                            style: AppTypography.label,
                                          ),
                                          Text(
                                            'Qty: ${entry.value.quantity.toInt()}',
                                            style: AppTypography.caption.copyWith(
                                                color: AppColors.textSecondary),
                                          ),
                                        ],
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

              const SizedBox(height: AppSpacing.x3l),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding, vertical: AppSpacing.md),
      child: Row(
        children: [
          Text(label,
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: AppTypography.label,
                textAlign: TextAlign.right,
                maxLines: 2),
          ),
        ],
      ),
    );
  }
}

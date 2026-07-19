import 'package:flutter/material.dart';
import '../domain/lifecycle_presenter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

// Shared status chip for quotations, orders, and dispatches.
// Centralises all colour/label mappings so they stay in sync across roles.

enum TradeChipKind { quotation, order, dispatch }

class TradeStatusChip extends StatelessWidget {
  final String status;
  final TradeChipKind kind;
  const TradeStatusChip({super.key, required this.status, required this.kind});

  @override
  Widget build(BuildContext context) {
    final chip = switch (kind) {
      TradeChipKind.quotation => quotationChipData(status),
      TradeChipKind.order => orderChipData(status),
      TradeChipKind.dispatch => dispatchChipData(status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chip.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        chip.label,
        style: AppTypography.caption
            .copyWith(color: chip.text, fontWeight: FontWeight.w700),
      ),
    );
  }
}

typedef ChipData = ({Color bg, Color text, String label});

ChipData orderChipData(String status) {
  final display = LifecyclePresenter.forOrderStatus(status);
  return (
    bg: display.color.withValues(alpha: 0.12),
    text: display.color,
    label: display.label,
  );
}

ChipData quotationChipData(String status) => switch (status.toUpperCase()) {
      'DRAFT' => (
          bg: AppColors.slate100,
          text: AppColors.slate700,
          label: 'Draft'
        ),
      'APPROVED' => (
          bg: const Color(0xFFE3F2FD),
          text: AppColors.blue600,
          label: 'Approved'
        ),
      'SENT' || 'CUSTOMER_SENT' => (
          bg: const Color(0xFFE8F5E9),
          text: AppColors.primaryMain,
          label: 'Sent'
        ),
      'CUSTOMER_ACCEPTED' => (
          bg: const Color(0xFFE8F5E9),
          text: const Color(0xFF2E7D32),
          label: 'Accepted'
        ),
      'CUSTOMER_REJECTED' => (
          bg: const Color(0xFFFCE4EC),
          text: const Color(0xFFB71C1C),
          label: 'Rejected'
        ),
      'CONVERTED' => (
          bg: const Color(0xFFE8F5E9),
          text: const Color(0xFF2E7D32),
          label: 'Converted'
        ),
      'EXPIRED' => (
          bg: AppColors.border,
          text: AppColors.textSecondary,
          label: 'Expired'
        ),
      _ => (
          bg: AppColors.border,
          text: AppColors.textSecondary,
          label: chipPretty(status)
        ),
    };

ChipData dispatchChipData(String status) {
  final display = LifecyclePresenter.forDispatchStatus(status);
  return (
    bg: display.color.withValues(alpha: 0.12),
    text: display.color,
    label: display.label,
  );
}

String chipPretty(String s) => s
    .toLowerCase()
    .split('_')
    .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

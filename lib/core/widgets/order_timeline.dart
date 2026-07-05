import 'package:flutter/material.dart';
import '../domain/workflow.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../features/orders/orders.dart';

export '../domain/workflow.dart' show OrderTimelineRole;

/// Role-aware order lifecycle timeline.
///
/// Buyer gets a 5-step customer view (no internal operational states).
/// Seller/Manager gets the full operational 5-step view with timestamps and attribution.
///
/// Steps and labels come from [OrderWorkflow] — never hardcoded here.
class OrderTimeline extends StatelessWidget {
  final Order order;
  final OrderTimelineRole role;

  const OrderTimeline({
    super.key,
    required this.order,
    this.role = OrderTimelineRole.seller,
  });

  @override
  Widget build(BuildContext context) {
    final steps = OrderWorkflow.stepsFor(order, role);
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          _TimelineRow(step: steps[i], isLast: i == steps.length - 1),
      ],
    );
  }
}

// ── Visual row ────────────────────────────────────────────────────────────────

class _TimelineRow extends StatelessWidget {
  final WorkflowStep step;
  final bool isLast;

  const _TimelineRow({required this.step, required this.isLast});

  Color get _dotBg {
    switch (step.state) {
      case WorkflowStepState.completed:
        return AppColors.primaryMain;
      case WorkflowStepState.current:
        return AppColors.primaryLight;
      case WorkflowStepState.pending:
        return AppColors.border.withValues(alpha: 0.4);
      case WorkflowStepState.cancelled:
        return AppColors.red600;
    }
  }

  Color get _dotIconColor {
    switch (step.state) {
      case WorkflowStepState.completed:
        return Colors.white;
      case WorkflowStepState.current:
        return AppColors.primaryMain;
      case WorkflowStepState.pending:
        return AppColors.textMuted;
      case WorkflowStepState.cancelled:
        return Colors.white;
    }
  }

  Border? get _dotBorder {
    if (step.state == WorkflowStepState.current) {
      return Border.all(color: AppColors.primaryMain, width: 2);
    }
    return null;
  }

  IconData get _dotIcon {
    if (step.state == WorkflowStepState.completed) return Icons.check_rounded;
    if (step.state == WorkflowStepState.cancelled) return Icons.close_rounded;
    return step.icon;
  }

  Color get _lineColor {
    return step.state == WorkflowStepState.completed
        ? AppColors.primaryMain.withValues(alpha: 0.35)
        : AppColors.border.withValues(alpha: 0.4);
  }

  TextStyle get _titleStyle {
    switch (step.state) {
      case WorkflowStepState.pending:
        return AppTypography.label.copyWith(color: AppColors.textMuted);
      case WorkflowStepState.cancelled:
        return AppTypography.label.copyWith(color: AppColors.red600);
      case WorkflowStepState.current:
        return AppTypography.label
            .copyWith(color: AppColors.primaryMain, fontWeight: FontWeight.w700);
      case WorkflowStepState.completed:
        return AppTypography.label.copyWith(color: AppColors.textPrimary);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _dotBg,
                  shape: BoxShape.circle,
                  border: _dotBorder,
                ),
                child: Icon(_dotIcon, color: _dotIconColor, size: 15),
              ),
              if (!isLast)
                Container(width: 2, height: 32, color: _lineColor),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: 5,
              bottom: isLast ? 0 : AppSpacing.x2l,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: _titleStyle),
                if (step.subtitle?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle!,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

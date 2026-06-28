import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../features/orders/orders.dart';

enum _StepState { completed, current, pending, cancelled }

class _Step {
  final String title;
  final String? subtitle;
  final _StepState state;
  final IconData icon;

  const _Step({
    required this.title,
    this.subtitle,
    required this.state,
    required this.icon,
  });
}

class OrderTimeline extends StatelessWidget {
  final Order order;

  const OrderTimeline({super.key, required this.order});

  static String _fmt(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('dd MMM, h:mm a').format(dt.toLocal());
  }

  List<_Step> _buildSteps() {
    final s = order.status;
    final cancelled = s == 'CANCELLED';
    final isLoaded = s == 'LOADED' || s == 'PARTIALLY_FULFILLED';
    final isCompleted = s == 'COMPLETED';
    final pastLoadingStarted = !cancelled && !['PENDING', 'CONFIRMED'].contains(s);
    final pastLoadingCompleted = !cancelled && (isLoaded || isCompleted);

    final steps = <_Step>[
      // 1. Order Created
      _Step(
        title: 'Order Created',
        subtitle: _fmt(order.createdAt ?? order.orderDate),
        state: _StepState.completed,
        icon: Icons.receipt_long_rounded,
      ),

      // 2. Confirmed
      _Step(
        title: 'Order Confirmed',
        subtitle: s == 'PENDING'
            ? 'Awaiting confirmation'
            : (order.assignedManagerUserId != null
                ? 'Manager assigned'
                : 'Owner handling'),
        state: cancelled
            ? _StepState.pending
            : (s == 'PENDING' ? _StepState.current : _StepState.completed),
        icon: Icons.verified_user_outlined,
      ),

      // 3. Loading Started
      _Step(
        title: 'Loading Started',
        subtitle: order.loadingStartedAt != null
            ? _fmt(order.loadingStartedAt)
            : (s == 'CONFIRMED' ? 'Awaiting loading start' : null),
        state: cancelled
            ? _StepState.pending
            : (s == 'LOADING'
                ? _StepState.current
                : (pastLoadingStarted ? _StepState.completed : _StepState.pending)),
        icon: Icons.inventory_2_outlined,
      ),

      // 4. Loading Completed
      _Step(
        title: s == 'PARTIALLY_FULFILLED' ? 'Partially Loaded' : 'Loading Completed',
        subtitle: s == 'PARTIALLY_FULFILLED'
            ? 'Some items had reduced quantities'
            : (order.loadingCompletedAt != null
                ? _fmt(order.loadingCompletedAt)
                : (s == 'LOADING' ? 'In progress' : null)),
        state: cancelled
            ? _StepState.pending
            : (!pastLoadingCompleted
                ? _StepState.pending
                : (isLoaded ? _StepState.current : _StepState.completed)),
        icon: Icons.done_all_rounded,
      ),

      // 5. Dispatched
      _Step(
        title: 'Dispatched',
        subtitle: isLoaded
            ? 'Ready — create dispatch from Actions'
            : (isCompleted ? 'Sent to buyer' : null),
        state: cancelled
            ? _StepState.pending
            : (isCompleted ? _StepState.completed : _StepState.pending),
        icon: Icons.local_shipping_rounded,
      ),

      // 6. Delivered
      _Step(
        title: 'Delivered',
        subtitle: null,
        state: isCompleted ? _StepState.completed : _StepState.pending,
        icon: Icons.check_circle_rounded,
      ),
    ];

    if (cancelled) {
      steps.add(_Step(
        title: 'Cancelled',
        subtitle: order.cancelledAt != null
            ? _fmt(order.cancelledAt)
            : (order.cancelReason?.isNotEmpty == true ? order.cancelReason : null),
        state: _StepState.cancelled,
        icon: Icons.cancel_rounded,
      ));
    }

    return steps;
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          _TimelineRow(step: steps[i], isLast: i == steps.length - 1),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _Step step;
  final bool isLast;

  const _TimelineRow({required this.step, required this.isLast});

  Color get _dotBg {
    switch (step.state) {
      case _StepState.completed:
        return AppColors.primaryMain;
      case _StepState.current:
        return AppColors.primaryLight;
      case _StepState.pending:
        return AppColors.border.withValues(alpha: 0.4);
      case _StepState.cancelled:
        return AppColors.red600;
    }
  }

  Color get _dotIconColor {
    switch (step.state) {
      case _StepState.completed:
        return Colors.white;
      case _StepState.current:
        return AppColors.primaryMain;
      case _StepState.pending:
        return AppColors.textMuted;
      case _StepState.cancelled:
        return Colors.white;
    }
  }

  Border? get _dotBorder {
    if (step.state == _StepState.current) {
      return Border.all(color: AppColors.primaryMain, width: 2);
    }
    return null;
  }

  IconData get _dotIcon {
    if (step.state == _StepState.completed) return Icons.check_rounded;
    if (step.state == _StepState.cancelled) return Icons.close_rounded;
    return step.icon;
  }

  Color get _lineColor {
    return step.state == _StepState.completed
        ? AppColors.primaryMain.withValues(alpha: 0.35)
        : AppColors.border.withValues(alpha: 0.4);
  }

  TextStyle get _titleStyle {
    if (step.state == _StepState.pending) {
      return AppTypography.label.copyWith(color: AppColors.textMuted);
    }
    if (step.state == _StepState.cancelled) {
      return AppTypography.label.copyWith(color: AppColors.red600);
    }
    if (step.state == _StepState.current) {
      return AppTypography.label
          .copyWith(color: AppColors.primaryMain, fontWeight: FontWeight.w700);
    }
    return AppTypography.label.copyWith(color: AppColors.textPrimary);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon column with connecting line
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
                Container(
                  width: 2,
                  height: 32,
                  color: _lineColor,
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // Content
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

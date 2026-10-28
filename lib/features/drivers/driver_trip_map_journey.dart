part of 'driver_trip_map_screen.dart';

class _OrderJourneyCard extends StatelessWidget {
  final Dispatch trip;
  final bool expanded;
  final VoidCallback onToggle;

  const _OrderJourneyCard({
    required this.trip,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: onToggle,
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : AppRadius.cardRadius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.forest100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.route_rounded,
                        color: AppColors.primaryMain, size: 18,),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Order Journey', style: AppTypography.h4),
                        Text(
                          'All steps of this order',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Timeline (visible when expanded)
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm,),
              child: _JourneyTimeline(trip: trip),
            ),
            // Hide button
            InkWell(
              onTap: onToggle,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Hide Journey',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.primaryMain,
                          fontWeight: FontWeight.w600,),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_up_rounded,
                        color: AppColors.primaryMain, size: 16,),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Journey timeline ───────────────────────────────────────────────────────────

enum _StepState { completed, active, pending }

class _Step {
  final int number;
  final String title;
  final String subtitle;
  final _StepState state;
  final String? time;

  const _Step({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.state,
    this.time,
  });
}

class _JourneyTimeline extends StatelessWidget {
  final Dispatch trip;

  const _JourneyTimeline({required this.trip});

  // The four things that happen, in order, each with when it was recorded.
  List<_Step> _buildSteps() {
    final s = trip.status.toUpperCase();
    final completedUpTo = switch (s) {
      'PENDING' => 2,
      'ACCEPTED' || 'DISPATCHED' || 'IN_TRANSIT' => 3,
      'DELIVERED' => 5,
      _ => 2,
    };
    final activeStep = switch (s) {
      'PENDING' => 3,
      'ACCEPTED' || 'DISPATCHED' || 'IN_TRANSIT' => 4,
      _ => 0,
    };
    final onWay = {'DISPATCHED', 'IN_TRANSIT', 'DELIVERED'}.contains(s);
    final definitions = [
      (1, 'Loading Started', 'The nursery started loading', trip.loadingStartedAt),
      (2, 'Loading Completed', 'Plants loaded at the nursery', trip.loadingCompletedAt),
      (3, 'Trip Accepted', 'You accepted this trip', trip.driverAcceptedAt),
      (4, 'On the Way', onWay ? 'You are on the way to the customer' : 'Tap Start Journey when you leave',
          onWay ? trip.tripStartedAt ?? trip.dispatchDate : null),
      (5, 'Delivered', 'The customer confirmed the delivery', trip.deliveryDate),
    ];

    return definitions.map((d) {
      final (num, title, sub, at) = d;
      final state = num <= completedUpTo
          ? _StepState.completed
          : num == activeStep
              ? _StepState.active
              : _StepState.pending;
      final time = stepTime(at);
      return _Step(
        number: num,
        title: title,
        subtitle: sub,
        state: state,
        time: time.isEmpty ? null : time,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    return Column(
      children: steps.asMap().entries.map((e) {
        final isLast = e.key == steps.length - 1;
        return _StepRow(step: e.value, isLast: isLast);
      }).toList(),
    );
  }
}

class _StepRow extends StatelessWidget {
  final _Step step;
  final bool isLast;

  const _StepRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final (circleBg, circleText, labelColor) = switch (step.state) {
      _StepState.completed => (
          AppColors.primaryMain,
          Colors.white,
          AppColors.textPrimary
        ),
      _StepState.active => (AppColors.blue600, Colors.white, AppColors.blue600),
      _StepState.pending => (
          AppColors.border,
          AppColors.textMuted,
          AppColors.textMuted
        ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circle + connector line column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Number circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: circleBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: step.state == _StepState.completed
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14,)
                        : Text(
                            '${step.number}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: circleText,
                              fontFamily: 'Inter',
                            ),
                          ),
                  ),
                ),
                // Connector line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: step.state == _StepState.completed
                          ? AppColors.primaryMain
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Text + timestamp
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          step.title,
                          style: AppTypography.body.copyWith(
                            fontWeight: step.state == _StepState.active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: labelColor,
                          ),
                        ),
                        Text(
                          step.subtitle,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      (step.time ?? '').replaceFirst(' · ', '\n'),
                      textAlign: TextAlign.right,
                      style: AppTypography.caption.copyWith(
                        color: step.state != _StepState.pending
                            ? AppColors.textSecondary
                            : AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  // Expand chevron (decorative, for future use)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.border,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plants card (collapsible) ──────────────────────────────────────────────────

class _PlantsCard extends StatelessWidget {
  final List<DispatchItem> items;
  final bool expanded;
  final VoidCallback onToggle;

  const _PlantsCard({
    required this.items,
    required this.expanded,
    required this.onToggle,
  });

  int get _totalQty => items.fold(0, (sum, i) => sum + i.quantity.toInt());

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : AppRadius.cardRadius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.forest100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.eco_rounded,
                        color: AppColors.primaryMain, size: 18,),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plants to Deliver (${items.length})',
                          style: AppTypography.h4,
                        ),
                        Text(
                          'Total Qty: $_totalQty',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            ...items.asMap().entries.map((e) {
              final isFirst = e.key == 0;
              return Column(
                children: [
                  if (!isFirst) const Divider(height: 1, indent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.cardPadding,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.forest100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.spa_rounded,
                              color: AppColors.primaryMain, size: 16,),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            e.value.plantName ?? 'Plant ${e.key + 1}',
                            style: AppTypography.body,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4,),
                          decoration: BoxDecoration(
                            color: AppColors.forest100,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Qty ${e.value.quantity.toInt()}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryMain,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

// ── Sticky bottom action bar ───────────────────────────────────────────────────

part of 'driver_home_screen.dart';

class _ActiveTripCard extends ConsumerStatefulWidget {
  final Dispatch trip;
  const _ActiveTripCard({required this.trip});

  @override
  ConsumerState<_ActiveTripCard> createState() => _ActiveTripCardState();
}

class _ActiveTripCardState extends ConsumerState<_ActiveTripCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final display = LifecyclePresenter.forDispatch(
      dispatch: trip,
      role: LifecycleRole.driver,
    );
    final assignedAt = DateTime.tryParse(trip.createdAt)?.toLocal();
    final assignedLabel = assignedAt != null
        ? DateFormat('dd MMM, hh:mm a').format(assignedAt)
        : null;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryMain, AppColors.primaryHover],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.cardRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryMain.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping_rounded,
                    color: Colors.white, size: 18,),
                const SizedBox(width: 6),
                Text(
                  'Active Trip',
                  style: AppTypography.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.8)),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Opacity(
                    opacity: _pulseAnim.value,
                    child: StatusBadge(
                      label: display.label,
                      variant: display.variant,
                      dot: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              trip.dispatchCode,
              style: AppTypography.h2.copyWith(
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
            if (assignedLabel != null)
              Text(
                'Assigned $assignedLabel',
                style: AppTypography.caption
                    .copyWith(color: Colors.white.withValues(alpha: 0.65)),
              ),
            const SizedBox(height: AppSpacing.md),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: AppSpacing.md),
            _TripInfoRow(
              icon: Icons.location_on_rounded,
              label: 'Deliver to',
              value: trip.destinationAddress ?? 'See trip details',
            ),
            if (trip.items.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _TripInfoRow(
                icon: Icons.inventory_2_outlined,
                label: 'Plants',
                value:
                    '${trip.items.length} item type${trip.items.length != 1 ? 's' : ''}',
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: NextActionPulse(child: ElevatedButton.icon(
                onPressed: () => context.push('/driver/trip/${trip.id}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryMain,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonRadius,
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Continue Trip'),
              ),),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _TripInfoRow(
      {required this.icon, required this.label, required this.value,});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTypography.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.6)),),
              Text(value,
                  style: AppTypography.label.copyWith(color: Colors.white),),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Active trip secondary actions ──────────────────────────────────────────────

class _ActiveTripActions extends ConsumerWidget {
  final Dispatch trip;
  const _ActiveTripActions({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.add_circle_outline_rounded,
            label: 'Add Event',
            color: AppColors.blue600,
            onTap: () => context.push('/driver/trips/${trip.id}/event'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionTile(
            icon: Icons.photo_camera_outlined,
            label: 'Upload Proof',
            color: AppColors.amber600,
            onTap: () => context.push('/driver/trips/${trip.id}/proof'),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Active trip tip ────────────────────────────────────────────────────────────

class _ActiveTripTip extends StatelessWidget {
  const _ActiveTripTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.forest100,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: AppColors.primaryMain,),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Complete your current delivery before accepting another trip.',
              style:
                  AppTypography.caption.copyWith(color: AppColors.primaryMain),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading skeleton ───────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatefulWidget {
  const _DashboardSkeleton();

  @override
  State<_DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<_DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              SizedBox(height: AppSpacing.sm),
              _Bone(height: 340, radius: 16),
              SizedBox(height: AppSpacing.md),
              _Bone(height: 80, radius: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  final double height;
  final double radius;
  const _Bone({required this.height, required this.radius});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

// ── Offline / error state ──────────────────────────────────────────────────────

class _OfflineState extends StatelessWidget {
  final VoidCallback onRetry;
  const _OfflineState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off_outlined,
            size: 64, color: AppColors.textMuted,),
        const SizedBox(height: AppSpacing.x2l),
        const Text('Unable to connect',
            style: AppTypography.h3, textAlign: TextAlign.center,),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Check your internet connection and try again.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.x2l),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.primaryMain),
          ),
        ),
      ],
    );
  }
}

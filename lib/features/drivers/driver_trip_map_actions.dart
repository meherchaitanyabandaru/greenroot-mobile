part of 'driver_trip_map_screen.dart';

class _BottomActionBar extends StatelessWidget {
  final String status;
  final bool busy;
  final String? destinationAddress;
  final VoidCallback onAccept;
  final VoidCallback onRefresh;
  final VoidCallback onNavigate;
  final VoidCallback onStartJourney;
  final VoidCallback onAddEvent;
  final VoidCallback onUploadProof;
  final VoidCallback onCompleteDelivery;

  const _BottomActionBar({
    required this.status,
    required this.busy,
    required this.destinationAddress,
    required this.onAccept,
    required this.onRefresh,
    required this.onNavigate,
    required this.onStartJourney,
    required this.onAddEvent,
    required this.onUploadProof,
    required this.onCompleteDelivery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding, 12, AppSpacing.screenPadding, 12,),
          child: _buildButtons(context),
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    switch (status) {
      case 'PENDING':
        return _PrimaryBtn(
          icon: Icons.check_circle_outline_rounded,
          label: 'Accept Trip',
          busy: busy,
          onPressed: onAccept,
        );

      case 'ACCEPTED':
      case 'DISPATCHED':
        return Row(
          children: [
            _OutlineIconBtn(
              icon: Icons.map_rounded,
              label: 'Maps',
              onPressed: destinationAddress != null ? onNavigate : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: _PrimaryBtn(
                icon: Icons.play_arrow_rounded,
                label: 'Start Journey',
                busy: busy,
                onPressed: onStartJourney,
              ),
            ),
          ],
        );

      case 'IN_TRANSIT':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _OutlineIconBtn(
                  icon: Icons.navigation_rounded,
                  label: 'Navigate',
                  onPressed: destinationAddress != null ? onNavigate : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                _OutlineIconBtn(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Add Event',
                  onPressed: onAddEvent,
                  color: AppColors.blue600,
                ),
                const SizedBox(width: AppSpacing.sm),
                _OutlineIconBtn(
                  icon: Icons.photo_camera_outlined,
                  label: 'Upload Proof',
                  onPressed: onUploadProof,
                  color: AppColors.amber600,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _PrimaryBtn(
              icon: Icons.where_to_vote_rounded,
              label: 'Complete Delivery',
              busy: busy,
              onPressed: onCompleteDelivery,
            ),
          ],
        );

      case 'DELIVERED':
        return SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight,
          child: FilledButton.icon(
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryMain.withValues(alpha: 0.15),
              disabledBackgroundColor: AppColors.forest100,
              disabledForegroundColor: AppColors.primaryMain,
              shape:
                  const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
            ),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Trip Completed', style: AppTypography.buttonLabel),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Button helpers ─────────────────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const _PrimaryBtn({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryMain,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
        ),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white,),
              )
            : Icon(icon),
        label: Text(label, style: AppTypography.buttonLabel),
      ),
    );
  }
}

class _OutlineIconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const _OutlineIconBtn({
    required this.icon,
    required this.label,
    this.onPressed,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: AppSpacing.buttonHeight,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.4)),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
            padding: EdgeInsets.zero,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.textMuted,),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                style: AppTypography.body, textAlign: TextAlign.center,),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,),
            ),
          ],
        ),
      ),
    );
  }
}

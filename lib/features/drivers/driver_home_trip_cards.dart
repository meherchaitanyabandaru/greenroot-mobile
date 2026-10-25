part of 'driver_home_screen.dart';

class _NoTripCard extends ConsumerStatefulWidget {
  const _NoTripCard();

  @override
  ConsumerState<_NoTripCard> createState() => _NoTripCardState();
}

class _NoTripCardState extends ConsumerState<_NoTripCard> {
  final _codeCtrl = TextEditingController();
  bool _joining = false;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _codeCtrl.addListener(() {
      if (_codeError != null && _codeCtrl.text.isNotEmpty) {
        setState(() => _codeError = null);
      }
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _joinTrip() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = 'Please enter a Trip ID to continue');
      return;
    }
    FocusScope.of(context).unfocus();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.forest100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.question_mark_rounded,
                  color: AppColors.primaryMain,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Join Trip?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Are you sure you want to join this trip?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Join Trip — LEFT
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryMain,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Join Trip',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Cancel — RIGHT
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryMain,
                        side: const BorderSide(color: AppColors.primaryMain),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _joining = true);
    await Future.delayed(const Duration(milliseconds: 80));
    if (mounted) {
      setState(() => _joining = false);
      context
          .push('/driver/scan/preview?code=${Uri.encodeQueryComponent(code)}');
    }
  }

  void _scanQr() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const UniversalQrScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status header ────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.forest100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color: AppColors.primaryMain,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No Active Trip', style: AppTypography.h4),
                      SizedBox(height: 2),
                      Text(
                        'You are available for delivery',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                const StatusBadge(
                  label: 'Available',
                  variant: BadgeVariant.success,
                  dot: true,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.md),

            // ── Join a Trip section ──────────────────────────────────────────
            const Text('Join a Trip', style: AppTypography.h4),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'To start a delivery, get the Trip ID from the nursery owner or manager.',
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Scan QR row ──────────────────────────────────────────────────
            GestureDetector(
              onTap: _scanQr,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.forest100,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.primaryMain,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Text('Join via QR Code', style: AppTypography.h4),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── OR divider ───────────────────────────────────────────────────
            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    'OR',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.border)),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Enter Trip ID ────────────────────────────────────────────────
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.none,
              onSubmitted: (_) => _joinTrip(),
              decoration: InputDecoration(
                hintText: 'e.g. DSP-20261025-0001',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
                errorText: _codeError,
                errorStyle: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: const OutlineInputBorder(
                  borderRadius: AppRadius.inputRadius,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.inputRadius,
                  borderSide: BorderSide(
                    color: _codeError != null
                        ? AppColors.red600
                        : AppColors.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.inputRadius,
                  borderSide: BorderSide(
                    color: _codeError != null
                        ? AppColors.red600
                        : AppColors.primaryMain,
                    width: 1.5,
                  ),
                ),
                errorBorder: const OutlineInputBorder(
                  borderRadius: AppRadius.inputRadius,
                  borderSide: BorderSide(color: AppColors.red600),
                ),
                focusedErrorBorder: const OutlineInputBorder(
                  borderRadius: AppRadius.inputRadius,
                  borderSide:
                      BorderSide(color: AppColors.red600, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),

            // ── Join Trip button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: FilledButton(
                onPressed: _joining ? null : _joinTrip,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonRadius,
                  ),
                ),
                child: _joining
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Join Trip',
                        style: AppTypography.label
                            .copyWith(color: Colors.white, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ACCEPTED: Waiting for nursery loading ─────────────────────────────────────

class _WaitingForLoadingCard extends ConsumerStatefulWidget {
  final Dispatch trip;
  const _WaitingForLoadingCard({required this.trip});

  @override
  ConsumerState<_WaitingForLoadingCard> createState() =>
      _WaitingForLoadingCardState();
}

class _WaitingForLoadingCardState
    extends ConsumerState<_WaitingForLoadingCard> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    ref.invalidate(_driverDashboardProvider);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: AppColors.amber600.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber600.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.amber100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: AppColors.amber600,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Trip Accepted ✓', style: AppTypography.h4),
                      const SizedBox(height: 2),
                      Text(
                        'Waiting for Nursery Loading',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.amber600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amber100,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.amber600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Waiting',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.amber600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.md),

            // Trip code + order
            Text(
              trip.dispatchCode,
              style: AppTypography.h3.copyWith(letterSpacing: 0.4),
            ),
            if (trip.orderNumber?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                'Order: ${trip.orderNumber}',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (trip.destinationAddress?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 13, color: AppColors.textMuted,),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trip.destinationAddress!,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Message box
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.amber100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.amber600, size: 16,),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Your trip has been accepted. The nursery is preparing the plants. You will receive a notification once loading is completed.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.amber600,
                        fontFamily: 'Inter',
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Actions
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppSpacing.buttonHeight,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/driver/trip/${trip.id}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryMain,
                        side: const BorderSide(color: AppColors.primaryMain),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.buttonRadius,
                        ),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View Trip'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SizedBox(
                    height: AppSpacing.buttonHeight,
                    child: OutlinedButton.icon(
                      onPressed: _refreshing ? null : _refresh,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.buttonRadius,
                        ),
                      ),
                      icon: _refreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.textMuted,),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh'),
                    ),
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

// ── DISPATCHED: Ready to depart ────────────────────────────────────────────────

class _ReadyToDepartCard extends ConsumerStatefulWidget {
  final Dispatch trip;
  const _ReadyToDepartCard({required this.trip});

  @override
  ConsumerState<_ReadyToDepartCard> createState() => _ReadyToDepartCardState();
}

class _ReadyToDepartCardState extends ConsumerState<_ReadyToDepartCard> {
  bool _starting = false;

  Future<void> _startJourney() async {
    setState(() => _starting = true);
    try {
      await ref
          .read(dispatchRepositoryProvider)
          .updateStatus(widget.trip.id, 'IN_TRANSIT');
      ref.invalidate(_driverDashboardProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journey started! GPS tracking is now active.'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to start: $e'),
              backgroundColor: AppColors.red600,),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;

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
                  'Ready to Depart',
                  style: AppTypography.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.8)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryMain,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Loaded',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryMain,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),
            Text(
              trip.dispatchCode,
              style: AppTypography.h2
                  .copyWith(color: Colors.white, letterSpacing: 0.4),
            ),

            const SizedBox(height: AppSpacing.sm),
            // Loading complete banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 16,),
                  const SizedBox(width: 8),
                  Text(
                    'Loading complete! All plants are loaded.',
                    style: AppTypography.caption.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: AppSpacing.md),

            _TripInfoRow(
              icon: Icons.store_outlined,
              label: 'Pickup',
              value: trip.sellerNurseryName ?? 'Nursery',
            ),
            const SizedBox(height: AppSpacing.sm),
            _TripInfoRow(
              icon: Icons.location_on_rounded,
              label: 'Deliver to',
              value: trip.destinationAddress ?? 'See trip details',
            ),
            if (trip.vehicleNumber?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.sm),
              _TripInfoRow(
                icon: Icons.directions_car_outlined,
                label: 'Vehicle',
                value: trip.vehicleNumber!,
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: NextActionPulse(child: ElevatedButton.icon(
                onPressed: _starting ? null : _startJourney,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryMain,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonRadius,
                  ),
                ),
                icon: _starting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryMain,
                        ),
                      )
                    : const Icon(Icons.navigation_rounded),
                label: Text(
                  _starting ? 'Starting...' : 'Start Journey',
                  style: AppTypography.label.copyWith(
                    color: AppColors.primaryMain,
                    fontSize: 15,
                  ),
                ),
              ),),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tip: who is responsible ───────────────────────────────────────────────────

class _WaitingTip extends StatelessWidget {
  const _WaitingTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.amber100,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.manage_accounts_rounded,
              size: 16, color: AppColors.amber600,),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Manager / Owner is currently loading plants. You will be notified when it\'s your turn to depart.',
              style: AppTypography.caption.copyWith(color: AppColors.amber600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartTip extends StatelessWidget {
  const _DepartTip();

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
          const Icon(Icons.drive_eta_rounded,
              size: 16, color: AppColors.primaryMain,),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'It\'s your turn! Plants are loaded and ready. Start your journey to make the delivery.',
              style:
                  AppTypography.caption.copyWith(color: AppColors.primaryMain),
            ),
          ),
        ],
      ),
    );
  }
}

// ── How it works card ──────────────────────────────────────────────────────────

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.forest100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.primaryMain,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryMain,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ask the nursery owner or manager for the Trip ID or scan the QR code provided for your trip.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Driver not connected to nursery ───────────────────────────────────────────

class _DriverNotConnectedCard extends StatelessWidget {
  const _DriverNotConnectedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryMain.withAlpha(51)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              size: 36,
              color: AppColors.primaryMain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "You're registered as a Driver!",
            style: AppTypography.h3.copyWith(color: AppColors.primaryMain),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'To start receiving trips, a nursery owner needs to connect you. '
            'Ask them to send an invite, or scan their QR code below.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const UniversalQrScreen(),
                fullscreenDialog: true,
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: const Text('Scan Nursery Invite QR'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pull down to refresh once connected.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Active trip card (gradient) ────────────────────────────────────────────────

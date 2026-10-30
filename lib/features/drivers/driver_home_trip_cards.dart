part of 'driver_home_screen.dart';

class _NoTripCard extends ConsumerStatefulWidget {
  const _NoTripCard();

  @override
  ConsumerState<_NoTripCard> createState() => _NoTripCardState();
}

class _NoTripCardState extends ConsumerState<_NoTripCard> {
  final _codeCtrl = TextEditingController();
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

  void _joinTrip() {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = 'Paste the trip code to continue');
      return;
    }
    FocusScope.of(context).unfocus();

    // The trip preview shows the trip and asks Accept / Reject: no extra
    // "are you sure" step before it.
    context.push('/driver/scan/preview?code=${Uri.encodeQueryComponent(code)}');
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
              'To start a delivery, scan the trip QR or paste the trip code from the nursery.',
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
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _joinTrip(),
              // A pasted full code opens the trip at once (the Join button sits under the keyboard on small phones).
              onChanged: (v) {
                if (RegExp(r'^TRIP-[0-9a-f-]{36}$', caseSensitive: false)
                    .hasMatch(v.trim())) {
                  _joinTrip();
                }
              },
              decoration: InputDecoration(
                hintText: 'Paste the trip code (TRIP-…)',
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
                onPressed: _joinTrip,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonRadius,
                  ),
                ),
                child: Text(
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

class _ReadyToDepartCard extends ConsumerStatefulWidget {
  final Dispatch trip;
  const _ReadyToDepartCard({required this.trip});

  @override
  ConsumerState<_ReadyToDepartCard> createState() => _ReadyToDepartCardState();
}

class _ReadyToDepartCardState extends ConsumerState<_ReadyToDepartCard> {
  bool _starting = false;

  Future<void> _startJourney() async {
    final consent = await startTripConsent(context, ref, widget.trip);
    if (consent == null || !mounted) return;
    setState(() => _starting = true);
    try {
      await ref
          .read(dispatchRepositoryProvider)
          .updateStatus(widget.trip.id, 'IN_TRANSIT', consent: consentOrNull(consent));
      ref.invalidate(_driverDashboardProvider);
      // The trip map sends the GPS points: open it, or the buyer sees no truck.
      if (mounted) context.push('/driver/trip/${widget.trip.id}');
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
                    widget.trip.orderStatus == 'PARTIALLY_FULFILLED'
                        ? 'Loading complete. Some plants were short.'
                        : 'Loading complete! All plants are loaded.',
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
                  'Ask the nursery owner or manager for the trip QR or trip code.',
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

// ── Active trip card (gradient) ────────────────────────────────────────────────

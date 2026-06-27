import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/main_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/qr_scanner_screen.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dispatches/dispatches.dart';
import '../notifications/notifications.dart';

// ── Dashboard data model ───────────────────────────────────────────────────────

class _DashboardData {
  final ActiveTripState tripState;
  final int pendingCount;
  final int deliveredCount;
  final AppNotification? latestNotification;

  const _DashboardData({
    required this.tripState,
    required this.pendingCount,
    required this.deliveredCount,
    required this.latestNotification,
  });
}

// ── Dashboard provider — 2 parallel API calls ──────────────────────────────────

final _driverDashboardProvider =
    FutureProvider.autoDispose<_DashboardData>((ref) async {
  final dispatchRepo = ref.read(dispatchRepositoryProvider);
  final notifRepo = ref.read(notificationRepositoryProvider);

  final results = await Future.wait([
    dispatchRepo.listDispatches(page: 1, perPage: 50),
    notifRepo.listNotifications(page: 1, perPage: 1),
  ]);

  final dispatches = (results[0] as (List<Dispatch>, dynamic)).$1;
  final notifications = (results[1] as (List<AppNotification>, dynamic)).$1;

  const activeStatuses = {'ACCEPTED', 'DISPATCHED', 'IN_TRANSIT'};
  final active =
      dispatches.where((d) => activeStatuses.contains(d.status)).toList();

  ActiveTripState tripState;
  if (active.length > 1) {
    tripState =
        const ActiveTripState(trip: null, result: ActiveTripResult.integrityError);
  } else if (active.isNotEmpty) {
    tripState = ActiveTripState(trip: active.first, result: ActiveTripResult.found);
  } else {
    tripState = const ActiveTripState(trip: null, result: ActiveTripResult.none);
  }

  return _DashboardData(
    tripState: tripState,
    pendingCount: dispatches.where((d) => d.status == 'PENDING').length,
    deliveredCount: dispatches.where((d) => d.status == 'DELIVERED').length,
    latestNotification: notifications.firstOrNull,
  );
});

// ── Root screen ────────────────────────────────────────────────────────────────

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationListProvider.notifier).load();
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final firstName = session.user?.name?.split(' ').first ?? 'Driver';
    final unread = ref.watch(notificationListProvider).unreadCount;
    final dashAsync = ref.watch(_driverDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: AppSpacing.screenPadding,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _greeting,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            Text(firstName, style: AppTypography.h2),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: unread > 0
                ? Badge.count(
                    count: unread,
                    backgroundColor: AppColors.primaryMain,
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined, size: 26),
                      onPressed: () =>
                          ref.read(mainTabIndexProvider.notifier).state = 2,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 26),
                    onPressed: () =>
                        ref.read(mainTabIndexProvider.notifier).state = 2,
                  ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryMain,
        displacement: 20,
        onRefresh: () async {
          ref.invalidate(_driverDashboardProvider);
          await ref.read(notificationListProvider.notifier).load();
        },
        child: dashAsync.when(
          loading: () => const _DashboardSkeleton(),
          error: (_, __) =>
              _OfflineState(onRetry: () => ref.invalidate(_driverDashboardProvider)),
          data: (data) => _DashboardBody(data: data),
        ),
      ),
    );
  }
}

// ── Dashboard body ─────────────────────────────────────────────────────────────

class _DashboardBody extends ConsumerWidget {
  final _DashboardData data;
  const _DashboardBody({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = data.tripState.trip;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + 100,
      ),
      children: trip == null
          ? [
              const _NoTripCard(),
              const SizedBox(height: AppSpacing.md),
              const _HowItWorksCard(),
            ]
          : trip.status == 'ACCEPTED'
              ? [
                  _WaitingForLoadingCard(trip: trip),
                  const SizedBox(height: AppSpacing.md),
                  const _WaitingTip(),
                ]
              : trip.status == 'DISPATCHED'
                  ? [
                      _ReadyToDepartCard(trip: trip),
                      const SizedBox(height: AppSpacing.md),
                      const _DepartTip(),
                    ]
                  : [
                      _ActiveTripCard(trip: trip),
                      const SizedBox(height: AppSpacing.md),
                      _ActiveTripActions(trip: trip),
                      const SizedBox(height: AppSpacing.md),
                      _ActiveTripTip(),
                    ],
    );
  }
}

// ── No active trip card — unified join card ────────────────────────────────────

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
                decoration: BoxDecoration(
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
      context.push('/driver/scan/preview?code=${Uri.encodeQueryComponent(code)}');
    }
  }

  Future<void> _scanQr() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(title: 'Scan Trip QR'),
        fullscreenDialog: true,
      ),
    );
    if (code != null && code.isNotEmpty && mounted) {
      context.push('/driver/scan/preview?code=${Uri.encodeQueryComponent(code)}');
    }
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
                  decoration: BoxDecoration(
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
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
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
                hintText: 'e.g. 3f7a2c9b-8d11-4f6a-9b2d-1e7c9f3a6b12',
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
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputRadius,
                  borderSide: const BorderSide(color: AppColors.border),
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
                errorBorder: OutlineInputBorder(
                  borderRadius: AppRadius.inputRadius,
                  borderSide: const BorderSide(color: AppColors.red600),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: AppRadius.inputRadius,
                  borderSide:
                      const BorderSide(color: AppColors.red600, width: 1.5),
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
                  shape: RoundedRectangleBorder(
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
                  decoration: BoxDecoration(
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
                      size: 13, color: AppColors.textMuted),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.amber600, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
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
                      onPressed: () =>
                          context.push('/driver/trip/${trip.id}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryMain,
                        side: const BorderSide(color: AppColors.primaryMain),
                        shape: RoundedRectangleBorder(
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
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.buttonRadius,
                        ),
                      ),
                      icon: _refreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textMuted),
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
              backgroundColor: AppColors.red600),
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
                    color: Colors.white, size: 18),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Loading complete! All plants are loaded.',
                    style: AppTypography.caption
                        .copyWith(color: Colors.white),
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
              value: 'Nursery',
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
              child: ElevatedButton.icon(
                onPressed: _starting ? null : _startJourney,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryMain,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
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
              ),
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
      decoration: BoxDecoration(
        color: AppColors.amber100,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.manage_accounts_rounded,
              size: 16, color: AppColors.amber600),
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
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.drive_eta_rounded,
              size: 16, color: AppColors.primaryMain),
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
            decoration: BoxDecoration(
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

// ── Active trip card (gradient) ────────────────────────────────────────────────

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
    final assignedAt = DateTime.tryParse(trip.createdAt)?.toLocal();
    final assignedLabel =
        assignedAt != null ? DateFormat('dd MMM, hh:mm a').format(assignedAt) : null;

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
                    color: Colors.white, size: 18),
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
                      label: trip.status.replaceAll('_', ' '),
                      variant: badgeVariantFromStatus(trip.status),
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
              child: ElevatedButton.icon(
                onPressed: () => context.push('/driver/trip/${trip.id}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryMain,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonRadius,
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Continue Trip'),
              ),
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
      {required this.icon, required this.label, required this.value});

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
                      .copyWith(color: Colors.white.withValues(alpha: 0.6))),
              Text(value,
                  style: AppTypography.label.copyWith(color: Colors.white)),
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
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: AppColors.primaryMain),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Complete your current delivery before accepting another trip.',
              style: AppTypography.caption.copyWith(color: AppColors.primaryMain),
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
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              _Bone(height: 340, radius: 16),
              const SizedBox(height: AppSpacing.md),
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
        const Icon(Icons.cloud_off_outlined, size: 64, color: AppColors.textMuted),
        const SizedBox(height: AppSpacing.x2l),
        const Text('Unable to connect',
            style: AppTypography.h3, textAlign: TextAlign.center),
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

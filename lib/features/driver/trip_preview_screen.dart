import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dispatches/dispatches.dart';

/// Shown when a driver enters a trip code — previews the trip and lets them accept.
class TripPreviewScreen extends ConsumerStatefulWidget {
  final String code;
  const TripPreviewScreen({super.key, required this.code});

  @override
  ConsumerState<TripPreviewScreen> createState() => _TripPreviewScreenState();
}

class _TripPreviewScreenState extends ConsumerState<TripPreviewScreen> {
  Dispatch? _dispatch;
  bool _loading = true;
  bool _accepting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ref.read(dispatchRepositoryProvider).findByCode(widget.code);
      if (mounted) setState(() => _dispatch = d);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Trip not found. Check the code and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    if (_dispatch == null) return;
    setState(() => _accepting = true);
    try {
      final accepted =
          await ref.read(dispatchRepositoryProvider).acceptDispatch(_dispatch!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip accepted! Get ready to start loading.'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
        // Navigate to driver trip dashboard
        context.go('/dispatches/${accepted.id}');
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red600),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Trip Details', style: AppTypography.h4),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryMain))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _dispatch != null
                  ? _TripDetails(
                      dispatch: _dispatch!,
                      currentUserId: ref.watch(sessionProvider).user?.id,
                      onAccept: _accept,
                      accepting: _accepting,
                    )
                  : const SizedBox.shrink(),
    );
  }
}

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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.red600.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  color: AppColors.red600, size: 36),
            ),
            const SizedBox(height: AppSpacing.x2l),
            const Text('Trip Not Found', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x2l),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryMain,
                side: const BorderSide(color: AppColors.primaryMain),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripDetails extends StatelessWidget {
  final Dispatch dispatch;
  final int? currentUserId;
  final VoidCallback onAccept;
  final bool accepting;

  const _TripDetails({
    required this.dispatch,
    required this.currentUserId,
    required this.onAccept,
    required this.accepting,
  });

  @override
  Widget build(BuildContext context) {
    final myTrip = dispatch.driverUserId != null && dispatch.driverUserId == currentUserId;
    final takenByOther = dispatch.driverUserId != null && dispatch.driverUserId != currentUserId;
    final alreadyAccepted = dispatch.status != 'PENDING' || myTrip || takenByOther;
    final hasDriver =
        dispatch.driverName != null || dispatch.status != 'PENDING';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // Trip ID card
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryMain, AppColors.primaryHover],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.cardRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Trip ID',
                    style: AppTypography.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const Spacer(),
                  StatusBadge(
                    label: dispatch.status.replaceAll('_', ' '),
                    variant: badgeVariantFromStatus(dispatch.status),
                    dot: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                dispatch.dispatchCode,
                style: AppTypography.h3.copyWith(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  letterSpacing: 1.2,
                ),
              ),
              if (dispatch.orderNumber != null)
                Text(
                  'Order: ${dispatch.orderNumber}',
                  style: AppTypography.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.x2l),

        // From / To card
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.store_outlined,
                iconBg: AppColors.primaryLight,
                iconColor: AppColors.primaryMain,
                label: 'From (Pickup)',
                value: 'Nursery',
              ),
              const Divider(height: 1, indent: 56),
              _InfoRow(
                icon: Icons.location_on_rounded,
                iconBg: AppColors.blue100,
                iconColor: AppColors.blue600,
                label: 'To (Delivery)',
                value: dispatch.destinationAddress ?? 'See order details',
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Items, Vehicle
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.inventory_2_outlined,
                iconBg: AppColors.amber100,
                iconColor: AppColors.amber600,
                label: 'Items',
                value: dispatch.items.isNotEmpty
                    ? '${dispatch.items.length} item types'
                    : 'See order details',
              ),
              if (dispatch.vehicleNumber != null) ...[
                const Divider(height: 1, indent: 56),
                _InfoRow(
                  icon: Icons.directions_car_outlined,
                  iconBg: AppColors.forest100,
                  iconColor: AppColors.primaryMain,
                  label: 'Vehicle',
                  value: dispatch.vehicleNumber!,
                ),
              ],
              if (dispatch.driverName != null) ...[
                const Divider(height: 1, indent: 56),
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  iconBg: AppColors.forest100,
                  iconColor: AppColors.primaryMain,
                  label: 'Assigned Driver',
                  value: dispatch.driverName!,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Security notice
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: AppRadius.cardRadius,
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_outlined,
                  color: AppColors.primaryMain, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'This trip code is unique and secure. Once you accept, you\'ll be linked to this trip.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.primaryMain),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.x3l),

        // Accept button
        if (!alreadyAccepted) ...[
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: accepting ? null : onAccept,
              icon: accepting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                accepting ? 'Accepting...' : 'Accept Trip',
                style: AppTypography.label,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonRadius),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel',
                  style:
                      AppTypography.label.copyWith(color: AppColors.textMuted)),
            ),
          ),
        ] else if (myTrip) ...[
          // Current user already accepted this trip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: AppRadius.buttonRadius,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.primaryMain),
                const SizedBox(width: AppSpacing.sm),
                Text('You\'ve accepted this trip',
                    style: AppTypography.label.copyWith(color: AppColors.primaryMain)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/dispatches/${dispatch.id}'),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Go to Trip'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryMain,
                side: const BorderSide(color: AppColors.primaryMain),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
              ),
            ),
          ),
        ] else ...[
          // Trip taken by another driver or already in progress
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.red600.withValues(alpha: 0.08),
              borderRadius: AppRadius.buttonRadius,
              border: Border.all(color: AppColors.red600.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_outlined, color: AppColors.red600),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    dispatch.status != 'PENDING'
                        ? 'Trip is already underway'
                        : 'Trip already assigned to another driver',
                    style: AppTypography.label.copyWith(color: AppColors.red600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Go Back',
                  style: AppTypography.label.copyWith(color: AppColors.textMuted)),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.x2l),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
                Text(value, style: AppTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

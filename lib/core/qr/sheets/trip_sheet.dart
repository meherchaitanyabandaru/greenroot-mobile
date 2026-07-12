import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/qr_shared_widgets.dart';
import '../classifier.dart';

// Shown when scanner detects a trip/dispatch code.
// Routes to driver flow or non-driver gate based on [isDriver].
class TripSheet extends StatelessWidget {
  final String tripCode;
  final bool isDriver;
  final VoidCallback onScanAnother;
  final void Function(QrSheetResult) onResult;

  const TripSheet({
    super.key,
    required this.tripCode,
    required this.isDriver,
    required this.onScanAnother,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    return isDriver ? _buildDriverContent(context) : _buildGateContent();
  }

  // ── Driver: show code + action to view trip ────────────────────────────────

  Widget _buildDriverContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QrHeaderRow(
          icon: Icons.local_shipping_outlined,
          iconColor: AppColors.primaryMain,
          iconBg: AppColors.forest100,
          title: 'Trip QR Code',
          subtitle: tripCode,
          subtitleClip: true,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => onResult(QrSheetResult.goToTrip),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('View Trip Details'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        QrScanAnotherButton(onTap: onScanAnother),
      ],
    );
  }

  // ── Non-driver gate: inform and offer rescan ───────────────────────────────

  Widget _buildGateContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const QrHeaderRow(
          icon: Icons.local_shipping_outlined,
          iconColor: AppColors.amber600,
          iconBg: Color(0xFFFFF3E0),
          title: 'Trip QR Code',
          subtitle: 'Only drivers can join trips',
        ),
        const SizedBox(height: 16),
        QrWarningBanner(
          'This QR code assigns a driver to a trip. '
          'Your account does not have a driver profile, so you cannot join this trip.',
        ),
        const SizedBox(height: 24),
        QrScanAnotherButton(onTap: onScanAnother),
      ],
    );
  }
}

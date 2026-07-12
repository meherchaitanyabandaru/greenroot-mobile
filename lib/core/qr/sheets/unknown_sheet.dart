import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/qr_shared_widgets.dart';

class UnknownSheet extends StatelessWidget {
  final VoidCallback onScanAnother;

  const UnknownSheet({super.key, required this.onScanAnother});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QrHeaderRow(
          icon: Icons.qr_code_scanner_rounded,
          iconColor: AppColors.red500,
          iconBg: AppColors.red500.withAlpha(26),
          title: 'Not a GreenRoot QR',
          subtitle: 'This QR code was not issued by GreenRoot and cannot be processed here.',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GreenRoot QR codes are used for:',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              for (final item in const [
                '• Invitations (customer, manager, driver)',
                '• Trip assignments for drivers',
                '• Quotation document verification',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    item,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        QrScanAnotherButton(onTap: onScanAnother),
      ],
    );
  }
}

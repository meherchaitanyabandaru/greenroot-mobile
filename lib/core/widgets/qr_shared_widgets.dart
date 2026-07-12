import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

// ── Header row ────────────────────────────────────────────────────────────────

class QrHeaderRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool subtitleClip;

  const QrHeaderRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.subtitleClip = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, size: 26, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.h4),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                maxLines: subtitleClip ? 1 : 2,
                overflow: subtitleClip ? TextOverflow.ellipsis : TextOverflow.visible,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Info card + row ───────────────────────────────────────────────────────────

class QrInfoCard extends StatelessWidget {
  final List<Widget> children;
  const QrInfoCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryMain.withAlpha(51)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) ...[
              const SizedBox(height: 4),
              Divider(height: 1, color: AppColors.border.withAlpha(120)),
              const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
  }
}

class QrInfoRow extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String label;
  final String value;
  final Color? valueColor;

  const QrInfoRow({
    super.key,
    required this.icon,
    this.iconSize = 16,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: iconSize, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Warning banner ────────────────────────────────────────────────────────────

class QrWarningBanner extends StatelessWidget {
  final String message;
  const QrWarningBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.amber600, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: AppTypography.caption.copyWith(color: AppColors.amber600)),
          ),
        ],
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class QrErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const QrErrorCard({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.red500, size: 48),
        const SizedBox(height: 12),
        Text(
          message,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

// ── Shared scan-another button ────────────────────────────────────────────────

class QrScanAnotherButton extends StatelessWidget {
  final VoidCallback onTap;
  const QrScanAnotherButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Scan another code'),
    );
  }
}

// ── Loading spinner ───────────────────────────────────────────────────────────

class QrLoadingSpinner extends StatelessWidget {
  const QrLoadingSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator(color: AppColors.primaryMain)),
    );
  }
}

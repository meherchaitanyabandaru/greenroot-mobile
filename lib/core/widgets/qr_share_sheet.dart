import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

// ── QR card type ──────────────────────────────────────────────────────────────

enum QrCodeType {
  tripQr,
  managerInvite,
  customerInvite,
}

extension _QrMeta on QrCodeType {
  String get badgeLabel => switch (this) {
        QrCodeType.tripQr         => 'TRIP QR',
        QrCodeType.managerInvite  => 'MANAGER INVITATION',
        QrCodeType.customerInvite => 'CUSTOMER INVITATION',
      };

  String get title => switch (this) {
        QrCodeType.tripQr         => 'Trip QR',
        QrCodeType.managerInvite  => 'Manager Invitation',
        QrCodeType.customerInvite => 'Customer Invitation',
      };

  String get subtitle => switch (this) {
        QrCodeType.tripQr         => 'Scan to Join Trip',
        QrCodeType.managerInvite  => 'Scan to Join Nursery',
        QrCodeType.customerInvite => 'Scan to Join Nursery',
      };

  String get idLabel => switch (this) {
        QrCodeType.tripQr         => 'Trip ID',
        QrCodeType.managerInvite  => 'Invitation ID',
        QrCodeType.customerInvite => 'Invitation ID',
      };

  IconData get icon => switch (this) {
        QrCodeType.tripQr         => Icons.local_shipping_outlined,
        QrCodeType.managerInvite  => Icons.manage_accounts_outlined,
        QrCodeType.customerInvite => Icons.people_outline_rounded,
      };

  Color get accentColor => switch (this) {
        QrCodeType.tripQr         => AppColors.primaryMain,
        QrCodeType.managerInvite  => AppColors.blue600,
        QrCodeType.customerInvite => AppColors.blue600,
      };

  Color get lightColor => switch (this) {
        QrCodeType.tripQr         => AppColors.forest100,
        QrCodeType.managerInvite  => AppColors.blue100,
        QrCodeType.customerInvite => AppColors.blue100,
      };
}

// ── Display ID formatter ───────────────────────────────────────────────────────

String _formatDisplayId(String code, QrCodeType type) {
  switch (type) {
    case QrCodeType.tripQr:
      return code;
    case QrCodeType.managerInvite:
      final clean = code.replaceAll('-', '').toUpperCase();
      final short = clean.length >= 8 ? clean.substring(0, 8) : clean;
      return 'MGR-$short';
    case QrCodeType.customerInvite:
      final clean = code.replaceAll('-', '').toUpperCase();
      final short = clean.length >= 8 ? clean.substring(0, 8) : clean;
      return 'CUS-$short';
  }
}

// ── Main widget ───────────────────────────────────────────────────────────────

class QrShareSheet extends StatelessWidget {
  final String code;
  final QrCodeType qrType;
  final String? shareMessage;
  final DateTime? expiresAt;

  const QrShareSheet({
    super.key,
    required this.code,
    this.qrType = QrCodeType.tripQr,
    this.shareMessage,
    this.expiresAt,
  });

  static Future<void> show(
    BuildContext context, {
    required String code,
    QrCodeType qrType = QrCodeType.tripQr,
    String? shareMessage,
    DateTime? expiresAt,
    // Legacy params kept for backward compatibility — ignored
    String title = '',
    String subtitle = '',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QrShareSheet(
        code: code,
        qrType: qrType,
        shareMessage: shareMessage,
        expiresAt: expiresAt,
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _share() async {
    final msg = shareMessage ??
        'Use this ${qrType.idLabel.toLowerCase()} on GreenRoot:\n\n${_formatDisplayId(code, qrType)}\n\nScan the QR or enter the ID manually.';
    await Share.share(msg, subject: qrType.title);
  }

  @override
  Widget build(BuildContext context) {
    final accent = qrType.accentColor;
    final light = qrType.lightColor;
    final displayId = _formatDisplayId(code, qrType);
    final expiry = expiresAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(expiresAt!.toLocal())
        : null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── QR Card ────────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header badge
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      qrType.badgeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: light,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(qrType.icon, color: accent, size: 28),
                ),

                const SizedBox(height: 12),

                // Title + subtitle
                Text(
                  qrType.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  qrType.subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontFamily: 'Inter',
                  ),
                ),

                const SizedBox(height: 20),

                // QR Code with leaf logo overlay
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      QrImageView(
                        data: code,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: accent == AppColors.primaryMain
                              ? const Color(0xFF1A4731)
                              : const Color(0xFF1E3A8A),
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: accent == AppColors.primaryMain
                              ? const Color(0xFF1A4731)
                              : const Color(0xFF1E3A8A),
                        ),
                      ),
                      // GreenRoot logo overlay
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.eco_rounded,
                          color: accent,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ID row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        qrType == QrCodeType.tripQr
                            ? Icons.local_shipping_outlined
                            : Icons.badge_outlined,
                        size: 14,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${qrType.idLabel}: ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontFamily: 'Inter',
                        ),
                      ),
                      Flexible(
                        child: Text(
                          displayId,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: const Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Expiry row
                if (expiry != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Expires: $expiry',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // One-time use footer
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: light,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 14, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        'One-time use only',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Action buttons ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Copy
                Expanded(
                  child: _ActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy ID',
                    color: const Color(0xFF475569),
                    onTap: () => _copy(context),
                  ),
                ),
                const SizedBox(width: 12),
                // Share
                Expanded(
                  child: _ActionButton(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    color: accent,
                    filled: true,
                    onTap: _share,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          borderRadius: AppRadius.buttonRadius,
          border: Border.all(
            color: filled ? color : const Color(0xFFE2E8F0),
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: filled ? Colors.white : color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.button.copyWith(
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

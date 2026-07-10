import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
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
        QrCodeType.managerInvite  => 'Scan to Join as Manager',
        QrCodeType.customerInvite => 'Scan to Connect with Nursery',
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
        QrCodeType.customerInvite => AppColors.primaryMain,
      };

  Color get lightColor => switch (this) {
        QrCodeType.tripQr         => AppColors.forest100,
        QrCodeType.managerInvite  => AppColors.blue100,
        QrCodeType.customerInvite => AppColors.forest100,
      };

  // Step-by-step instructions for how to use the QR
  List<_Step> get instructions => switch (this) {
        QrCodeType.customerInvite => const [
          _Step(icon: Icons.share_rounded,         text: 'Send this QR image to your customer via WhatsApp or any app'),
          _Step(icon: Icons.smartphone_rounded,     text: 'Customer installs GreenRoot on their phone'),
          _Step(icon: Icons.qr_code_scanner_rounded,text: 'They open the app → tap Scan QR on the home screen'),
          _Step(icon: Icons.check_circle_outlined,  text: 'QR is scanned → they are linked to your nursery as a customer'),
        ],
        QrCodeType.managerInvite => const [
          _Step(icon: Icons.share_rounded,          text: 'Send this QR image to your Gumastha via WhatsApp or any app'),
          _Step(icon: Icons.smartphone_rounded,     text: 'Gumastha installs GreenRoot on their phone'),
          _Step(icon: Icons.qr_code_scanner_rounded,text: 'They open the app → tap Scan QR on the home screen'),
          _Step(icon: Icons.check_circle_outlined,  text: 'QR is scanned → they join your nursery as a manager'),
        ],
        QrCodeType.tripQr => const [
          _Step(icon: Icons.share_rounded,          text: 'Send this QR image to your driver'),
          _Step(icon: Icons.smartphone_rounded,     text: 'Driver opens GreenRoot on their phone'),
          _Step(icon: Icons.qr_code_scanner_rounded,text: 'Driver taps the QR scan button on the Driver screen'),
          _Step(icon: Icons.check_circle_outlined,  text: 'QR scanned → driver is assigned to this trip'),
        ],
      };

  String get shareText => switch (this) {
        QrCodeType.customerInvite =>
          'You have been invited to connect with a nursery on GreenRoot.\n\n'
          'Install GreenRoot, open the app, and scan this QR to connect.',
        QrCodeType.managerInvite =>
          'You have been invited to join a nursery as a Manager on GreenRoot.\n\n'
          'Install GreenRoot, open the app, and scan this QR to accept.',
        QrCodeType.tripQr =>
          'You have a new trip assignment on GreenRoot.\n\n'
          'Open GreenRoot and scan this QR to join the trip.',
      };
}

class _Step {
  final IconData icon;
  final String text;
  const _Step({required this.icon, required this.text});
}

// ── Display ID formatter ──────────────────────────────────────────────────────

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

class QrShareSheet extends StatefulWidget {
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

  @override
  State<QrShareSheet> createState() => _QrShareSheetState();
}

class _QrShareSheetState extends State<QrShareSheet> {
  final _qrKey = GlobalKey();
  bool _sharing = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      if (kIsWeb) {
        // Web: file sharing not available — copy invite code to clipboard
        await Clipboard.setData(ClipboardData(text: widget.code));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invite code copied — share it with your contact'),
              backgroundColor: AppColors.primaryMain,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Mobile: render QR card to image and share
      final boundary = _qrKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/greenroot_invite_qr.png');
      await file.writeAsBytes(bytes);

      final text = widget.shareMessage ?? widget.qrType.shareText;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text,
        subject: widget.qrType.title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share image: $e'),
            backgroundColor: AppColors.red600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.qrType.accentColor;
    final light = widget.qrType.lightColor;
    final displayId = _formatDisplayId(widget.code, widget.qrType);
    final expiry = widget.expiresAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(widget.expiresAt!.toLocal())
        : null;
    final steps = widget.qrType.instructions;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── QR Card (captured for image export) ────────────────────────
            RepaintBoundary(
              key: _qrKey,
              child: Container(
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
                    // Badge
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          widget.qrType.badgeLabel,
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
                          color: light, shape: BoxShape.circle),
                      child:
                          Icon(widget.qrType.icon, color: accent, size: 28),
                    ),
                    const SizedBox(height: 12),

                    // Title + subtitle
                    Text(
                      widget.qrType.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.qrType.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // QR code
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          QrImageView(
                            data: widget.code,
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
                                  color:
                                      Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Icon(Icons.eco_rounded,
                                color: accent, size: 26),
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
                            widget.qrType == QrCodeType.tripQr
                                ? Icons.local_shipping_outlined
                                : Icons.badge_outlined,
                            size: 14,
                            color: const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.qrType.idLabel}: ',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              fontFamily: 'Inter',
                            ),
                          ),
                          Flexible(
                            child: Text(
                              displayId,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Expiry
                    if (expiry != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 13, color: Color(0xFF94A3B8)),
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
                          Icon(Icons.lock_outline_rounded,
                              size: 14, color: accent),
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
            ),

            const SizedBox(height: 16),

            // ── Action buttons ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.copy_rounded,
                      label: 'Copy ID',
                      color: const Color(0xFF475569),
                      onTap: _copy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: _sharing
                          ? Icons.hourglass_top_rounded
                          : (kIsWeb ? Icons.copy_all_rounded : Icons.image_rounded),
                      label: _sharing
                          ? 'Preparing...'
                          : (kIsWeb ? 'Copy Code' : 'Share Image'),
                      color: accent,
                      filled: true,
                      onTap: _sharing ? () {} : _shareImage,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── How to use instructions ───────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        'How to use',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...steps.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${e.key + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  e.value.text,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF475569),
                                    fontFamily: 'Inter',
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Shows a bottom sheet with a QR code, copy button, WhatsApp share, and link share.
///
/// Usage:
///   QrShareSheet.show(context, code: invite.uuid, title: 'Manager Invite', subtitle: '...')
class QrShareSheet extends StatelessWidget {
  final String code;
  final String title;
  final String subtitle;
  final String shareMessage;

  const QrShareSheet({
    super.key,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.shareMessage,
  });

  static Future<void> show(
    BuildContext context, {
    required String code,
    required String title,
    String subtitle = '',
    String? shareMessage,
  }) {
    final msg = shareMessage ?? 'Use this code to join on GreenRoot:\n\n$code';
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QrShareSheet(
        code: code,
        title: title,
        subtitle: subtitle,
        shareMessage: msg,
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

  Future<void> _shareWhatsApp(BuildContext context) async {
    final uri = Uri.parse(
      'whatsapp://send?text=${Uri.encodeComponent(shareMessage)}',
    );
    // Try WhatsApp direct; fallback to system share sheet
    try {
      if (!await _launchUrl(uri)) {
        await Share.share(shareMessage, subject: title);
      }
    } catch (_) {
      await Share.share(shareMessage, subject: title);
    }
  }

  Future<bool> _launchUrl(Uri uri) async {
    // Use url_launcher if available; we use a platform channel workaround
    // via share_plus for simplicity (works on Android & iOS)
    await Share.shareUri(uri);
    return true;
  }

  Future<void> _shareLink(BuildContext context) async {
    await Share.share(shareMessage, subject: title);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.x3l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),

          Text(title, style: AppTypography.h3),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.x2l),

          // QR Code
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: code,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.textPrimary,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Code text + copy
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.inputRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: AppTypography.caption.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _copy(context),
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy_rounded,
                            size: 16, color: AppColors.primaryMain),
                        const SizedBox(width: 4),
                        Text('Copy',
                            style: AppTypography.caption.copyWith(
                                color: AppColors.primaryMain,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Share buttons row
          Row(
            children: [
              // WhatsApp
              Expanded(
                child: _ShareButton(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () => _shareWhatsApp(context),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Share link
              Expanded(
                child: _ShareButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  color: AppColors.primaryMain,
                  onTap: () => _shareLink(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.buttonRadius,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.button.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

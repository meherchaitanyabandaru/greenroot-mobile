import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/qr_scanner_screen.dart';

/// Driver-only screen: scan a trip QR code or enter a trip code manually.
class DriverScanScreen extends StatefulWidget {
  const DriverScanScreen({super.key});

  @override
  State<DriverScanScreen> createState() => _DriverScanScreenState();
}

class _DriverScanScreenState extends State<DriverScanScreen> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(title: 'Scan Trip QR'),
        fullscreenDialog: true,
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      _navigateToPreview(result.trim());
    }
  }

  void _submitCode() {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    _navigateToPreview(code);
  }

  void _navigateToPreview(String code) {
    context.push('/driver/scan/preview?code=${Uri.encodeQueryComponent(code)}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Join a Trip'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: AppSpacing.x2l),

          // Scan QR button
          GestureDetector(
            onTap: _openScanner,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryMain, AppColors.primaryHover],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppRadius.cardRadius,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner_rounded,
                      color: Colors.white, size: 56),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Tap to Scan QR Code',
                    style:
                        AppTypography.h4.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Point your camera at the trip QR code',
                    style: AppTypography.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.x2l),

          // Divider with "OR"
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'OR',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textMuted),
              ),
            ),
            const Expanded(child: Divider()),
          ]),

          const SizedBox(height: AppSpacing.x2l),

          // Manual code entry
          Text('Enter Trip Code Manually', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _codeController,
            focusNode: _focusNode,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
              TextInputFormatter.withFunction((old, next) =>
                  next.copyWith(text: next.text.toUpperCase())),
            ],
            decoration: InputDecoration(
              hintText: 'e.g. DSP-20250001',
              hintStyle:
                  AppTypography.body.copyWith(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.tag_rounded,
                  color: AppColors.textSecondary),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _codeController,
                builder: (_, value, __) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => _codeController.clear(),
                  );
                },
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: AppRadius.inputRadius,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.inputRadius,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.inputRadius,
                borderSide:
                    const BorderSide(color: AppColors.primaryMain, width: 2),
              ),
            ),
            onSubmitted: (_) => _submitCode(),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _codeController,
              builder: (_, value, __) {
                return FilledButton.icon(
                  onPressed:
                      value.text.trim().isNotEmpty ? _submitCode : null,
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.primaryMain),
                  icon: const Icon(Icons.search_rounded),
                  label: Text('Find Trip', style: AppTypography.label),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

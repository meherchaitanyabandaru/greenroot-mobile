import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../qr/classifier.dart';
import '../qr/scan_frame.dart';
import '../qr/sheets/invite_sheet.dart';
import '../qr/sheets/trip_sheet.dart';
import '../qr/sheets/unknown_sheet.dart';
import '../qr/sheets/verify_sheet.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../features/auth/presentation/providers/session_provider.dart';
import '../../features/drivers/driver_home_screen.dart'
    show driverHasActiveTripProvider;
import '../../features/drivers/trip_preview_screen.dart';

class UniversalQrScreen extends ConsumerStatefulWidget {
  const UniversalQrScreen({super.key});

  @override
  ConsumerState<UniversalQrScreen> createState() => _UniversalQrScreenState();
}

class _UniversalQrScreenState extends ConsumerState<UniversalQrScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _ctrl;
  bool _torchOn = false;
  bool _detected = false;

  late final AnimationController _lineCtrl;
  late final Animation<double> _lineAnim;
  Timer? _autoTorchTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _lineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut),
    );
    // Auto-torch after 2.5 s if nothing scanned yet (dark room heuristic).
    _autoTorchTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!_detected && mounted && !_torchOn) {
        _ctrl.toggleTorch();
        setState(() => _torchOn = true);
      }
    });
  }

  @override
  void dispose() {
    _autoTorchTimer?.cancel();
    _lineCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  // ── Detection ─────────────────────────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _processValue(value.trim());
  }

  Future<void> _processValue(String raw) async {
    if (_detected) return;
    _detected = true;
    await _ctrl.stop();
    HapticFeedback.mediumImpact();
    if (!mounted) return;

    final isDriver = ref.read(sessionProvider).capabilities.hasDriverProfile;

    // Drivers with an active trip cannot join another trip or accept invites.
    if (isDriver && ref.read(driverHasActiveTripProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have an active trip to complete first.'),
          backgroundColor: AppColors.red600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final detection = classifyQr(raw);

    final result = await showModalBottomSheet<QrSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => _SheetShell(
        raw: raw,
        detection: detection,
        isDriver: isDriver,
      ),
    );

    if (!mounted) return;

    switch (result ?? QrSheetResult.resume) {
      case QrSheetResult.resume:
        setState(() => _detected = false);
        await _ctrl.start();
      case QrSheetResult.goToTrip:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TripPreviewScreen(code: raw)),
        );
        if (mounted) Navigator.of(context).pop();
      case QrSheetResult.close:
        Navigator.of(context).pop();
    }
  }

  // ── Torch + gallery ───────────────────────────────────────────────────────

  Future<void> _toggleTorch() async {
    await _ctrl.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final result = await _ctrl.analyzeImage(file.path);
    if (!mounted) return;
    final value = result?.barcodes.firstOrNull?.rawValue;
    if (value != null && value.isNotEmpty) {
      _processValue(value.trim());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No QR code found in the selected image.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Camera unavailable\n${error.errorCode.name}',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          QrScanFrame(lineAnimation: _lineAnim),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                  ),
                  Expanded(
                    child: Text(
                      'Scan QR Code',
                      style: AppTypography.h3.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleTorch,
                    icon: Icon(
                      _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _torchOn ? Colors.yellow : Colors.white,
                      size: 26,
                    ),
                    tooltip: _torchOn ? 'Turn off flash' : 'Turn on flash',
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(
                      'Point your camera at a QR code',
                      style: AppTypography.body.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _pickFromGallery,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_outlined, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Choose from Gallery',
                              style: AppTypography.button.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet shell ────────────────────────────────────────────────────────
// Wraps the typed sheet widgets in the standard bottom-sheet container.

class _SheetShell extends StatelessWidget {
  final String raw;
  final QrDetection detection;
  final bool isDriver;

  const _SheetShell({
    required this.raw,
    required this.detection,
    required this.isDriver,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildSheet(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context) {
    void resume() => Navigator.of(context).pop(QrSheetResult.resume);
    void close() => Navigator.of(context).pop(QrSheetResult.close);

    return switch (detection.type) {
      QrType.invite => InviteSheet(
          uuid: raw,
          onScanAnother: resume,
          onResult: (r) => Navigator.of(context).pop(r),
        ),
      QrType.quotationVerify => VerifySheet(
          token: detection.verifyToken!,
          onDone: close,
        ),
      QrType.tripCode => TripSheet(
          tripCode: raw,
          isDriver: isDriver,
          onScanAnother: resume,
          onResult: (r) => Navigator.of(context).pop(r),
        ),
      QrType.unknown => UnknownSheet(onScanAnother: resume),
    };
  }
}

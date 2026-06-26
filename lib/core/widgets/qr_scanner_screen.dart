import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Full-screen QR scanner with:
/// - Auto-torch after 2.5 s without a detection (dark room heuristic)
/// - Manual torch toggle button
/// - Gallery pick — decodes QR from a selected photo
/// - Pops with the decoded String value when a code is found
class QrScannerScreen extends StatefulWidget {
  final String title;

  const QrScannerScreen({super.key, this.title = 'Scan QR Code'});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _ctrl;
  bool _torchOn = false;
  bool _detected = false;

  // Scan-line animation
  late final AnimationController _lineCtrl;
  late final Animation<double> _lineAnim;

  // Auto-torch: enable flash after 2.5 s if nothing scanned yet
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

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _detected = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(value);
  }

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
      _detected = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(value);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No QR code found in the selected image.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera feed — full screen
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined,
                        color: Colors.white54, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Camera unavailable\n${error.errorCode.name}',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),

          // Overlay: dark border + transparent square cutout
          _ScanOverlay(lineAnimation: _lineAnim),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 26),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTypography.h3.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Torch button
                  IconButton(
                    onPressed: _toggleTorch,
                    icon: Icon(
                      _torchOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      color: _torchOn ? Colors.yellow : Colors.white,
                      size: 26,
                    ),
                    tooltip: _torchOn ? 'Turn off flash' : 'Turn on flash',
                  ),
                ],
              ),
            ),
          ),

          // Bottom bar: gallery pick
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
                      style: AppTypography.body
                          .copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _pickFromGallery,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_outlined,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Choose from Gallery',
                              style: AppTypography.button
                                  .copyWith(color: Colors.white),
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

// ── Scan overlay ───────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  final Animation<double> lineAnimation;

  const _ScanOverlay({required this.lineAnimation});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final cutout = size.width * 0.72;
      final left = (size.width - cutout) / 2;
      final top = (size.height - cutout) / 2 - 40;

      return Stack(
        children: [
          // Dark overlay with cutout
          CustomPaint(
            size: size,
            painter: _OverlayPainter(
              cutoutRect: Rect.fromLTWH(left, top, cutout, cutout),
            ),
          ),
          // Corner brackets
          Positioned(
            left: left,
            top: top,
            child: _Corners(size: cutout),
          ),
          // Animated scan line inside cutout
          Positioned(
            left: left + 4,
            top: top + 4,
            child: AnimatedBuilder(
              animation: lineAnimation,
              builder: (_, __) {
                return SizedBox(
                  width: cutout - 8,
                  height: cutout - 8,
                  child: Align(
                    alignment: Alignment(0, (lineAnimation.value * 2) - 1),
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.primaryMain.withValues(alpha: 0.9),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect cutoutRect;

  const _OverlayPainter({required this.cutoutRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final rounded = RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16));

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(rounded),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => cutoutRect != old.cutoutRect;
}

// Corner bracket decoration (like a camera viewfinder)
class _Corners extends StatelessWidget {
  final double size;

  const _Corners({required this.size});

  @override
  Widget build(BuildContext context) {
    const arm = 24.0;
    const thick = 3.5;
    const r = 14.0;
    const color = AppColors.primaryMain;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(arm: arm, thick: thick, radius: r, color: color),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double arm;
  final double thick;
  final double radius;
  final Color color;

  const _CornerPainter(
      {required this.arm,
      required this.thick,
      required this.radius,
      required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawPath(
        Path()
          ..moveTo(radius, 0)
          ..lineTo(arm, 0)
          ..moveTo(0, radius)
          ..lineTo(0, arm)
          ..moveTo(0, 0 + radius)
          ..arcToPoint(Offset(radius, 0),
              radius: Radius.circular(radius), clockwise: false),
        paint);

    // Top-right
    canvas.drawPath(
        Path()
          ..moveTo(w - arm, 0)
          ..lineTo(w - radius, 0)
          ..arcToPoint(Offset(w, radius),
              radius: Radius.circular(radius), clockwise: true)
          ..lineTo(w, arm),
        paint);

    // Bottom-left
    canvas.drawPath(
        Path()
          ..moveTo(0, h - arm)
          ..lineTo(0, h - radius)
          ..arcToPoint(Offset(radius, h),
              radius: Radius.circular(radius), clockwise: true)
          ..lineTo(arm, h),
        paint);

    // Bottom-right
    canvas.drawPath(
        Path()
          ..moveTo(w - arm, h)
          ..lineTo(w - radius, h)
          ..arcToPoint(Offset(w, h - radius),
              radius: Radius.circular(radius), clockwise: false)
          ..lineTo(w, h - arm),
        paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Full-screen camera overlay: dark cutout + animated scan line + corner brackets.
class QrScanFrame extends StatelessWidget {
  final Animation<double> lineAnimation;
  const QrScanFrame({super.key, required this.lineAnimation});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final cutout = size.width * 0.72;
      final left = (size.width - cutout) / 2;
      final top = (size.height - cutout) / 2 - 40;
      final rect = Rect.fromLTWH(left, top, cutout, cutout);

      return Stack(
        children: [
          CustomPaint(size: size, painter: _OverlayPainter(cutoutRect: rect)),
          Positioned(left: left, top: top, child: _ScanCorners(size: cutout)),
          Positioned(
            left: left + 4,
            top: top + 4,
            child: AnimatedBuilder(
              animation: lineAnimation,
              builder: (_, __) => SizedBox(
                width: cutout - 8,
                height: cutout - 8,
                child: Align(
                  alignment: Alignment(0, (lineAnimation.value * 2) - 1),
                  child: Container(
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xE5266140), // primaryMain 90%
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

// ── Dark overlay with transparent cutout ──────────────────────────────────────

class _OverlayPainter extends CustomPainter {
  final Rect cutoutRect;
  const _OverlayPainter({required this.cutoutRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16))),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => cutoutRect != old.cutoutRect;
}

// ── Corner brackets ───────────────────────────────────────────────────────────

class _ScanCorners extends StatelessWidget {
  final double size;
  const _ScanCorners({required this.size});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: const CustomPaint(painter: _CornerPainter()));
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 24.0, thick = 3.5, r = 14.0;
    final paint = Paint()
      ..color = AppColors.primaryMain
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;

    canvas
      ..drawPath(
          Path()
            ..moveTo(r, 0)
            ..lineTo(arm, 0)
            ..moveTo(0, r)
            ..lineTo(0, arm)
            ..moveTo(0, r)
            ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r), clockwise: false),
          paint)
      ..drawPath(
          Path()
            ..moveTo(w - arm, 0)
            ..lineTo(w - r, 0)
            ..arcToPoint(Offset(w, r), radius: const Radius.circular(r), clockwise: true)
            ..lineTo(w, arm),
          paint)
      ..drawPath(
          Path()
            ..moveTo(0, h - arm)
            ..lineTo(0, h - r)
            ..arcToPoint(Offset(r, h), radius: const Radius.circular(r), clockwise: true)
            ..lineTo(arm, h),
          paint)
      ..drawPath(
          Path()
            ..moveTo(w - arm, h)
            ..lineTo(w - r, h)
            ..arcToPoint(Offset(w, h - r), radius: const Radius.circular(r), clockwise: false)
            ..lineTo(w, h - arm),
          paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

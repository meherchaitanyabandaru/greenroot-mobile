import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared premium map components used across driver / buyer / owner map screens.
// ─────────────────────────────────────────────────────────────────────────────

// ── Desaturated tile colour matrix ────────────────────────────────────────────
//
// Apply as ColorFilter around TileLayer so the OSM basemap becomes a soft
// backdrop — markers and route lines become the focal point.

const ColorFilter kMapDesatFilter = ColorFilter.matrix([
  0.860, 0.117, 0.023, 0, 6,
  0.060, 0.917, 0.023, 0, 6,
  0.060, 0.117, 0.823, 0, 6,
  0,     0,     0,     1, 0,
]);

// ── Backdrop-blur pill chip ───────────────────────────────────────────────────

class MapChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const MapChip({
    super.key,
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Text-only pill chip (no icon) ─────────────────────────────────────────────

class MapTextChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;

  const MapTextChip({
    super.key,
    required this.label,
    required this.color,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'Inter',
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Circular map action button ────────────────────────────────────────────────

class MapIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  const MapIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor = AppColors.primaryMain,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.90),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.60),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
        ),
      ),
    );
  }
}

// ── Animated truck marker — pulses while active (IN_TRANSIT) ──────────────────

class MapTruckMarker extends StatefulWidget {
  final bool active;
  const MapTruckMarker({super.key, this.active = false});

  @override
  State<MapTruckMarker> createState() => _MapTruckMarkerState();
}

class _MapTruckMarkerState extends State<MapTruckMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(MapTruckMarker old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _ctrl.repeat();
    if (!widget.active && old.active) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.active)
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final v = _pulse.value;
                return Container(
                  width: 62 * v,
                  height: 62 * v,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryMain
                        .withValues(alpha: 0.35 * (1 - v)),
                  ),
                );
              },
            ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryMain,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryMain.withValues(alpha: 0.48),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const CustomPaint(painter: TruckIconPainter()),
          ),
        ],
      ),
    );
  }
}

// ── Animated point marker (nursery green leaf / home blue) ────────────────────

class MapPointMarker extends StatefulWidget {
  final Color color;
  final String label;
  final String sublabel;
  final bool isNursery;

  const MapPointMarker({
    super.key,
    required this.color,
    required this.label,
    required this.sublabel,
    required this.isNursery,
  });

  @override
  State<MapPointMarker> createState() => _MapPointMarkerState();
}

class _MapPointMarkerState extends State<MapPointMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.42),
                    blurRadius: 14,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: widget.isNursery
                    ? const LeafIconPainter()
                    : HomeIconPainter(accent: widget.color),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: widget.color,
                      fontFamily: 'Inter',
                      letterSpacing: -0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    widget.sublabel,
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.textMuted,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Completed point marker — dimmed with checkmark ────────────────────────────

class MapCompletedMarker extends StatelessWidget {
  final String label;
  const MapCompletedMarker({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryMain.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryMain.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.check_rounded,
            color: AppColors.primaryMain.withValues(alpha: 0.7),
            size: 16,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon Painters
// ─────────────────────────────────────────────────────────────────────────────

class TruckIconPainter extends CustomPainter {
  const TruckIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Cargo box
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.10, h * 0.22, w * 0.44, h * 0.40),
        const Radius.circular(2.5),
      ),
      white,
    );

    // Cab
    final cab = ui.Path()
      ..moveTo(w * 0.54, h * 0.62)
      ..lineTo(w * 0.54, h * 0.33)
      ..lineTo(w * 0.70, h * 0.26)
      ..lineTo(w * 0.86, h * 0.42)
      ..lineTo(w * 0.86, h * 0.62)
      ..close();
    canvas.drawPath(cab, white);

    // Chassis
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.60, w * 0.84, h * 0.07),
        const Radius.circular(1),
      ),
      white,
    );

    // Wheels
    canvas.drawCircle(Offset(w * 0.26, h * 0.74), w * 0.09, white);
    canvas.drawCircle(Offset(w * 0.72, h * 0.74), w * 0.09, white);

    // Hubs
    final hub = Paint()
      ..color = AppColors.primaryMain
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.26, h * 0.74), w * 0.04, hub);
    canvas.drawCircle(Offset(w * 0.72, h * 0.74), w * 0.04, hub);

    // Window
    final win = Paint()
      ..color = AppColors.primaryMain.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.58, h * 0.34, w * 0.22, h * 0.18),
        const Radius.circular(2),
      ),
      win,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class LeafIconPainter extends CustomPainter {
  const LeafIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final leaf = ui.Path()
      ..moveTo(w * 0.50, h * 0.17)
      ..cubicTo(w * 0.88, h * 0.17, w * 0.88, h * 0.63, w * 0.50, h * 0.79)
      ..cubicTo(w * 0.12, h * 0.63, w * 0.12, h * 0.17, w * 0.50, h * 0.17)
      ..close();
    canvas.drawPath(leaf, white);

    final stem = Paint()
      ..color = AppColors.forest600.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.50, h * 0.77), Offset(w * 0.50, h * 0.89), stem);

    final rib = Paint()
      ..color = AppColors.forest600.withValues(alpha: 0.38)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.50, h * 0.23), Offset(w * 0.50, h * 0.77), rib);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class HomeIconPainter extends CustomPainter {
  final Color accent;
  const HomeIconPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Roof
    final roof = ui.Path()
      ..moveTo(w * 0.50, h * 0.15)
      ..lineTo(w * 0.84, h * 0.44)
      ..lineTo(w * 0.16, h * 0.44)
      ..close();
    canvas.drawPath(roof, white);

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.42, w * 0.56, h * 0.40),
        const Radius.circular(2),
      ),
      white,
    );

    // Door
    final door = Paint()
      ..color = accent.withValues(alpha: 0.58)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.57, w * 0.24, h * 0.25),
        const Radius.circular(2),
      ),
      door,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) =>
      old is HomeIconPainter && old.accent != accent;
}

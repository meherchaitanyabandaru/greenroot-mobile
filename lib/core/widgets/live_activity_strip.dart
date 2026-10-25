import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum LiveActivity { loading, inTransit }

/// A small looping animation that shows work is happening right now: plants
/// hopping onto the lorry while an order is loading, the lorry driving to the
/// pin while a delivery is on its way. Still (no motion) when the phone asks
/// for reduced motion.
class LiveActivityStrip extends StatefulWidget {
  final LiveActivity activity;
  final String? label;

  const LiveActivityStrip({super.key, required this.activity, this.label});

  @override
  State<LiveActivityStrip> createState() => _LiveActivityStripState();
}

class _LiveActivityStripState extends State<LiveActivityStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
      _c.value = 0.6;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.activity == LiveActivity.loading;
    final color = loading ? AppColors.blue600 : AppColors.primaryMain;
    final label = widget.label ??
        (loading ? 'Loading plants…' : 'On the way to the delivery point');
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 28,
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => loading
                    ? _Plants(t: _c.value, color: color)
                    : _Road(t: _c.value, color: color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySmall
                    .copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three plants hop in turn, like crates being lifted one after another.
class _Plants extends StatelessWidget {
  final double t;
  final Color color;
  const _Plants({required this.t, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < 3; i++)
          Transform.translate(
            // Each plant hops during its own third of the loop.
            offset: Offset(0, -8 * math.max(0, math.sin((t * 3 - i) * math.pi))),
            child: Icon(Icons.local_florist_rounded, size: 20, color: color),
          ),
        Icon(Icons.local_shipping_rounded,
            size: 22, color: color.withValues(alpha: 0.5),),
      ],
    );
  }
}

/// The lorry drives along a dashed road towards the delivery pin.
class _Road extends StatelessWidget {
  final double t;
  final Color color;
  const _Road({required this.t, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      const truck = 22.0, pin = 18.0;
      final travel = box.maxWidth - truck - pin;
      final eased = Curves.easeInOut.transform(t);
      return Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DashPainter(color.withValues(alpha: 0.35))),
          ),
          Positioned(
            right: 0,
            child: Icon(Icons.location_on_rounded, size: pin, color: color),
          ),
          Positioned(
            left: travel * eased,
            // A small bounce, like a lorry on an Indian road.
            top: 3 + 1.5 * math.sin(t * math.pi * 16).abs(),
            child: Icon(Icons.local_shipping_rounded, size: truck, color: color),
          ),
        ],
      );
    },);
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height - 3;
    for (double x = 0; x < size.width - 18; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

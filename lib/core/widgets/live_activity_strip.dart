import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum LiveActivity { loading }

/// A small looping animation that shows work is happening right now: plants
/// hopping onto the lorry while an order is loading. (A trip on its way shows
/// the truck moving on the live map instead.) Still (no motion) when the phone
/// asks for reduced motion.
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
    const color = AppColors.blue600;
    final label = widget.label ?? 'Loading plants…';
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
                builder: (_, __) => _Plants(t: _c.value, color: color),
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

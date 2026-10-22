import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Gently pulses its child (a soft glow that breathes) so first-time users see
/// which button moves the order or trip forward. Still when [active] is false
/// or the phone asks for reduced motion.
class NextActionPulse extends StatefulWidget {
  final Widget child;
  final bool active;
  final BorderRadius borderRadius;

  const NextActionPulse({
    super.key,
    required this.child,
    this.active = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<NextActionPulse> createState() => _NextActionPulseState();
}

class _NextActionPulseState extends State<NextActionPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(NextActionPulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final still = !widget.active || MediaQuery.of(context).disableAnimations;
    if (still) {
      _c
        ..stop()
        ..value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryMain.withValues(alpha: 0.45 * _c.value),
              blurRadius: 4 + 14 * _c.value,
              spreadRadius: 3 * _c.value,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

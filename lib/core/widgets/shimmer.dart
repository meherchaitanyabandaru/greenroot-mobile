import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// A sweeping-gradient loading placeholder ("skeleton shimmer"). Wrap a tree
/// of solid-colored placeholder boxes (see [ShimmerBox]) in a single
/// [Shimmer] so the highlight band sweeps across all of them together,
/// rather than giving each box its own out-of-sync animation.
///
/// Deliberately hand-rolled with core Flutter animation APIs instead of
/// pulling in the `shimmer` package -- this is a well-known ~40-line
/// technique (ShaderMask + a translating gradient) and the app has no other
/// animation dependency to justify adding one just for this.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 1.4s per the "skeleton shimmer: 1.2-1.6s, repeating gently" spec.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFFE7ECEA),
                Color(0xFFE7ECEA),
                Color(0xFFF5F8F6),
                Color(0xFFE7ECEA),
                Color(0xFFE7ECEA),
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              begin: const Alignment(-1.0, -0.2),
              end: const Alignment(1.0, 0.2),
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0, 0);
  }
}

/// One placeholder box within a [Shimmer] -- a plain rounded rect standing
/// in for a line of text, an icon, or a card. Give it the same width/height
/// as the real content it's covering for.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.sm),
      ),
    );
  }
}

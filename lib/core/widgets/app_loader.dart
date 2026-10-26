import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// GreenRoot's loading mark: a leaf that gently breathes inside a spinning
/// ring. Use it wherever a page or section waits for data; small spinners
/// inside buttons stay as they are. The leaf holds still when the phone asks
/// for reduced motion (the ring is the system spinner).
class AppLoader extends StatefulWidget {
  final double size;
  const AppLoader({super.key, this.size = 56});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _breath.value = 1; // rest at full size
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      label: 'Loading',
      child: SizedBox.square(
        dimension: s,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: AppColors.forest100,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox.square(
              dimension: s,
              child: CircularProgressIndicator(
                strokeWidth: s / 18,
                strokeCap: StrokeCap.round,
                color: AppColors.primaryMain,
              ),
            ),
            ScaleTransition(
              scale: Tween(begin: 0.82, end: 1.0).animate(
                CurvedAnimation(parent: _breath, curve: Curves.easeInOut),
              ),
              child: Icon(
                Icons.eco_rounded,
                size: s * 0.5,
                color: AppColors.primaryMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

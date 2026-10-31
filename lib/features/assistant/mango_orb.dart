import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mango_chat_controller.dart';

/// Mango's glowing orb with sound bars at the sides. Each state has its own
/// colours and motion; with the phone's "reduce motion" setting it is still.
class MangoOrb extends StatefulWidget {
  final OrbState state;

  /// Microphone loudness, 0 to 1, while listening.
  final double level;
  final double size;
  const MangoOrb({super.key, required this.state, required this.level, required this.size});

  @override
  State<MangoOrb> createState() => _MangoOrbState();
}

class _MangoOrbState extends State<MangoOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  static const _labels = {
    OrbState.idle: 'Mango is ready',
    OrbState.listening: 'Mango is listening',
    OrbState.thinking: 'Mango is thinking',
    OrbState.speaking: 'Mango is speaking',
    OrbState.error: 'Something went wrong',
    OrbState.limit: 'No questions left today',
    OrbState.micDenied: 'Microphone not allowed',
  };

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      label: _labels[widget.state],
      liveRegion: true,
      child: SizedBox(
        height: s * 1.2,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _t,
          builder: (_, __) => CustomPaint(
            painter: _OrbPainter(t: _t.value, state: widget.state, level: widget.level, size: s),
            child: Center(
              child: ExcludeSemantics(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: widget.state == OrbState.limit ? 0.55 : 1,
                  child: Text('🥭', style: TextStyle(fontSize: s * 0.34)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  final OrbState state;
  final double level;
  final double size;
  _OrbPainter({required this.t, required this.state, required this.level, required this.size});

  static const _leaf = Color(0xFF2E9E5B);
  static const _lime = Color(0xFF9BE15D);
  static const _amber = Color(0xFFFFC23D);
  static const _orange = Color(0xFFFF8A3D);
  static const _teal = Color(0xFF2EC4B6);
  static const _grey = Color(0xFFB8C2BC);

  List<Color> get _colors => switch (state) {
        OrbState.limit || OrbState.micDenied => const [_grey, Color(0xFFD9DED9), _grey],
        OrbState.error => const [_amber, _orange, Color(0xFFE5604D), _amber],
        _ => const [_teal, _leaf, _lime, _amber, _orange, _teal],
      };

  @override
  void paint(Canvas canvas, Size box) {
    final c = box.center(Offset.zero);
    final wave = math.sin(t * 2 * math.pi * 3);
    final scale = switch (state) {
      OrbState.listening => 1 + level * 0.12,
      OrbState.speaking => 1 + 0.04 * wave.abs(),
      OrbState.idle => 1 + 0.015 * math.sin(t * 2 * math.pi),
      _ => 1.0,
    };
    final r = size / 2 * scale;
    final spin = switch (state) {
      OrbState.thinking => t * 2 * math.pi * 4,
      OrbState.limit || OrbState.micDenied => 0.0,
      _ => t * 2 * math.pi,
    };

    _bars(canvas, box, c, r, wave);

    // Soft glow around the orb.
    final glow = state == OrbState.limit || state == OrbState.micDenied ? _grey : (state == OrbState.error ? _orange : _lime);
    canvas.drawCircle(c, r * 1.45, Paint()
      ..shader = RadialGradient(colors: [glow.withValues(alpha: 0.35), glow.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: c, radius: r * 1.45)),);
    // Inside: light, with a little colour moving through it.
    canvas.drawCircle(c, r, Paint()
      ..shader = RadialGradient(
        center: Alignment(0.3 * math.cos(spin), 0.3 * math.sin(spin)),
        colors: [Colors.white, _colors[1].withValues(alpha: 0.25), _colors[0].withValues(alpha: 0.18)],
        stops: const [0.2, 0.75, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r)),);
    // The ring: a blurred glow and a sharp edge, turning.
    final ring = SweepGradient(colors: _colors, transform: GradientRotation(spin)).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16
      ..shader = ring
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),);
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.035
      ..shader = ring,);
  }

  // Sound bars to the left and right: they follow the voice while listening
  // and the speech while speaking; otherwise they rest as small dots.
  void _bars(Canvas canvas, Size box, Offset c, double r, double wave) {
    final live = state == OrbState.listening || state == OrbState.speaking;
    final paint = Paint()
      ..color = (live ? _leaf : _grey).withValues(alpha: live ? 0.7 : 0.35)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    const gap = 7.0;
    for (final side in [-1, 1]) {
      for (var i = 0;; i++) {
        final x = c.dx + side * (r * 1.12 + i * gap);
        if (x < 4 || x > box.width - 4) break;
        final fade = 1 - i / 22;
        if (fade <= 0) break;
        var h = 3.0;
        if (live) {
          final energy = state == OrbState.listening ? 0.25 + level : 0.5 + 0.4 * wave.abs();
          h = 4 + r * 0.55 * fade * energy * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 5 + i * 1.3)).abs();
        }
        canvas.drawLine(Offset(x, c.dy - h / 2), Offset(x, c.dy + h / 2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t || old.state != state || old.level != level || old.size != size;
}

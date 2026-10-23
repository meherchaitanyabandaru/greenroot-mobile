import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'mango_controller.dart';
import 'mango_finder.dart';
import 'mango_guides.dart';

/// Sits above the whole app (MaterialApp.router `builder`): the Ask Mango
/// button, the guide picker and the spotlight walkthrough. Screens are not
/// modified; targets are found by the labels they already show.
class MangoLayer extends StatefulWidget {
  final Widget child;
  final MangoController controller;

  /// Who is using the app now; null hides Ask Mango (e.g. splash screen).
  final MangoAudience? Function() audience;

  /// Rebuild when this changes (route/session changes).
  final Listenable? refresh;

  const MangoLayer({
    super.key,
    required this.child,
    required this.controller,
    required this.audience,
    this.refresh,
  });

  @override
  State<MangoLayer> createState() => _MangoLayerState();
}

class _MangoLayerState extends State<MangoLayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Element? _target;
  Rect? _hole;
  Duration _lastSearch = Duration.zero;
  Duration _stepStarted = Duration.zero;
  Duration _now = Duration.zero;
  bool _scrolledIntoView = false;
  int _stepKey = -1;
  List<({MangoGuide guide, bool here})> _ranked = const [];

  MangoController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    // Not lazy: dispose() would otherwise create it on a dead element.
    _ticker = createTicker(_onTick);
    _c.addListener(_onController);
    widget.refresh?.addListener(_rebuild);
    // Added before the router's own observer, so Back reaches Mango first.
    WidgetsBinding.instance.addObserver(this);
  }

  // Back on the guide picker closes it. During a walkthrough Back navigates
  // as usual (guides span screens: "go back to Market, open Chats").
  @override
  Future<bool> didPopRoute() async {
    if (!_c.picking) return false;
    _c.exit();
    return true;
  }

  @override
  void didUpdateWidget(MangoLayer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
    }
    if (old.refresh != widget.refresh) {
      old.refresh?.removeListener(_rebuild);
      widget.refresh?.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_onController);
    widget.refresh?.removeListener(_rebuild);
    _ticker.dispose();
    super.dispose();
  }

  void _rebuild() {
    // The router notifies while the tree below this layer is still being
    // built (the very first frame): a setState then marks this widget dirty
    // mid-build (debug '!_dirty' assertion). Rebuild right after instead.
    scheduleMicrotask(() {
      if (mounted) setState(() {});
    });
  }

  void _onController() {
    final key = _c.guide == null ? -1 : _c.stepIndex + (_c.done ? 1000 : 0);
    if (key != _stepKey) {
      _stepKey = key;
      _target = null;
      _hole = null;
      _scrolledIntoView = false;
      _lastSearch = Duration.zero;
      _stepStarted = _now;
    }
    final spotlight = _c.step != null && _c.step!.targets.isNotEmpty;
    if (spotlight && !_ticker.isActive) _ticker.start();
    if (!spotlight && _ticker.isActive) _ticker.stop();
    _rebuild();
  }

  // Every frame: follow the target (scrolling, keyboard, animations); every
  // 300 ms look it up again, since the user may have moved to another screen.
  void _onTick(Duration now) {
    _now = now;
    final step = _c.step;
    if (step == null || step.targets.isEmpty) return;
    if (_target == null ||
        !_target!.mounted ||
        now - _lastSearch > const Duration(milliseconds: 300)) {
      _lastSearch = now;
      _target = MangoFinder.find(step.targets);
    }
    var rect = MangoFinder.rectOf(_target);
    if (rect != null && !_scrolledIntoView) {
      _scrolledIntoView = true;
      final screen = MediaQuery.sizeOf(context);
      if (rect.top < 80 || rect.bottom > screen.height - 80) {
        Scrollable.ensureVisible(
          _target!,
          alignment: 0.4,
          duration: const Duration(milliseconds: 250),
        );
      }
    }
    if (rect != null) rect = rect.inflate(6);
    if (rect != _hole) setState(() => _hole = rect);
  }

  void _onPointerUp(PointerUpEvent e) {
    final step = _c.step;
    final hole = _hole;
    if (step == null || hole == null || !step.advanceOnTap) return;
    if (!hole.contains(e.position)) return;
    final key = _stepKey;
    // Let the tap reach the real button first, then move on.
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted && key == _stepKey) _c.next();
    });
  }

  @override
  Widget build(BuildContext context) {
    final audience = widget.audience();
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: _onPointerUp,
      child: Stack(
        children: [
          widget.child,
          if (_c.picking && audience != null)
            _Picker(controller: _c, ranked: _ranked)
          else if (_c.guide != null)
            ..._walkthrough(context)
          else if (audience != null)
            _AskMangoButton(
              onTap: () {
                // Read the screen now: the tree can't be walked during build.
                _ranked = rankGuides(audience, MangoFinder.onScreen);
                _c.openPicker();
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _walkthrough(BuildContext context) {
    final step = _c.step;
    final hole = step == null || step.targets.isEmpty ? null : _hole;
    final size = MediaQuery.sizeOf(context);
    final missing = step != null &&
        step.targets.isNotEmpty &&
        hole == null &&
        _now - _stepStarted > const Duration(milliseconds: 1200);
    final visibleH = size.height - MediaQuery.viewInsetsOf(context).bottom;
    final cardAtTop = hole != null && hole.center.dy > visibleH * 0.5;
    return [
      // Dim and guard the screen only while a spotlight is shown. With no
      // target on screen (an instruction step, or a sheet covering it) the
      // user must still be able to act: open an ad, pick the customer…
      if (hole != null) Positioned.fill(child: _Barrier(hole: hole)),
      if (hole != null) _PointingHand(hole: hole, screen: size),
      _StepCard(controller: _c, atTop: cardAtTop, missing: missing),
    ];
  }
}

// ── Dimmed backdrop with a clear, tappable hole over the target ──────────────

class _Barrier extends LeafRenderObjectWidget {
  final Rect? hole;
  const _Barrier({required this.hole});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBarrier(hole);

  @override
  void updateRenderObject(BuildContext context, _RenderBarrier r) =>
      r.hole = hole;
}

class _RenderBarrier extends RenderBox {
  _RenderBarrier(this._hole);
  Rect? _hole;
  set hole(Rect? v) {
    if (v == _hole) return;
    _hole = v;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  // Taps on the dim area are blocked; taps inside the hole fall through to
  // the real widget underneath, so the user presses the actual button.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final hole = _hole;
    if (hole != null && hole.shift(-_origin).contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  Offset get _origin => localToGlobal(Offset.zero);

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final full = offset & size;
    final hole = _hole;
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.6);
    if (hole == null) {
      canvas.drawRect(full, dim);
      return;
    }
    final r = RRect.fromRectAndRadius(
      hole.shift(offset - _origin),
      const Radius.circular(12),
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(r),
      ),
      dim,
    );
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0xFFFFC53D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}

// ── Pointing hand that bobs next to the target ───────────────────────────────

class _PointingHand extends StatefulWidget {
  final Rect hole;
  final Size screen;
  const _PointingHand({required this.hole, required this.screen});

  @override
  State<_PointingHand> createState() => _PointingHandState();
}

class _PointingHandState extends State<_PointingHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _a.stop();
    } else if (!_a.isAnimating) {
      _a.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const s = 40.0;
    final below = widget.hole.bottom + s + 8 < widget.screen.height;
    final left =
        (widget.hole.center.dx - s / 2).clamp(4.0, widget.screen.width - s - 4);
    return Positioned(
      left: left,
      top: below ? widget.hole.bottom + 4 : widget.hole.top - s - 4,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, (below ? 1 : -1) * 6 * _a.value),
              child: child,
            ),
            child: Text(
              below ? '👆' : '👇',
              style: const TextStyle(
                fontSize: s - 6,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Instruction card ─────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final MangoController controller;
  final bool atTop;
  final bool missing;
  const _StepCard({
    required this.controller,
    required this.atTop,
    required this.missing,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final guide = c.guide!;
    final pad = MediaQuery.paddingOf(context);
    final done = c.done;
    return Positioned(
      left: 12,
      right: 12,
      top: atTop ? pad.top + 12 : null,
      bottom: atTop
          ? null
          : pad.bottom + MediaQuery.viewInsetsOf(context).bottom + 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: AppColors.surface,
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _MangoFace(size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          done
                              ? guide.title
                              : '${guide.title} · ${c.stepIndex + 1}/${guide.steps.length}',
                          style: AppTypography.label
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      IconButton(
                        // No tooltip: this layer sits above the app's Overlay.
                        icon: const Icon(
                          Icons.close_rounded,
                          semanticLabel: 'Close guide',
                        ),
                        onPressed: c.exit,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      done
                          ? "Nice work! That's it. Tap Ask Mango 🥭 any time you need help."
                          : c.step!.text,
                      style: AppTypography.body
                          .copyWith(color: AppColors.textPrimary, height: 1.35),
                    ),
                  ),
                  if (missing) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Can't see it here? Follow the earlier step, or tap Next.",
                      style: AppTypography.caption
                          .copyWith(color: AppColors.amber700),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (!c.isFirst || done)
                        TextButton(
                          onPressed: c.back,
                          child: const Text('Back'),
                        ),
                      const Spacer(),
                      if (done)
                        TextButton(
                          onPressed: c.replay,
                          child: const Text('Replay'),
                        )
                      else
                        TextButton(
                          onPressed: c.exit,
                          child: const Text('Skip'),
                        ),
                      const SizedBox(width: 4),
                      FilledButton(
                        // The app theme makes filled buttons full width.
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(88, 44),
                        ),
                        onPressed: done ? c.exit : c.next,
                        child: Text(
                          done
                              ? 'Done'
                              : c.isLast
                                  ? 'Finish'
                                  : 'Next',
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Guide picker ─────────────────────────────────────────────────────────────

class _Picker extends StatelessWidget {
  final MangoController controller;
  final List<({MangoGuide guide, bool here})> ranked;
  const _Picker({required this.controller, required this.ranked});

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Positioned.fill(
      child: GestureDetector(
        onTap: controller.exit,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.5),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // keep taps inside the panel
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.75,
                ),
                child: Material(
                  color: AppColors.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, pad.bottom + 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const _MangoFace(size: 44),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Hi! I am Mango. What do you want to do?',
                                style: AppTypography.h4,
                              ),
                            ),
                            IconButton(
                              // No tooltip: this layer sits above the app's Overlay.
                              icon: const Icon(
                                Icons.close_rounded,
                                semanticLabel: 'Close',
                              ),
                              onPressed: controller.exit,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final e in ranked)
                                ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  leading: Icon(
                                    e.here
                                        ? Icons.star_rounded
                                        : Icons.touch_app_rounded,
                                    color: e.here
                                        ? AppColors.amber600
                                        : AppColors.primaryMain,
                                  ),
                                  title: Text(e.guide.title),
                                  subtitle: e.here
                                      ? const Text('For this screen')
                                      : null,
                                  trailing:
                                      const Icon(Icons.chevron_right_rounded),
                                  onTap: () => controller.start(e.guide),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Button and character ─────────────────────────────────────────────────────

/// The 🥭 tab. Drag it anywhere; on release it snaps to the nearest side edge
/// (so it never parks over content) and the spot is remembered.
class _AskMangoButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AskMangoButton({required this.onTap});

  @override
  State<_AskMangoButton> createState() => _AskMangoButtonState();
}

class _AskMangoButtonState extends State<_AskMangoButton> {
  static const _prefsKey =
      'mango_button_pos'; // "L:0.60" = side : top as a fraction of height
  static const _w = 48.0, _h = 56.0;

  bool _right = false;
  double _yFraction = 0.6;
  Offset? _drag; // top-left while dragging

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved =
          (await SharedPreferences.getInstance()).getString(_prefsKey);
      final parts = saved?.split(':');
      final y = parts?.length == 2 ? double.tryParse(parts![1]) : null;
      if (y == null || !mounted) return;
      setState(() {
        _right = parts![0] == 'R';
        _yFraction = y.clamp(0.0, 1.0);
      });
    } catch (_) {
      // No saved spot: keep the default.
    }
  }

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance()).setString(
          _prefsKey, '${_right ? 'R' : 'L'}:${_yFraction.toStringAsFixed(3)}',);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final minY = pad.top + 8;
    final maxY = size.height - pad.bottom - _h - 8;
    final snappedTop = (minY + (maxY - minY) * _yFraction).clamp(minY, maxY);
    final drag = _drag;
    final radius = _right && drag == null
        ? const BorderRadius.horizontal(left: Radius.circular(24))
        : drag == null
            ? const BorderRadius.horizontal(right: Radius.circular(24))
            : BorderRadius.circular(24);

    return AnimatedPositioned(
      duration:
          drag == null ? const Duration(milliseconds: 220) : Duration.zero,
      curve: Curves.easeOut,
      left: drag?.dx ?? (_right ? size.width - _w : 0),
      top: drag?.dy ?? snappedTop,
      child: GestureDetector(
        onPanStart: (_) => setState(
            () => _drag = Offset(_right ? size.width - _w : 0, snappedTop),),
        onPanUpdate: (d) => setState(() {
          final next = _drag! + d.delta;
          _drag = Offset(
              next.dx.clamp(0, size.width - _w), next.dy.clamp(minY, maxY),);
        }),
        onPanEnd: (_) {
          final at = _drag!;
          setState(() {
            _right = at.dx + _w / 2 > size.width / 2;
            _yFraction = maxY > minY ? (at.dy - minY) / (maxY - minY) : 0.5;
            _drag = null;
          });
          _save();
        },
        child: Semantics(
          container: true,
          button: true,
          label: 'Ask Mango, app guide',
          child: Material(
            color: const Color(0xFFFFF4D6),
            elevation: drag == null ? 4 : 10,
            borderRadius: radius,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: radius,
              child: const SizedBox(
                width: _w,
                height: _h,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ExcludeSemantics(
                      child: Text('🥭', style: TextStyle(fontSize: 22)),
                    ),
                    Icon(
                      Icons.touch_app_rounded,
                      size: 14,
                      color: Color(0xFFB45309),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MangoFace extends StatelessWidget {
  final double size;
  const _MangoFace({required this.size});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF4D6),
            shape: BoxShape.circle,
          ),
          child: Text('🥭', style: TextStyle(fontSize: size * 0.55)),
        ),
      );
}

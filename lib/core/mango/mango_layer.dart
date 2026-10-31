import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mango_popups.dart';

/// Sits above the whole app (MaterialApp.router `builder`): the 🥭 button
/// that opens Mango AI. Drag it to either side; the spot is remembered. It
/// steps aside while a dialog or sheet is open or the keyboard is up.
class MangoLayer extends StatefulWidget {
  final Widget child;

  /// Whether the signed-in user gets Mango AI here (null route: hide).
  final bool Function() visible;
  final VoidCallback onAsk;

  /// Rebuild when this changes (route, session, popups).
  final Listenable? refresh;

  const MangoLayer({super.key, required this.child, required this.visible, required this.onAsk, this.refresh});

  @override
  State<MangoLayer> createState() => _MangoLayerState();
}

class _MangoLayerState extends State<MangoLayer> {
  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(MangoLayer old) {
    super.didUpdateWidget(old);
    if (old.refresh != widget.refresh) {
      old.refresh?.removeListener(_rebuild);
      widget.refresh?.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_rebuild);
    super.dispose();
  }

  // The router notifies while the tree below is still being built (first
  // frame); a setState then would mark this widget dirty mid-build.
  void _rebuild() => scheduleMicrotask(() {
        if (mounted) setState(() {});
      });

  @override
  Widget build(BuildContext context) {
    final inTheWay = mangoPopups.open.value > 0 || MediaQuery.viewInsetsOf(context).bottom > 0;
    return Stack(
      children: [
        widget.child,
        if (widget.visible() && !inTheWay) _AskMangoButton(onTap: widget.onAsk),
      ],
    );
  }
}

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
          label: 'Ask Mango AI',
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
                      Icons.mic_rounded,
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

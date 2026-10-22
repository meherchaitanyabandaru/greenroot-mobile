import 'package:flutter/material.dart';

/// Finds what a guide step points at: the visible, tappable widget showing a
/// label (Text, tooltip or semantics label). Hidden tabs (IndexedStack),
/// Offstage subtrees and pages covered by another route are ignored, so the
/// spotlight lands only on what the user can actually see and tap.
class MangoFinder {
  /// The element to spotlight for the first label that is on screen, or null.
  static Element? find(List<String> labels, {Element? root}) {
    if (labels.isEmpty) return null;
    final start = root ?? WidgetsBinding.instance.rootElement;
    if (start == null) return null;
    final wanted = labels.map(_norm).toList();
    Element? best;
    var bestRank = labels.length;
    void visit(Element e) {
      final label = _labelOf(e.widget);
      if (label != null) {
        final rank = wanted.indexOf(_norm(label));
        if (rank >= 0 && rank < bestRank && _visible(e)) {
          best = _tappableAncestor(e);
          bestRank = rank;
        }
      }
      e.visitChildElements(visit);
    }

    visit(start);
    return best;
  }

  /// Whether any of [labels] is currently visible.
  static bool onScreen(String label, {Element? root}) =>
      find([label], root: root) != null;

  /// On-screen rectangle of [e], or null if it is not laid out / visible.
  static Rect? rectOf(Element? e) {
    if (e == null || !e.mounted) return null;
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    final rect = ro.localToGlobal(Offset.zero) & ro.size;
    return rect.isEmpty ? null : rect;
  }

  static String _norm(String s) => s.trim().toLowerCase();

  static String? _labelOf(Widget w) {
    if (w is Text) return w.data ?? w.textSpan?.toPlainText();
    if (w is RichText) return w.text.toPlainText();
    if (w is Tooltip) return w.message;
    if (w is IconButton) return w.tooltip;
    if (w is Semantics) return w.properties.label;
    return null;
  }

  static Element _tappableAncestor(Element e) {
    Element found = e;
    var depth = 0;
    e.visitAncestorElements((a) {
      final w = a.widget;
      // Real controls win; their inner InkWell/GestureDetector come first on
      // the way up, so keep looking a few levels for the control itself.
      if (w is ButtonStyleButton ||
          w is ListTile ||
          w is IconButton ||
          w is TextField ||
          w is Checkbox) {
        found = a;
        return false;
      }
      // "I agree" text beside a checkbox: spotlight the row so both are tappable.
      if (depth < 25 && w is Row && _hasCheckbox(a)) {
        found = a;
        return false;
      }
      // A loose tap area only counts when close; far up it may be the page.
      if (identical(found, e) &&
          depth < 8 &&
          (w is InkWell || w is InkResponse || w is GestureDetector)) {
        found = a;
      }
      return ++depth < 40;
    });
    // Labels of text fields / checkboxes sit next to them, not inside: then
    // the label itself (or the nearest tap area) is spotlighted.
    return found;
  }

  static bool _hasCheckbox(Element row) {
    var has = false;
    void visit(Element e) {
      if (has) return;
      if (e.widget is Checkbox) {
        has = true;
      } else {
        e.visitChildElements(visit);
      }
    }

    row.visitChildElements(visit);
    return has;
  }

  static bool _visible(Element e) {
    if (MangoFinder.rectOf(e) == null) return false;
    final route = ModalRoute.of(e);
    if (route != null && !route.isCurrent) return false;
    var visible = true;
    Element child = e;
    e.visitAncestorElements((a) {
      final w = a.widget;
      if (w is Offstage && w.offstage) {
        visible = false;
      } else if (w is Visibility && !w.visible) {
        visible = false;
      } else if (w is IndexedStack) {
        final i = w.children.indexWhere((c) => identical(c, child.widget));
        if (i >= 0 && i != (w.index ?? 0)) visible = false;
      }
      child = a;
      return visible;
    });
    return visible;
  }
}

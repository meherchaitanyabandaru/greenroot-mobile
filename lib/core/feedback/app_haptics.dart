import 'package:flutter/services.dart';

/// One place for the app's haptic language, so every screen feels the same:
/// a firm tap when a step of an order or trip goes through, a heavy one when
/// something is refused, a light click when switching tabs.
class AppHaptics {
  AppHaptics._();

  static void success() => HapticFeedback.mediumImpact();

  static void error() => HapticFeedback.heavyImpact();

  static void tap() => HapticFeedback.selectionClick();
}

import 'package:flutter/services.dart';

/// Centralized haptic feedback for premium tactile responses.
abstract final class AppHaptics {
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();

  static void success() => HapticFeedback.mediumImpact();
  static void error() => HapticFeedback.heavyImpact();
  static void tap() => HapticFeedback.lightImpact();
}

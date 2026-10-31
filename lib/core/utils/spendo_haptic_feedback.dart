import 'package:flutter/services.dart';

/// Ergonomic haptic feedback utility for Spendo.
///
/// Provides consistent touch feedback patterns across the app while safely
/// handling devices without haptic hardware or unsupported platforms.
class SpendoHaptics {
  const SpendoHaptics._();

  /// Light impact feedback for quick interactive taps, chips, and small buttons.
  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      // Gracefully ignore on unsupported devices
    }
  }

  /// Medium impact feedback for state toggles, secondary actions, and sheet dismissals.
  static Future<void> medium() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Gracefully ignore on unsupported devices
    }
  }

  /// Success/Heavy impact feedback for critical confirmations, saves, or successfully completed tasks.
  static Future<void> success() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Gracefully ignore on unsupported devices
    }
  }

  /// Selection click feedback for picker wheels, carousels, or segment switches.
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {
      // Gracefully ignore on unsupported devices
    }
  }
}

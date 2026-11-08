import 'package:flutter/material.dart';

/// Spendo FinTech Typography System.
/// Powered by Plus Jakarta Sans for high-precision, glanceable numbers
/// combined with Cairo for pristine Arabic typography and Heebo for Hebrew.
class AppTypography {
  AppTypography._();

  static const String numbersFont = 'PlusJakartaSans';
  static const String arabicFont = 'Cairo';
  static const String hebrewFont = 'Heebo';

  /// Default fallback fonts for Arabic and Hebrew glyph continuity
  static const List<String> fallbackFonts = ['Cairo', 'Heebo'];

  /// Large hero numbers, account balances, main KPI figures
  static TextStyle numberHero({
    Color? color,
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = 0.5,
    double? height,
  }) {
    return TextStyle(
      fontFamily: numbersFont,
      fontFamilyFallback: fallbackFonts,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Medium financial figures, transaction cards, rates, gauges
  static TextStyle numberMedium({
    Color? color,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = 0.3,
    double? height,
  }) {
    return TextStyle(
      fontFamily: numbersFont,
      fontFamilyFallback: fallbackFonts,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Small figures, dates, badges, phone numbers, national IDs
  static TextStyle numberSmall({
    Color? color,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 0.2,
    double? height,
  }) {
    return TextStyle(
      fontFamily: numbersFont,
      fontFamilyFallback: fallbackFonts,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Standard numbers style with configurable size and weight
  static TextStyle number({
    Color? color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 0.2,
    double? height,
  }) {
    return TextStyle(
      fontFamily: numbersFont,
      fontFamilyFallback: fallbackFonts,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

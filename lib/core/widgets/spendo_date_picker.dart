import 'package:flutter/material.dart';
import 'package:sanad_app/core/theme/app_colors.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';

/// A unified, Obsidian Dark & Daylight adaptive DatePicker utility for Spendo.
///
/// Fixes Flutter Material 3 invisible text bugs by strictly defining
/// both background and foreground contrast colors across both Dark & Light themes,
/// while providing ergonomic Birth Date picking (Year mode first).
class SpendoDatePicker {
  SpendoDatePicker._();

  /// Standard date picker for work logs, payments, vehicle logs, and debts.
  static Future<DateTime?> pickDate(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    DatePickerMode initialDatePickerMode = DatePickerMode.day,
    String? helpText,
    String cancelText = 'إلغاء',
    String confirmText = 'تأكيد',
  }) async {
    SpendoHaptics.light();
    return _showStyledPicker(
      context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDatePickerMode: initialDatePickerMode,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
    );
  }

  /// Specialized birth date picker: starts directly in Year mode for effortless navigation
  /// without requiring hundreds of clicks backwards.
  static Future<DateTime?> pickBirthDate(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String helpText = 'اختر سنة وتاريخ الميلاد',
    String cancelText = 'إلغاء',
    String confirmText = 'تأكيد',
  }) async {
    SpendoHaptics.light();
    final now = DateTime.now();
    final effectiveFirst = firstDate ?? DateTime(1930);
    final effectiveLast = lastDate ?? now;
    final effectiveInitial = initialDate ?? DateTime(now.year - 25, 1, 1);

    // Guard against initialDate being out of bounds
    final clampedInitial = effectiveInitial.isAfter(effectiveLast)
        ? effectiveLast
        : (effectiveInitial.isBefore(effectiveFirst) ? effectiveFirst : effectiveInitial);

    return _showStyledPicker(
      context,
      initialDate: clampedInitial,
      firstDate: effectiveFirst,
      lastDate: effectiveLast,
      initialDatePickerMode: DatePickerMode.year,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
    );
  }

  static Future<DateTime?> _showStyledPicker(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required DatePickerMode initialDatePickerMode,
    String? helpText,
    required String cancelText,
    required String confirmText,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF141418) : Colors.white;
    final surfaceHeader = isDark ? const Color(0xFF1B1B22) : const Color(0xFFF4F5F7);
    final surfaceBorder = isDark ? const Color(0xFF282832) : const Color(0xFFE2E4E8);
    final textWhite = isDark ? Colors.white : const Color(0xFF111827);
    final textMuted = isDark ? const Color(0xFF8E8E9A) : const Color(0xFF6B7280);
    const brandGreen = AppColors.spendoGreen;

    final themeData = ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: brandGreen,
              onPrimary: Colors.white,
              surface: bg,
              onSurface: textWhite,
              surfaceContainerHigh: bg,
              surfaceContainerHighest: bg,
            )
          : ColorScheme.light(
              primary: brandGreen,
              onPrimary: Colors.white,
              surface: bg,
              onSurface: textWhite,
              surfaceContainerHigh: bg,
              surfaceContainerHighest: bg,
            ),
      dialogTheme: DialogThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: surfaceBorder, width: 1.0),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: surfaceHeader,
        headerForegroundColor: textWhite,
        headerHeadlineStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textWhite,
          fontFamily: 'Cairo',
        ),
        headerHelpStyle: TextStyle(
          fontSize: 12,
          color: textMuted,
          fontFamily: 'Cairo',
        ),
        weekdayStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textMuted,
          fontFamily: 'Cairo',
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          if (states.contains(WidgetState.disabled)) {
            return textMuted.withValues(alpha: 0.35);
          }
          return textWhite;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return brandGreen;
          }
          return Colors.transparent;
        }),
        dayOverlayColor: WidgetStateProperty.all(brandGreen.withValues(alpha: 0.12)),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          if (states.contains(WidgetState.disabled)) {
            return textMuted.withValues(alpha: 0.35);
          }
          return textWhite;
        }),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return brandGreen;
          }
          return Colors.transparent;
        }),
        yearOverlayColor: WidgetStateProperty.all(brandGreen.withValues(alpha: 0.12)),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return brandGreen;
        }),
        todayBorder: const BorderSide(color: brandGreen, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: surfaceBorder, width: 1.0),
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: brandGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
      ),
    );

    return await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDatePickerMode: initialDatePickerMode,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Theme(
            data: themeData,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

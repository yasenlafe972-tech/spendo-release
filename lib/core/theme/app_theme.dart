import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const String _prefThemeKey = 'spendo_theme_mode_v1';
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static Future<void> initThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefThemeKey);
      if (saved == 'light') {
        themeModeNotifier.value = ThemeMode.light;
      } else if (saved == 'system') {
        themeModeNotifier.value = ThemeMode.system;
      } else {
        themeModeNotifier.value = ThemeMode.dark;
      }
    } catch (_) {}
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = mode == ThemeMode.light
          ? 'light'
          : (mode == ThemeMode.system ? 'system' : 'dark');
      await prefs.setString(_prefThemeKey, val);
    } catch (_) {}
  }

  static void toggleTheme() {
    if (themeModeNotifier.value == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }

  /// Eye-friendly Obsidian & Deep Slate Dark Theme (Revolut 10 inspired)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Cairo',
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.spendoGreen,
        secondary: AppColors.spendoMint,
        error: AppColors.dangerRed,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          fontFamily: 'Cairo',
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: AppColors.surfaceCardBorder,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: Colors.white,
        unselectedItemColor: AppColors.monoIcon,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  /// Calm, Eye-Friendly Light Theme (Revolut 10 Day Mode)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      fontFamily: 'Cairo',
      colorScheme: const ColorScheme.light(
        surface: Color(0xFFFFFFFF),
        primary: AppColors.spendoGreen,
        secondary: Color(0xFF059669),
        error: AppColors.dangerRed,
        onSurface: Color(0xFF111827),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: Color(0xFF111827),
          fontSize: 18,
          fontWeight: FontWeight.w800,
          fontFamily: 'Cairo',
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF111827),
        unselectedItemColor: Color(0xFF9CA3AF),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

/// Custom smooth page transition (Fade + Directional Slide + Subtle Scale)
/// for all Navigator.push routes across Spendo.
class SpendoPageTransitionsBuilder extends PageTransitionsBuilder {
  const SpendoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedEntry = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final curvedSecondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Incoming page slides smoothly from the leading edge with a soft fade & scale
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-0.08, 0.0),
        end: Offset.zero,
      ).animate(curvedEntry),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedEntry),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 0.97).animate(curvedSecondary),
          child: child,
        ),
      ),
    );
  }
}

class AppTheme {
  AppTheme._();

  static const String _prefThemeKey = 'spendo_theme_mode_v1';
  static const String _prefFontScaleKey = 'spendo_font_scale_v1';
  static const String prefFontScaleTsKey = 'spendo_font_scale_updated_at';
  static const String prefThemeTsKey = 'spendo_theme_mode_updated_at';
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);
  static final ValueNotifier<double> fontScaleNotifier =
      ValueNotifier<double>(1.0);

  static const PageTransitionsTheme _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: SpendoPageTransitionsBuilder(),
      TargetPlatform.iOS: SpendoPageTransitionsBuilder(),
      TargetPlatform.windows: SpendoPageTransitionsBuilder(),
      TargetPlatform.macOS: SpendoPageTransitionsBuilder(),
      TargetPlatform.linux: SpendoPageTransitionsBuilder(),
    },
  );

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

      final savedScale = prefs.getDouble(_prefFontScaleKey);
      if (savedScale != null && savedScale >= 0.80 && savedScale <= 1.25) {
        fontScaleNotifier.value = savedScale;
      }
    } catch (_) {}
  }

  static Future<void> setFontScale(double scale, {bool updateTimestamp = true}) async {
    final clamped = scale.clamp(0.80, 1.25);
    fontScaleNotifier.value = clamped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefFontScaleKey, clamped);
      if (updateTimestamp) {
        await prefs.setInt(prefFontScaleTsKey, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  static Future<void> setThemeMode(ThemeMode mode, {bool updateTimestamp = true}) async {
    themeModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = mode == ThemeMode.light
          ? 'light'
          : (mode == ThemeMode.system ? 'system' : 'dark');
      await prefs.setString(_prefThemeKey, val);
      if (updateTimestamp) {
        await prefs.setInt(prefThemeTsKey, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  static bool get isLightMode {
    if (themeModeNotifier.value == ThemeMode.light) return true;
    if (themeModeNotifier.value == ThemeMode.dark) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.light;
  }

  static bool get isDarkMode => !isLightMode;

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
      pageTransitionsTheme: _pageTransitionsTheme,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.spendoBlue,
        onPrimary: Colors.white,
        secondary: AppColors.spendoBlueLight,
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
      pageTransitionsTheme: _pageTransitionsTheme,
      colorScheme: const ColorScheme.light(
        surface: Color(0xFFFFFFFF),
        primary: AppColors.spendoBlue,
        onPrimary: Colors.white,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

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
}

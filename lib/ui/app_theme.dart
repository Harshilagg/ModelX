import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF7F5F3); // soft beige
  static const Color surface = Colors.white;
  static const Color primary = Color(0xFF0B0B0B); // near black
  static const Color muted = Color(0xFF8A8A8A);
  static const Color accent = Color(0xFFBFA17A); // subtle gold
  static const Color success = Color(0xFF2E7D32);
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        background: AppColors.background,
        surface: AppColors.surface,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.primary),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.primary),
        titleTextStyle: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      // cardTheme intentionally left minimal; individual components apply shadows
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          elevation: 4,
        ),
      ),
    );
  }
}

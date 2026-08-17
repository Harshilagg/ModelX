import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ModelX brand palette — the same tokens used on the marketing website,
/// so the app and the website read as one product.
class AppColors {
  static const Color paper = Color(0xFFFFFFFF);
  static const Color paperRaised = Color(0xFFFAFAF8);
  static const Color ink = Color(0xFF0A0A0A);
  static const Color inkSoft = Color(0xFF5C5C55);
  static const Color inkFaint = Color(0xFF8C8C83);
  static const Color line = Color(0xFFE3E3DC);
  static const Color lineStrong = Color(0xFFC7C7BC);

  /// The one warm accent — used sparingly (badges, highlights), never as
  /// the default button/link color.
  static const Color gold = Color(0xFF93712F);
  static const Color goldBg = Color(0xFFF1E6D3);

  /// Reserved for live/unread indicators and destructive actions only.
  static const Color select = Color(0xFFC6273A);

  static const Color success = Color(0xFF2E7D32);
  static const Color successBg = Color(0xFFE7F3E8);
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double pill = 999.0;
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final textTheme = GoogleFonts.archivoTextTheme(base.textTheme).copyWith(
      headlineSmall: GoogleFonts.archivo(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.ink,
      ),
      titleLarge: GoogleFonts.archivo(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      titleMedium: GoogleFonts.archivo(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: GoogleFonts.archivo(fontSize: 15, color: AppColors.ink),
      bodyMedium: GoogleFonts.archivo(fontSize: 14, color: AppColors.ink),
      bodySmall: GoogleFonts.archivo(fontSize: 12.5, color: AppColors.inkFaint),
      labelLarge: GoogleFonts.archivo(fontSize: 13, fontWeight: FontWeight.w600),
      labelSmall: GoogleFonts.archivo(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.inkFaint,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.paper,
      primaryColor: AppColors.ink,
      cardColor: AppColors.paper,
      dividerColor: AppColors.line,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.ink,
        onPrimary: AppColors.paper,
        secondary: AppColors.gold,
        onSecondary: AppColors.ink,
        surface: AppColors.paper,
        onSurface: AppColors.ink,
        error: AppColors.select,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.ink),
        titleTextStyle: GoogleFonts.archivo(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.paper,
        selectedItemColor: AppColors.ink,
        unselectedItemColor: AppColors.inkFaint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.paper,
          disabledBackgroundColor: AppColors.lineStrong,
          disabledForegroundColor: AppColors.paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          elevation: 0,
          textStyle: GoogleFonts.archivo(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.lineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: GoogleFonts.archivo(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          textStyle: GoogleFonts.archivo(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paperRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.select),
        ),
        hintStyle: GoogleFonts.archivo(color: AppColors.inkFaint, fontSize: 14.5),
        labelStyle: GoogleFonts.archivo(color: AppColors.inkSoft, fontSize: 14),
      ),
      iconTheme: const IconThemeData(color: AppColors.ink),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.ink),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.archivo(color: AppColors.paper, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    );
  }
}

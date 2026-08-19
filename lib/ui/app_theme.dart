import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ModelX brand palette — reasoned independently for the app itself
/// (fashion, casting, portfolios), not copied from the companion
/// website. "The light gallery, and the dark backstage": most surfaces
/// stay a bright paper-white reading ground; a deep "backstage" surface
/// is reserved for specific hero moments (profile heroes, feed leads,
/// onboarding, auth) rather than used as a whole-app theme.
class AppColors {
  static const Color paper = Color(0xFFFFFFFF);
  static const Color paperRaised = Color(0xFFFAFAF8);
  static const Color ink = Color(0xFF0A0A0A);
  static const Color inkSoft = Color(0xFF5C5C55);
  static const Color inkFaint = Color(0xFF8C8C83);
  static const Color line = Color(0xFFE3E3DC);
  static const Color lineStrong = Color(0xFFC7C7BC);

  /// Deep near-black "backstage" surface — hero bands and full-bleed
  /// moments only, never the app's default background.
  static const Color backstage = Color(0xFF111110);
  static const Color backstageRaised = Color(0xFF1B1A17);
  static const Color onBackstage = Color(0xFFF2EFE9);
  static const Color onBackstageSoft = Color(0xB3F2EFE9); // ~70% opacity

  /// The one warm accent — a richer antique brass than a "safe" muted
  /// gold, used with confidence but never as a button fill.
  static const Color gold = Color(0xFFB08A4C);
  static const Color goldBg = Color(0xFFF1E6D3);
  static const Color goldOnBackstage = Color(0xFFC7A164);

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

/// Shared elevation recipes — extracted so every raised surface in the
/// app (cards, dashboard chrome, sheets) draws from the same three
/// shadows instead of each screen inventing its own.
class AppShadows {
  static final List<BoxShadow> card = [
    BoxShadow(color: AppColors.ink.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
  ];
  static final List<BoxShadow> raised = [
    BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
  ];
  static final List<BoxShadow> overlay = [
    BoxShadow(color: AppColors.ink.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10)),
  ];
}

class AppIconSize {
  static const double xs = 14;
  static const double sm = 18;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;
}

/// Single-sourced 7-level type scale (display/heading/subheading/body/
/// caption/metadata/label). `ThemeData.textTheme` wires its slots to
/// these so existing `Theme.of(context).textTheme.X` call sites keep
/// resolving unchanged; new code can also reach these directly.
class AppTypography {
  static TextStyle get display => GoogleFonts.archivo(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.ink,
      );
  static TextStyle get heading => GoogleFonts.archivo(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.ink,
      );
  static TextStyle get subheading => GoogleFonts.archivo(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.ink,
      );
  static TextStyle get bodyEmphasized => GoogleFonts.archivo(fontSize: 15, color: AppColors.ink);
  static TextStyle get body => GoogleFonts.archivo(fontSize: 14, color: AppColors.ink);
  static TextStyle get caption => GoogleFonts.archivo(fontSize: 12.5, color: AppColors.inkFaint);

  /// Timestamps, counts, meta rows — distinct from [label]'s bold
  /// uppercase eyebrow voice, which shouldn't also carry this job.
  static TextStyle get metadata => GoogleFonts.archivo(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: AppColors.inkFaint,
      );
  static TextStyle get label => GoogleFonts.archivo(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.inkFaint,
      );

  /// The one serif accent — Bodoni Moda, restrained to hero/display
  /// moments (profile names, one emphasis word in a headline, a
  /// featured feed item). Never in lists, cards, chips, or nav.
  static TextStyle displayAccent({
    double fontSize = 40,
    Color color = AppColors.ink,
    FontWeight fontWeight = FontWeight.w500,
  }) =>
      GoogleFonts.bodoniModa(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: FontStyle.italic,
        color: color,
        height: 1.02,
      );
}

/// Small snackbar helper so error toasts read distinctly from success/
/// neutral ones instead of rendering identically ink-on-paper.
void showAppToast(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.select : AppColors.ink,
    ),
  );
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final textTheme = GoogleFonts.archivoTextTheme(base.textTheme).copyWith(
      displaySmall: AppTypography.display,
      headlineSmall: AppTypography.heading,
      titleLarge: AppTypography.subheading,
      titleMedium: GoogleFonts.archivo(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
      bodyLarge: AppTypography.bodyEmphasized,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.caption,
      labelLarge: GoogleFonts.archivo(fontSize: 13, fontWeight: FontWeight.w600),
      labelSmall: AppTypography.label,
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
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.ink,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.inkFaint,
        labelStyle: AppTypography.label.copyWith(letterSpacing: 0.2),
        unselectedLabelStyle: AppTypography.label.copyWith(letterSpacing: 0.2, fontWeight: FontWeight.w600),
        dividerColor: AppColors.line,
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

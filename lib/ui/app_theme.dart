import 'package:flutter/material.dart';
import 'app_type.dart';
import 'board_palette.dart';
import 'board_theme.dart';

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
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
  static final List<BoxShadow> raised = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  static final List<BoxShadow> overlay = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
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
/// The older type roles, now served by [AppType].
///
/// These are what the brand and agency screens still ask for. Like
/// [BoardType], each role forwards rather than being edited out of a
/// few hundred call sites at once, so those screens pick up Albert Sans
/// with the rest of the app and can be renamed as each is touched.
///
/// The weights drop. Archivo at 800 was doing the work of a display
/// face; Albert Sans at that weight reads as shouting, and the design
/// is a light one.
class AppTypography {
  static TextStyle get display =>
      AppType.display(fontSize: 34, color: AppColors.ink);

  static TextStyle get heading =>
      AppType.title(fontSize: 24, color: AppColors.ink);

  static TextStyle get subheading =>
      AppType.heading(fontSize: 19, color: AppColors.ink);

  static TextStyle get bodyEmphasized => AppType.body(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );

  static TextStyle get body => AppType.body(fontSize: 15, color: AppColors.ink);

  static TextStyle get caption =>
      AppType.body(fontSize: 13, color: AppColors.inkFaint);

  /// Timestamps, counts, meta rows.
  static TextStyle get metadata =>
      AppType.tabular(fontSize: 13, color: AppColors.inkFaint);

  /// The small eyebrow label. Floored at 13px for the same reason the
  /// board's monospace was: 11px is below a comfortable reading size,
  /// and the tracking that made it legible as capitals is gone.
  static TextStyle get label => AppType.label(color: AppColors.inkFaint);

  /// The serif accent is retired along with the rest. It was restrained
  /// to hero moments; the new direction has one family and no italic
  /// display voice, so this forwards rather than introducing a second
  /// face into screens that are otherwise consistent.
  static TextStyle displayAccent({
    double fontSize = 40,
    Color color = AppColors.ink,
    FontWeight fontWeight = FontWeight.w500,
  }) =>
      AppType.display(fontSize: fontSize, color: color, fontWeight: fontWeight);
}

/// Small snackbar helper so error toasts read distinctly from success/
/// neutral ones instead of rendering identically ink-on-paper.
void showAppToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? BoardColors.rejected : BoardColors.ink,
    ),
  );
}

class AppTheme {
  static ThemeData light() {
    final palette = BoardPalette.day();
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

    // Only the *type* moves here; every colour below is untouched.
    //
    // This is the furniture Flutter draws for us -- dialogs, snackbars,
    // pickers, the text inside Material buttons -- not the screens,
    // which still ask BoardType for their styles until they are
    // retyped. Pulling it off google_fonts now is worth doing early:
    // that package resolves Archivo over the network on first run, so
    // it sat on the startup path and made this theme impossible to
    // build offline or in a test at all.
    final textTheme = AppType.textTheme(palette);

    // Frame-level chrome — scaffold grounds, dialogs, snackbars, text
    // fields, progress — is pulled onto the Slate Nude palette so the
    // furniture Flutter draws for us matches the screens we draw
    // ourselves. AppColors itself is left alone: the brand and agency
    // sides still reference those constants directly, and retuning them
    // would restyle screens this redesign hasn't covered yet.
    return base.copyWith(
      scaffoldBackgroundColor: BoardColors.paper,
      primaryColor: BoardColors.ink,
      canvasColor: BoardColors.paper,
      cardColor: BoardColors.card,
      dividerColor: BoardColors.inkLine,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: BoardColors.ink,
        onPrimary: BoardColors.onInk,
        secondary: BoardColors.brass,
        onSecondary: BoardColors.ink,
        surface: BoardColors.paper,
        onSurface: BoardColors.ink,
        error: BoardColors.rejected,
        onError: BoardColors.onInk,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BoardColors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BoardColors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: BoardColors.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: BoardColors.ink,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.ink),
        titleTextStyle: AppType.heading(fontSize: 18, color: BoardColors.ink),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: BoardColors.paper,
        selectedItemColor: BoardColors.ink,
        unselectedItemColor: BoardColors.mushroom,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.ink,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.inkFaint,
        labelStyle: AppType.label(color: AppColors.ink),
        unselectedLabelStyle: AppType.label(color: AppColors.inkFaint),
        dividerColor: AppColors.line,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BoardColors.ink,
          foregroundColor: BoardColors.onInk,
          disabledBackgroundColor: BoardColors.mushroom,
          disabledForegroundColor: BoardColors.onInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          elevation: 0,
          textStyle: AppType.label(fontSize: 14.5, fontWeight: FontWeight.w600),
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
          textStyle: AppType.label(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          textStyle: AppType.label(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BoardColors.shell,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
        hintStyle: AppType.body(fontSize: 14.5, color: AppColors.inkFaint),
        labelStyle: AppType.label(fontSize: 14, color: AppColors.inkSoft),
      ),
      iconTheme: const IconThemeData(color: AppColors.ink),
      dividerTheme: DividerThemeData(
        color: BoardColors.inkLine,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BoardColors.ink,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BoardColors.ink,
        contentTextStyle: AppType.body(
          fontSize: 13.5,
          color: BoardColors.onInk,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[palette],
    );
  }

  /// Night.
  ///
  /// Built from [BoardPalette.night] and [AppType] rather than from the
  /// constants above, because [AppColors] has no dark half -- its `ink`
  /// and `line` are light-mode values and would read as mud on ink.
  ///
  /// This is deliberately not a shared builder with [light]. That one is
  /// still a hybrid: its furniture sits on the Slate Nude palette but its
  /// type and several of its component themes still reach into
  /// [AppColors], and unpicking that is what retyping the screens does.
  /// Folding the two together now would mean changing light on the way
  /// past, which is exactly the visible regression this step must not
  /// have. They converge once the screens are migrated.
  ///
  /// Not reachable while `kThemeSwitchingEnabled` is false. Onboarding
  /// uses it directly all the same, through a local [Theme] override, so
  /// it is exercised from the day it lands rather than sitting unproven
  /// until the flag flips.
  static ThemeData night() {
    final palette = BoardPalette.night();
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    final textTheme = AppType.textTheme(palette);

    return base.copyWith(
      scaffoldBackgroundColor: palette.surface,
      primaryColor: palette.onSurface,
      canvasColor: palette.surface,
      cardColor: palette.surfaceRaised,
      dividerColor: palette.line,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: palette.onSurface,
        onPrimary: palette.surface,
        secondary: palette.brass,
        onSecondary: palette.ink,
        surface: palette.surface,
        onSurface: palette.onSurface,
        // The tint, not the fill: full-strength rejected is a block
        // colour and goes muddy as a word on ink.
        error: palette.rejectedText,
        onError: palette.ink,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surfaceRaised,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfaceRaised,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.onSurface,
        centerTitle: false,
        iconTheme: IconThemeData(color: palette.onSurface),
        titleTextStyle: AppType.heading(fontSize: 18, color: palette.onSurface),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.onSurface,
        unselectedItemColor: palette.onSurfaceFaint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: palette.onSurface,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: palette.onSurface,
        unselectedLabelColor: palette.onSurfaceFaint,
        labelStyle: AppType.label(color: palette.onSurface),
        unselectedLabelStyle: AppType.label(color: palette.onSurfaceFaint),
        dividerColor: palette.line,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.onSurface,
          foregroundColor: palette.surface,
          disabledBackgroundColor: palette.well,
          disabledForegroundColor: palette.onSurfaceFaint,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          elevation: 0,
          textStyle: AppType.label(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.onSurface,
          side: BorderSide(color: palette.lineStrong),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: AppType.label(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.onSurface,
          textStyle: AppType.label(fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceField,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: _nightBorder(palette.line),
        enabledBorder: _nightBorder(palette.line),
        focusedBorder: _nightBorder(palette.onSurfaceSoft, width: 1.4),
        errorBorder: _nightBorder(palette.rejectedText),
        focusedErrorBorder: _nightBorder(palette.rejectedText, width: 1.4),
        hintStyle: AppType.body(fontSize: 16, color: palette.onSurfaceFaint),
        labelStyle: AppType.label(color: palette.onSurfaceSoft),
      ),
      iconTheme: IconThemeData(color: palette.onSurface),
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.onSurface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceRaised,
        contentTextStyle: AppType.body(color: palette.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BoardRadius.panel),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[palette],
    );
  }

  static OutlineInputBorder _nightBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(BoardRadius.panel),
        borderSide: BorderSide(color: color, width: width),
      );
}

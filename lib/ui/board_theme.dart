import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "The Board" — the departures-board design language from the style
/// board (option 1a, "quiet colour").
///
/// The metaphor is an airport departures board: castings are departures,
/// the roster is a board, and statuses settle into place like split-flap
/// tiles. Three type roles carry it — condensed all-caps for titles,
/// Archivo for prose, and a monospace for anything numeric (times,
/// measurements, money, tags).
///
/// This sits alongside [AppColors]/[AppTypography] in `app_theme.dart`
/// rather than replacing them: the brand and agency sides of the app
/// still render on the older palette, so both have to keep compiling
/// until those screens migrate too.
/// Slate Nude — warm neutrals plus muted signals.
///
/// Paper and ink are unchanged; everything between them was retuned warm
/// so a mixed board reads as one object rather than as a page with
/// stickers on it. There is a single accent — brass, for money and the
/// comp card — and three status hues held inside one lightness band, so
/// a row of green, amber and red sits flat instead of one shouting.
class BoardColors {
  // ---- Structure -----------------------------------------------------

  /// Page ground.
  static const Color paper = Color(0xFFF4F2EC);

  /// Inactive fills — unselected chips, search fields, quiet wells.
  static const Color shell = Color(0xFFE4E0D4);

  /// A neutral fill and nothing else. Never a text colour, and never a
  /// background for coloured text.
  static const Color mushroom = Color(0xFFA7A08F);

  /// Panels and the nav bar — the mid-dark surface between paper and ink.
  static const Color slate = Color(0xFF474843);

  /// The strongest surface. Heroes, the board, primary buttons.
  static const Color ink = Color(0xFF141513);

  /// The one accent: money, and the comp card.
  static const Color brass = Color(0xFFC29A60);

  /// Cards that must lift off [paper]. The palette has no lighter step
  /// than paper, so a raised card keeps plain white and earns its
  /// separation from elevation rather than hue.
  static const Color card = Color(0xFFFFFFFF);

  // ---- Status --------------------------------------------------------

  static const Color booked = Color(0xFF436B4C);
  static const Color negotiating = Color(0xFFB4832A);
  static const Color rejected = Color(0xFFA33B2E);

  /// Applied is deliberately not a hue — it is the absence of news.
  static const Color applied = slate;

  // ---- Text tints ----------------------------------------------------
  //
  // Slate and brass share a lightness band, so a full-strength coloured
  // word on slate collapses into it. Full-strength brass, green, amber
  // and red are fills only; these tints are what a coloured *word* uses
  // when it has to sit on slate. On ink, use the full-strength colour.

  static const Color brassText = Color(0xFFD9B57C);
  static const Color bookedText = Color(0xFF8FB394);
  static const Color negotiatingText = Color(0xFFD8B573);
  static const Color rejectedText = Color(0xFFD6907F);

  /// The readable text form of [fill] for a word sitting on [slate].
  /// Anything without a tint is left alone, so this is safe to wrap
  /// around any accent.
  static Color textOnSlate(Color fill) {
    if (fill == brass) return brassText;
    if (fill == booked) return bookedText;
    if (fill == negotiating) return negotiatingText;
    if (fill == rejected) return rejectedText;
    return fill;
  }

  // ---- Derived ink-on-surface values ---------------------------------

  static const Color onInk = Color(0xFFF4F2EC);
  static final Color onInkSoft = const Color(0xFFF4F2EC).withValues(alpha: 0.66);
  static final Color onInkFaint = const Color(0xFFF4F2EC).withValues(alpha: 0.62);
  static final Color onInkLine = const Color(0xFFF4F2EC).withValues(alpha: 0.16);
  static final Color onInkWell = const Color(0xFFF4F2EC).withValues(alpha: 0.12);

  static final Color inkSoft = const Color(0xFF141513).withValues(alpha: 0.72);
  static final Color inkLine = const Color(0xFF141513).withValues(alpha: 0.14);
  static final Color inkLineStrong = const Color(0xFF141513).withValues(alpha: 0.25);
  static final Color inkWell = const Color(0xFF141513).withValues(alpha: 0.08);

  /// Scrim behind a spec sheet.
  static final Color scrim = const Color(0xFF141513).withValues(alpha: 0.55);
}

/// The three type roles. Nothing in this design system uses a font
/// outside these — a fourth voice is how a board stops reading as one.
class BoardType {
  /// Saira Condensed 700, uppercase. Screen titles and card titles only:
  /// never a list row, a chip, or a nav label's body.
  static TextStyle display({
    double fontSize = 34,
    Color color = BoardColors.ink,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = 0.3,
    double height = 0.92,
  }) =>
      GoogleFonts.sairaCondensed(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Saira Condensed 600 — the smaller title voice used for row titles,
  /// tab labels and buttons.
  static TextStyle title({
    double fontSize = 16,
    Color color = BoardColors.ink,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 0.6,
  }) =>
      GoogleFonts.sairaCondensed(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.05,
      );

  /// Archivo — prose. Descriptions, captions, bios. 12.5–15px.
  static TextStyle body({
    double fontSize = 13,
    Color color = BoardColors.ink,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.45,
  }) =>
      GoogleFonts.archivo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  /// IBM Plex Mono — times, measurements, money, counts, tags, and every
  /// small uppercase label. If it is a number or a key, it is mono.
  static TextStyle mono({
    double fontSize = 10,
    Color color = BoardColors.ink,
    FontWeight fontWeight = FontWeight.w500,
    double letterSpacing = 0.8,
    double height = 1.1,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// The recurring eyebrow above a section — mono, wide-tracked, muted.
  static TextStyle sectionLabel({Color? color}) => GoogleFonts.ibmPlexMono(
        fontSize: 9.5,
        fontWeight: FontWeight.w500,
        color: color ?? BoardColors.inkSoft,
        letterSpacing: 1.35,
        height: 1.1,
      );
}

class BoardRadius {
  static const double tile = 4;
  static const double chip = 3;
  static const double card = 10;
  static const double panel = 12;
  static const double sheet = 18;
  static const double pill = 999;
}

/// The corner-cut silhouette used for anything standing in for a comp
/// card: portfolio tiles, profile photos, network crops.
///
/// Mirrors the design's
/// `clip-path: polygon(0 0, calc(100% - N) 0, 100% N, 100% 100%, 0 100%)`.
class CompCardClipper extends CustomClipper<Path> {
  final double cut;
  const CompCardClipper({this.cut = 20});

  @override
  Path getClip(Size size) {
    // Never let the notch exceed the box, or the path inverts on very
    // small tiles (a 44x52 network crop asks for a 12px cut, but a
    // narrow column can shrink that box further).
    final c = cut.clamp(0.0, size.shortestSide / 2);
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - c, 0)
      ..lineTo(size.width, c)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(CompCardClipper oldClipper) => oldClipper.cut != cut;
}

/// A placeholder fill for imagery that hasn't loaded or doesn't exist —
/// the diagonal hatch from the style board, so an empty crop still reads
/// as a deliberate slot rather than a broken image.
class BoardHatch extends StatelessWidget {
  final bool dark;
  final Widget? child;
  const BoardHatch({super.key, this.dark = false, this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HatchPainter(dark: dark),
      child: child ?? const SizedBox.expand(),
    );
  }
}

class _HatchPainter extends CustomPainter {
  final bool dark;
  _HatchPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final base = dark ? const Color(0xFF1D1E1A) : const Color(0xFFCBC8BD);
    final stripe = dark ? const Color(0xFF2A2B27) : const Color(0xFFD6D3C9);
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    final paint = Paint()
      ..color = stripe
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;

    // 135° hatch, 14px period. Start far enough left that the diagonals
    // still cover the top-right corner.
    for (double x = -size.height; x < size.width + size.height; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => oldDelegate.dark != dark;
}

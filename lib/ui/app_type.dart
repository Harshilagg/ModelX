import 'package:flutter/material.dart';

import 'board_palette.dart';

/// Albert Sans, in six roles.
///
/// This replaces [BoardType], whose three voices -- condensed all-caps
/// titles, Archivo prose and a tracked monospace for anything numeric --
/// carried the departures-board metaphor. That metaphor is retired, and
/// with it the shouting: everything here is one family, sentence case,
/// and light.
///
/// Two things are deliberate.
///
/// The family is *bundled*, not fetched. `google_fonts` resolves over
/// the network on first run, which on a dark, text-first splash shows a
/// frame of fallback type and, on a cold offline start, never resolves
/// at all. The cost is ~130KB in the bundle.
///
/// Because Google publishes Albert Sans only as a variable font, weight
/// is set twice: [FontVariation] drives the actual `wght` axis, and
/// `fontWeight` is set alongside it so that anything reading the style
/// back -- a test, a `TextStyle.merge`, synthetic bolding on a fallback
/// family -- still sees the intended weight. Setting only one of the two
/// is the usual way variable fonts render flat.
class AppType {
  const AppType._();

  static const String family = 'Albert Sans';

  static TextStyle _base({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    Color? color,
    double? letterSpacing,
    bool tabular = false,
  }) => TextStyle(
    fontFamily: family,
    fontSize: fontSize,
    fontWeight: fontWeight,
    // The axis, and the label for it. See the class doc.
    fontVariations: [FontVariation('wght', fontWeight.value.toDouble())],
    height: height,
    color: color,
    letterSpacing: letterSpacing,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );

  /// The largest voice: splash and success headlines, screen heroes.
  static TextStyle display({
    double fontSize = 36,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.08,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    // -0.03em. Albert Sans opens up noticeably at display sizes, and
    // without this the headlines read loose against the prototype.
    letterSpacing: fontSize * -0.03,
  );

  /// Step and section titles -- the 28px voice the signup steps open on.
  static TextStyle title({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.1,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: fontSize * -0.03,
  );

  /// Row titles, card titles, tab labels, button labels.
  static TextStyle heading({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double height = 1.2,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  );

  /// Prose. Descriptions, hints, bios.
  static TextStyle body({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.5,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  );

  /// Field labels, meta, chips, status badges.
  ///
  /// This is what the old 9.5--10px monospace label becomes. The size
  /// change is the point: that voice was used 83 times, below a
  /// comfortable reading size, and tracked uppercase on top of it.
  static TextStyle label({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double height = 1.3,
    bool tabular = false,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    tabular: tabular,
  );

  /// Legal lines, counters, the quietest meta.
  static TextStyle caption({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.5,
    bool tabular = false,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    tabular: tabular,
  );

  /// Figures that sit in a column or change in place -- prices, counts,
  /// measurements, timers, "Step 2 of 4".
  ///
  /// With the monospace retired there is nothing else holding these
  /// still: proportional digits are different widths, so a count ticking
  /// 8 -> 9 -> 10 shifts everything beside it. Prose numbers ("about two
  /// minutes") do not need this and should not use it.
  static TextStyle tabular({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double height = 1.3,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    tabular: true,
  );

  /// The family applied across Material's own text slots, so widgets we
  /// do not own -- dialogs, snackbars, pickers -- come along too.
  static TextTheme textTheme(BoardPalette palette) {
    final on = palette.onSurface;
    final soft = palette.onSurfaceSoft;
    return TextTheme(
      displayLarge: display(fontSize: 44, color: on),
      displayMedium: display(color: on),
      displaySmall: title(fontSize: 32, color: on),
      headlineLarge: title(color: on),
      headlineMedium: title(fontSize: 24, color: on),
      headlineSmall: heading(fontSize: 22, color: on),
      titleLarge: heading(color: on),
      titleMedium: heading(fontSize: 17, color: on),
      titleSmall: heading(fontSize: 15, color: on),
      bodyLarge: body(fontSize: 16, color: on),
      bodyMedium: body(color: on),
      bodySmall: body(fontSize: 13, color: soft),
      labelLarge: label(fontSize: 15, color: on),
      labelMedium: label(color: on),
      labelSmall: caption(color: soft),
    );
  }
}

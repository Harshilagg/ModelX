import 'package:flutter/material.dart';

import 'board_theme.dart';

/// Slate Nude, resolved against the current brightness.
///
/// [BoardColors] holds the same palette as compile-time constants, which
/// is why it cannot serve two themes: its derived alpha values are
/// `static final`, so they bind once at class-load and never see a
/// brightness. This extension is the same palette expressed as instance
/// fields, which a screen reads through [BoardColors.of].
///
/// The important part is the naming. Day and night do not shuffle the
/// palette, they *swap two of its members*: in day, paper is the surface
/// and ink is the text; in night those trade places. A screen written
/// against `paper` and `ink` therefore cannot be made to work in both,
/// while a screen written against `surface` and `onSurface` gets night
/// for free. So the brand names stay for the things that genuinely do
/// not move -- brass, the status hues, slate panels -- and everything
/// structural is named for the job it does.
@immutable
class BoardPalette extends ThemeExtension<BoardPalette> {
  // ---- Brand constants, identical in both themes ---------------------

  final Color paper;
  final Color shell;
  final Color mushroom;
  final Color slate;
  final Color ink;
  final Color brass;

  // ---- Status --------------------------------------------------------

  final Color booked;
  final Color negotiating;
  final Color rejected;
  final Color applied;

  /// The readable *text* forms of the accents. Slate and brass share a
  /// lightness band, so a full-strength coloured word laid on slate
  /// collapses into it; these tints are what a coloured word uses there,
  /// and on any dark surface. See [readable].
  final Color brassText;
  final Color bookedText;
  final Color negotiatingText;
  final Color rejectedText;

  // ---- Structure, resolved per brightness ----------------------------

  /// The page ground.
  final Color surface;

  /// A card that must lift off [surface]. Day has no step lighter than
  /// paper, so a raised card is plain white and earns separation from
  /// elevation rather than hue; night steps up from ink instead.
  final Color surfaceRaised;

  /// Inactive fills -- unselected chips, search and form fields, wells.
  final Color surfaceField;

  /// The mid-dark panel between surface and its opposite. Slate in both
  /// themes, which is what keeps the "coloured words sit on ink, never
  /// on slate" rule meaningful after dark.
  final Color panel;

  // ---- Foregrounds ---------------------------------------------------

  final Color onSurface;
  final Color onSurfaceSoft;
  final Color onSurfaceFaint;

  /// Text on [panel] and on [ink] -- always the light tone, both themes.
  final Color onPanel;
  final Color onPanelSoft;

  // ---- Hairlines and veils -------------------------------------------

  final Color line;
  final Color lineStrong;
  final Color well;
  final Color scrim;

  const BoardPalette({
    required this.paper,
    required this.shell,
    required this.mushroom,
    required this.slate,
    required this.ink,
    required this.brass,
    required this.booked,
    required this.negotiating,
    required this.rejected,
    required this.applied,
    required this.brassText,
    required this.bookedText,
    required this.negotiatingText,
    required this.rejectedText,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceField,
    required this.panel,
    required this.onSurface,
    required this.onSurfaceSoft,
    required this.onSurfaceFaint,
    required this.onPanel,
    required this.onPanelSoft,
    required this.line,
    required this.lineStrong,
    required this.well,
    required this.scrim,
  });

  /// The palette exactly as it renders today. Every value here is lifted
  /// from [BoardColors] unchanged, so a screen moved onto this extension
  /// must look pixel-identical in light mode.
  factory BoardPalette.day() => BoardPalette(
        paper: BoardColors.paper,
        shell: BoardColors.shell,
        mushroom: BoardColors.mushroom,
        slate: BoardColors.slate,
        ink: BoardColors.ink,
        brass: BoardColors.brass,
        booked: BoardColors.booked,
        negotiating: BoardColors.negotiating,
        rejected: BoardColors.rejected,
        applied: BoardColors.applied,
        brassText: BoardColors.brassText,
        bookedText: BoardColors.bookedText,
        negotiatingText: BoardColors.negotiatingText,
        rejectedText: BoardColors.rejectedText,
        surface: BoardColors.paper,
        surfaceRaised: BoardColors.card,
        surfaceField: BoardColors.shell,
        panel: BoardColors.slate,
        onSurface: BoardColors.ink,
        onSurfaceSoft: BoardColors.inkSoft,
        onSurfaceFaint: BoardColors.ink.withValues(alpha: 0.55),
        onPanel: BoardColors.onInk,
        onPanelSoft: BoardColors.onInkSoft,
        line: BoardColors.inkLine,
        lineStrong: BoardColors.inkLineStrong,
        well: BoardColors.inkWell,
        scrim: BoardColors.scrim,
      );

  /// Night. No hue is invented: the surface and foreground roles simply
  /// trade ends of the existing ramp, and the accents keep their text
  /// tints -- which were already designed to be read on a dark ground.
  ///
  /// The one genuinely new value is [surfaceField]. Ink is the darkest
  /// step the palette has, so a form field on ink had nowhere to go; this
  /// is a single step up from it, matching the prototype's field tone.
  factory BoardPalette.night() => BoardPalette(
        paper: BoardColors.paper,
        shell: BoardColors.shell,
        mushroom: BoardColors.mushroom,
        slate: BoardColors.slate,
        ink: BoardColors.ink,
        brass: BoardColors.brass,
        booked: BoardColors.booked,
        negotiating: BoardColors.negotiating,
        rejected: BoardColors.rejected,
        applied: BoardColors.applied,
        brassText: BoardColors.brassText,
        bookedText: BoardColors.bookedText,
        negotiatingText: BoardColors.negotiatingText,
        rejectedText: BoardColors.rejectedText,
        surface: BoardColors.ink,
        surfaceRaised: nightField,
        surfaceField: nightField,
        panel: BoardColors.slate,
        onSurface: BoardColors.onInk,
        onSurfaceSoft: BoardColors.onInkSoft,
        onSurfaceFaint: BoardColors.onInkFaint,
        onPanel: BoardColors.onInk,
        onPanelSoft: BoardColors.onInkSoft,
        line: BoardColors.onInkLine,
        lineStrong: BoardColors.onInk.withValues(alpha: 0.25),
        well: BoardColors.onInkWell,
        scrim: BoardColors.ink.withValues(alpha: 0.72),
      );

  /// One step up from ink, for surfaces that have to separate from it.
  static const Color nightField = Color(0xFF1C1B19);

  /// The readable text form of [fill] for a word sitting on [panel], on
  /// [ink], or on any dark ground. Anything without a tint is returned
  /// unchanged, so this is safe to wrap around any colour.
  ///
  /// Mirrors [BoardColors.textOnSlate], kept as an instance method so a
  /// migrated screen has one thing to reach for rather than two.
  Color readable(Color fill) {
    if (fill == brass) return brassText;
    if (fill == booked) return bookedText;
    if (fill == negotiating) return negotiatingText;
    if (fill == rejected) return rejectedText;
    return fill;
  }

  /// True when this palette is the dark one. Occasionally a widget needs
  /// to branch on more than a colour -- picking an asset, or an overlay
  /// style -- and asking the palette is steadier than asking the
  /// ambient [Theme], which onboarding deliberately overrides.
  bool get isNight => surface == BoardColors.ink;

  @override
  BoardPalette copyWith({
    Color? paper,
    Color? shell,
    Color? mushroom,
    Color? slate,
    Color? ink,
    Color? brass,
    Color? booked,
    Color? negotiating,
    Color? rejected,
    Color? applied,
    Color? brassText,
    Color? bookedText,
    Color? negotiatingText,
    Color? rejectedText,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceField,
    Color? panel,
    Color? onSurface,
    Color? onSurfaceSoft,
    Color? onSurfaceFaint,
    Color? onPanel,
    Color? onPanelSoft,
    Color? line,
    Color? lineStrong,
    Color? well,
    Color? scrim,
  }) =>
      BoardPalette(
        paper: paper ?? this.paper,
        shell: shell ?? this.shell,
        mushroom: mushroom ?? this.mushroom,
        slate: slate ?? this.slate,
        ink: ink ?? this.ink,
        brass: brass ?? this.brass,
        booked: booked ?? this.booked,
        negotiating: negotiating ?? this.negotiating,
        rejected: rejected ?? this.rejected,
        applied: applied ?? this.applied,
        brassText: brassText ?? this.brassText,
        bookedText: bookedText ?? this.bookedText,
        negotiatingText: negotiatingText ?? this.negotiatingText,
        rejectedText: rejectedText ?? this.rejectedText,
        surface: surface ?? this.surface,
        surfaceRaised: surfaceRaised ?? this.surfaceRaised,
        surfaceField: surfaceField ?? this.surfaceField,
        panel: panel ?? this.panel,
        onSurface: onSurface ?? this.onSurface,
        onSurfaceSoft: onSurfaceSoft ?? this.onSurfaceSoft,
        onSurfaceFaint: onSurfaceFaint ?? this.onSurfaceFaint,
        onPanel: onPanel ?? this.onPanel,
        onPanelSoft: onPanelSoft ?? this.onPanelSoft,
        line: line ?? this.line,
        lineStrong: lineStrong ?? this.lineStrong,
        well: well ?? this.well,
        scrim: scrim ?? this.scrim,
      );

  @override
  BoardPalette lerp(ThemeExtension<BoardPalette>? other, double t) {
    if (other is! BoardPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return BoardPalette(
      paper: c(paper, other.paper),
      shell: c(shell, other.shell),
      mushroom: c(mushroom, other.mushroom),
      slate: c(slate, other.slate),
      ink: c(ink, other.ink),
      brass: c(brass, other.brass),
      booked: c(booked, other.booked),
      negotiating: c(negotiating, other.negotiating),
      rejected: c(rejected, other.rejected),
      applied: c(applied, other.applied),
      brassText: c(brassText, other.brassText),
      bookedText: c(bookedText, other.bookedText),
      negotiatingText: c(negotiatingText, other.negotiatingText),
      rejectedText: c(rejectedText, other.rejectedText),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceField: c(surfaceField, other.surfaceField),
      panel: c(panel, other.panel),
      onSurface: c(onSurface, other.onSurface),
      onSurfaceSoft: c(onSurfaceSoft, other.onSurfaceSoft),
      onSurfaceFaint: c(onSurfaceFaint, other.onSurfaceFaint),
      onPanel: c(onPanel, other.onPanel),
      onPanelSoft: c(onPanelSoft, other.onPanelSoft),
      line: c(line, other.line),
      lineStrong: c(lineStrong, other.lineStrong),
      well: c(well, other.well),
      scrim: c(scrim, other.scrim),
    );
  }
}

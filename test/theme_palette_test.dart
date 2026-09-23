import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_modelx/ui/app_theme.dart';
import 'package:flutter_application_modelx/ui/app_type.dart';
import 'package:flutter_application_modelx/ui/board_palette.dart';
import 'package:flutter_application_modelx/ui/board_theme.dart';
import 'package:flutter_application_modelx/ui/theme_controller.dart';

void main() {
  // Neither theme may reach the network. Both now build their type
  // from the bundled Albert Sans, so if a google_fonts call creeps back
  // into either one, these tests fail rather than the app silently
  // gaining a font fetch on its startup path.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('day palette', () {
    // The point of this group: moving a screen onto the extension must
    // not change a single pixel in light mode. If one of these drifts,
    // the migration has silently restyled the migrated screens.
    final day = BoardPalette.day();

    test('structural roles resolve to the constants they replace', () {
      expect(day.surface, BoardColors.paper);
      expect(day.surfaceField, BoardColors.shell);
      expect(day.panel, BoardColors.slate);
      expect(day.onSurface, BoardColors.ink);
      expect(day.onSurfaceSoft, BoardColors.inkSoft);
      expect(day.onPanel, BoardColors.onInk);
      expect(day.onPanelSoft, BoardColors.onInkSoft);
      expect(day.line, BoardColors.inkLine);
      expect(day.lineStrong, BoardColors.inkLineStrong);
      expect(day.well, BoardColors.inkWell);
      expect(day.scrim, BoardColors.scrim);
    });

    test('a raised card is still plain white, not a tinted paper', () {
      // The palette has no step lighter than paper, so a card that must
      // lift off it earns separation from elevation rather than hue.
      expect(day.surfaceRaised, BoardColors.card);
    });

    test('accents and status hues are unchanged', () {
      expect(day.brass, BoardColors.brass);
      expect(day.booked, BoardColors.booked);
      expect(day.negotiating, BoardColors.negotiating);
      expect(day.rejected, BoardColors.rejected);
      expect(day.applied, BoardColors.slate);
    });
  });

  group('night palette', () {
    final day = BoardPalette.day();
    final night = BoardPalette.night();

    test('surface and foreground swap ends of the existing ramp', () {
      expect(night.surface, BoardColors.ink);
      expect(night.onSurface, BoardColors.onInk);
      expect(night.surface, day.onSurface);
      expect(night.onSurface, day.surface);
    });

    test('invents no hue beyond the one field tone', () {
      // Everything night uses must already exist in the palette, with
      // the single documented exception -- otherwise "the existing
      // palette stays" has quietly stopped being true.
      final known = {
        BoardColors.paper, BoardColors.shell, BoardColors.mushroom,
        BoardColors.slate, BoardColors.ink, BoardColors.brass,
        BoardColors.card, BoardColors.booked, BoardColors.negotiating,
        BoardColors.rejected, BoardColors.brassText, BoardColors.bookedText,
        BoardColors.negotiatingText, BoardColors.rejectedText,
        // onInk is deliberately absent: it is the same value as paper.
        // That is the whole trick night relies on -- the light end of
        // the ramp is one colour doing two jobs.
        BoardPalette.nightField,
      };
      for (final c in [
        night.surface, night.surfaceRaised, night.surfaceField,
        night.panel, night.onSurface, night.brass, night.booked,
        night.negotiating, night.rejected,
      ]) {
        expect(known, contains(c), reason: '$c is not a palette colour');
      }
    });

    test('slate stays the panel, so the tint-on-slate rule survives', () {
      // Coloured words sit on ink, never on slate -- on slate they drop
      // to their tint. That rule is only meaningful if slate is still
      // the panel after dark.
      expect(night.panel, BoardColors.slate);
      expect(night.readable(BoardColors.brass), BoardColors.brassText);
      expect(night.readable(BoardColors.booked), BoardColors.bookedText);
      expect(night.readable(BoardColors.rejected), BoardColors.rejectedText);
    });

    test('an untinted colour passes through readable() untouched', () {
      expect(night.readable(BoardColors.mushroom), BoardColors.mushroom);
    });

    test('isNight distinguishes the two', () {
      expect(night.isNight, isTrue);
      expect(day.isNight, isFalse);
    });
  });

  group('themes', () {
    test('both carry their palette as an extension', () {
      expect(AppTheme.light().extension<BoardPalette>()?.isNight, isFalse);
      expect(AppTheme.night().extension<BoardPalette>()?.isNight, isTrue);
    });

    testWidgets('BoardColors.of reads the ambient palette', (tester) async {
      late BoardPalette seen;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.night(),
        home: Builder(builder: (context) {
          seen = BoardColors.of(context);
          return const SizedBox();
        }),
      ));
      expect(seen.isNight, isTrue);
    });

    testWidgets('falls back to day when no extension is installed', (tester) async {
      // Most widget tests pump a bare MaterialApp. Those must keep
      // rendering what they render today rather than throwing.
      late BoardPalette seen;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          seen = BoardColors.of(context);
          return const SizedBox();
        }),
      ));
      expect(seen.isNight, isFalse);
      expect(seen.surface, BoardColors.paper);
    });
  });

  group('type', () {
    test('drives the variable weight axis, not just fontWeight', () {
      // Albert Sans ships only as a variable font. Setting fontWeight
      // alone renders every weight at the default axis position, which
      // is the usual way a variable font comes out flat.
      final s = AppType.heading(fontWeight: FontWeight.w600);
      expect(s.fontFamily, 'Albert Sans');
      expect(s.fontWeight, FontWeight.w600);
      expect(s.fontVariations?.single.value, 600);
    });

    test('tabular figures are opt-in, and on by default only for tabular()', () {
      expect(AppType.tabular().fontFeatures, isNotEmpty);
      expect(AppType.body().fontFeatures, isNull);
      expect(AppType.label(tabular: true).fontFeatures, isNotEmpty);
    });
  });

  group('theme switching gate', () {
    test('is pinned to light while disabled, whatever is stored', () {
      // Unmigrated screens have no dark treatment, so a stored
      // preference must not be able to reach MaterialApp yet.
      final c = ThemeController(ThemeMode.dark);
      expect(c.storedMode, ThemeMode.dark);
      expect(c.mode, kThemeSwitchingEnabled ? ThemeMode.dark : ThemeMode.light);
    });
  });
}

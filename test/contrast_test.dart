import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/ui/app_theme.dart';
import 'package:flutter_application_modelx/ui/board_palette.dart';
import 'package:flutter_application_modelx/ui/board_theme.dart';

/// Relative luminance, per WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Flattens a translucent colour onto an opaque one.
Color over(Color fg, Color bg) => Color.from(
      alpha: 1,
      red: fg.a * fg.r + (1 - fg.a) * bg.r,
      green: fg.a * fg.g + (1 - fg.a) * bg.g,
      blue: fg.a * fg.b + (1 - fg.a) * bg.b,
    );

void main() {
  // WCAG AA: 4.5:1 for body text, 3:1 for large text and glyphs.
  const bodyMinimum = 4.5;

  group('day theme', () {
    final day = BoardPalette.day();

    test('body text clears AA on every surface it lands on', () {
      for (final (surface, name) in [
        (day.surface, 'paper'),
        (day.surfaceRaised, 'card'),
        (day.surfaceField, 'shell'),
      ]) {
        expect(contrast(day.onSurface, surface), greaterThanOrEqualTo(bodyMinimum),
            reason: 'onSurface on $name');
        expect(contrast(over(day.onSurfaceSoft, surface), surface),
            greaterThanOrEqualTo(bodyMinimum),
            reason: 'onSurfaceSoft on $name');
      }
    });

    test('secondary text clears AA, after being darkened for it', () {
      // AppColors.inkFaint measured 3.03:1 on paper -- fine as an icon,
      // below the bar as the text colour it is used as in about thirty
      // places.
      expect(contrast(AppColors.inkFaint, BoardColors.paper),
          greaterThanOrEqualTo(bodyMinimum));
      expect(contrast(AppColors.inkFaint, BoardColors.shell),
          greaterThanOrEqualTo(4.4));
    });

    test('mushroom is never asked to be a foreground', () {
      // The palette's own rule. It measures 1.97:1 on shell, which is
      // below even the 3:1 a non-text glyph needs.
      expect(contrast(BoardColors.mushroom, BoardColors.shell), lessThan(3.0));
      final nav = AppTheme.light().bottomNavigationBarTheme.unselectedItemColor!;
      expect(nav, isNot(BoardColors.mushroom));
      expect(contrast(nav, BoardColors.paper), greaterThanOrEqualTo(3.0));
    });
  });

  group('night theme', () {
    final night = BoardPalette.night();

    test('body text clears AA on ink', () {
      expect(contrast(night.onSurface, night.surface),
          greaterThanOrEqualTo(bodyMinimum));
      expect(contrast(over(night.onSurfaceSoft, night.surface), night.surface),
          greaterThanOrEqualTo(bodyMinimum));
    });

    test('form fields are readable, not just distinguishable', () {
      expect(contrast(night.onSurface, night.surfaceField),
          greaterThanOrEqualTo(bodyMinimum));
    });

    test('the error tint reads on ink, where the full-strength hue does not', () {
      // This is why errors on dark use the tint: rejected at full
      // strength is a block colour and goes muddy as a word.
      expect(contrast(night.rejectedText, night.surface),
          greaterThanOrEqualTo(3.0));
      expect(contrast(night.rejectedText, night.surface),
          greaterThan(contrast(night.rejected, night.surface)));
    });

    test('amber needs ink on it, which is why the badge uses ink', () {
      expect(contrast(night.ink, night.negotiating),
          greaterThan(contrast(night.onPanel, night.negotiating)));
    });
  });
}

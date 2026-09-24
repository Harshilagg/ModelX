import 'package:flutter/material.dart';

/// The measurements the design repeats.
///
/// These are not suggestions -- the prototype is built on a small set of
/// sizes used everywhere, and the app's current cramped feel comes
/// largely from each screen inventing its own. Reading them from here is
/// what makes two screens built months apart line up.
class AppMetrics {
  const AppMetrics._();

  /// Side gutter on every screen. Also the minimum breathing room
  /// between content and a screen edge at phone width.
  static const double gutter = 24;

  /// Between one form field and the next.
  static const double fieldGap = 20;

  /// Between a step title (and its hint) and the first field under it.
  static const double titleGap = 28;

  /// Pill buttons, and anything that has to line up with them.
  static const double control = 57;

  /// The height of a single-line input.
  ///
  /// ---- CHANGE THIS to resize every input in the app ----
  ///
  /// Every text field, password field and date field in onboarding and
  /// the forms reads this one number, so raising it here resizes all of
  /// them together and nothing drifts out of alignment.
  ///
  /// The reference design puts this at 52, the same as a button. That
  /// is tight for a field that is mostly empty space: a button is
  /// filled and reads as substantial at 52, while an empty input at the
  /// same height reads as a thin bar. Kept separate from [control] for
  /// exactly that reason -- inputs and buttons do not have to match.
  ///
  /// Sensible range is roughly 52 to 64. Past that the form starts
  /// scrolling on a short phone.
  static const double field = 58;

  /// Chips, and the segmented control's inner buttons.
  static const double chip = 40;

  /// The smallest a tappable thing may be. Below this it is a miss
  /// waiting to happen -- several icon buttons in the app are currently
  /// under it.
  static const double tapTarget = 44;

  /// The progress rail above a multi-step form.
  static const double progressBar = 2;
  static const double progressGap = 4;

  /// Bottom inset that still clears a gesture bar when the device
  /// reports none. Mirrors the prototype's `max(20px, safe-area)`.
  ///
  /// Reads `padding`, not `viewPadding`: with the keyboard up, the
  /// gesture bar is behind it and `padding.bottom` correctly drops to
  /// zero, leaving just the design gutter. `viewPadding` ignores the
  /// keyboard and would push the footer up by a bar that is not there.
  static double bottomInset(BuildContext context, {double minimum = 20}) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return inset > minimum ? inset : minimum;
  }

  /// Matching top inset.
  static double topInset(BuildContext context, {double minimum = 12}) {
    final inset = MediaQuery.viewPaddingOf(context).top;
    return inset > minimum ? inset : minimum;
  }
}

/// Corner radii, as the new design uses them.
///
/// [BoardRadius] still holds the board-era values and is still correct
/// for the screens that have not been retyped; these are the ones the
/// prototype specifies.
class AppRadii {
  const AppRadii._();

  /// Inputs, panels, notices.
  static const double field = 12;

  /// Cards and photo frames.
  static const double card = 14;

  /// Photos inside the masonry.
  static const double photo = 10;

  /// Anything fully rounded. Buttons, chips, the progress rail.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  static BorderRadius get fieldRadius => BorderRadius.circular(field);
  static BorderRadius get cardRadius => BorderRadius.circular(card);
}

/// The durations and curves the prototype animates on.
///
/// Every one of these is disabled under [MediaQuery.disableAnimations];
/// widgets in this kit check that rather than each caller remembering to.
class AppMotion {
  const AppMotion._();

  /// Colour and transform changes on press or selection.
  static const Duration quick = Duration(milliseconds: 200);

  /// A selection ring, a dot fading in.
  static const Duration medium = Duration(milliseconds: 300);

  /// Step transitions.
  static const Duration step = Duration(milliseconds: 320);

  /// The progress rail filling, a card growing.
  static const Duration slow = Duration(milliseconds: 500);

  /// Greyscale resolving into colour.
  static const Duration reveal = Duration(milliseconds: 700);

  /// The prototype's `cubic-bezier(.22, 1, .36, 1)` -- a fast start that
  /// settles rather than bounces.
  static const Curve settle = Curves.easeOutQuint;

  static const Curve enter = Curves.easeOut;

  /// True when the platform asks for reduced motion. Animations should
  /// jump to their end state rather than being skipped, so nothing ends
  /// up invisible.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/app_theme.dart';
import '../ui/board_palette.dart';

/// Wraps an onboarding route so it is dark in both themes.
///
/// The decision was that onboarding stays dark whatever the phone is set
/// to. That is done here, as a local [Theme] override, rather than by
/// moving the app-wide mode: switching the global mode would drag every
/// screen behind this one into dark as well, and those screens have no
/// dark treatment yet.
///
/// It also means the dark theme is genuinely exercised from the day it
/// lands, instead of sitting unproven until day/night switching opens up.
class OnboardingTheme extends StatelessWidget {
  final Widget child;

  const OnboardingTheme({super.key, required this.child});

  /// The palette every onboarding screen draws with.
  ///
  /// Read this rather than `BoardColors.of(context)` when the context
  /// in question is the one that *installs* this widget. A page that
  /// returns `OnboardingTheme(...)` from its own build method sits
  /// above the Theme it is installing, so looking the palette up from
  /// there returns the app's theme, not this one -- which produced a
  /// light page with dark inputs, a white scrim over the splash
  /// masonry, and bone buttons invisible against bone paper.
  ///
  /// Descendants are below the Theme and can keep using
  /// `BoardColors.of(context)` as normal.
  static final BoardPalette palette = BoardPalette.night();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.night(),
      // The status bar icons have to be light here regardless of the
      // ambient theme, and restored on the way out -- otherwise the app
      // behind is left with white-on-white icons.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFF141513),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: child,
      ),
    );
  }
}

/// The photographs the onboarding ships with.
///
/// Bundled rather than fetched. The splash is the first thing a new user
/// sees, often on a cold start with no network yet, and the prototype's
/// remote URLs would have left it blank -- besides being someone else's
/// CDN on our launch path.
class OnboardingPhotos {
  const OnboardingPhotos._();

  static const String _masonryDir = 'assets/onboarding/masonry';

  /// Supplied portrait frames, in the order they were delivered.
  static const List<String> masonry = [
    '$_masonryDir/01.jpg',
    '$_masonryDir/02.jpg',
    '$_masonryDir/03.jpg',
    '$_masonryDir/04.jpg',
    '$_masonryDir/05.jpg',
    '$_masonryDir/06.jpg',
    '$_masonryDir/07.jpg',
    '$_masonryDir/08.jpg',
  ];

  static const String model = 'assets/onboarding/roles/model.jpg';
  static const String brand = 'assets/onboarding/roles/brand.jpg';
  static const String agency = 'assets/onboarding/roles/agency.jpg';

  /// Warms the image cache before the splash paints.
  ///
  /// Called while startup is already waiting on Firebase, so it costs no
  /// extra time and the first frame is never a grid of empty rectangles.
  /// Failures are ignored: a missing asset should not stop the app
  /// launching.
  static Future<void> precache(BuildContext context) async {
    await Future.wait([
      for (final path in [...masonry, model, brand, agency])
        precacheImage(AssetImage(path), context).catchError((_) {}),
    ]);
  }
}

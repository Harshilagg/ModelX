import 'package:flutter/material.dart';

import 'app_metrics.dart';

/// Black-and-white resolving into colour.
///
/// The same gesture appears three times in the onboarding -- the one lit
/// photo travelling through the splash masonry, the role card that comes
/// alive when you pick it, and the user's own photo turning to colour on
/// the success screen. It is the design's single recurring idea, so it is
/// one widget rather than three near-copies.
///
/// The prototype expresses it in CSS as
/// `filter: grayscale(1) brightness(.72)` relaxing to
/// `grayscale(0) brightness(1)`. There is no filter property on a Flutter
/// widget, so this builds the equivalent 4x5 colour matrix and animates
/// its two inputs.
class GreyscaleReveal extends StatelessWidget {
  /// 0 renders fully desaturated, 1 renders the image untouched.
  final double amount;

  /// Multiplies every channel. The prototype dims unlit photos to 0.72
  /// so the lit one reads as lit rather than merely colourful.
  final double dimmedBrightness;

  final Duration duration;
  final Curve curve;
  final Widget child;

  const GreyscaleReveal({
    super.key,
    required this.amount,
    required this.child,
    this.dimmedBrightness = 0.72,
    this.duration = AppMotion.reveal,
    this.curve = AppMotion.enter,
  });

  @override
  Widget build(BuildContext context) {
    // Under reduced motion the end state is applied immediately rather
    // than skipped -- a photo that never resolves would leave the whole
    // screen grey.
    final effective = AppMotion.reduced(context) ? Duration.zero : duration;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: amount, end: amount),
      duration: effective,
      curve: curve,
      builder: (context, t, child) => ColorFiltered(
        colorFilter: ColorFilter.matrix(
          saturationMatrix(
            saturation: t,
            // Brightness travels with saturation, so a half-revealed
            // photo is half-lit too.
            brightness: dimmedBrightness + (1 - dimmedBrightness) * t,
          ),
        ),
        child: child,
      ),
      child: child,
    );
  }

  /// The colour matrix for a given saturation and brightness.
  ///
  /// Desaturating means collapsing each channel onto the luminance of
  /// the pixel; the coefficients are the usual Rec. 709 weights, which
  /// is what a browser's `grayscale()` uses, so this matches the
  /// prototype rather than merely approximating it.
  ///
  /// Exposed for tests -- the visual result is hard to assert on, but
  /// the matrix is exact.
  static List<double> saturationMatrix({
    required double saturation,
    double brightness = 1,
  }) {
    const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
    final s = saturation.clamp(0.0, 1.0);
    final b = brightness;

    // Each row: how much of R, G and B survives into that channel.
    double keep(double lum) => b * (lum + (1 - lum) * s);
    double drop(double lum) => b * (lum - lum * s);

    return <double>[
      keep(lumR),
      drop(lumG),
      drop(lumB),
      0,
      0,
      drop(lumR),
      keep(lumG),
      drop(lumB),
      0,
      0,
      drop(lumR),
      drop(lumG),
      keep(lumB),
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }
}

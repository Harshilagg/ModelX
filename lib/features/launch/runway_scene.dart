import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The preloader's palette and fixed measurements.
///
/// The artboard is 390 x 844 and every coordinate in this file is in
/// that space. The painter scales it to the real screen once, so the
/// numbers below stay the numbers from the design rather than
/// fractions someone has to reverse-engineer.
class RunwayScene {
  const RunwayScene._();

  static const double boardWidth = 390;
  static const double boardHeight = 844;

  static const Color ground = Color(0xFF0B0B0B);
  static const Color light = Color(0xFFF2EFE8);
  static const Color floor = Color(0xFF111110);
  static const Color floorEdge = Color(0xFF262624);
  static const Color captionInk = Color(0xFFA8A59E);
  static const Color wordmarkOnDark = Color(0xFFF5F4F0);

  /// ---- CHANGE THIS to recolour the flood ----
  static const Color accent = Color(0xFF2A3FF5);

  /// The name is not final, so it lives in one place.
  static const String appName = 'ModelX';

  /// Wordmark ink. Reads against whatever the accent turns out to be:
  /// a light accent needs dark type on it.
  static Color wordmarkInk(Color accent) =>
      accent.computeLuminance() > 0.6 ? ground : wordmarkOnDark;

  // ---- The runway ----------------------------------------------------

  /// Where the floor converges.
  static const double horizon = 208;
  static const Offset vanishLeft = Offset(184, horizon);
  static const Offset vanishRight = Offset(206, horizon);
  static const Offset floorLeft = Offset(35, boardHeight);
  static const Offset floorRight = Offset(355, boardHeight);

  /// Seams, as (top x, bottom x) pairs.
  static const List<(double, double)> seams = [
    (188, 103),
    (191.5, 159),
    (198.5, 231),
    (202, 287),
  ];

  /// Edge lights: y, radius, and the half-width of the floor there.
  static const List<(double y, double radius, double halfWidth)> edgeLights = [
    (236, 0.67, 18.3),
    (262, 0.74, 25.1),
    (296, 0.82, 34.0),
    (340, 0.93, 45.5),
    (398, 1.08, 60.6),
    (472, 1.26, 79.9),
    (566, 1.50, 104.4),
    (684, 1.80, 135.2),
    (830, 2.16, 173.3),
  ];

  // ---- The mark and the walk -----------------------------------------

  /// Where the walk ends.
  static const Offset mark = Offset(195, 432);
  static const int stepCount = 9;

  /// Where step [i] lands and how big it is.
  ///
  /// The curve is the design's: t^1.25 so the steps crowd together
  /// near the horizon and open out as they come forward, which is what
  /// makes a flat plane read as receding.
  static ({Offset at, double scale}) step(int i) {
    final t = (i + 1) / stepCount;
    final y = 262 + 168 * math.pow(t, 1.25).toDouble();
    final scale = 0.32 + 0.68 * t;

    // The last step is both feet together on the mark; the rest
    // alternate to either side of the centre line.
    if (i == stepCount - 1) return (at: Offset(mark.dx, y), scale: scale);
    final side = i.isEven ? -1 : 1;
    return (at: Offset(mark.dx + side * 7 * scale, y), scale: scale);
  }

  /// A stiletto print: a sole and a heel.
  static void paintFoot(Canvas canvas, Offset at, double scale, Paint paint) {
    canvas.drawOval(
      Rect.fromCenter(
        center: at,
        width: 3.2 * scale * 2,
        height: 6.4 * scale * 2,
      ),
      paint,
    );
    canvas.drawCircle(at - Offset(0, 10.5 * scale), 1.6 * scale, paint);
  }

  /// Both feet on the mark, which is how the walk ends and what the
  /// reflection mirrors.
  static void paintFinalFeet(Canvas canvas, double scale, Paint paint) {
    for (final side in [-1, 1]) {
      paintFoot(
        canvas,
        Offset(mark.dx + side * 5.5 * scale, mark.dy),
        scale,
        paint,
      );
    }
  }

  // ---- The front row --------------------------------------------------

  /// A blurred figure in the front row: a head and a pair of shoulders.
  ///
  /// Each is drawn twice -- once offset upward as a faint rim light,
  /// once as the silhouette -- which is what stops them reading as
  /// flat holes in the scene.
  static const List<Silhouette> frontRowLeft = [
    Silhouette(
      head: Offset(2, 630),
      headRadius: 28,
      shoulders: 'M-52 780C-48 700 -26 660 2 660C30 660 50 700 56 780Z',
      rimOpacity: 0.11,
      rimOffset: Offset(4, -5),
      fill: frontRowFar,
    ),
    Silhouette(
      head: Offset(46, 744),
      headRadius: 42,
      shoulders: 'M-50 860C-48 800 0 792 46 794C98 792 140 804 152 860Z',
      rimOpacity: 0.17,
      rimOffset: Offset(5, -5),
      fill: frontRowNear,
    ),
  ];

  static const List<Silhouette> frontRowRight = [
    Silhouette(
      head: Offset(390, 656),
      headRadius: 24,
      shoulders: 'M344 790C348 720 366 684 390 684C414 684 432 720 436 790Z',
      rimOpacity: 0.10,
      rimOffset: Offset(-4, -5),
      fill: frontRowFar,
    ),
    Silhouette(
      head: Offset(352, 768),
      headRadius: 36,
      shoulders: 'M248 860C256 818 304 810 352 814C398 812 436 818 444 860Z',
      rimOpacity: 0.16,
      rimOffset: Offset(-5, -5),
      fill: frontRowNear,
    ),
  ];

  /// The closest figure, in front of both groups.
  static const Silhouette frontRowCentre = Silhouette(
    head: Offset(204, 806),
    headRadius: 40,
    shoulders: 'M126 900C132 846 168 838 204 838C242 838 276 846 282 900Z',
    rimOpacity: 0.17,
    rimOffset: Offset(0, -5),
    fill: frontRowNear,
  );

  /// The front row's two depths.
  ///
  /// ---- CHANGE THESE to make the crowd read more or less ----
  ///
  /// Both are lighter than [ground], which is the whole point. The
  /// design's own values were darker than the background -- #040404 and
  /// #020202 against #0B0B0B -- so the figures were holes cut in an
  /// already black screen and only their rim light gave them away.
  /// Lifting them above the ground is what turns them into shapes.
  ///
  /// [frontRowNear] stays the darker of the two. The closer figures
  /// catch less of the backlight, and keeping that order is what sorts
  /// them front to back.
  static const Color frontRowFar = Color(0xFF23211E);
  static const Color frontRowNear = Color(0xFF1A1815);

  /// The haze the front row sits against.
  static const Offset backlight = Offset(195, 800);
  static const Size backlightSize = Size(270, 120);

  // ---- Flashes --------------------------------------------------------

  /// Where a paparazzi flash blooms from, as (centre, radius). They
  /// come from off-screen: the cameras are never drawn.
  static const List<(Offset at, double radius)> flashes = [
    (Offset(-15, 424), 110),
    (Offset(390, 424), 100),
    (Offset(-10, 490), 85),
    (Offset(375, 445), 90),
    (Offset(-25, 400), 100),
    (Offset(390, 424), 100),
    (Offset(0, 444), 85),
    (Offset(0, 420), 85),
    (Offset(390, 436), 90),
  ];
}

/// One figure in the front row.
class Silhouette {
  final Offset head;
  final double headRadius;

  /// The shoulder line, as the design's own path data.
  final String shoulders;

  final double rimOpacity;
  final Offset rimOffset;
  final Color fill;

  const Silhouette({
    required this.head,
    required this.headRadius,
    required this.shoulders,
    required this.rimOpacity,
    required this.rimOffset,
    required this.fill,
  });

  /// The silhouette as a path.
  ///
  /// The shoulder curves are transcribed rather than parsed: a path
  /// string parser is a lot of surface for five fixed shapes that
  /// never change.
  Path build() {
    final path = Path()
      ..addOval(Rect.fromCircle(center: head, radius: headRadius));
    _appendShoulders(path);
    return path;
  }

  void _appendShoulders(Path path) {
    final numbers = RegExp(
      r'-?\d+(?:\.\d+)?',
    ).allMatches(shoulders).map((m) => double.parse(m.group(0)!)).toList();

    // M x y C x1 y1 x2 y2 x y C x1 y1 x2 y2 x y [C ...] Z
    var i = 0;
    path.moveTo(numbers[i++], numbers[i++]);
    while (i + 5 < numbers.length) {
      path.cubicTo(
        numbers[i++],
        numbers[i++],
        numbers[i++],
        numbers[i++],
        numbers[i++],
        numbers[i++],
      );
    }
    path.close();
  }
}

/// A Gaussian blur, as a paint.
///
/// SVG's stdDeviation and Flutter's sigma are the same measure, so the
/// design's blur radii carry over unchanged.
Paint blurred(Color color, double sigma) => Paint()
  ..color = color
  ..maskFilter = MaskFilter.blur(ui.BlurStyle.normal, sigma);

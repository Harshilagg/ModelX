import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'runway_scene.dart';

/// Where the preloader is in its run.
enum RunwayPhase {
  /// The walk down the runway.
  walking,

  /// Waiting: the walk is done but startup is not.
  holding,

  /// Startup finished; the scene turns accent and gives way.
  ///
  /// The marks on the floor take [RunwayScene.accentGlow]; the flood
  /// that follows them takes [RunwayScene.accent] itself.
  firing,
}

/// One frame of the scene.
///
/// Passed whole so the painter has no state of its own and can be
/// compared cheaply in [CustomPainter.shouldRepaint].
@immutable
class RunwayFrame {
  final RunwayPhase phase;

  /// Seconds since the walk began. Keeps running into the hold so the
  /// step trails finish settling rather than snapping.
  final double walk;

  /// The hold loop, 0 to 1 over one full cycle.
  final double hold;

  /// The finale, 0 to 1.
  final double fire;

  /// True once the accent has taken over and only the flood matters.
  final bool flooded;

  const RunwayFrame({
    required this.phase,
    required this.walk,
    required this.hold,
    required this.fire,
    this.flooded = false,
  });

  @override
  bool operator ==(Object other) =>
      other is RunwayFrame &&
      other.phase == phase &&
      other.walk == walk &&
      other.hold == hold &&
      other.fire == fire &&
      other.flooded == flooded;

  @override
  int get hashCode => Object.hash(phase, walk, hold, fire, flooded);
}

/// Paints the runway.
///
/// Everything that never moves -- floor, seams, edge lights, the front
/// row -- is recorded into a picture once per size and replayed, so a
/// frame costs the animated layers only. The front row alone is five
/// blurred shapes drawn twice each; redrawing those sixty times a
/// second is most of a frame budget on its own.
class RunwayPainter extends CustomPainter {
  final RunwayFrame frame;

  /// The still layers, recorded once.
  final ui.Picture? backdrop;

  const RunwayPainter({required this.frame, this.backdrop});

  /// Fits the 390x844 artboard to the screen.
  ///
  /// Scaled by width and anchored to the bottom: the runway recedes to
  /// a vanishing point, so the bottom edge is the one that has to stay
  /// put. Stretching to fit would flatten the perspective and squash
  /// the footprints.
  static ({double scale, Offset origin}) fit(Size size) {
    final scale = size.width / RunwayScene.boardWidth;
    return (
      scale: scale,
      origin: Offset(0, size.height - RunwayScene.boardHeight * scale),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final placed = fit(size);

    canvas.drawRect(Offset.zero & size, Paint()..color = RunwayScene.ground);

    canvas.save();
    canvas.translate(placed.origin.dx, placed.origin.dy);
    canvas.scale(placed.scale);

    // Everything is clipped to the artboard's own bounds so a blurred
    // silhouette that overhangs the edge does not bleed up the side of
    // a taller screen.
    canvas.clipRect(
      const Rect.fromLTWH(
        0,
        -RunwayScene.boardHeight,
        RunwayScene.boardWidth,
        RunwayScene.boardHeight * 2,
      ),
    );

    final entrance = _ramp(frame.walk, 0.1, 1.3);
    final fading = frame.phase == RunwayPhase.firing
        ? 1 - _ramp(frame.fire, 0, 0.3)
        : 1.0;

    if (backdrop != null) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: entrance),
      );
      canvas.drawPicture(backdrop!);
      canvas.restore();
    }

    _paintSpotlight(canvas, entrance * fading);
    _paintMark(canvas, fading);
    _paintReflection(canvas);
    _paintSteps(canvas);
    _paintRipples(canvas);
    _paintFlashes(canvas);

    canvas.restore();
  }

  // ---- Spotlight -------------------------------------------------------

  void _paintSpotlight(Canvas canvas, double opacity) {
    if (opacity <= 0) return;

    // The beam lengthens and the pool slides forward together, tracking
    // the walk from the horizon down to the mark.
    final travel = _eased(_ramp(frame.walk, 0.35, 3.25));
    final breathe = frame.phase == RunwayPhase.holding
        ? 1 -
              0.25 *
                  (0.5 - 0.5 * math.cos(2 * math.pi * ((frame.hold * 9) % 1)))
        : 1.0;

    final alpha = opacity * breathe;

    canvas.save();

    // The sway is in time with the steps, and stops when they do.
    if (frame.walk > 0.45 && frame.walk < 3.17) {
      final beat = ((frame.walk - 0.45) / 0.34) % 2;
      final sway = (beat < 1 ? beat : 2 - beat) * 2 - 1;
      canvas.translate(RunwayScene.mark.dx, 0);
      canvas.rotate(sway * 0.7 * math.pi / 180);
      canvas.translate(-RunwayScene.mark.dx, 0);
    }

    // Two cones: a wide one and a tight one inside it.
    final beamEnd = 0.63 + 0.37 * travel;
    for (final spread in [
      (188.0, 202.0, 128.0, 262.0),
      (191.0, 199.0, 160.0, 230.0),
    ]) {
      final path = Path()
        ..moveTo(spread.$1, 0)
        ..lineTo(spread.$2, 0)
        ..lineTo(
          spread.$1 + (spread.$4 - spread.$1) * beamEnd,
          RunwayScene.mark.dy * beamEnd,
        )
        ..lineTo(
          spread.$2 + (spread.$3 - spread.$2) * beamEnd,
          RunwayScene.mark.dy * beamEnd,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = RunwayScene.light.withValues(alpha: 0.045 * alpha),
      );
    }
    canvas.restore();

    // The pool of light on the floor, arriving with the feet.
    final poolScale = 0.5 + 0.5 * travel;
    final poolY = RunwayScene.mark.dy - 159 * (1 - travel);
    for (final pool in [(66.0, 14.0, 0.07), (36.0, 8.0, 0.06)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(RunwayScene.mark.dx, poolY),
          width: pool.$1 * 2 * poolScale,
          height: pool.$2 * 2 * poolScale,
        ),
        Paint()..color = RunwayScene.light.withValues(alpha: pool.$3 * alpha),
      );
    }

    // The fixture itself.
    for (final fixture in [(14.0, 3.0, 0.85), (34.0, 7.0, 0.12)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(195, 1),
          width: fixture.$1 * 2,
          height: fixture.$2 * 2,
        ),
        Paint()
          ..color = RunwayScene.light.withValues(alpha: fixture.$3 * alpha),
      );
    }
  }

  // ---- The mark and the reflection -------------------------------------

  void _paintMark(Canvas canvas, double fading) {
    final show = _ramp(frame.walk, 0.6, 1.4) * fading;
    if (show <= 0) return;
    canvas.drawOval(
      Rect.fromCenter(center: RunwayScene.mark, width: 22 * 2, height: 5.2 * 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = RunwayScene.light.withValues(alpha: 0.35 * show),
    );
  }

  void _paintReflection(Canvas canvas) {
    final streak =
        _ramp(frame.walk, 2.1, 3.5) *
        (frame.phase == RunwayPhase.firing ? 1 - _ramp(frame.fire, 0, 0.3) : 1);

    if (streak > 0) {
      for (final s in [(520.0, 46.0, 80.0), (545.0, 18.0, 110.0)]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(RunwayScene.mark.dx, s.$1),
            width: s.$2 * 2,
            height: s.$3 * 2,
          ),
          blurred(RunwayScene.light.withValues(alpha: 0.05 * streak), 7),
        );
      }
    }

    // The feet, mirrored in the floor.
    final feet = _ramp(frame.walk, 3.25, 3.85);
    if (feet <= 0) return;

    final accent = frame.phase == RunwayPhase.firing
        ? _ramp(frame.fire, 0, 0.3)
        : 0.0;
    final colour = Color.lerp(
      RunwayScene.light,
      RunwayScene.accentGlow,
      accent,
    )!;

    canvas.save();
    canvas.translate(0, 437);
    canvas.scale(1, -1.45);
    canvas.translate(0, -437);
    RunwayScene.paintFinalFeet(
      canvas,
      1,
      blurred(colour.withValues(alpha: (0.2 + 0.15 * accent) * feet), 1.2),
    );
    canvas.restore();
  }

  // ---- The walk --------------------------------------------------------

  void _paintSteps(Canvas canvas) {
    for (var i = 0; i < RunwayScene.stepCount; i++) {
      final last = i == RunwayScene.stepCount - 1;
      final start = 0.45 + 0.34 * i;
      final local = frame.walk - start;
      if (local <= 0) continue;

      // Landing: a 3px drop that settles, over the first fifth.
      final landing = Curves.easeOutCubic.transform(
        (local / (last ? 0.6 : 1.8 * 0.18)).clamp(0.0, 1.0),
      );

      double opacity;
      if (last) {
        opacity = landing;
      } else {
        // Then it fades back to a trail, so the eye follows the newest
        // print rather than reading nine equal ones.
        final decay = ((local - 1.8 * 0.18) / (1.8 * 0.82)).clamp(0.0, 1.0);
        opacity = landing - (landing - 0.16) * decay;
      }

      if (frame.phase == RunwayPhase.firing) {
        final out = _ramp(frame.fire, 0, 0.3);
        if (!last) opacity *= 1 - out;
      }
      if (opacity <= 0.001) continue;

      final step = RunwayScene.step(i);
      final drop = 3 * (1 - landing);
      final grow = 0.9 + 0.1 * landing;

      var colour = RunwayScene.light;
      if (last && frame.phase == RunwayPhase.firing) {
        colour = Color.lerp(
          RunwayScene.light,
          RunwayScene.accentGlow,
          _ramp(frame.fire, 0, 0.3),
        )!;
      }

      final paint = Paint()..color = colour.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(step.at.dx, step.at.dy + drop);
      canvas.scale(grow);
      canvas.translate(-step.at.dx, -step.at.dy);

      if (last) {
        RunwayScene.paintFinalFeet(canvas, step.scale, paint);
      } else {
        RunwayScene.paintFoot(canvas, step.at, step.scale, paint);
      }
      canvas.restore();
    }
  }

  // ---- Waiting ---------------------------------------------------------

  void _paintRipples(Canvas canvas) {
    final firing = frame.phase == RunwayPhase.firing;
    if (frame.phase != RunwayPhase.holding && !firing) return;

    // Two, half a cycle apart, so the mark is never still while the
    // app is still working.
    for (final offset in [0.0, 0.5]) {
      var t = ((frame.hold * 11) + offset) % 1;
      if (firing) {
        // One last ripple on the way out, in accent.
        t = _ramp(frame.fire, 0, 0.5);
        if (offset != 0) continue;
      }

      final scale = 1 + 1.6 * t;
      final colour = firing ? RunwayScene.accentGlow : RunwayScene.light;
      canvas.drawOval(
        Rect.fromCenter(
          center: RunwayScene.mark,
          width: 22 * 2 * scale,
          height: 5.2 * 2 * scale,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colour.withValues(alpha: 0.5 * (1 - t)),
      );
    }
  }

  void _paintFlashes(Canvas canvas) {
    // Flashes stop the moment the walk is over and the finale starts.
    if (frame.phase == RunwayPhase.firing) return;

    for (var i = 0; i < RunwayScene.flashes.length; i++) {
      final flash = RunwayScene.flashes[i];
      double t;

      if (frame.phase == RunwayPhase.walking || frame.walk < 4.0) {
        // Single pops, on the steps that land hardest.
        const cues = [1.13, 1.81, 2.22, 2.83, 2.97, 3.22, 3.34, 3.5, 2.5];
        t = (frame.walk - cues[i]) / 0.5;
      } else {
        // In the hold they keep coming, at intervals that do not line
        // up, so the waiting never falls into a rhythm.
        if (i > 3) continue;
        final period = [2.3, 2.7, 3.1, 3.7][i];
        t = ((frame.hold * 19.8) % period) / 0.5;
      }

      if (t <= 0 || t >= 1) continue;
      // Quick bloom, slow fade.
      final opacity = t < 0.08 ? t / 0.08 : (1 - (t - 0.08) / 0.92);
      canvas.drawCircle(
        flash.$1,
        flash.$2,
        blurred(Colors.white.withValues(alpha: 0.6 * opacity), 26),
      );
    }
  }

  // ---- Helpers ---------------------------------------------------------

  /// 0 before [from], 1 after [to], linear between.
  static double _ramp(double value, double from, double to) =>
      ((value - from) / (to - from)).clamp(0.0, 1.0);

  static double _eased(double t) =>
      const Cubic(0.35, 0.1, 0.35, 1).transform(t.clamp(0.0, 1.0));

  @override
  bool shouldRepaint(RunwayPainter old) =>
      old.frame != frame || old.backdrop != backdrop;
}

/// Records the layers that never move.
ui.Picture recordBackdrop() {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Floor.
  canvas.drawPath(
    Path()
      ..moveTo(RunwayScene.vanishLeft.dx, RunwayScene.vanishLeft.dy)
      ..lineTo(RunwayScene.floorLeft.dx, RunwayScene.floorLeft.dy)
      ..lineTo(RunwayScene.floorRight.dx, RunwayScene.floorRight.dy)
      ..lineTo(RunwayScene.vanishRight.dx, RunwayScene.vanishRight.dy)
      ..close(),
    Paint()..color = RunwayScene.floor,
  );

  // Seams, fading out as they come forward.
  final seamPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8
    ..shader = ui.Gradient.linear(
      const Offset(0, RunwayScene.horizon),
      const Offset(0, RunwayScene.boardHeight),
      [
        RunwayScene.light.withValues(alpha: 0.09),
        RunwayScene.light.withValues(alpha: 0.05),
        RunwayScene.light.withValues(alpha: 0),
      ],
      [0, 0.55, 1],
    );
  for (final seam in RunwayScene.seams) {
    canvas.drawLine(
      Offset(seam.$1, RunwayScene.horizon),
      Offset(seam.$2, RunwayScene.boardHeight),
      seamPaint,
    );
  }

  // The two edges.
  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = RunwayScene.floorEdge;
  canvas.drawLine(RunwayScene.vanishLeft, RunwayScene.floorLeft, edge);
  canvas.drawLine(RunwayScene.vanishRight, RunwayScene.floorRight, edge);

  // Edge lights, growing as they approach.
  final lamp = Paint()..color = RunwayScene.light.withValues(alpha: 0.32);
  for (final light in RunwayScene.edgeLights) {
    canvas.drawCircle(
      Offset(RunwayScene.mark.dx - light.$3, light.$1),
      light.$2,
      lamp,
    );
    canvas.drawCircle(
      Offset(RunwayScene.mark.dx + light.$3, light.$1),
      light.$2,
      lamp,
    );
  }

  // The haze the front row sits against.
  canvas.drawOval(
    Rect.fromCenter(
      center: RunwayScene.backlight,
      width: RunwayScene.backlightSize.width * 2,
      height: RunwayScene.backlightSize.height * 2,
    ),
    blurred(RunwayScene.light.withValues(alpha: 0.07), 34),
  );

  // The front row: the two side groups, then the closest figure.
  for (final figure in [
    ...RunwayScene.frontRowLeft,
    ...RunwayScene.frontRowRight,
    RunwayScene.frontRowCentre,
  ]) {
    final shape = figure.build();
    canvas.save();
    canvas.translate(figure.rimOffset.dx, figure.rimOffset.dy);
    canvas.drawPath(
      shape,
      blurred(RunwayScene.light.withValues(alpha: figure.rimOpacity), 6),
    );
    canvas.restore();
    canvas.drawPath(shape, blurred(figure.fill, 10));
  }

  return recorder.endRecording();
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_metrics.dart';

/// What the assistant is doing.
enum ApertureState {
  /// At rest, iris half open.
  idle,

  /// The opening breathes with the voice.
  listening,

  /// The iris turns and a needle laps the ring.
  thinking,

  /// The iris opens and the light blooms.
  responding,
}

/// The assistant button: a camera iris that opens, turns and blooms.
///
/// The blades are solved rather than drawn by hand. Six straight leaves
/// sit on a ring; each one runs from a vertex of a hexagon out to the
/// ring along the edge it shares with its neighbour, and closes back
/// around the ring's arc. Changing one number -- the opening radius --
/// re-solves the whole shape, which is what lets the iris breathe and
/// bloom without a frame of artwork per state.
class ApertureButton extends StatefulWidget {
  final ApertureState state;
  final VoidCallback? onPressed;
  final double size;

  /// The leaves.
  final Color bladeColor;

  /// Behind the leaves, and the hairlines between them.
  final Color groundColor;

  /// The dashed outer ring and its travelling knob.
  final Color ringColor;

  /// What the bloom resolves to.
  final Color bloomColor;

  final String semanticLabel;

  const ApertureButton({
    super.key,
    this.state = ApertureState.idle,
    this.onPressed,
    this.size = 62,
    this.bladeColor = const Color(0xFFFFFFFF),
    this.groundColor = const Color(0xFF0B0B0B),
    this.ringColor = const Color(0xFF5F5E5A),
    this.bloomColor = const Color(0xFFED93B1),
    this.semanticLabel = 'Assistant',
  });

  /// The artwork is drawn in the reference's own 88-unit box and scaled,
  /// so every radius below is the number from the design rather than a
  /// fraction someone has to reverse-engineer.
  static const double designBox = 88;

  @override
  State<ApertureButton> createState() => _ApertureButtonState();
}

class _ApertureButtonState extends State<ApertureButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    // One long cycle the painter reads a running time out of, rather
    // than a controller per state.
    duration: const Duration(seconds: 12),
  );

  bool _down = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ApertureButton old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _sync();
  }

  void _sync() {
    // Idle is a still shape, so nothing needs to run for it. Under
    // reduced motion nothing runs at all and every state renders its
    // resting form.
    final wants =
        widget.state != ApertureState.idle && !AppMotion.reduced(context);

    if (wants && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!wants && _clock.isAnimating) {
      _clock.stop();
      _clock.value = 0;
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: AppMotion.quick,
          child: SizedBox.square(
            dimension: widget.size,
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => CustomPaint(
                painter: _AperturePainter(
                  state: widget.state,
                  seconds:
                      _clock.value * _clock.duration!.inMilliseconds / 1000,
                  bladeColor: widget.bladeColor,
                  groundColor: widget.groundColor,
                  ringColor: widget.ringColor,
                  bloomColor: widget.bloomColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AperturePainter extends CustomPainter {
  final ApertureState state;
  final double seconds;
  final Color bladeColor;
  final Color groundColor;
  final Color ringColor;
  final Color bloomColor;

  const _AperturePainter({
    required this.state,
    required this.seconds,
    required this.bladeColor,
    required this.groundColor,
    required this.ringColor,
    required this.bloomColor,
  });

  /// Blade count and the ring they close against, from the reference.
  static const int _blades = 6;
  static const double _bladeRing = 19.4;

  /// Radii in the reference's 88-unit box. The box itself is 44, drawn
  /// by whatever hosts the button rather than by the painter, so the
  /// same artwork sits on a light pill or a dark bar.
  static const double _dashRing = 34;
  static const double _iris = 20;
  static const double _knob = 2.8;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / ApertureButton.designBox;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);

    final t = seconds;

    // ---- the state's three variables ------------------------------
    double opening;
    double spin;
    Color ground = groundColor;
    Color ring = ringColor;
    Color knobColor = bladeColor;
    double knobAngle = _knobAngleFor(const Offset(17, -29.4));
    double ringScale = 1;

    switch (state) {
      case ApertureState.idle:
        opening = 7;
        spin = 0;

      case ApertureState.listening:
        // A fast tremor inside a slow swell, so it reads as speech
        // rather than a metronome.
        opening = 7 + 2.2 * math.sin(t * 7) * math.sin(t * 2.3).abs();
        spin = 0;
        ring = const Color(0xFF888780);
        ringScale = 1 - 0.05 * (0.5 - 0.5 * math.cos(t * 2 * math.pi / 1.4));

      case ApertureState.thinking:
        opening = 6;
        spin = (t * 60) % 360 * math.pi / 180;
        ring = const Color(0xFF888780);
        // The knob laps the ring rather than sitting still.
        knobAngle = -math.pi / 2 + (t / 2 % 1) * 2 * math.pi;

      case ApertureState.responding:
        final c = (t % 2.4) / 2.4;
        // Opens fast then holds, so the bloom lands rather than easing
        // in and out symmetrically.
        final e = c < 0.55 ? 1 - math.pow(1 - c / 0.55, 3).toDouble() : 1.0;
        opening = 3 + 10 * e;
        spin = -30 * e * math.pi / 180;
        ring = Color.lerp(ringColor, bloomColor, math.min(1, c / 0.55))!;
        knobColor = Color.lerp(bladeColor, bloomColor, e)!;
        ground = c < 0.35
            ? groundColor
            : Color.lerp(
                groundColor,
                bloomColor,
                math.min(1, (c - 0.35) / 0.35),
              )!;
    }

    // ---- ring, knob, iris ------------------------------------------
    _drawDashedRing(canvas, _dashRing * ringScale, ring);

    canvas.drawCircle(Offset.zero, _iris, Paint()..color = ground);
    _drawBlades(canvas, opening, spin);
    canvas.drawCircle(
      Offset.zero,
      _iris,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = bladeColor,
    );

    canvas.drawCircle(
      Offset(_dashRing * math.cos(knobAngle), _dashRing * math.sin(knobAngle)),
      _knob,
      Paint()..color = knobColor,
    );

    canvas.restore();
  }

  double _knobAngleFor(Offset at) => math.atan2(at.dy, at.dx);

  /// The outer ring, dashed by stepping around it rather than by a
  /// dash effect, which Flutter has no equivalent of.
  void _drawDashedRing(Canvas canvas, double radius, Color colour) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = colour;

    const dash = 5.0, gap = 3.5;
    final circumference = 2 * math.pi * radius;
    final steps = (circumference / (dash + gap)).floor();
    final sweep = 2 * math.pi / steps;
    final on = sweep * dash / (dash + gap);

    for (var i = 0; i < steps; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        i * sweep,
        on,
        false,
        paint,
      );
    }
  }

  /// Six leaves, solved from the opening radius.
  void _drawBlades(Canvas canvas, double opening, double spin) {
    // Below a hair's width the leaves collapse into each other and the
    // solve has no real root.
    final r = opening.clamp(0.5, _bladeRing - 0.5);

    final vertices = <Offset>[
      for (var i = 0; i < _blades; i++)
        Offset(
          r * math.cos(i * 2 * math.pi / _blades - math.pi / 2),
          r * math.sin(i * 2 * math.pi / _blades - math.pi / 2),
        ),
    ];

    // Where each leaf's edge meets the ring: walk out from the vertex
    // along the shared edge until the distance from the middle is the
    // ring's radius.
    final onRing = <Offset>[];
    for (var i = 0; i < _blades; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % _blades];
      var u = a - b;
      final length = u.distance;
      if (length == 0) return;
      u = u / length;

      final dp = a.dx * u.dx + a.dy * u.dy;
      final disc = dp * dp - (a.distanceSquared - _bladeRing * _bladeRing);
      if (disc < 0) return;
      final t = -dp + math.sqrt(disc);
      onRing.add(a + u * t);
    }

    final fill = Paint()..color = bladeColor;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round
      ..color = groundColor;

    canvas.save();
    canvas.rotate(spin);

    for (var i = 0; i < _blades; i++) {
      final j = (i + 1) % _blades;
      final p = onRing[i], q = onRing[j], v = vertices[j];

      // Which way round the ring closes the leaf without crossing it.
      final clockwise = (q.dx * p.dy - q.dy * p.dx) > 0;

      final path = Path()
        ..moveTo(p.dx, p.dy)
        ..lineTo(v.dx, v.dy)
        ..lineTo(q.dx, q.dy)
        ..arcToPoint(
          p,
          radius: const Radius.circular(_bladeRing),
          clockwise: clockwise,
        )
        ..close();

      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AperturePainter old) =>
      old.seconds != seconds ||
      old.state != state ||
      old.bladeColor != bladeColor ||
      old.groundColor != groundColor;
}

import 'package:flutter/material.dart';

/// The line glyphs the navigation is drawn with.
enum NavGlyph { home, jobs, network, profile, notifications, messages }

/// Draws a [NavGlyph].
///
/// Paths rather than an icon font: these come from the design as SVG,
/// and transcribing them keeps the exact shape. A font would also scale
/// with the system text size, and the bar's height is fixed so that the
/// assistant button can be placed above it without measuring.
class NavGlyphIcon extends StatelessWidget {
  final NavGlyph glyph;
  final double size;
  final Color color;

  const NavGlyphIcon({
    super.key,
    required this.glyph,
    required this.color,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _GlyphPainter(glyph: glyph, color: color),
    ),
  );
}

class _GlyphPainter extends CustomPainter {
  final NavGlyph glyph;
  final Color color;

  const _GlyphPainter({required this.glyph, required this.color});

  /// Everything below is written in the design's 24-unit box.
  static const double _box = 24;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / _box);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    for (final path in _paths()) {
      canvas.drawPath(path, stroke);
    }
    canvas.restore();
  }

  List<Path> _paths() => switch (glyph) {
    NavGlyph.home => [
      Path()
        ..moveTo(4, 11)
        ..lineTo(12, 4)
        ..lineTo(20, 11)
        ..lineTo(20, 20)
        ..lineTo(15, 20)
        ..lineTo(15, 14)
        ..lineTo(9, 14)
        ..lineTo(9, 20)
        ..lineTo(4, 20)
        ..close(),
    ],
    NavGlyph.jobs => [
      Path()
        ..addRRect(RRect.fromLTRBR(3, 7, 21, 20, const Radius.circular(2.5))),
      // The handle, and the seam across the case.
      Path()
        ..moveTo(9, 7)
        ..lineTo(9, 5)
        ..lineTo(15, 5)
        ..lineTo(15, 7),
      Path()
        ..moveTo(3, 13)
        ..lineTo(21, 13),
    ],
    NavGlyph.network => [
      Path()..addOval(Rect.fromCircle(center: const Offset(9, 8), radius: 3.5)),
      // The near figure's shoulders.
      Path()
        ..moveTo(3, 20)
        ..cubicTo(3, 16.7, 5.7, 14, 9, 14)
        ..cubicTo(12.3, 14, 15, 16.7, 15, 20),
      // The second figure, half behind the first.
      Path()
        ..moveTo(16, 4.5)
        ..arcToPoint(
          const Offset(16, 11.5),
          radius: const Radius.circular(3.5),
        ),
      Path()
        ..moveTo(18, 14)
        ..cubicTo(20, 14.7, 21, 16.8, 21, 20),
    ],
    NavGlyph.profile => [
      Path()..addOval(Rect.fromCircle(center: const Offset(12, 8), radius: 4)),
      Path()
        ..moveTo(4, 20)
        ..cubicTo(4, 16, 7.6, 13, 12, 13)
        ..cubicTo(16.4, 13, 20, 16, 20, 20),
    ],
    // Drawn to match the four above rather than taken from the
    // design, which has no bell: same 1.8 stroke, same round joins,
    // same optical weight so it does not read as borrowed.
    NavGlyph.notifications => [
      Path()
        ..moveTo(5.4, 17)
        ..lineTo(7, 13.7)
        ..lineTo(7, 9.5)
        ..arcToPoint(const Offset(17, 9.5), radius: const Radius.circular(5))
        ..lineTo(17, 13.7)
        ..lineTo(18.6, 17)
        ..close(),
      Path()
        ..moveTo(10, 19)
        ..arcToPoint(
          const Offset(14, 19),
          radius: const Radius.circular(2),
          clockwise: false,
        ),
    ],
    NavGlyph.messages => [
      Path()
        ..moveTo(4, 16.5)
        ..lineTo(4, 7)
        ..arcToPoint(const Offset(6, 5), radius: const Radius.circular(2))
        ..lineTo(18, 5)
        ..arcToPoint(const Offset(20, 7), radius: const Radius.circular(2))
        ..lineTo(20, 14)
        ..arcToPoint(const Offset(18, 16), radius: const Radius.circular(2))
        ..lineTo(8.5, 16)
        ..close(),
    ],
  };

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}

import 'package:flutter/material.dart';

import '../../ui/app_type.dart';
import '../../ui/board_theme.dart';

/// A hairline rule with a word in the middle.
class OrDivider extends StatelessWidget {
  final String label;

  const OrDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: p.line, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(label, style: AppType.label(color: p.onSurfaceFaint)),
        ),
        Expanded(child: Divider(color: p.line, height: 1)),
      ],
    );
  }
}

/// The Google mark.
///
/// Painted rather than shipped as an asset: it is four arcs, it cannot
/// go missing from the bundle, and it scales without a set of density
/// variants. Google's brand terms require the four colours and forbid
/// recolouring it to match a theme, so it stays as it is on dark.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CustomPaint(painter: _GooglePainter()),
  );
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(size.width * 0.08);
    final stroke = size.width * 0.22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four arcs, anticlockwise from the right: blue, green, yellow, red.
    const arcs = <(double, double, Color)>[
      (-0.35, 0.95, Color(0xFF4285F4)),
      (0.60, 1.45, Color(0xFF34A853)),
      (2.05, 1.15, Color(0xFFFBBC05)),
      (3.20, 1.30, Color(0xFFEA4335)),
    ];
    for (final (start, sweep, colour) in arcs) {
      canvas.drawArc(rect, start, sweep, false, paint..color = colour);
    }

    // The crossbar that makes it a G rather than a ring.
    canvas.drawLine(
      Offset(size.width * 0.52, size.height * 0.5),
      Offset(size.width * 0.96, size.height * 0.5),
      paint
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = stroke * 0.95,
    );
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}

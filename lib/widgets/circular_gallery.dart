import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/app_type.dart';
import '../ui/board_theme.dart';

/// One frame in a [CircularGallery].
class GalleryShot {
  final String url;

  /// Drawn under the frame. Null leaves the space free.
  final String? label;

  const GalleryShot({required this.url, this.label});
}

/// Shots laid along an arc, dragged sideways.
///
/// A Flutter port of the curved WebGL gallery, kept to its geometry
/// rather than eyeballed: the frames sit on a circle whose radius is
/// solved from one number, [bend], which is the distance the outermost
/// frame drops below the middle one. Each frame is also rotated by its
/// own angle on that circle, so the row reads as a curve rather than a
/// straight line of tilted pictures.
///
/// The scrolling is a [PageView] rather than a hand-written simulation.
/// The original ran its own inertia and then snapped to the nearest
/// frame afterwards; a PageView already flings, snaps and follows a
/// finger with the platform's own feel, which is worth more here than
/// matching the original's easing exactly.
class CircularGallery extends StatefulWidget {
  final List<GalleryShot> shots;
  final ValueChanged<int>? onTap;

  /// How far the outermost frame drops, in logical pixels.
  ///
  /// This is the whole shape. 0 lays the frames flat in a row; larger
  /// values tighten the curve.
  final double bend;

  /// Height of the gallery, labels included.
  final double height;

  /// How much of the width one frame occupies. Lower shows more of the
  /// neighbours, which is what makes the curve legible.
  final double frameFraction;

  final double borderRadius;

  /// How much of the arc's own angle each frame actually leans, 0 to 1.
  ///
  /// The original ties the lean to the curve exactly, which works on a
  /// wide canvas where a dozen frames span the viewport and each one
  /// sits near the middle. At phone width only three fit, so the
  /// neighbours land at the edge of the circle where that angle is past
  /// thirty degrees and the row reads as a fan of scattered prints
  /// rather than a curve. This keeps the curve and softens the lean.
  final double tilt;

  const CircularGallery({
    super.key,
    required this.shots,
    this.onTap,
    this.bend = 56,
    this.height = 300,
    this.frameFraction = 0.58,
    this.borderRadius = 10,
    this.tilt = 0.38,
  });

  /// Where a frame sits on the arc, given how far it is from the middle.
  ///
  /// [x] and [halfWidth] are in the same units; [bend] is the drop at
  /// `x == halfWidth`. Returns the vertical drop and the rotation in
  /// radians, clockwise-positive as Flutter measures it.
  ///
  /// Solved rather than approximated: for a circle of radius R through
  /// the middle of the row, the drop at x is `R - sqrt(R^2 - x^2)`, and
  /// R is whatever makes that equal [bend] at the edge. Rotation is the
  /// angle subtended, so each frame stays tangent to the curve.
  ///
  /// The sign is the opposite of the WebGL original's, and has to be.
  /// There, z-rotation is counter-clockwise-positive with the y axis
  /// pointing up; Flutter's Transform.rotate is clockwise-positive with
  /// y pointing down. Copying the formula across unchanged mirrors the
  /// whole row: frames lean in toward the middle instead of splaying
  /// away from it.
  static ({double drop, double angle}) arc({
    required double x,
    required double halfWidth,
    required double bend,
    double tilt = 1,
  }) {
    if (bend <= 0 || halfWidth <= 0) return (drop: 0, angle: 0);

    final radius = (halfWidth * halfWidth + bend * bend) / (2 * bend);
    // Past the edge the circle has no solution, and frames do travel
    // past it on their way out of view.
    final effective = math.min(x.abs(), halfWidth);
    final drop = radius - math.sqrt(radius * radius - effective * effective);
    final angle = math.asin(effective / radius) * tilt;

    return (drop: drop, angle: x.sign * angle);
  }

  @override
  State<CircularGallery> createState() => _CircularGalleryState();
}

class _CircularGalleryState extends State<CircularGallery> {
  late final PageController _controller = PageController(
    viewportFraction: widget.frameFraction,
    // Starts in the middle of the looped range so there is room to drag
    // either way from the first frame.
    initialPage: _loopOrigin,
  );

  /// The gallery loops by running a large page range and reading the
  /// real shot out of it with a modulo, so dragging never hits an end.
  static const _loops = 1000;

  int get _loopOrigin =>
      widget.shots.isEmpty ? 0 : _loops ~/ 2 * widget.shots.length;

  /// Tracks the controller so each frame can be placed by its distance
  /// from the middle, which is what the arc needs.
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _page = _loopOrigin.toDouble();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    // Both guards matter: without clients there is no page to read, and
    // without dimensions `page` throws rather than returning null.
    if (!_controller.hasClients) return;
    if (!_controller.position.haveDimensions) return;
    setState(() => _page = _controller.page ?? _page);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shots.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final halfWidth = constraints.maxWidth / 2;
          final frameWidth = constraints.maxWidth * widget.frameFraction;

          return PageView.builder(
            controller: _controller,
            // Unbounded: the modulo below turns it back into a real
            // shot, so there is no end to reach in either direction.
            itemCount: widget.shots.length * _loops,
            padEnds: true,
            itemBuilder: (context, page) {
              final index = page % widget.shots.length;
              final offset = (page - _page) * frameWidth;
              final placement = CircularGallery.arc(
                x: offset,
                halfWidth: halfWidth,
                bend: widget.bend,
                tilt: widget.tilt,
              );

              return _Frame(
                shot: widget.shots[index],
                drop: placement.drop,
                angle: placement.angle,
                borderRadius: widget.borderRadius,
                onTap: widget.onTap == null ? null : () => widget.onTap!(index),
              );
            },
          );
        },
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  final GalleryShot shot;
  final double drop;
  final double angle;
  final double borderRadius;
  final VoidCallback? onTap;

  const _Frame({
    required this.shot,
    required this.drop,
    required this.angle,
    required this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);

    return Transform.translate(
      offset: Offset(0, drop),
      child: Transform.rotate(
        angle: angle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: Image.network(
                      shot.url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : const BoardHatch(),
                      errorBuilder: (_, __, ___) => const BoardHatch(),
                    ),
                  ),
                ),
              ),
              if (shot.label != null) ...[
                const SizedBox(height: 10),
                Text(
                  shot.label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label(color: p.onSurfaceSoft),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/board_theme.dart';
import '../widgets/kit/kit.dart';
import 'onboarding_theme.dart';

/// One column of the splash masonry.
class MasonryColumn {
  /// Indices into the supplied photo list.
  final List<int> photos;

  /// How long one full loop takes. Each column differs so the three
  /// never line up into a visible grid.
  final Duration duration;

  /// Down instead of up, for the middle column.
  final bool reversed;

  /// Where in its loop the column starts, 0..1. Without this all three
  /// begin flush at the top and the first second looks like a table.
  final double offset;

  const MasonryColumn({
    required this.photos,
    required this.duration,
    required this.offset,
    this.reversed = false,
  });
}

/// The drifting contact sheet behind the splash.
///
/// Three columns at different speeds with the middle one reversed, every
/// photo desaturated, and exactly one at a time lifting into full
/// colour -- the same "picked" moment that happens again when you choose
/// a role, which is the point of repeating it.
///
/// Two things carry the illusion:
///
/// * Each column renders its photo list **twice** and translates by half
///   its own height. At the moment the first copy leaves the top the
///   second is exactly where it started, so the loop has no seam.
/// * Tile heights are uneven and fixed. Even heights would read as a
///   grid; the unevenness is what makes it a contact sheet.
///
/// Under reduced motion the columns stop and the spotlight freezes on
/// one lit photo, rather than everything going grey.
class MasonryBackground extends StatefulWidget {
  /// Turns the colour spotlight off, leaving a still, desaturated wall.
  final bool spotlight;

  const MasonryBackground({super.key, this.spotlight = true});

  /// How long each photo holds the spotlight.
  static const Duration spotlightHold = Duration(seconds: 1);

  /// Tile heights, in the order the photos were supplied. Fixed rather
  /// than derived from each image's aspect: the rhythm of the column is
  /// a design decision, not a property of the photographs.
  static const List<double> heights = [200, 260, 180, 240, 220, 270, 190, 250];

  /// The order the spotlight travels in.
  ///
  /// Deliberately not sequential and not adjacent: consecutive entries
  /// sit in different columns, so the lit photo jumps across the screen
  /// instead of walking down one side.
  static const List<int> spotlightOrder = [4, 2, 3, 7, 5, 0, 1, 6];

  /// The prototype ran three columns of four. Eight photos divide 3/3/2,
  /// and the short column is given the slowest speed so its shorter loop
  /// is the least obvious of the three.
  static const List<MasonryColumn> columns = [
    MasonryColumn(
      photos: [0, 3, 6],
      duration: Duration(seconds: 46),
      offset: 0.10,
    ),
    MasonryColumn(
      photos: [1, 4, 7],
      duration: Duration(seconds: 58),
      offset: 0.45,
      reversed: true,
    ),
    MasonryColumn(
      photos: [2, 5],
      duration: Duration(seconds: 52),
      offset: 0.70,
    ),
  ];

  @override
  State<MasonryBackground> createState() => _MasonryBackgroundState();
}

class _MasonryBackgroundState extends State<MasonryBackground>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  Timer? _spotlightTimer;
  int _spotlightStep = 0;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final column in MasonryBackground.columns)
        AnimationController(vsync: this, duration: column.duration),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MasonryBackground old) {
    super.didUpdateWidget(old);
    if (old.spotlight != widget.spotlight) _sync();
  }

  /// Starts or stops both animations to match the current settings.
  void _sync() {
    final reduced = AppMotion.reduced(context);

    for (var i = 0; i < _controllers.length; i++) {
      final c = _controllers[i];
      if (reduced) {
        c.stop();
        // Held at zero; the column's own offset is still applied in the
        // builder, so a stopped masonry is staggered rather than flush.
        c.value = 0;
      } else if (!c.isAnimating) {
        c.repeat();
      }
    }

    _spotlightTimer?.cancel();
    if (widget.spotlight && !reduced) {
      _spotlightTimer = Timer.periodic(
        MasonryBackground.spotlightHold,
        (_) => setState(
          () => _spotlightStep =
              (_spotlightStep + 1) % MasonryBackground.spotlightOrder.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _spotlightTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _litPhoto {
    if (!widget.spotlight) return null;
    return MasonryBackground.spotlightOrder[_spotlightStep];
  }

  @override
  Widget build(BuildContext context) {
    final lit = _litPhoto;

    return ExcludeSemantics(
      child: ClipRect(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < MasonryBackground.columns.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _MasonryColumn(
                    column: MasonryBackground.columns[i],
                    controller: _controllers[i],
                    litPhoto: lit,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MasonryColumn extends StatelessWidget {
  final MasonryColumn column;
  final AnimationController controller;
  final int? litPhoto;

  const _MasonryColumn({
    required this.column,
    required this.controller,
    required this.litPhoto,
  });

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    final runHeight =
        column.photos
            .map((i) => MasonryBackground.heights[i])
            .fold<double>(0, (a, b) => a + b) +
        gap * column.photos.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Enough copies to cover the viewport plus one full run, so the
        // column is never short at any point in the loop.
        final copies = (constraints.maxHeight / runHeight).ceil() + 1;

        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            // The offset is added here rather than seeded into the
            // controller: repeat() restarts from its minimum on the next
            // tick, so a value assigned before it is discarded. This is
            // the equivalent of CSS's negative animation-delay.
            final phase = (controller.value + column.offset) % 1.0;
            final travelled = phase * runHeight;
            final dy = column.reversed ? travelled - runHeight : -travelled;
            return Transform.translate(offset: Offset(0, dy), child: child);
          },
          // The run is taller than the viewport on purpose -- that is
          // what there is to scroll. A plain Column reports the excess
          // as an overflow and paints yellow stripes over the splash, so
          // the constraint is lifted here and the parent ClipRect does
          // the trimming.
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var copy = 0; copy < copies; copy++)
                  for (final index in column.photos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: gap),
                      child: _MasonryTile(
                        index: index,
                        height: MasonryBackground.heights[index],
                        lit: litPhoto == index,
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MasonryTile extends StatelessWidget {
  final int index;
  final double height;
  final bool lit;

  const _MasonryTile({
    required this.index,
    required this.height,
    required this.lit,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);

    // Every tile is its own layer, so one tile changing colour does not
    // repaint the other twenty-odd scrolling past it.
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.photo),
        child: GreyscaleReveal(
          amount: lit ? 1 : 0,
          duration: AppMotion.slow,
          child: Container(
            height: height,
            width: double.infinity,
            color: p.surfaceField,
            child: Image.asset(
              OnboardingPhotos.masonry[index],
              fit: BoxFit.cover,
              // A missing asset must not take the splash down with it.
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

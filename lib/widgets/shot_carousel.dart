import 'dart:async';
import 'package:flutter/material.dart';
import '../ui/board_theme.dart';
import 'board_widgets.dart';

/// A looping, swipeable gallery of portfolio shots.
///
/// The card nearest the centre is shown at full size and its neighbours
/// fall away, so a model's best frame reads first and the rest of the
/// book is visibly still there. It wraps in both directions — swiping
/// past the last shot continues into the first — and drifts on its own
/// until the viewer touches it, at which point it stops and stays where
/// they left it.
class ShotCarousel extends StatefulWidget {
  final List<String> urls;

  /// Height of the strip, including the indicator row.
  final double height;

  /// How much of the viewport one card occupies. Lower shows more of
  /// the neighbouring shots.
  final double viewportFraction;

  /// Time between automatic advances. Null disables the drift.
  final Duration? autoAdvance;

  final Color accent;
  final ValueChanged<int>? onTap;

  const ShotCarousel({
    super.key,
    required this.urls,
    this.height = 190,
    this.viewportFraction = 0.56,
    this.autoAdvance = const Duration(seconds: 4),
    this.accent = BoardColors.brass,
    this.onTap,
  });

  @override
  State<ShotCarousel> createState() => _ShotCarouselState();
}

class _ShotCarouselState extends State<ShotCarousel> {
  /// Start deep into the virtual list so the gallery can be swiped
  /// backwards from the first shot without hitting an edge.
  static const _origin = 10000;

  late final PageController _controller;
  Timer? _timer;
  double _page = _origin.toDouble();

  /// Set once the viewer drags. The drift is theirs to stop, not
  /// something that should resume and yank the strip out from under them.
  bool _userTookOver = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: _origin,
      viewportFraction: widget.viewportFraction,
    )..addListener(_onScroll);
    _startTimer();
  }

  void _onScroll() {
    // `page` is null until the controller is attached to a viewport.
    final page = _controller.hasClients ? _controller.page : null;
    if (page != null && page != _page) {
      setState(() => _page = page);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final interval = widget.autoAdvance;
    if (interval == null || widget.urls.length < 2) return;
    _timer = Timer.periodic(interval, (_) {
      if (!mounted || !_controller.hasClients || _userTookOver) return;
      _controller.nextPage(
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void didUpdateWidget(ShotCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoAdvance != widget.autoAdvance ||
        oldWidget.urls.length != widget.urls.length) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.urls.length;
    if (count == 0) return const SizedBox.shrink();

    // A single shot has nothing to rotate through, so it renders as a
    // plain card rather than a carousel that can't move.
    if (count == 1) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: AspectRatio(
            aspectRatio: 0.78,
            child: GestureDetector(
              onTap: widget.onTap == null ? null : () => widget.onTap!(0),
              child: BoardMedia(url: widget.urls.first, cut: 18),
            ),
          ),
        ),
      );
    }

    final active = ((_page.round() % count) + count) % count;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is UserScrollNotification && !_userTookOver) {
                setState(() => _userTookOver = true);
                _timer?.cancel();
              }
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              // Unbounded in both directions: the modulo below maps any
              // index back onto the real shots, which is what makes the
              // gallery circular rather than just long.
              itemBuilder: (context, index) {
                final i = ((index % count) + count) % count;
                final distance = (_page - index).abs().clamp(0.0, 1.0);
                final scale = 1 - (distance * 0.18);

                return Center(
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: 1 - (distance * 0.35),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: GestureDetector(
                          onTap: widget.onTap == null
                              ? null
                              : () => widget.onTap!(i),
                          child: BoardMedia(
                            url: widget.urls[i],
                            dark: i.isOdd,
                            cut: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == active ? 16 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: i == active
                      ? widget.accent
                      : BoardColors.inkLineStrong,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

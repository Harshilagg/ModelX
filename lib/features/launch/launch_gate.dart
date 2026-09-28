import 'package:flutter/material.dart';

import 'app_ready.dart';
import 'runway_preloader.dart';
import 'runway_scene.dart';

/// Holds the preloader over the app until startup has landed.
///
/// An overlay rather than a route, because there is no single first
/// screen to navigate to: startup resolves to one of six, and which
/// one is decided by work this widget knows nothing about. Keeping the
/// app mounted underneath also means it is warm and laid out by the
/// time it is revealed, instead of building into a fade.
class LaunchGate extends StatefulWidget {
  final Widget child;

  /// Delays the ready signal, to see the waiting state on a machine
  /// that starts too fast to produce one. Debug builds only.
  final Duration debugSlowStart;

  const LaunchGate({
    super.key,
    required this.child,
    this.debugSlowStart = Duration.zero,
  });

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  bool _preloaderDone = false;

  late final Future<void> _ready = () {
    if (widget.debugSlowStart == Duration.zero) return AppReady.future;
    return Future.wait([
      AppReady.future,
      Future<void>.delayed(widget.debugSlowStart),
    ]);
  }();

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _onFinished() {
    if (!mounted || _preloaderDone) return;
    setState(() => _preloaderDone = true);
    _reveal.forward();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: RunwayScene.ground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Underneath from the first frame, so it is built and laid
          // out before anyone sees it.
          AnimatedBuilder(
            animation: _reveal,
            builder: (context, child) {
              final t = const Cubic(0.2, 0.8, 0.2, 1).transform(_reveal.value);
              return Opacity(
                opacity: _preloaderDone ? t : 0,
                child: Transform.scale(scale: 1.04 - 0.04 * t, child: child),
              );
            },
            child: widget.child,
          ),

          if (!_preloaderDone)
            RunwayPreloader(ready: _ready, onFinished: _onFinished),
        ],
      ),
    );
  }
}

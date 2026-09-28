import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'runway_painter.dart';
import 'runway_scene.dart';

/// Haptics on each footstep and on the flood.
///
/// ---- CHANGE THIS to turn the feel on or off ----
const bool kLaunchHaptics = true;

/// The launch preloader: footsteps down a runway, then the brand.
///
/// Presentation only. It is handed a future that completes when the
/// app's own startup is done and a callback for when it is finished;
/// it decides nothing about where the app goes, and contains no
/// startup logic of its own.
///
/// The walk always plays in full. On a fast device, finishing startup
/// in 300ms and cutting the animation halfway would read as a glitch
/// rather than as speed, so the finale waits for both the walk and the
/// app to be ready.
class RunwayPreloader extends StatefulWidget {
  /// Completes when the app is ready to be shown.
  final Future<void> ready;

  /// Called once the preloader has finished getting out of the way.
  final VoidCallback onFinished;

  const RunwayPreloader({
    super.key,
    required this.ready,
    required this.onFinished,
  });

  // ---- The timeline, in seconds ----------------------------------------

  /// The walk, including the trails still settling behind it.
  static const Duration walkDuration = Duration(milliseconds: 4700);

  /// When the final step has landed and the walk counts as finished.
  static const double walkSettled = 3.8;

  /// One turn of the waiting loop.
  ///
  /// The ripples run on 1.8s and the spotlight breathes on 2.2s. 19.8
  /// is the first length that contains a whole number of both, so the
  /// loop repeats without either of them jumping.
  static const Duration holdDuration = Duration(milliseconds: 19800);

  /// Recolour, flood, wordmark, reveal.
  static const Duration fireDuration = Duration(milliseconds: 3000);

  /// Points within the finale.
  static const double floodStart = 0.4 / 3.0;
  static const double floodEnd = 1.25 / 3.0;
  static const double wordStart = 1.05 / 3.0;
  static const double wordEnd = 1.85 / 3.0;
  static const double revealAt = 2.4 / 3.0;

  @override
  State<RunwayPreloader> createState() => _RunwayPreloaderState();
}

class _RunwayPreloaderState extends State<RunwayPreloader>
    with TickerProviderStateMixin {
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: RunwayPreloader.walkDuration,
  );
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: RunwayPreloader.holdDuration,
  );
  late final AnimationController _fire = AnimationController(
    vsync: this,
    duration: RunwayPreloader.fireDuration,
  );

  RunwayPhase _phase = RunwayPhase.walking;
  bool _walkSettled = false;
  bool _appReady = false;
  bool _finished = false;
  int _stepsFelt = 0;

  ui.Picture? _backdrop;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _backdrop = recordBackdrop();

    widget.ready.then((_) => _onReady()).catchError((_) {
      // Startup's own error handling owns the failure. All this needs
      // to know is that it should stop waiting -- swallowing it here
      // and holding forever would hide an error the app is already
      // prepared to show.
      _onReady();
    });

    _walk.addListener(_watchWalk);
    _fire.addStatusListener(_watchFire);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced == _reducedMotion && _walk.isAnimating) return;
    _reducedMotion = reduced;

    if (_reducedMotion) {
      // The still scene, with the walk already over. Nothing moves and
      // nothing loops; it waits, then hands over.
      _walk.value = 1;
      _walkSettled = true;
      _maybeFire();
    } else if (!_walk.isAnimating && _walk.value == 0) {
      _walk.forward();
    }
  }

  /// Watches for the final step landing.
  void _watchWalk() {
    final seconds =
        _walk.value * RunwayPreloader.walkDuration.inMilliseconds / 1000;

    if (kLaunchHaptics && _phase == RunwayPhase.walking) {
      // One tick per step, as it lands.
      final landed = ((seconds - 0.45) / 0.34).floor() + 1;
      if (landed > _stepsFelt && landed <= RunwayScene.stepCount) {
        _stepsFelt = landed;
        HapticFeedback.selectionClick();
      }
    }

    if (!_walkSettled && seconds >= RunwayPreloader.walkSettled) {
      _walkSettled = true;
      _maybeFire();
    }
  }

  void _onReady() {
    if (!mounted || _appReady) return;
    _appReady = true;
    _maybeFire();
  }

  /// The finale runs only once both the walk and the app are done.
  void _maybeFire() {
    if (!mounted || _phase == RunwayPhase.firing) return;
    if (!_walkSettled) return;

    if (!_appReady) {
      // Still working: settle into the wait rather than freezing on the
      // last frame of the walk.
      if (_phase != RunwayPhase.holding) {
        setState(() => _phase = RunwayPhase.holding);
        if (!_reducedMotion) _hold.repeat();
      }
      return;
    }

    setState(() => _phase = RunwayPhase.firing);
    _hold.stop();
    if (kLaunchHaptics) HapticFeedback.mediumImpact();

    if (_reducedMotion) {
      // No flood, no wordmark: straight to the app.
      _fire.value = 1;
      _handOver();
    } else {
      _fire.forward();
    }
  }

  void _watchFire(AnimationStatus status) {
    if (status == AnimationStatus.completed) _handOver();
  }

  void _handOver() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _walk.removeListener(_watchWalk);
    _fire.removeStatusListener(_watchFire);
    _walk.dispose();
    _hold.dispose();
    _fire.dispose();
    _backdrop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RunwayScene.ground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The scene, and only the scene, repaints per frame.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_walk, _hold, _fire]),
              builder: (context, _) => CustomPaint(
                painter: RunwayPainter(
                  backdrop: _backdrop,
                  frame: RunwayFrame(
                    phase: _phase,
                    walk:
                        _walk.value *
                        RunwayPreloader.walkDuration.inMilliseconds /
                        1000,
                    hold: _hold.value,
                    fire: _fire.value,
                  ),
                ),
              ),
            ),
          ),
          _Caption(phase: _phase, walk: _walk, fire: _fire),
          _Flood(fire: _fire, reduced: _reducedMotion),
        ],
      ),
    );
  }
}

/// The line under the scene, and the one word it changes.
class _Caption extends StatelessWidget {
  final RunwayPhase phase;
  final Animation<double> walk;
  final Animation<double> fire;

  const _Caption({required this.phase, required this.walk, required this.fire});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      // Above the home indicator, as the design places it.
      bottom: 104 + MediaQuery.paddingOf(context).bottom * 0.3,
      child: AnimatedBuilder(
        animation: Listenable.merge([walk, fire]),
        builder: (context, _) {
          final appearing = ((walk.value * 4.7 - 0.6) / 1.2).clamp(0.0, 1.0);
          final leaving = phase == RunwayPhase.firing
              ? (fire.value / (0.3 / 3.0)).clamp(0.0, 1.0)
              : 0.0;

          return Opacity(
            opacity: appearing * (1 - leaving),
            child: Text(
              phase == RunwayPhase.holding
                  ? 'Almost ready'
                  : 'Setting the stage',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Instrument Serif',
                fontStyle: FontStyle.italic,
                fontSize: 20,
                letterSpacing: 0.2,
                color: RunwayScene.captionInk,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The accent taking the screen, and the name arriving on it.
class _Flood extends StatelessWidget {
  final Animation<double> fire;
  final bool reduced;

  const _Flood({required this.fire, required this.reduced});

  @override
  Widget build(BuildContext context) {
    if (reduced) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: fire,
      builder: (context, _) {
        if (fire.value <= RunwayPreloader.floodStart) {
          return const SizedBox.shrink();
        }

        final grow = const Cubic(0.7, 0, 0.2, 1).transform(
          ((fire.value - RunwayPreloader.floodStart) /
                  (RunwayPreloader.floodEnd - RunwayPreloader.floodStart))
              .clamp(0.0, 1.0),
        );

        final word = const Cubic(0.2, 0.8, 0.2, 1).transform(
          ((fire.value - RunwayPreloader.wordStart) /
                  (RunwayPreloader.wordEnd - RunwayPreloader.wordStart))
              .clamp(0.0, 1.0),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final placed = RunwayPainter.fit(constraints.biggest);
            final centre = Offset(
              placed.origin.dx + RunwayScene.mark.dx * placed.scale,
              placed.origin.dy + RunwayScene.mark.dy * placed.scale,
            );

            // Big enough that the circle covers the screen from a
            // centre that is nowhere near the middle of it.
            final reach = constraints.biggest.longestSide * 1.6;

            return Stack(
              children: [
                Positioned(
                  left: centre.dx - reach,
                  top: centre.dy - reach,
                  width: reach * 2,
                  height: reach * 2,
                  child: Transform.scale(
                    scale: grow,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: RunwayScene.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                if (word > 0)
                  Center(
                    child: Opacity(
                      opacity: word,
                      // Tracking is painted after the last letter too,
                      // so a centred tracked mark sits half a space
                      // left of true centre. Nudged back by half.
                      child: Transform.translate(
                        offset: Offset(
                          RunwayScene.wordmarkLetterSpacing / 2,
                          10 * (1 - word),
                        ),
                        child: Text(
                          RunwayScene.appName.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Albert Sans',
                            fontWeight: FontWeight.w500,
                            fontSize: RunwayScene.wordmarkSize,
                            letterSpacing: RunwayScene.wordmarkLetterSpacing,
                            color: RunwayScene.wordmarkInk(RunwayScene.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

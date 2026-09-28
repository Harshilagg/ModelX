import 'dart:async';

import 'package:flutter/material.dart';

/// Signals when the app's own startup has produced a real screen.
///
/// Startup finishes in several places -- the onboarding flag, the auth
/// stream, then up to three profile lookups -- and which screen it
/// lands on is decided by all of them. Rather than teach the preloader
/// any of that, each real destination is wrapped in [AppReadyMarker],
/// which reports once on mount.
///
/// Nothing here changes what startup decides. It only replaces the
/// three spinners that used to stand in for this.
class AppReady {
  AppReady._();

  static final Completer<void> _done = Completer<void>();

  /// Completes the first time a real screen is mounted.
  static Future<void> get future => _done.future;

  static void signal() {
    if (!_done.isCompleted) _done.complete();
  }
}

/// Wraps a real destination and reports that startup has landed.
///
/// Reports from [initState], not from a build: a build can run many
/// times, and signalling from one is a side effect in the wrong place.
class AppReadyMarker extends StatefulWidget {
  final Widget child;

  const AppReadyMarker({super.key, required this.child});

  @override
  State<AppReadyMarker> createState() => _AppReadyMarkerState();
}

class _AppReadyMarkerState extends State<AppReadyMarker> {
  @override
  void initState() {
    super.initState();
    AppReady.signal();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// What stands in while startup is still working.
///
/// Nothing: the preloader is on top and owns the screen. This exists
/// so the three spinners it replaced leave no gap, and so the ground
/// underneath matches if the preloader ever fades early.
class AppLoadingPlaceholder extends StatelessWidget {
  const AppLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFF0B0B0B));
}

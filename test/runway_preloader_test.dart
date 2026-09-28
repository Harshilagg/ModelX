import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/features/launch/app_ready.dart';
import 'package:flutter_application_modelx/features/launch/runway_painter.dart';
import 'package:flutter_application_modelx/features/launch/runway_preloader.dart';
import 'package:flutter_application_modelx/features/launch/runway_scene.dart';
import 'package:flutter_application_modelx/onboarding/splash_page.dart'
    show kWordmark;

/// WCAG relative contrast between two opaque colours.
double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

Future<void> pump(
  WidgetTester tester, {
  required Future<void> ready,
  required VoidCallback onFinished,
  bool reduceMotion = false,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reduceMotion),
        child: RunwayPreloader(ready: ready, onFinished: onFinished),
      ),
    ),
  );
}

void main() {
  group('the walk', () {
    testWidgets('plays in full even when startup is instant', (tester) async {
      // Cutting the animation short on a fast device reads as a glitch
      // rather than as speed.
      var finished = false;
      await pump(
        tester,
        ready: Future<void>.value(),
        onFinished: () => finished = true,
      );

      await tester.pump(const Duration(seconds: 2));
      expect(finished, isFalse, reason: 'handed over mid-walk');

      await tester.pump(const Duration(seconds: 2));
      expect(finished, isFalse, reason: 'handed over before the finale');

      await tester.pump(const Duration(seconds: 4));
      expect(finished, isTrue);
    });

    test('the last step is both feet on the mark', () {
      final last = RunwayScene.step(RunwayScene.stepCount - 1);
      expect(last.at.dx, RunwayScene.mark.dx);
      expect(last.scale, closeTo(1.0, 0.001));
    });

    test('steps alternate either side of the centre line', () {
      final first = RunwayScene.step(0);
      final second = RunwayScene.step(1);
      expect(first.at.dx, lessThan(RunwayScene.mark.dx));
      expect(second.at.dx, greaterThan(RunwayScene.mark.dx));
    });

    test('steps grow and spread as they come forward', () {
      // A flat plane only reads as receding if the spacing opens out.
      final gaps = [
        for (var i = 1; i < RunwayScene.stepCount; i++)
          RunwayScene.step(i).at.dy - RunwayScene.step(i - 1).at.dy,
      ];
      for (var i = 1; i < gaps.length; i++) {
        expect(gaps[i], greaterThan(gaps[i - 1]), reason: 'gap $i');
      }
      expect(
        RunwayScene.step(0).scale,
        lessThan(RunwayScene.step(RunwayScene.stepCount - 1).scale),
      );
    });
  });

  group('waiting for a slow start', () {
    testWidgets('holds until startup is done, then finishes', (tester) async {
      var finished = false;
      final slow = Completer<void>();

      await pump(tester, ready: slow.future, onFinished: () => finished = true);

      // Well past the walk, and still waiting.
      await tester.pump(const Duration(seconds: 6));
      expect(finished, isFalse);
      expect(
        find.text('Almost ready'),
        findsOneWidget,
        reason: 'the caption should say it is still working',
      );

      slow.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(finished, isTrue);
    });

    testWidgets('says what it is doing before that', (tester) async {
      await pump(tester, ready: Completer<void>().future, onFinished: () {});
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Setting the stage'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('a failed start', () {
    testWidgets('stops waiting rather than holding forever', (tester) async {
      // Startup owns its own error handling. Swallowing the failure
      // here would hide an error the app is already prepared to show.
      var finished = false;
      final failing = Completer<void>();

      await pump(
        tester,
        ready: failing.future,
        onFinished: () => finished = true,
      );
      await tester.pump(const Duration(seconds: 5));

      failing.completeError(StateError('startup failed'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(finished, isTrue);
    });
  });

  group('reduced motion', () {
    testWidgets('shows the scene still and hands straight over', (
      tester,
    ) async {
      var finished = false;
      await pump(
        tester,
        ready: Future<void>.value(),
        onFinished: () => finished = true,
        reduceMotion: true,
      );

      // pumpAndSettle would time out if anything were looping.
      await tester.pumpAndSettle();
      expect(finished, isTrue);
    });
  });

  group('fitting the screen', () {
    test('anchors the runway to the bottom on any aspect', () {
      // The runway recedes to a vanishing point, so the bottom edge is
      // the one that must stay put.
      for (final size in [
        const Size(375, 667), // SE
        const Size(390, 844), // the artboard
        const Size(430, 932), // Pro Max
      ]) {
        final placed = RunwayPainter.fit(size);
        expect(placed.scale, closeTo(size.width / 390, 0.001));
        expect(
          placed.origin.dy + RunwayScene.boardHeight * placed.scale,
          closeTo(size.height, 0.001),
          reason: '$size',
        );
      }
    });

    testWidgets('lays out on an SE and a Pro Max', (tester) async {
      for (final size in [const Size(375, 667), const Size(430, 932)]) {
        await pump(
          tester,
          ready: Future<void>.value(),
          onFinished: () {},
          size: size,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: '$size');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('the front row', () {
    test('stands out from the ground rather than sinking into it', () {
      // The design's own fills were darker than the background --
      // #040404 and #020202 against #0B0B0B -- so the figures were
      // holes cut in an already black screen and only the rim light
      // gave them away.
      final ground = RunwayScene.ground.computeLuminance();
      expect(RunwayScene.frontRowFar.computeLuminance(), greaterThan(ground));
      expect(RunwayScene.frontRowNear.computeLuminance(), greaterThan(ground));
    });

    test('the near figures stay darker, so depth still sorts', () {
      expect(
        RunwayScene.frontRowNear.computeLuminance(),
        lessThan(RunwayScene.frontRowFar.computeLuminance()),
      );
    });

    test('every figure takes one of the two depths', () {
      // So a colour change reaches all of them rather than leaving one
      // behind on a literal.
      for (final figure in [
        ...RunwayScene.frontRowLeft,
        ...RunwayScene.frontRowRight,
        RunwayScene.frontRowCentre,
      ]) {
        expect(
          figure.fill,
          anyOf(RunwayScene.frontRowFar, RunwayScene.frontRowNear),
        );
      }
    });

    test('they stay dark enough to read as a crowd, not as walls', () {
      // Past the floor they stop being silhouettes.
      expect(
        RunwayScene.frontRowFar.computeLuminance(),
        lessThan(RunwayScene.floor.computeLuminance() + 0.03),
      );
    });
  });

  group('the brand', () {
    test('the name and the accent each live in one place', () {
      expect(RunwayScene.appName, 'ModelX');
      expect(RunwayScene.accent, const Color(0xFF6B1F2A));
      expect(RunwayScene.accentGlow, const Color(0xFFBF4A5B));
    });

    test('the wordmark is the lockup the rest of the app uses', () {
      // The splash sets it at 15pt with 5.1 of tracking. That ratio is
      // the mark; the size is just how big it is drawn. If these two
      // drift, the flood and the screen after it stop matching.
      expect(RunwayScene.wordmarkTracking, closeTo(5.1 / 15, 0.001));
      expect(RunwayScene.appName, kWordmark);
    });

    test('the wordmark fits the narrowest screen it ships on', () {
      final painter = TextPainter(
        text: TextSpan(
          text: RunwayScene.appName.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Albert Sans',
            fontWeight: FontWeight.w500,
            fontSize: RunwayScene.wordmarkSize,
            letterSpacing: RunwayScene.wordmarkLetterSpacing,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // 360 wide, less a 24pt gutter either side.
      expect(painter.width, lessThanOrEqualTo(360 - 48));
    });

    test('the flood carries the wordmark', () {
      expect(
        contrast(
          RunwayScene.accent,
          RunwayScene.wordmarkInk(RunwayScene.accent),
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('the feet still read on the floor once they turn accent', () {
      // The reason accentGlow exists. Oxblood itself is 1.7:1 here, so
      // recolouring the feet with the flood colour would erase them at
      // the moment they land.
      expect(
        contrast(RunwayScene.accentGlow, RunwayScene.ground),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        RunwayScene.accentGlow.computeLuminance(),
        greaterThan(RunwayScene.accent.computeLuminance()),
      );
    });

    test('the wordmark stays legible whatever the accent becomes', () {
      // A light accent needs dark type on it.
      for (final accent in [
        RunwayScene.accent,
        const Color(0xFF2A3FF5), // the cobalt this replaced
        const Color(0xFFC29A60), // brass, which sits near the crossover
        const Color(0xFFF0E9C8),
      ]) {
        final ink = RunwayScene.wordmarkInk(accent);
        expect(
          contrast(accent, ink),
          greaterThanOrEqualTo(4.5),
          reason: '$accent was given the less legible of the two inks',
        );
      }
    });
  });

  group('the readiness signal', () {
    testWidgets('reports once a real screen mounts', (tester) async {
      var signalled = false;
      unawaited(AppReady.future.then((_) => signalled = true));

      await tester.pumpWidget(
        const MaterialApp(
          home: AppReadyMarker(child: Scaffold(body: Text('a real screen'))),
        ),
      );
      await tester.pump();
      expect(signalled, isTrue);
    });
  });
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/ui/app_theme.dart';
import 'package:flutter_application_modelx/widgets/circular_gallery.dart';

List<GalleryShot> shots(int n) => [
  for (var i = 0; i < n; i++)
    GalleryShot(
      url: 'https://example.test/$i.jpg',
      label: (i + 1).toString().padLeft(2, '0'),
    ),
];

Future<void> pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

void main() {
  group('the arc', () {
    const halfWidth = 195.0;
    const bend = 56.0;

    test('the middle frame sits flat and square', () {
      final at = CircularGallery.arc(x: 0, halfWidth: halfWidth, bend: bend);
      expect(at.drop, 0);
      expect(at.angle, 0);
    });

    test('bend is exactly the drop at the edge', () {
      // The whole shape is defined by this one number, so it has to
      // mean what it says rather than being a vague strength dial.
      final at = CircularGallery.arc(
        x: halfWidth,
        halfWidth: halfWidth,
        bend: bend,
      );
      expect(at.drop, closeTo(bend, 0.001));
    });

    test('frames further out sit lower and lean further', () {
      double dropAt(double x) =>
          CircularGallery.arc(x: x, halfWidth: halfWidth, bend: bend).drop;
      double angleAt(double x) => CircularGallery.arc(
        x: x,
        halfWidth: halfWidth,
        bend: bend,
      ).angle.abs();

      expect(dropAt(50), lessThan(dropAt(120)));
      expect(dropAt(120), lessThan(dropAt(195)));
      expect(angleAt(50), lessThan(angleAt(120)));
    });

    test('the two sides mirror each other', () {
      final left = CircularGallery.arc(
        x: -120,
        halfWidth: halfWidth,
        bend: bend,
      );
      final right = CircularGallery.arc(
        x: 120,
        halfWidth: halfWidth,
        bend: bend,
      );
      expect(left.drop, closeTo(right.drop, 1e-9));
      expect(left.angle, closeTo(-right.angle, 1e-9));
    });

    test('a frame past the edge does not produce NaN', () {
      // Frames do travel beyond the edge on their way out of view, and
      // the circle has no solution out there.
      for (final x in [400.0, -400.0, 100000.0]) {
        final at = CircularGallery.arc(x: x, halfWidth: halfWidth, bend: bend);
        expect(at.drop.isFinite, isTrue, reason: 'drop at $x');
        expect(at.angle.isFinite, isTrue, reason: 'angle at $x');
      }
    });

    test('no bend lays the frames flat', () {
      for (final x in [-195.0, 0.0, 195.0]) {
        final at = CircularGallery.arc(x: x, halfWidth: halfWidth, bend: 0);
        expect(at.drop, 0);
        expect(at.angle, 0);
      }
    });

    test('the drop really follows a circle', () {
      // Checks the geometry rather than the code: every frame must be
      // the same distance from the centre of the circle it sits on.
      const b = 56.0;
      final radius = (halfWidth * halfWidth + b * b) / (2 * b);
      for (final x in [0.0, 40.0, 110.0, 195.0]) {
        final drop = CircularGallery.arc(
          x: x,
          halfWidth: halfWidth,
          bend: b,
        ).drop;
        // Centre of the circle is `radius` below the middle frame.
        final dy = radius - drop;
        expect(math.sqrt(x * x + dy * dy), closeTo(radius, 0.001));
      }
    });
  });

  group('the gallery', () {
    testWidgets('shows nothing when there are no shots', (tester) async {
      await pump(tester, CircularGallery(shots: const []));
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('lays out and labels its frames', (tester) async {
      await pump(tester, CircularGallery(shots: shots(4)));
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
    });

    testWidgets('loops, so dragging never reaches an end', (tester) async {
      await pump(tester, CircularGallery(shots: shots(3)));
      final view = tester.widget<PageView>(find.byType(PageView));

      // Far more pages than shots: the real one is read back with a
      // modulo, so there is no edge to hit in either direction.
      expect(
        view.childrenDelegate.estimatedChildCount,
        greaterThan(shots(3).length * 100),
      );
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.initialPage,
        greaterThan(0),
      );
    });

    testWidgets('a tap reports the real shot, not the looped page', (
      tester,
    ) async {
      int? tapped;
      await pump(
        tester,
        CircularGallery(shots: shots(3), onTap: (i) => tapped = i),
      );
      // The centre of the row, which is the frame sitting flat and
      // square under the finger.
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await tester.pump();
      expect(tapped, isNotNull);
      expect(tapped, inInclusiveRange(0, 2));
    });

    testWidgets('survives a drag', (tester) async {
      await pump(tester, CircularGallery(shots: shots(5)));
      await tester.drag(find.byType(PageView), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

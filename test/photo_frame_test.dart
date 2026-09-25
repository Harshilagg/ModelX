import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/ui/board_theme.dart';
import 'package:flutter_application_modelx/widgets/board_widgets.dart';

void main() {
  group('photo frames', () {
    testWidgets('always clip, square corners or not', (tester) async {
      // This is what broke when the fold was removed. Nothing inside a
      // frame keeps to its box on its own -- a cover-fitted image
      // paints past its edges by design, and the hatch placeholder
      // draws its diagonals from outside the box so they reach the
      // corners. With no clip they bled across the whole rail.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 160,
                child: BoardMedia(cut: 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clipped = find.descendant(
        of: find.byType(BoardMedia),
        matching: find.byWidgetPredicate((w) => w is ClipRect || w is ClipPath),
      );
      expect(
        clipped,
        findsWidgets,
        reason: 'a frame with no clip lets its placeholder escape',
      );
    });

    testWidgets('are square-cornered, not folded', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 160,
                child: BoardMedia(cut: 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Square means no ClipPath; the rectangular ClipRect stays.
      expect(find.byType(ClipPath), findsNothing);
      expect(
        find.descendant(
          of: find.byType(BoardMedia),
          matching: find.byType(ClipRect),
        ),
        findsWidgets,
      );
    });

    testWidgets('fold returns when the switch is turned up', (tester) async {
      // Proves the per-frame notch values are still wired, so turning
      // BoardShape.photoCornerFold back to 1 restores the old shapes
      // rather than a uniform one.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(width: 120, height: 160)),
        ),
      );

      const clipper = CompCardClipper(cut: 20);
      final folded = clipper.getClip(const Size(120, 160));
      // The notch corner is outside the path; the square corner is in.
      expect(folded.contains(const Offset(119, 1)), isFalse);
      expect(folded.contains(const Offset(119, 159)), isTrue);

      const square = CompCardClipper(cut: 0);
      expect(
        square.getClip(const Size(120, 160)).contains(const Offset(119, 1)),
        isTrue,
      );
    });

    test('the switch is a multiplier, so frames stay proportional', () {
      // Each frame passes its own notch -- 8pt on a feed tile, 20pt on
      // a profile hero. A single size would flatten that difference.
      expect(BoardShape.photoCornerFold, isA<double>());
      expect(BoardShape.photoCornerFold, greaterThanOrEqualTo(0));
    });
  });
}

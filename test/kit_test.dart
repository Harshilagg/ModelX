import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/ui/app_theme.dart';
import 'package:flutter_application_modelx/ui/board_theme.dart';
import 'package:flutter_application_modelx/widgets/kit/kit.dart';

Future<void> pump(WidgetTester tester, Widget child, {Size? size}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.night(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('AppStatus.parse', () {
    test('classifies the vocabulary actually stored', () {
      expect(AppStatus.parse('applied'), AppStatus.applied);
      expect(AppStatus.parse('PENDING'), AppStatus.applied);
      expect(AppStatus.parse('Shortlisted'), AppStatus.shortlisted);
      expect(AppStatus.parse('callback'), AppStatus.shortlisted);
      expect(AppStatus.parse('negotiating'), AppStatus.negotiating);
      expect(AppStatus.parse('ACCEPTED'), AppStatus.booked);
      expect(AppStatus.parse('booked'), AppStatus.booked);
      expect(AppStatus.parse('open'), AppStatus.open);
      expect(AppStatus.parse('rejected'), AppStatus.rejected);
      expect(AppStatus.parse('closed'), AppStatus.rejected);
    });

    test('"not selected" is a rejection, not a booking', () {
      // Both branches match on 'select'. If rejection is not tested
      // first, telling someone they did not get the job reads as
      // telling them they did.
      expect(AppStatus.parse('not selected'), AppStatus.rejected);
      expect(AppStatus.parse('selected'), AppStatus.booked);
    });

    test('anything unrecognised falls back rather than inventing a state', () {
      expect(AppStatus.parse('something unheard of'), AppStatus.applied);
      expect(AppStatus.parse(''), AppStatus.applied);
    });

    test('a rejection never claims attention', () {
      expect(AppStatus.rejected.needsAttention, isFalse);
      expect(AppStatus.booked.needsAttention, isTrue);
      // ...and sorts last, so it cannot head a list by accident.
      expect(
        AppStatus.rejected.urgency,
        greaterThan(AppStatus.applied.urgency),
      );
    });

    test('a model is told "Not selected", never "Rejected"', () {
      expect(AppStatus.rejected.label, 'Not selected');
    });
  });

  group('AppStatusBadge', () {
    testWidgets('open carries no fill', (tester) async {
      await pump(tester, const AppStatusBadge(AppStatus.open));
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppStatusBadge),
          matching: find.byType(Container),
        ),
      );
      final d = box.decoration as BoxDecoration;
      expect(d.color, Colors.transparent);
      expect(d.border, isNotNull);
    });

    testWidgets('amber takes ink, not bone, or it cannot be read', (
      tester,
    ) async {
      await pump(tester, const AppStatusBadge(AppStatus.shortlisted));
      final text = tester.widget<Text>(find.text('Shortlisted'));
      expect(text.style?.color, BoardColors.ink);
    });

    testWidgets('a label override wins over the stored wording', (
      tester,
    ) async {
      await pump(
        tester,
        const AppStatusBadge(AppStatus.applied, label: 'To review'),
      );
      expect(find.text('To review'), findsOneWidget);
      expect(find.text('Applied'), findsNothing);
    });
  });

  group('GreyscaleReveal', () {
    test('fully desaturated collapses every channel onto luminance', () {
      final m = GreyscaleReveal.saturationMatrix(saturation: 0);
      // Row 1 and row 2 must be identical to row 0: that is what grey
      // means. If they differ the image keeps a colour cast.
      expect(m.sublist(0, 3), m.sublist(5, 8));
      expect(m.sublist(0, 3), m.sublist(10, 13));
      expect(m[0] + m[1] + m[2], closeTo(1.0, 1e-9));
    });

    test('fully saturated is the identity', () {
      final m = GreyscaleReveal.saturationMatrix(saturation: 1);
      expect(m[0], closeTo(1, 1e-9));
      expect(m[1], closeTo(0, 1e-9));
      expect(m[6], closeTo(1, 1e-9));
      expect(m[12], closeTo(1, 1e-9));
    });

    test('brightness scales the colour rows but never alpha', () {
      final m = GreyscaleReveal.saturationMatrix(
        saturation: 1,
        brightness: 0.5,
      );
      expect(m[0], closeTo(0.5, 1e-9));
      // Alpha row untouched -- dimming must not make an image
      // translucent.
      expect(m[18], 1);
      expect(m[19], 0);
    });
  });

  group('AppChipGroup', () {
    testWidgets('single-select replaces, and re-tapping clears', (
      tester,
    ) async {
      var value = <String>[];
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => AppChipGroup(
            options: const ['Fashion', 'Beauty'],
            selected: value,
            multiSelect: false,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );

      await tester.tap(find.text('Fashion'));
      await tester.pumpAndSettle();
      expect(value, ['Fashion']);

      await tester.tap(find.text('Beauty'));
      await tester.pumpAndSettle();
      expect(value, ['Beauty'], reason: 'single-select must replace');

      // Without this there is no way to undo a single-select that has
      // no "none of these" option.
      await tester.tap(find.text('Beauty'));
      await tester.pumpAndSettle();
      expect(value, isEmpty);
    });

    testWidgets('multi-select accumulates', (tester) async {
      var value = <String>[];
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => AppChipGroup(
            options: const ['Runway Walk', 'Posing'],
            selected: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      await tester.tap(find.text('Runway Walk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Posing'));
      await tester.pumpAndSettle();
      expect(value, ['Runway Walk', 'Posing']);
    });
  });

  group('AppPillButton', () {
    testWidgets('busy swaps the label and blocks the tap', (tester) async {
      var taps = 0;
      await pump(
        tester,
        AppPillButton(
          label: 'Create my profile',
          busyLabel: 'Creating your profile...',
          busy: true,
          onPressed: () => taps++,
        ),
      );
      expect(find.text('Creating your profile...'), findsOneWidget);
      await tester.tap(find.byType(AppPillButton));
      await tester.pumpAndSettle();
      expect(taps, 0, reason: 'a busy button must not submit twice');
    });

    testWidgets('meets the minimum tap target', (tester) async {
      await pump(tester, AppPillButton(label: 'Continue', onPressed: () {}));
      expect(
        tester.getSize(find.byType(AppPillButton)).height,
        greaterThanOrEqualTo(AppMetrics.tapTarget),
      );
    });
  });

  group('AppField', () {
    testWidgets('an error replaces the hint rather than stacking', (
      tester,
    ) async {
      await pump(
        tester,
        const AppField(
          label: 'Email',
          hint: 'Use your company email if you have one.',
          error: 'Enter a valid email address.',
          child: SizedBox(height: 52),
        ),
      );
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(
        find.text('Use your company email if you have one.'),
        findsNothing,
      );
    });

    testWidgets('marks what is optional, not what is required', (tester) async {
      await pump(
        tester,
        const AppField(
          label: 'Phone number',
          optional: true,
          child: SizedBox(height: 52),
        ),
      );
      expect(find.text('Optional'), findsOneWidget);
    });
  });

  group('AppStepShell', () {
    testWidgets('lays out at 360x640 without overflowing', (tester) async {
      await pump(
        tester,
        AppStepShell(
          step: 1,
          total: 4,
          title: 'About you',
          hint: 'This is how brands and agencies will know you.',
          onBack: () {},
          footer: AppPillButton(label: 'Continue', onPressed: () {}),
          children: const [
            AppField(label: 'Full name', child: SizedBox(height: 52)),
            AppField(label: 'City', child: SizedBox(height: 52)),
          ],
        ),
        size: const Size(360, 640),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Step 2 of 4'), findsOneWidget);
    });

    testWidgets('scrolls back to the top when the step changes', (
      tester,
    ) async {
      // Step 3 opening halfway down because step 2 was scrolled is the
      // single most common bug in a multi-step form.
      Widget shell(int step) => AppStepShell(
        step: step,
        total: 4,
        title: 'Step $step',
        onBack: () {},
        footer: AppPillButton(label: 'Continue', onPressed: () {}),
        children: [
          for (var i = 0; i < 20; i++)
            AppField(label: 'Field $i', child: const SizedBox(height: 52)),
        ],
      );

      await pump(tester, shell(0), size: const Size(390, 700));
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Scrollable>(scrollable).controller!.offset,
        greaterThan(0),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.night(),
          home: Scaffold(body: shell(1)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Scrollable>(find.byType(Scrollable).first)
            .controller!
            .offset,
        0,
      );
    });
  });
}

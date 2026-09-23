import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/onboarding/masonry_background.dart';
import 'package:flutter_application_modelx/onboarding/onboarding_theme.dart';
import 'package:flutter_application_modelx/onboarding/role_select_page.dart';
import 'package:flutter_application_modelx/onboarding/splash_page.dart';
import 'package:flutter_application_modelx/ui/board_palette.dart';
import 'package:flutter_application_modelx/ui/board_theme.dart';

/// Pumps a page at a given size, with optional reduced motion.
Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(390, 844),
  bool reduceMotion = false,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: page,
      ),
    ),
  );
}

void main() {
  group('masonry', () {
    test('every photo appears exactly once across the columns', () {
      // A photo in two columns is visibly the same image scrolling in
      // two places at once.
      final used = [for (final c in MasonryBackground.columns) ...c.photos]
        ..sort();
      expect(used, List.generate(OnboardingPhotos.masonry.length, (i) => i));
    });

    test(
      'the spotlight visits every photo, and never twice in a row in one column',
      () {
        final order = MasonryBackground.spotlightOrder;
        expect(order.toSet().length, order.length, reason: 'no repeats');
        expect(
          order.toSet(),
          List.generate(OnboardingPhotos.masonry.length, (i) => i).toSet(),
        );

        int columnOf(int photo) => MasonryBackground.columns.indexWhere(
          (c) => c.photos.contains(photo),
        );

        // The point of the order is that the lit photo jumps across the
        // screen rather than walking down one column.
        for (var i = 0; i < order.length; i++) {
          final a = columnOf(order[i]);
          final b = columnOf(order[(i + 1) % order.length]);
          expect(
            a == b,
            isFalse,
            reason:
                'photos ${order[i]} and ${order[(i + 1) % order.length]} '
                'are both in column $a',
          );
        }
      },
    );

    test('there is a height for every photo', () {
      expect(MasonryBackground.heights.length, OnboardingPhotos.masonry.length);
      // Even heights would read as a grid rather than a contact sheet.
      expect(MasonryBackground.heights.toSet().length, greaterThan(4));
    });

    test('no two columns share a loop duration', () {
      final durations = MasonryBackground.columns
          .map((c) => c.duration)
          .toSet();
      expect(durations.length, MasonryBackground.columns.length);
    });

    testWidgets('keeps running without throwing', (tester) async {
      await pumpPage(
        tester,
        const OnboardingTheme(child: Scaffold(body: MasonryBackground())),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      // Left running: the columns repeat forever by design, so the test
      // ends while animating rather than settling.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('stops dead under reduced motion', (tester) async {
      await pumpPage(
        tester,
        const OnboardingTheme(child: Scaffold(body: MasonryBackground())),
        reduceMotion: true,
      );
      // pumpAndSettle would time out if anything were still ticking.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('splash', () {
    testWidgets('offers both ways out from the first slide', (tester) async {
      // A returning user must never have to sit through the carousel to
      // reach the login form.
      await pumpPage(
        tester,
        SplashPage(onCreateAccount: () {}, onLogIn: () {}),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Create an account'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('advances, then stops on the last slide', (tester) async {
      await pumpPage(
        tester,
        SplashPage(onCreateAccount: () {}, onLogIn: () {}),
      );
      expect(find.textContaining('Talent moves'), findsOneWidget);

      await tester.pump(SplashPage.slideDuration);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('More than'), findsOneWidget);

      await tester.pump(SplashPage.slideDuration);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Where casting'), findsOneWidget);

      // Must not wrap around to the beginning.
      await tester.pump(SplashPage.slideDuration * 2);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Where casting'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('does not auto-advance under reduced motion', (tester) async {
      await pumpPage(
        tester,
        SplashPage(onCreateAccount: () {}, onLogIn: () {}),
        reduceMotion: true,
      );
      await tester.pump(SplashPage.slideDuration * 3);
      expect(find.textContaining('Talent moves'), findsOneWidget);
    });

    testWidgets('lays out on a small phone at large text', (tester) async {
      await pumpPage(
        tester,
        SplashPage(onCreateAccount: () {}, onLogIn: () {}),
        size: const Size(360, 640),
        textScale: 1.3,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('role select', () {
    testWidgets('selecting does not navigate; the button does', (tester) async {
      // A single tap that navigated made a mis-tap drop you into the
      // wrong signup, with no way back that keeps what you typed.
      SignupRole? chosen;
      await pumpPage(
        tester,
        RoleSelectPage(onSelected: (r) => chosen = r, onBack: () {}),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agency'));
      await tester.pumpAndSettle();
      expect(chosen, isNull);

      await tester.tap(find.text('Continue as agency'));
      await tester.pumpAndSettle();
      expect(chosen, SignupRole.agency);
    });

    testWidgets('the chosen card grows and the others shrink', (tester) async {
      await pumpPage(tester, RoleSelectPage(onSelected: (_) {}, onBack: () {}));
      await tester.pumpAndSettle();

      double cardHeight(String label) => tester
          .getSize(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(ClipRRect),
                )
                .first,
          )
          .height;

      final modelFirst = cardHeight('Model');
      expect(modelFirst, greaterThan(cardHeight('Brand')));

      await tester.tap(find.text('Brand'));
      await tester.pumpAndSettle();
      expect(cardHeight('Brand'), greaterThan(cardHeight('Model')));
      expect(cardHeight('Model'), lessThan(modelFirst));
    });

    testWidgets('the role dot is brass, never a status colour', (tester) async {
      // Green and amber mean booked and negotiating everywhere else in
      // the app; using them as identity colours here would teach the
      // wrong association on the first screen a user sees.
      await pumpPage(tester, RoleSelectPage(onSelected: (_) {}, onBack: () {}));
      await tester.pumpAndSettle();

      final dots = tester
          .widgetList<Container>(find.byType(Container))
          .where(
            (c) =>
                (c.decoration as BoxDecoration?)?.shape == BoxShape.circle &&
                (c.decoration as BoxDecoration?)?.color == BoardColors.brass,
          );
      expect(dots, isNotEmpty);

      for (final banned in [BoardColors.booked, BoardColors.negotiating]) {
        expect(
          tester
              .widgetList<Container>(find.byType(Container))
              .any((c) => (c.decoration as BoxDecoration?)?.color == banned),
          isFalse,
          reason: '$banned is a status colour',
        );
      }
    });

    testWidgets('each role crops its photo differently', (tester) async {
      // One global crop point leaves at least one card showing a blank
      // wall, because the supplied images put their subject at
      // different heights.
      final crops = SignupRole.values.map((r) => r.crop).toSet();
      expect(crops.length, SignupRole.values.length);
    });

    testWidgets('lays out at 360x640', (tester) async {
      await pumpPage(
        tester,
        RoleSelectPage(onSelected: (_) {}, onBack: () {}),
        size: const Size(360, 640),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('userType', () {
    test('keeps the capitalisation existing documents already use', () {
      // Normalising this would be a data migration, not a redesign.
      expect(SignupRole.model.userType, 'Model');
      expect(SignupRole.brand.userType, 'Brand');
      expect(SignupRole.agency.userType, 'Agency');
    });
  });

  group('onboarding theme', () {
    testWidgets('is dark even when the app is light', (tester) async {
      late BoardPalette seen;
      await pumpPage(
        tester,
        OnboardingTheme(
          child: Builder(
            builder: (context) {
              seen = BoardColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.isNight, isTrue);
    });
  });
}

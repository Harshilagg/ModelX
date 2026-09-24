import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/onboarding/brand_signup_page.dart';
import 'package:flutter_application_modelx/onboarding/login_page.dart';
import 'package:flutter_application_modelx/onboarding/model_signup_page.dart';
import 'package:flutter_application_modelx/onboarding/role_select_page.dart';
import 'package:flutter_application_modelx/onboarding/splash_page.dart';
import 'package:flutter_application_modelx/onboarding/success_page.dart';
import 'package:flutter_application_modelx/ui/app_theme.dart';
import 'package:flutter_application_modelx/ui/app_type.dart';
import 'package:flutter_application_modelx/ui/board_theme.dart';
import 'package:flutter_application_modelx/widgets/kit/kit.dart';

/// Pumps a page under the *light* app theme.
///
/// That is the case that broke: a page returning OnboardingTheme from
/// its own build sits above the Theme it installs, so it read the app's
/// light palette while its children read the dark one -- a light page
/// with dark inputs and bone buttons invisible against bone paper.
Future<void> pumpUnderLight(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: page));
  await tester.pump(const Duration(milliseconds: 600));
}

/// The background of the page's own Scaffold.
Color? scaffoldColour(WidgetTester tester) =>
    tester.widgetList<Scaffold>(find.byType(Scaffold)).last.backgroundColor;

void main() {
  group('onboarding stays dark under the light app theme', () {
    final pages = <String, Widget Function()>{
      'splash': () => SplashPage(onCreateAccount: () {}, onLogIn: () {}),
      'role select': () => RoleSelectPage(onSelected: (_) {}, onBack: () {}),
      'login': () => const OnboardingLoginPage(),
      'model signup': () => const ModelSignupPage(userType: 'Model'),
      'brand signup': () => const BrandSignupFlow(),
      'success': () => SuccessPage(role: SuccessRole.model, onContinue: () {}),
    };

    pages.forEach((name, build) {
      testWidgets('$name paints on ink, not paper', (tester) async {
        await pumpUnderLight(tester, build());
        expect(
          scaffoldColour(tester),
          BoardColors.ink,
          reason: '$name is meant to be dark in both themes',
        );
        await tester.pumpWidget(const SizedBox());
      });
    });
  });

  group('role select', () {
    testWidgets('the continue button is visible against the page', (
      tester,
    ) async {
      // A filled pill is drawn in the foreground colour. If the page
      // resolves its palette from the wrong side of the Theme, the
      // button and the background are the same bone and it disappears.
      await pumpUnderLight(
        tester,
        RoleSelectPage(onSelected: (_) {}, onBack: () {}),
      );

      final pill = tester.widget<Container>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Continue as model'),
            matching: find.byType(AppPillButton),
          ),
          matching: find.byType(Container),
        ),
      );
      final fill = (pill.decoration as BoxDecoration).color;

      expect(fill, isNot(scaffoldColour(tester)));
      expect(fill, BoardColors.onInk);
    });

    testWidgets('continue actually fires', (tester) async {
      SignupRole? chosen;
      await pumpUnderLight(
        tester,
        RoleSelectPage(onSelected: (r) => chosen = r, onBack: () {}),
      );

      await tester.tap(find.text('Continue as model'));
      await tester.pumpAndSettle();
      expect(chosen, SignupRole.model);

      await tester.tap(find.text('Brand'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue as brand'));
      await tester.pumpAndSettle();
      expect(chosen, SignupRole.brand);
    });
  });

  group('header controls', () {
    testWidgets('the log-in button reads on one line', (tester) async {
      // It was inside a box fixed to the back button's width, so
      // "Log in" wrapped to roughly one letter per line.
      await pumpUnderLight(
        tester,
        RoleSelectPage(onSelected: (_) {}, onBack: () {}, onLogIn: () {}),
      );

      final label = find.text('Log in');
      expect(label, findsOneWidget);

      final size = tester.getSize(label);
      final oneLine = AppType.label().fontSize! * AppType.label().height!;
      expect(
        size.height,
        lessThan(oneLine * 1.6),
        reason: 'the label wrapped onto more than one line',
      );
      // Wide enough to be the word rather than a stack of letters.
      expect(size.width, greaterThan(size.height));
    });

    testWidgets('tapping it fires', (tester) async {
      var tapped = false;
      await pumpUnderLight(
        tester,
        RoleSelectPage(
          onSelected: (_) {},
          onBack: () {},
          onLogIn: () => tapped = true,
        ),
      );
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('it is absent when there is nowhere to go', (tester) async {
      await pumpUnderLight(
        tester,
        RoleSelectPage(onSelected: (_) {}, onBack: () {}),
      );
      expect(find.text('Log in'), findsNothing);
    });
  });

  group('splash', () {
    testWidgets('the scrim fades to ink, never to paper', (tester) async {
      // The scrim sits over the masonry. Resolved from the light
      // palette it became a white column fading down the lower half of
      // the screen.
      await pumpUnderLight(
        tester,
        SplashPage(onCreateAccount: () {}, onLogIn: () {}),
      );

      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.gradient)
          .whereType<LinearGradient>();

      expect(gradients, isNotEmpty);
      for (final g in gradients) {
        for (final c in g.colors) {
          expect(
            Color(c.toARGB32()).withValues(alpha: 1),
            BoardColors.ink,
            reason: 'scrim must fade to ink',
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  });
}

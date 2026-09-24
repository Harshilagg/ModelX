import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_modelx/onboarding/login_page.dart';
import 'package:flutter_application_modelx/ui/app_theme.dart';

/// Opens the app the way a returning visitor sees it.
///
/// Once the splash has been seen, AppEntry hands off to AuthGate, which
/// with no signed-in user shows login as the *root* route -- nothing
/// underneath it. That is the state the signup dead end lived in, and
/// none of the earlier tests reproduced it: they all entered from the
/// splash, where login is pushed and the routing came from the flow.
Future<void> openAsReturningVisitor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light(), home: const OnboardingLoginPage()),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('creating an account from a root login', () {
    testWidgets('reaches a role picker that actually works', (tester) async {
      await openAsReturningVisitor(tester);
      expect(find.text('Welcome back.'), findsOneWidget);

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('How will you use ModelX?'), findsOneWidget);

      // All three of these were broken, and together they left no way
      // out of the screen but killing the app.
      expect(
        find.text('Log in'),
        findsOneWidget,
        reason: 'the log-in control must be offered',
      );
      expect(
        find.bySemanticsLabel('Go back'),
        findsOneWidget,
        reason: 'there must be something to go back to',
      );

      await tester.tap(find.text('Continue as model'));
      await tester.pumpAndSettle();
      expect(
        find.text('Create your account'),
        findsOneWidget,
        reason: 'Continue must route somewhere',
      );
    });

    testWidgets('back from the role picker returns to login', (tester) async {
      await openAsReturningVisitor(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Go back'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back.'), findsOneWidget);
    });

    testWidgets('log in from the role picker returns to login', (tester) async {
      // Not a second login pushed on top: the one underneath.
      await openAsReturningVisitor(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.text('How will you use ModelX?'), findsNothing);
    });

    for (final (chip, cta, title) in const [
      ('Brand', 'Continue as brand', 'Create your brand account'),
      ('Agency', 'Continue as agency', 'Create your agency account'),
    ]) {
      testWidgets('$chip routes too', (tester) async {
        await openAsReturningVisitor(tester);
        await tester.tap(find.text('Create an account'));
        await tester.pumpAndSettle();

        await tester.tap(find.text(chip));
        await tester.pumpAndSettle();
        await tester.tap(find.text(cta));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
      });
    }
  });

  group('login as the root route', () {
    testWidgets('offers no back button, rather than a dead one', (
      tester,
    ) async {
      await openAsReturningVisitor(tester);
      expect(find.bySemanticsLabel('Go back'), findsNothing);
    });

    testWidgets('but the reset views still have one', (tester) async {
      await openAsReturningVisitor(tester);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Go back'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Go back'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back.'), findsOneWidget);
    });
  });
}

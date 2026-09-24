import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/onboarding/auth_router.dart';
import 'package:flutter_application_modelx/onboarding/login_page.dart';

Future<void> pumpLogin(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const OnboardingLoginPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AuthRouter.messageFor', () {
    test('does not reveal whether an address has an account', () {
      // Firebase collapses a wrong password and an unknown email into
      // invalid-credential deliberately, so that the login form cannot
      // be used to enumerate who is registered. The wording has to stay
      // vague to match, or it undoes that.
      final unknown = AuthRouter.messageFor(
        FirebaseAuthException(code: 'user-not-found'),
      );
      final wrongPassword = AuthRouter.messageFor(
        FirebaseAuthException(code: 'wrong-password'),
      );
      final collapsed = AuthRouter.messageFor(
        FirebaseAuthException(code: 'invalid-credential'),
      );
      expect(unknown, wrongPassword);
      expect(wrongPassword, collapsed);
      expect(unknown, isNot(contains('account')));
    });

    test('says something useful for the failures worth distinguishing', () {
      expect(
        AuthRouter.messageFor(FirebaseAuthException(code: 'too-many-requests')),
        contains('Too many'),
      );
      expect(
        AuthRouter.messageFor(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        contains('connection'),
      );
    });

    test('a non-Firebase error still produces a sentence', () {
      expect(AuthRouter.messageFor(StateError('boom')), isNotEmpty);
    });
  });

  group('login screen', () {
    testWidgets('validates before touching the network', (tester) async {
      await pumpLogin(tester);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the email you signed up with.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('errors clear as soon as the field is corrected', (
      tester,
    ) async {
      // Leaving a field red while it is being fixed reads as the fix
      // not working.
      await pumpLogin(tester);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your password.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'a@b.com');
      await tester.pumpAndSettle();
      expect(find.text('Enter your password.'), findsNothing);
    });

    testWidgets('forgot-password carries the email already typed', (
      tester,
    ) async {
      await pumpLogin(tester);
      await tester.enterText(
        find.byType(TextField).first,
        'someone@example.com',
      );
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset your password'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller?.text, 'someone@example.com');
    });

    testWidgets('reset validates the address', (tester) async {
      await pumpLogin(tester);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'not-an-email');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('back steps through the views rather than leaving', (
      tester,
    ) async {
      await pumpLogin(tester);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('Reset your password'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Go back'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back.'), findsOneWidget);
    });

    testWidgets('offers Google, and does not offer a dead Apple button', (
      tester,
    ) async {
      // Sign in with Apple is not implemented. Rendering it disabled
      // would advertise something that does not work.
      await pumpLogin(tester);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
    });

    testWidgets('both boxes are the same size and both carry a hint', (
      tester,
    ) async {
      // Equal height was never the whole story. An email box with grey
      // placeholder text beside an empty password box reads as two
      // different controls even when they measure the same, which is
      // what made the form look unconsidered.
      await pumpLogin(tester);

      final boxes = find.byType(InputDecorator);
      expect(boxes, findsNWidgets(2));
      expect(tester.getSize(boxes.at(0)), tester.getSize(boxes.at(1)));

      for (var i = 0; i < 2; i++) {
        final decoration = tester
            .widget<InputDecorator>(boxes.at(i))
            .decoration;
        expect(
          decoration.hintText,
          isNotNull,
          reason: 'input $i renders as an empty box',
        );
        expect(decoration.hintText, isNotEmpty);
      }
    });

    testWidgets('lays out at 360x640', (tester) async {
      await pumpLogin(tester, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
    });
  });
}

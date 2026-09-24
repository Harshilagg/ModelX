import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/onboarding/agency_signup_page.dart';
import 'package:flutter_application_modelx/onboarding/brand_signup_page.dart';

Future<void> pump(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('brand signup', () {
    testWidgets('validates step 1 before advancing', (tester) async {
      await pump(tester, const BrandSignupFlow());
      expect(find.text('Step 1 of 3'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);
    });

    testWidgets('industry is single-select', (tester) async {
      // A brand that is two industries is really the first one, and the
      // stored field is a single string.
      await pump(tester, const BrandSignupFlow());
      await tester.enterText(find.byType(TextField).first, 'a@b.com');
      await tester.enterText(find.byType(TextField).last, 'longenough');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 3'), findsOneWidget);
      await tester.tap(find.text('Fashion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beauty'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      // Name and city are still empty, so it must not advance -- and
      // the industry error must be gone, proving one chip stuck.
      expect(find.text('Pick the industry that fits best.'), findsNothing);
    });

    testWidgets('lays out at 360x640', (tester) async {
      await pump(tester, const BrandSignupFlow(), size: const Size(360, 640));
      expect(tester.takeException(), isNull);
    });
  });

  group('agency signup', () {
    testWidgets('counts digits, not formatting, in the phone number', (
      tester,
    ) async {
      await pump(tester, const AgencySignupFlow());
      await tester.enterText(find.byType(TextField).first, 'a@b.com');
      await tester.enterText(find.byType(TextField).last, 'longenough');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 3'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Meridian Talent');
      await tester.enterText(fields.at(1), '+91 (22)');
      await tester.enterText(fields.at(2), 'Mumbai');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a phone number brands can reach.'),
        findsOneWidget,
      );

      await tester.enterText(fields.at(1), '+91 22 5555 0100');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 3'), findsOneWidget);
    });

    testWidgets('the last step asks for nothing', (tester) async {
      await pump(tester, const AgencySignupFlow());
      await tester.enterText(find.byType(TextField).first, 'a@b.com');
      await tester.enterText(find.byType(TextField).last, 'longenough');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Meridian');
      await tester.enterText(fields.at(1), '+91 22 5555 0100');
      await tester.enterText(fields.at(2), 'Mumbai');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Create agency account'), findsOneWidget);
      expect(
        find.text('You can edit your agency page anytime.'),
        findsOneWidget,
      );
    });

    testWidgets('lays out at 360x640', (tester) async {
      await pump(tester, const AgencySignupFlow(), size: const Size(360, 640));
      expect(tester.takeException(), isNull);
    });
  });
}

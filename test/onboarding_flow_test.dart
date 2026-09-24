import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_modelx/onboarding/onboarding_flow.dart';
import 'package:flutter_application_modelx/ui/app_theme.dart';

/// Walks the flow from the splash, under the light app theme -- the
/// case where the palette bug hid every button.
Future<void> start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light(), home: const OnboardingFlow()),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> toRoleSelect(WidgetTester tester) async {
  await tester.tap(find.text('Create an account'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the whole way in', () {
    testWidgets('splash reaches the role picker', (tester) async {
      await start(tester);
      expect(find.textContaining('Talent moves'), findsOneWidget);

      await toRoleSelect(tester);
      expect(find.text('How will you use ModelX?'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('splash reaches login', (tester) async {
      await start(tester);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    // The three sides, each all the way from the splash into its own
    // first step. This is what "is the signup flow wired up" means, and
    // nothing short of walking it actually answers the question.
    final sides =
        <String, (String chip, String cta, String title, String step)>{
          'model': (
            'Model',
            'Continue as model',
            'Create your account',
            'Step 1 of 4',
          ),
          'brand': (
            'Brand',
            'Continue as brand',
            'Create your brand account',
            'Step 1 of 3',
          ),
          'agency': (
            'Agency',
            'Continue as agency',
            'Create your agency account',
            'Step 1 of 3',
          ),
        };

    sides.forEach((name, spec) {
      final (chip, cta, title, step) = spec;

      testWidgets('$name: role picker opens its signup', (tester) async {
        await start(tester);
        await toRoleSelect(tester);

        // Model is preselected, so only the other two need a tap.
        if (chip != 'Model') {
          await tester.tap(find.text(chip));
          await tester.pumpAndSettle();
        }

        await tester.tap(find.text(cta));
        await tester.pumpAndSettle();

        expect(
          find.text(title),
          findsOneWidget,
          reason: '$name signup did not open',
        );
        expect(find.text(step), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    });
  });

  group('each signup can be walked', () {
    testWidgets('model: step 1 blocks, then advances', (tester) async {
      await start(tester);
      await toRoleSelect(tester);
      await tester.tap(find.text('Continue as model'));
      await tester.pumpAndSettle();

      // Empty step must not advance.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'anya@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'longenough');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 4'), findsOneWidget);
      expect(find.text('About you'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('brand: reaches its last step', (tester) async {
      await start(tester);
      await toRoleSelect(tester);
      await tester.tap(find.text('Brand'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue as brand'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'hi@brand.com');
      await tester.enterText(find.byType(TextField).at(1), 'longenough');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Your brand'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Lumiere');
      await tester.tap(find.text('Fashion'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Mumbai');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Create brand account'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('agency: reaches its last step', (tester) async {
      await start(tester);
      await toRoleSelect(tester);
      await tester.tap(find.text('Agency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue as agency'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'hi@agency.com');
      await tester.enterText(find.byType(TextField).at(1), 'longenough');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Your agency'), findsOneWidget);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Meridian Talent');
      await tester.enterText(fields.at(1), '+91 22 5555 0100');
      await tester.enterText(fields.at(2), 'Bandra, Mumbai');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Create agency account'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the way back out', () {
    testWidgets('back from a signup returns to the role picker', (
      tester,
    ) async {
      await start(tester);
      await toRoleSelect(tester);
      await tester.tap(find.text('Continue as model'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Go back'));
      await tester.pumpAndSettle();
      expect(find.text('How will you use ModelX?'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('back from the role picker returns to the splash', (
      tester,
    ) async {
      await start(tester);
      await toRoleSelect(tester);
      await tester.tap(find.bySemanticsLabel('Go back'));
      // Not pumpAndSettle: the splash masonry loops forever by design,
      // so nothing on that screen ever settles. Pump past the route
      // transition instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Talent moves'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

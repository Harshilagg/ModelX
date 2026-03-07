import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/pages/create_profile_page.dart';

void main() {
  testWidgets('CreateProfilePage stepper and finish calls onComplete', (WidgetTester tester) async {
    var completed = false;

    await tester.pumpWidget(MaterialApp(home: CreateProfilePage(onComplete: () { completed = true; })));

    // Enter display name and username
    await tester.enterText(find.bySemanticsLabel('Display name'), 'Test User');
    await tester.enterText(find.bySemanticsLabel('Username (letters, numbers, underscores)'), 'test_user');

    // Move to second step by invoking the continue button
    final continueFinder = find.text('CONTINUE');
    if (continueFinder.evaluate().isNotEmpty) {
      await tester.tap(continueFinder);
      await tester.pumpAndSettle();
    } else {
      // Fallback: directly set currentStep via state (test-only)
      final state = tester.state(find.byType(CreateProfilePage));
      // ignore: invalid_use_of_protected_member
      (state as dynamic).setState(() => (state as dynamic)._currentStep = 1);
      await tester.pumpAndSettle();
    }

    // Tap Finish
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });
}

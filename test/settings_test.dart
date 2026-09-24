import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/ui/theme_controller.dart';
import 'package:flutter_application_modelx/widgets/board_widgets.dart';
import 'package:flutter_application_modelx/widgets/kit/kit.dart';

void main() {
  group('ThemeController', () {
    test('reports light while switching is gated, whatever is stored', () {
      final c = ThemeController(ThemeMode.dark);
      expect(c.storedMode, ThemeMode.dark);
      expect(c.mode, kThemeSwitchingEnabled ? ThemeMode.dark : ThemeMode.light);
    });

    test('notifies once per real change', () async {
      final c = ThemeController(ThemeMode.system);
      var notifications = 0;
      c.addListener(() => notifications++);

      await c.setMode(ThemeMode.dark);
      expect(notifications, 1);
      // Setting the same mode again must not churn the whole tree.
      await c.setMode(ThemeMode.dark);
      expect(notifications, 1);
    });
  });

  group('ThemeScope', () {
    testWidgets('hands down the same controller, not a new one', (
      tester,
    ) async {
      final controller = ThemeController(ThemeMode.dark);
      ThemeController? seen;

      await tester.pumpWidget(
        ThemeScope(
          controller: controller,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                seen = ThemeScope.maybeOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(identical(seen, controller), isTrue);
    });

    testWidgets('returns null above the scope rather than throwing', (
      tester,
    ) async {
      ThemeController? seen = ThemeController();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen = ThemeScope.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, isNull);
    });
  });

  group('the top bar counter', () {
    testWidgets('hides the badge at zero and shows it above', (tester) async {
      Future<void> pump(int unread) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardTopBar(initial: 'A', hint: 'Search', unread: unread),
          ),
        ),
      );

      // A "0" in a box reads as a broken counter, not an empty inbox.
      await pump(0);
      await tester.pumpAndSettle();
      expect(find.text('0'), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

      await pump(4);
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);

      await pump(150);
      await tester.pumpAndSettle();
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('meets the minimum tap target', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BoardTopBar(initial: 'A', hint: 'Search', unread: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(
        find.bySemanticsLabel(RegExp('Messages')).first,
      );
      expect(size.height, greaterThanOrEqualTo(AppMetrics.tapTarget));
    });
  });
}

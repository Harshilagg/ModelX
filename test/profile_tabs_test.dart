import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/ui/app_theme.dart';
import 'package:flutter_application_modelx/ui/board_theme.dart';
import 'package:flutter_application_modelx/widgets/board_widgets.dart';

/// Reads the tab labels in the order the rail lays them out.
List<String> railOrder(WidgetTester tester) => tester
    .widgetList<BoardTabRail>(find.byType(BoardTabRail))
    .first
    .tabs
    .toList();

void main() {
  // Both profile pages need Firebase to build, so the order is checked
  // through the rail itself rather than by pumping the screens. What
  // matters is that the two agree and that Portfolio leads.
  group('tab order', () {
    testWidgets('portfolio comes first on a rail of three', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BoardTabRail(
              tabs: const ['Portfolio', 'Details', 'Posts'],
              index: 0,
              onTap: (_) {},
              accent: BoardColors.brass,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(railOrder(tester), ['Portfolio', 'Details', 'Posts']);
    });

    testWidgets('a three-tab rail still fits at 1.5x text', (tester) async {
      // "Portfolio" is the longest of the three and now sits first,
      // where the rail gives the selected tab its accent.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: BoardTabRail(
                tabs: const ['Portfolio', 'Details', 'Posts'],
                index: 0,
                onTap: (_) {},
                accent: BoardColors.brass,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the source files agree', () {
    // A cheap guard that the two screens did not drift: a model looking
    // at their own profile and a brand looking at the same profile
    // should meet the same order.
    test('both pages lead with Portfolio', () {
      for (final path in [
        'lib/pages/profile_page.dart',
        'lib/pages/user_profile_page.dart',
      ]) {
        final source = File(path).readAsStringSync();
        final match = RegExp(r"tabs: const \[([^\]]*)\]").firstMatch(source);
        expect(match, isNotNull, reason: '$path has no tab rail');
        final first = match!.group(1)!.split(',').first.trim();
        expect(first, "'Portfolio'", reason: '$path does not lead with it');
      }
    });

    test('no tab jump is written as a bare number', () {
      // "_tab = 1" meaning Portfolio is what broke when the order
      // changed. Jumps go through the named constant now.
      for (final path in [
        'lib/pages/profile_page.dart',
        'lib/pages/user_profile_page.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          RegExp(r'_tab = [0-9]').hasMatch(source),
          isFalse,
          reason: '$path jumps to a hardcoded tab index',
        );
      }
    });
  });
}

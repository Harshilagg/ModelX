import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/ui/app_theme.dart';
import 'package:flutter_application_modelx/widgets/kit/kit.dart';

const destinations = [
  NavDestination(label: 'Home', glyph: NavGlyph.home),
  NavDestination(label: 'Jobs', glyph: NavGlyph.jobs),
  NavDestination(label: 'Network', glyph: NavGlyph.network),
  NavDestination(label: 'Profile', glyph: NavGlyph.profile),
];

Future<void> pumpBar(
  WidgetTester tester, {
  int index = 0,
  ValueChanged<int>? onTap,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: AppNavBar(
                    destinations: destinations,
                    currentIndex: index,
                    onTap: onTap ?? (_) {},
                  ),
                ),
                const SizedBox(width: 10),
                const SizedBox.square(dimension: AppNavBar.height),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the shell', () {
    // Twice now a destination has been compared against a bare number
    // and quietly meant the wrong tab once the order changed: the "ALL
    // n" link on the profile, and the rule that hides the top bar on
    // Profile, which read != 4 and started showing a second header.
    test('no destination is compared against a bare index', () {
      final source = File('lib/pages/dashboard_page.dart').readAsStringSync();
      final offenders = RegExp(
        r'_selectedIndex\s*(==|!=)\s*[0-9]',
      ).allMatches(source).map((m) => m.group(0)).toList();
      expect(
        offenders,
        isEmpty,
        reason: 'compare against the named constants instead',
      );
    });

    test('the destinations and their search hints stay in step', () {
      // The hints are indexed by the selected tab, so a list of the
      // wrong length reads the wrong hint or throws.
      final source = File('lib/pages/dashboard_page.dart').readAsStringSync();
      // Counted as quoted entries, not by splitting on commas: one of
      // the hints is "Search jobs, brands, cities".
      final hints = RegExp(r"'[^']*'")
          .allMatches(
            RegExp(
              r"_searchHints = \[(.*?)\];",
              dotAll: true,
            ).firstMatch(source)!.group(1)!,
          )
          .length;
      expect(hints, destinations.length);
    });
  });

  group('the bar', () {
    testWidgets('names only the chosen destination', (tester) async {
      // Five labels at a legible size is most of the bar's width, which
      // is why the old bar had none and left the glyphs to explain
      // themselves.
      await pumpBar(tester, index: 1);
      expect(find.text('Jobs'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Network'), findsNothing);
    });

    testWidgets('fits four destinations and the assistant at 390', (
      tester,
    ) async {
      await pumpBar(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('still fits on a 360 phone', (tester) async {
      // The design fixes the open tab at 112, which fits 390 exactly.
      // Narrower than that it has to give, or the row overflows.
      await pumpBar(tester, width: 360);
      expect(tester.takeException(), isNull);
    });

    testWidgets('selecting reports the index', (tester) async {
      int? picked;
      await pumpBar(tester, onTap: (i) => picked = i);
      await tester.tap(find.byType(NavGlyphIcon).at(2));
      await tester.pumpAndSettle();
      expect(picked, 2);
    });

    testWidgets('every destination has a glyph', (tester) async {
      await pumpBar(tester);
      expect(find.byType(NavGlyphIcon), findsNWidgets(destinations.length));
    });

    testWidgets('the bar keeps its height whatever the font scale', (
      tester,
    ) async {
      // The shell places the assistant beside it without measuring, so
      // this must not move with the system font.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: AppNavBar(
                destinations: destinations,
                currentIndex: 0,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppNavBar)).height, AppNavBar.height);
    });
  });

  group('the assistant button', () {
    testWidgets('draws in every state without throwing', (tester) async {
      for (final state in ApertureState.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ApertureButton(state: state, onPressed: () {}),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '$state');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('idle is still, so nothing animates at rest', (tester) async {
      // A button that never stops repainting keeps the whole shell
      // awake behind it.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: ApertureButton())),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('holds still under reduced motion', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: ApertureButton(state: ApertureState.thinking),
              ),
            ),
          ),
        ),
      );
      // pumpAndSettle would time out if the iris were still turning.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports a tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: ApertureButton(onPressed: () => tapped = true)),
          ),
        ),
      );
      await tester.tap(find.byType(ApertureButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });
}

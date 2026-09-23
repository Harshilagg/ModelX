import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/services/application_feed.dart';
import 'package:flutter_application_modelx/ui/app_theme.dart';
import 'package:flutter_application_modelx/widgets/kit/kit.dart';

Application app({
  required String status,
  DateTime? start,
  String title = 'Editorial shoot',
}) =>
    Application(
      id: 'x',
      isGig: true,
      data: const {},
      title: title,
      subtitle: 'Mumbai',
      status: status,
      start: start,
      appliedAt: null,
      posterName: 'Lumiere',
    );

void main() {
  group('relativeTime', () {
    final now = DateTime.now();

    test('reads as English, not as a board stamp', () {
      expect(relativeTime(now.subtract(const Duration(seconds: 20))), 'just now');
      expect(relativeTime(now.subtract(const Duration(minutes: 6))), '6 minutes ago');
      expect(relativeTime(now.subtract(const Duration(hours: 4))), '4 hours ago');
      expect(relativeTime(now.subtract(const Duration(days: 1))), 'yesterday');
      expect(relativeTime(now.subtract(const Duration(days: 3))), '3 days ago');
      expect(relativeTime(now.subtract(const Duration(days: 21))), '3 weeks ago');
    });

    test('turns the old meaningless 193D into something readable', () {
      // The board printed "193D". Nobody reads that as half a year.
      expect(relativeTime(now.subtract(const Duration(days: 193))), '6 months ago');
      expect(relativeTime(now.subtract(const Duration(days: 800))), '2 years ago');
    });

    test('future dates read forwards, because shoot dates usually are', () {
      expect(relativeTime(now.add(const Duration(days: 3))), 'in 3 days');
      expect(relativeTime(now.add(const Duration(days: 1))), 'tomorrow');
    });

    test('singular and plural agree', () {
      expect(relativeTime(now.subtract(const Duration(hours: 1))), '1 hour ago');
      expect(relativeTime(now.subtract(const Duration(hours: 2))), '2 hours ago');
    });

    test('a missing date is not a crash', () {
      expect(relativeTime(null), '--');
    });
  });

  group('what counts as up next', () {
    test('a booking that has already shot is finished work', () {
      // Leaving it at the top would make the card look stuck for weeks
      // after the job was done.
      final past = app(
        status: 'booked',
        start: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(past.isUpNext, isFalse);

      final ahead = app(
        status: 'booked',
        start: DateTime.now().add(const Duration(days: 2)),
      );
      expect(ahead.isUpNext, isTrue);
    });

    test('a booking with no date stays eligible', () {
      // Absent is not the same as past.
      expect(app(status: 'booked').isUpNext, isTrue);
    });

    test('a rejection is never the headline', () {
      // It needs nothing from anyone and is a poor first thing to see.
      expect(app(status: 'rejected').isUpNext, isFalse);
      expect(app(status: 'not selected').isUpNext, isFalse);
    });

    test('a plain application is not waiting on the applicant', () {
      expect(app(status: 'applied').isUpNext, isFalse);
    });

    test('booked outranks negotiating outranks shortlisted', () {
      expect(AppStatus.booked.urgency, lessThan(AppStatus.negotiating.urgency));
      expect(AppStatus.negotiating.urgency,
          lessThan(AppStatus.shortlisted.urgency));
    });
  });

  group('UpNextCard', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('says what to do when there is nothing', (tester) async {
      await pump(tester, const UpNextCard(
        item: null,
        counts: [],
        emptyMessage: 'Nothing needs you right now.',
      ));
      expect(find.text('Nothing needs you right now.'), findsOneWidget);
    });

    testWidgets('counts are tappable and land on their own status',
        (tester) async {
      String? tapped;
      await pump(tester, UpNextCard(
        item: null,
        emptyMessage: 'x',
        counts: [
          UpNextCount(label: 'Applied', value: 3, onTap: () => tapped = 'applied'),
          UpNextCount(label: 'Booked', value: 12, onTap: () => tapped = 'booked'),
        ],
      ));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);

      await tester.tap(find.text('Booked'));
      await tester.pumpAndSettle();
      expect(tapped, 'booked');
    });

    testWidgets('shows one item with its status and a way in', (tester) async {
      var opened = false;
      await pump(tester, UpNextCard(
        counts: const [],
        emptyMessage: 'x',
        item: UpNextItem(
          title: 'Editorial shoot',
          subtitle: 'Lumiere - Shoots in 3 days',
          status: AppStatus.negotiating,
          onOpen: () => opened = true,
        ),
      ));
      expect(find.text('Editorial shoot'), findsOneWidget);
      expect(find.text('Negotiating'), findsOneWidget);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
    });

    testWidgets('lays out at 320dp without overflowing', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pump(tester, UpNextCard(
        emptyMessage: 'x',
        item: UpNextItem(
          title: 'A rather long editorial shoot title that will wrap',
          subtitle: 'Lumiere Studio - Shoots in 3 days',
          status: AppStatus.shortlisted,
          onOpen: () {},
        ),
        counts: const [
          UpNextCount(label: 'Applied', value: 3),
          UpNextCount(label: 'Shortlisted', value: 12),
          UpNextCount(label: 'Negotiating', value: 4),
          UpNextCount(label: 'Booked', value: 1),
        ],
      ));
      expect(tester.takeException(), isNull);
    });
  });
}

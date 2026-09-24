import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/services/copilot_conversation.dart';
import 'package:flutter_application_modelx/ui/app_theme.dart';
import 'package:flutter_application_modelx/widgets/kit/kit.dart';

/// The service is built on the first question rather than with the
/// conversation, so these can construct one without a Firebase app.
/// Nothing here sends a real question.
Future<void> pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the conversation', () {
    test('starts empty and reports no history', () {
      final c = CopilotConversation();
      expect(c.isEmpty, isTrue);
      expect(c.hasHistory, isFalse);
      expect(c.sending, isFalse);
    });

    test('keeps what was asked, so closing does not lose it', () {
      // It used to live on the panel widget, so every close destroyed
      // the thread and every reopen started from nothing.
      final c = CopilotConversation();
      c.messages;
      expect(
        () => c.messages.add(CopilotMessage.user('x')),
        throwsUnsupportedError,
        reason: 'the list is handed out read-only',
      );
    });

    test('clearing empties it and says so', () {
      final c = CopilotConversation();
      var notified = 0;
      c.addListener(() => notified++);
      c.clear();
      expect(notified, 1);
      expect(c.isEmpty, isTrue);
    });

    test('an empty question is not sent', () async {
      final c = CopilotConversation();
      await c.send('   ', const {});
      expect(c.isEmpty, isTrue);
    });
  });

  group('the docked stage', () {
    testWidgets('offers openers and a field, and does not cover the screen', (
      tester,
    ) async {
      final c = CopilotConversation();
      await pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: CopilotDock(
            conversation: c,
            pageContext: const {},
            suggestions: const ['Portfolio tips', 'How do I get hired?'],
            onExpand: () {},
            onDismiss: () {},
          ),
        ),
      );

      expect(find.text('Ask about this screen'), findsOneWidget);
      expect(find.text('Portfolio tips'), findsOneWidget);
      expect(find.byType(AppTextField), findsOneWidget);

      // A dock, not a sheet: it has to stay small enough to leave the
      // screen it is asking about visible.
      final height = tester.getSize(find.byType(CopilotDock)).height;
      expect(height, lessThan(844 * 0.4));
    });

    testWidgets('asking grows the surface before the answer lands', (
      tester,
    ) async {
      // The reply has to arrive somewhere it can be read, so the dock
      // expands on send rather than when the answer returns.
      var expanded = false;
      final c = CopilotConversation();
      await pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: CopilotDock(
            conversation: c,
            pageContext: const {},
            suggestions: const ['Portfolio tips'],
            onExpand: () => expanded = true,
            onDismiss: () {},
          ),
        ),
      );

      await tester.tap(find.text('Portfolio tips'));
      await tester.pump();
      expect(expanded, isTrue);
    });

    testWidgets('invites you back when there is a thread', (tester) async {
      final c = CopilotConversation();
      await c.send('', const {});
      await pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: CopilotDock(
            conversation: c,
            pageContext: const {},
            suggestions: const [],
            onExpand: () {},
            onDismiss: () {},
          ),
        ),
      );
      // Nothing was actually sent, so it still reads as a fresh start.
      expect(find.text('Ask about this screen'), findsOneWidget);
    });
  });

  group('the open stage', () {
    testWidgets('says what it is for when there is nothing yet', (
      tester,
    ) async {
      await pump(
        tester,
        CopilotPanel(
          conversation: CopilotConversation(),
          pageContext: const {},
          onCollapse: () {},
        ),
      );
      expect(find.textContaining('Ask about your profile'), findsOneWidget);
    });

    testWidgets('closes on request', (tester) async {
      var closed = false;
      await pump(
        tester,
        CopilotPanel(
          conversation: CopilotConversation(),
          pageContext: const {},
          onCollapse: () => closed = true,
        ),
      );
      await tester.tap(find.bySemanticsLabel('Close assistant').first);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });

    testWidgets('offers no Clear until there is something to clear', (
      tester,
    ) async {
      await pump(
        tester,
        CopilotPanel(
          conversation: CopilotConversation(),
          pageContext: const {},
          onCollapse: () {},
        ),
      );
      expect(find.text('Clear'), findsNothing);
    });

    testWidgets('lays out at 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CopilotPanel(
              conversation: CopilotConversation(),
              pageContext: const {},
              onCollapse: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

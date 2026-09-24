import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// NotificationsPage reads FirebaseAuth.instance while it builds, so it
/// cannot be pumped without a Firebase app -- the same limitation that
/// leaves create_profile_widget_test red. These check the shape of the
/// source instead, which is weaker than rendering it but does catch the
/// specific thing that broke: a page pushed as a route with no Scaffold
/// of its own comes up black, with the debug underline beneath every
/// line of text, because nothing above it supplies Material.
void main() {
  final source = File('lib/pages/notifications_page.dart').readAsStringSync();

  group('the page shell', () {
    test('brings its own Scaffold when it is not embedded', () {
      expect(source, contains('if (widget.embedded) return body;'));
      expect(source, contains('return Scaffold('));
      expect(source, contains('backgroundColor: BoardColors.paper'));
    });

    test('offers a way back, since it is now a pushed route', () {
      expect(source, contains("semanticLabel: 'Go back'"));
    });

    test('still works as a body inside another screen', () {
      // It is reached from the bell now, but the flag keeps the
      // embedded form available rather than forcing one shape.
      expect(source, contains('final bool embedded;'));
      expect(source, contains('this.embedded = false'));
    });

    test('does not reserve space for a nav bar that is not there', () {
      // Embedded, the floating bar covers the bottom of the page.
      // Pushed, reserving for one leaves a hand's width of empty page.
      expect(source, contains('_footClearance'));
      expect(
        RegExp(r'16,\s*110').hasMatch(source),
        isFalse,
        reason: 'a hardcoded bar clearance is left over',
      );
    });
  });
}

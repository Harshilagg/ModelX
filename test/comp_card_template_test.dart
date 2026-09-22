import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/widgets/comp_card_templates.dart';

/// Every template is drawn at a fixed 396 × 612 and then scaled, so a
/// layout that doesn't fit overflows for real rather than shrinking.
/// These render all ten faces — five templates, front and back — against
/// both a full profile and an empty one.
void main() {
  const full = {
    'fullName': 'Emiliana Jasper-Chandran',
    'location': 'Bengaluru',
    'username': 'emiliana',
    'contact': '+91 98200 00000',
    'height': '175',
    'heightUnit': 'cm',
    'measurements': '82-60-88',
    'shoeSize': '9',
    'shoeSizeUnit': 'UK',
    'hairColor': 'Black',
    'eyeColor': 'Brown',
    'agencies': ['ModelX Management'],
  };

  Future<Object?> renderFace(
    WidgetTester tester,
    CompCardTemplate template, {
    required bool back,
    Map<String, dynamic> user = full,
    double textScale = 1.0,
  }) async {
    final data = CompCardData.fromUser(
      user,
      images: List<String?>.filled(7, null),
    );

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: CompCardFace(template: template, data: data, back: back),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.takeException();
  }

  group('every face lays out at true trim', () {
    for (final template in CompCardTemplate.values) {
      for (final back in [false, true]) {
        final side = back ? 'back' : 'front';

        testWidgets('${template.name} $side', (tester) async {
          expect(await renderFace(tester, template, back: back), isNull);
        });

        testWidgets('${template.name} $side survives an empty profile',
            (tester) async {
          expect(
            await renderFace(tester, template, back: back, user: const {}),
            isNull,
          );
        });
      }
    }
  });

  group('print layout is immune to the system font size', () {
    // A comp card is print. Someone's accessibility text setting must not
    // reflow a 5.5 x 8.5 in card, so the faces neutralise text scaling.
    for (final template in CompCardTemplate.values) {
      testWidgets('${template.name} ignores a 2x text scale', (tester) async {
        expect(
          await renderFace(tester, template, back: true, textScale: 2.0),
          isNull,
        );
      });
    }
  });

  group('CompCardData', () {
    test('reads bust/waist/hips out of a measurements string', () {
      final data = CompCardData.fromUser(
        {'measurements': '82-60-88'},
        images: const [],
      );
      expect(data.bust, '82');
      expect(data.waist, '60');
      expect(data.hips, '88');
    });

    test('falls back to the separate waist and hips fields', () {
      final data = CompCardData.fromUser(
        {'waist': '61', 'hips': '89'},
        images: const [],
      );
      // There is no bust field on the profile, so it prints as a dash
      // rather than inventing a number.
      expect(data.bust, CompCardData.dash);
      expect(data.waist, '61');
      expect(data.hips, '89');
    });

    test('strips the unit for stat grids but keeps it on the full line', () {
      final data = CompCardData.fromUser(
        {'height': '175', 'heightUnit': 'cm'},
        images: const [],
      );
      expect(data.height, '175 CM');
      expect(data.heightNumber, '175');
    });

    test('an empty profile prints dashes, never "null"', () {
      final data = CompCardData.fromUser(const {}, images: const []);
      for (final value in [
        data.city, data.phone, data.height, data.bust,
        data.waist, data.hips, data.shoe, data.hair, data.eyes,
      ]) {
        expect(value, CompCardData.dash);
      }
      expect(data.name, 'Your Name');
    });

    test('templates ask for more shots than the old fixed four', () {
      expect(CompCardTemplate.range.totalShots, 7);
      expect(CompCardTemplate.runway.totalShots, 4);
    });
  });

  group('CompCardReadiness', () {
    // One definition, because the tool, the profile spec sheet and the
    // Network nudge used to compute three different numbers — the same
    // card could read 38% on one screen and 75% on another.
    test('scores only fields a template actually prints', () {
      // Weight is on no card, so filling it must not move the number.
      expect(CompCardReadiness.printed.containsKey('weight'), isFalse);
      expect(
        CompCardReadiness.statsPercent(const {'weight': '65'}),
        0,
      );
    });

    test('measurements count either as a triple or as waist plus hips', () {
      expect(
        CompCardReadiness.statsPercent(const {'measurements': '82-60-88'}),
        CompCardReadiness.statsPercent(const {'waist': '60', 'hips': '88'}),
      );
    });

    test('a complete profile reads 100 and nothing is missing', () {
      const complete = {
        'height': '175',
        'measurements': '82-60-88',
        'shoeSize': '9',
        'hairColor': 'Black',
        'eyeColor': 'Brown',
        'location': 'Mumbai',
        'contact': '+91 98200 00000',
        'username': 'ira',
      };
      expect(CompCardReadiness.statsPercent(complete), 100);
      expect(CompCardReadiness.missing(complete), isEmpty);
    });

    test('missing names the fields, so a nudge can be actionable', () {
      final missing = CompCardReadiness.missing(const {'height': '175'});
      expect(missing, contains('City'));
      expect(missing, contains('Phone'));
      expect(missing, isNot(contains('Height')));
    });

    test('an empty profile is 0, not a crash', () {
      expect(CompCardReadiness.statsPercent(const {}), 0);
      expect(
        CompCardReadiness.missing(const {}).length,
        CompCardReadiness.printed.length,
      );
    });
  });

  group('slots', () {
    test('there are enough named slots for the busiest template', () {
      final busiest = CompCardTemplate.values
          .map((t) => t.totalShots)
          .reduce((a, b) => a > b ? a : b);
      expect(compCardSlots.length, greaterThanOrEqualTo(busiest));
    });

    test('slot 0 is the headshot, which is the front', () {
      expect(compCardSlots.first, 'HEADSHOT');
    });
  });
}

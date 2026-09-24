import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/onboarding/model_signup_data.dart';
import 'package:flutter_application_modelx/onboarding/model_signup_page.dart';
import 'package:flutter_application_modelx/onboarding/success_page.dart';

ModelSignupData filled() => ModelSignupData()
  ..email = 'Anya@Example.com '
  ..password = 'longenough'
  ..phone = '+91 98765 43210'
  ..fullName = ' Anya Sharma '
  ..username = 'anyasharma'
  ..dob = DateTime(2000, 6, 15)
  ..city = 'Mumbai'
  ..height = '172'
  ..bust = '82'
  ..waist = '60'
  ..hips = '88'
  ..skills = ['Runway Walk', 'Posing'];

void main() {
  group('account document', () {
    test('writes exactly the keys the old single-page signup wrote', () {
      // This is the guarantee the whole redesign rests on: the form may
      // change shape, the document may not. A new key here is a schema
      // change nobody asked for.
      final doc = filled().accountDocument(
        uid: 'u1',
        userType: 'Model',
        viaGoogle: false,
      );
      expect(doc.keys.toSet(), {
        'uid',
        'fullName',
        'fullNameLower',
        'username',
        'usernameLower',
        'email',
        'phone',
        'phoneVerified',
        'profileCompleted',
        'userType',
        'dob',
        'followers',
        'following',
        'authProvider',
        'createdAt',
      });
    });

    test('normalises the same way the old form did', () {
      final doc = filled().accountDocument(
        uid: 'u1',
        userType: 'Model',
        viaGoogle: false,
      );
      expect(doc['fullName'], 'Anya Sharma');
      expect(doc['fullNameLower'], 'anya sharma');
      expect(doc['usernameLower'], 'anyasharma');
      expect(doc['email'], 'anya@example.com');
      expect(doc['userType'], 'Model');
      expect(doc['authProvider'], 'email');
    });

    test('empty name and username store null, not an empty string', () {
      // The lookup queries match on these; an empty string is a value
      // that two blank accounts would collide on.
      final doc = (ModelSignupData()..email = 'a@b.com').accountDocument(
        uid: 'u1',
        userType: 'Model',
        viaGoogle: false,
      );
      expect(doc['fullNameLower'], isNull);
      expect(doc['usernameLower'], isNull);
    });

    test('is incomplete until step 4', () {
      // So that abandoning mid-form lands on the repair path rather
      // than a half-filled dashboard.
      final doc = filled().accountDocument(
        uid: 'u1',
        userType: 'Model',
        viaGoogle: false,
      );
      expect(doc['profileCompleted'], false);
    });
  });

  group('profile document', () {
    test('adds no field that does not already exist on users', () {
      final doc = filled().profileDocument();
      // Every one of these is already written by the profile editor.
      expect(doc.keys.toSet(), {
        'location',
        'height',
        'heightUnit',
        'waist',
        'hips',
        'skills',
        'bio',
        'instagram',
        'website',
        'profileCompleted',
        'measurements',
      });
    });

    test('measurements use the format the app already documents', () {
      // The existing editor's own hint says "e.g. 82-60-88": hyphenated,
      // unitless, centimetres.
      expect(filled().profileDocument()['measurements'], '82-60-88');
    });

    test('a partial measurement is not written at all', () {
      // "82-88" cannot be read back -- nothing says which of the three
      // is missing, and the profile renders the raw string. The
      // separate waist and hips fields still carry what was given.
      final d = filled()..waist = '';
      final doc = d.profileDocument();
      expect(doc.containsKey('measurements'), isFalse);
      expect(doc['hips'], '88');
    });

    test('skills are stored comma-separated, as the editor stores them', () {
      expect(filled().profileDocument()['skills'], 'Runway Walk, Posing');
    });

    test('the first photo becomes the avatar, and none means none', () {
      expect(filled().profileDocument().containsKey('profileImage'), isFalse);
      final withPhoto = filled()..photoUrls = ['a.jpg', 'b.jpg'];
      expect(withPhoto.profileDocument()['profileImage'], 'a.jpg');
    });

    test('completes the profile', () {
      expect(filled().profileDocument()['profileCompleted'], true);
    });
  });

  group('skills vocabulary', () {
    test('matches what agencies pick from when posting a casting', () {
      // If these drift, a model ticking "Runway Walk" stops matching a
      // casting that requires it, which is the entire point of the
      // field.
      expect(ModelSignupData.skillOptions, [
        'Runway Walk',
        'Posing',
        'Acting',
        'Dance',
        'Voice Over',
        'Swimming',
        'Sports',
        'Yoga',
      ]);
    });
  });

  group('validation', () {
    test('step 1 wants a real email and eight characters', () {
      final d = ModelSignupData()
        ..email = 'nope'
        ..password = 'short';
      final e = d.validate(0);
      expect(e['email'], isNotNull);
      expect(e['password'], isNotNull);
    });

    test('step 2 enforces the username rule the app already uses', () {
      final d = filled()..username = 'no';
      expect(d.validate(1)['username'], isNotNull);
      d.username = 'has spaces';
      expect(d.validate(1)['username'], isNotNull);
      d.username = 'fine_name99';
      expect(d.validate(1)['username'], isNull);
    });

    test('step 2 rejects an impossible date of birth', () {
      final d = filled()..dob = DateTime.now().add(const Duration(days: 1));
      expect(d.validate(1)['dob'], isNotNull);
    });

    test('step 3 bounds height, and wants one skill', () {
      final d = filled()..height = '12';
      expect(d.validate(2)['height'], isNotNull);
      d.height = '172';
      expect(d.validate(2)['height'], isNull);
      d.skills = [];
      expect(d.validate(2)['skills'], isNotNull);
    });

    test('step 4 asks for nothing', () {
      // A profile with no photographs is still a profile.
      expect(ModelSignupData().validate(3), isEmpty);
    });
  });

  group('height', () {
    test('reads back in feet only while the unit is centimetres', () {
      final d = ModelSignupData()..height = '172';
      expect(d.heightInFeet, "5'8\"");
      d.heightUnit = 'ft';
      expect(d.heightInFeet, isNull);
    });

    test('rolls twelve inches up to the next foot', () {
      // Otherwise it prints 5'12".
      final d = ModelSignupData()..height = '182.9';
      expect(d.heightInFeet, isNot(contains('12')));
    });

    test('the unit has the three values the stored field accepts', () {
      expect(ModelSignupData().heightUnit, 'cm');
    });
  });

  group('age', () {
    test('counts whole years, not calendar years', () {
      final almost = DateTime.now().subtract(const Duration(days: 364));
      expect((ModelSignupData()..dob = almost).age, 0);
    });
  });

  group('screen', () {
    testWidgets('opens on step 1 of 4 and lays out small', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: ModelSignupPage(userType: 'Model')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Create your account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('will not advance past an invalid first step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ModelSignupPage(userType: 'Model')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);
    });
  });

  group('success', () {
    testWidgets('tells each role what to do next', (tester) async {
      for (final (role, cta) in [
        (SuccessRole.model, 'Explore castings'),
        (SuccessRole.brand, 'Browse talent'),
        (SuccessRole.agency, 'Go to dashboard'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: SuccessPage(role: role, onContinue: () {}),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(cta), findsOneWidget);
        expect(find.text("What's next"), findsOneWidget);
      }
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// What the model signup collects, and where each value goes.
///
/// Kept apart from the screen so the mapping can be read, and tested,
/// without a widget tree. The mapping is the delicate part of this
/// screen: the design asks for more than the `users` document holds, and
/// no field may be added.
///
/// Four of the prototype's inputs are not collected at all, rather than
/// collected and dropped: stage name and TikTok have nowhere to go, a
/// comp card upload would bypass the generator the app already has, and
/// a video reel is a feature rather than a restyle. An input whose value
/// would be discarded is worse than no input.
class ModelSignupData {
  // Step 1 -- account
  String email = '';
  String password = '';
  String phone = '';

  // Step 2 -- about you
  String fullName = '';
  String username = '';
  DateTime? dob;
  String city = '';

  // Step 3 -- stats
  String height = '';

  /// One of `cm`, `in`, `ft` -- the three values `heightUnit` already
  /// accepts. The prototype offered a two-way in/cm toggle; the stored
  /// field has three options and the profile editor already writes all
  /// three.
  String heightUnit = 'cm';

  /// Centimetres. There is no unit field for measurements anywhere in
  /// the app, so there is nowhere to record a choice of inches -- and a
  /// toggle whose setting is discarded would silently corrupt the
  /// numbers for anyone who used it.
  String bust = '';
  String waist = '';
  String hips = '';

  /// Written to `skills`, comma-separated, which is the shape the
  /// profile editor already stores.
  List<String> skills = [];

  // Step 4 -- show your work
  List<String> photoUrls = [];
  String bio = '';
  String instagram = '';
  String website = '';

  /// What agencies pick from when they post a casting, so a model who
  /// ticks "Runway Walk" matches a casting that asks for it.
  ///
  /// These are capabilities, not genres. The prototype's list (Fashion,
  /// Editorial, Commercial...) describes *looks*, which exist on
  /// castings and gigs but never on a user document -- there would be
  /// nothing to write them to.
  static const List<String> skillOptions = [
    'Runway Walk',
    'Posing',
    'Acting',
    'Dance',
    'Voice Over',
    'Swimming',
    'Sports',
    'Yoga',
  ];

  static const List<String> photoSlots = [
    'Headshot',
    'Full length',
    'Side profile',
  ];

  /// The document written when the account is created, at the end of
  /// step 2.
  ///
  /// Exactly the keys the single-page signup wrote, with the same types
  /// and the same null-when-empty behaviour. `profileCompleted` stays
  /// false until step 4, so abandoning here leaves an account that
  /// AuthGate already knows how to rescue.
  Map<String, dynamic> accountDocument({
    required String uid,
    required String userType,
    required bool viaGoogle,
  }) {
    final name = fullName.trim();
    final user = username.trim();
    return {
      'uid': uid,
      'fullName': name,
      'fullNameLower': name.isNotEmpty ? name.toLowerCase() : null,
      'username': user,
      'usernameLower': user.isNotEmpty ? user.toLowerCase() : null,
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'phoneVerified': false,
      'profileCompleted': false,
      'userType': userType,
      'dob': dob,
      'followers': [],
      'following': [],
      'authProvider': viaGoogle ? 'google' : 'email',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// The merge written at the end of step 4, which also completes the
  /// profile.
  ///
  /// Every key here already exists on the document and is already
  /// editable from the profile page.
  Map<String, dynamic> profileDocument() {
    final data = <String, dynamic>{
      'location': city.trim(),
      'height': height.trim(),
      'heightUnit': heightUnit,
      'waist': waist.trim(),
      'hips': hips.trim(),
      'skills': skills.join(', '),
      'bio': bio.trim(),
      'instagram': instagram.trim(),
      'website': website.trim(),
      'profileCompleted': true,
    };

    final measurements = formattedMeasurements();
    if (measurements != null) data['measurements'] = measurements;
    if (photoUrls.isNotEmpty) data['profileImage'] = photoUrls.first;

    return data;
  }

  /// Bust, waist and hips as the app already stores them.
  ///
  /// The existing editor documents the format in its own hint --
  /// `e.g. 82-60-88` -- hyphenated, unitless, centimetres.
  ///
  /// Returns null unless all three are present. A partial string like
  /// "82-88" cannot be read back: nothing says which measurement is
  /// missing, and the profile renders the raw value. The individual
  /// `waist` and `hips` fields still carry whatever was given.
  String? formattedMeasurements() {
    final parts = [bust.trim(), waist.trim(), hips.trim()];
    if (parts.any((p) => p.isEmpty)) return null;
    return parts.join('-');
  }

  /// Age in whole years, or null if no date is set.
  int? get age {
    final d = dob;
    if (d == null) return null;
    final now = DateTime.now();
    var years = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
      years--;
    }
    return years;
  }

  /// Height read back in feet and inches, for the hint under the field.
  ///
  /// Only shown when the unit is centimetres -- it is there to reassure
  /// someone who thinks in feet that they typed the right number.
  String? get heightInFeet {
    if (heightUnit != 'cm') return null;
    final cm = double.tryParse(height.trim());
    if (cm == null || cm < 100 || cm > 230) return null;
    final totalInches = (cm / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    // 12 inches rolls up rather than printing 5'12".
    return inches == 12 ? "${feet + 1}'0\"" : "$feet'$inches\"";
  }

  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,30}$');
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Errors for a step, keyed by field. Empty means the step may
  /// advance.
  ///
  /// Step 4 validates nothing: everything on it is optional, and a
  /// profile with no photographs is still a profile.
  Map<String, String> validate(int step) {
    final errors = <String, String>{};

    switch (step) {
      case 0:
        if (!_emailPattern.hasMatch(email.trim())) {
          errors['email'] = 'Enter a valid email address.';
        }
        if (password.length < 8) {
          errors['password'] = 'Use at least 8 characters.';
        }
      case 1:
        if (fullName.trim().isEmpty) {
          errors['fullName'] = 'Enter your full name.';
        }
        if (!_usernamePattern.hasMatch(username.trim())) {
          errors['username'] = 'Use 3 to 30 letters, numbers or underscores.';
        }
        // TODO(policy): under-18 handling is undecided. The prototype
        // showed a guardian-consent notice here but implemented
        // nothing, so nothing is shown. Whatever is decided -- a
        // notice, a consent step, or refusing signup -- belongs here.
        final years = age;
        if (years == null || years < 0 || years > 110) {
          errors['dob'] = 'Enter your date of birth.';
        }
        if (city.trim().isEmpty) {
          errors['city'] = 'Add the city you work from.';
        }
      case 2:
        final cm = double.tryParse(height.trim());
        if (heightUnit == 'cm' && (cm == null || cm < 100 || cm > 230)) {
          errors['height'] = 'Enter your height in centimetres.';
        } else if (height.trim().isEmpty) {
          errors['height'] = 'Enter your height.';
        }
        if (skills.isEmpty) {
          errors['skills'] = 'Pick at least one thing you can do.';
        }
    }

    return errors;
  }

  @visibleForTesting
  ModelSignupData copyForTest() => ModelSignupData()
    ..email = email
    ..password = password
    ..phone = phone
    ..fullName = fullName
    ..username = username
    ..dob = dob
    ..city = city
    ..height = height
    ..heightUnit = heightUnit
    ..bust = bust
    ..waist = waist
    ..hips = hips
    ..skills = [...skills]
    ..photoUrls = [...photoUrls]
    ..bio = bio
    ..instagram = instagram
    ..website = website;
}

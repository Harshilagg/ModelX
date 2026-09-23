import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../agency/agency_dashboard_page.dart';
import '../pages/create_profile_page.dart';
import '../pages/dashboard_page.dart';
import '../brand/brand_dashboard_page.dart';

/// Where an account belongs, and how to find out.
///
/// This was written twice: once in `AuthGate` and once inside the login
/// screen, and the two had drifted. Both looked up the same three
/// collections in the same order, but an account with an unfinished
/// model profile was sent to `CreateProfilePage` by one and to the role
/// picker by the other -- so whether a half-registered user was asked to
/// finish their profile or to choose their account type again depended
/// on which door they came through.
class AuthRouter {
  const AuthRouter._();

  /// Resolves a typed identifier to the email Firebase Auth expects.
  ///
  /// People sign in with an email, a username or their own name, so a
  /// non-email is looked up across four fields in turn. The order is
  /// deliberate: the lowercased fields are the indexed ones and match
  /// regardless of how the name was typed, and the exact-case fields are
  /// fallbacks for documents written before the lowercase mirrors
  /// existed.
  static Future<String> resolveEmail(String identifier) async {
    final input = identifier.trim();
    if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input)) return input;

    final normalized = input.replaceFirst(RegExp(r'^@'), '');
    final lower = normalized.toLowerCase();
    final users = FirebaseFirestore.instance.collection('users');

    for (final (field, value) in [
      ('usernameLower', lower),
      ('username', normalized),
      ('fullNameLower', lower),
      ('fullName', normalized),
    ]) {
      final q = await users.where(field, isEqualTo: value).limit(1).get();
      if (q.docs.isEmpty) continue;

      final email = q.docs.first.data()['email'];
      if (email == null) {
        throw FirebaseAuthException(
          code: 'invalid-user',
          message: 'That account has no email linked to it.',
        );
      }
      return email.toString().trim();
    }

    throw FirebaseAuthException(
      code: 'user-not-found',
      message: 'No account found for that username.',
    );
  }

  /// The screen this account should land on.
  ///
  /// Returns null when the account has no profile document at all, which
  /// the caller handles -- there is no sensible screen for it, and
  /// guessing one is how someone ends up in the wrong side of the app.
  static Future<Widget?> destinationFor(String uid) async {
    final db = FirebaseFirestore.instance;

    final userDoc = await db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final completed = userDoc.data()?['profileCompleted'] == true;
      // An unfinished profile is asked to finish, not to pick a role
      // again -- picking one a second time does not write anything new.
      return completed ? const DashboardPage() : const CreateProfilePage();
    }

    if ((await db.collection('brands').doc(uid).get()).exists) {
      return const BrandDashboardPage();
    }

    if ((await db.collection('agency').doc(uid).get()).exists) {
      return const AgencyDashboardPage();
    }

    return null;
  }

  /// Turns a Firebase error code into something worth reading.
  ///
  /// Firebase collapses a wrong password and an unknown email into
  /// `invalid-credential` on purpose, so that a stranger cannot use the
  /// login form to discover whether an address has an account. The
  /// wording has to stay vague to match.
  static String messageFor(Object error) {
    if (error is! FirebaseAuthException) {
      return 'Something went wrong. Please try again.';
    }
    return switch (error.code) {
      'invalid-credential' || 'wrong-password' || 'user-not-found' =>
        "That email and password don't match. Try again or reset your password.",
      'invalid-email' => 'That email address does not look right.',
      'user-disabled' => 'That account has been disabled.',
      'too-many-requests' =>
        'Too many attempts. Wait a moment and try again.',
      'network-request-failed' =>
        'No connection. Check your network and try again.',
      _ => error.message ?? 'Something went wrong. Please try again.',
    };
  }
}

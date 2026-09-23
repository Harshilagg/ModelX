import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../agency/agency_signup_page.dart';
import '../brand/brand_signup_page.dart';
import '../pages/signup_page.dart';
import 'login_page.dart';
import 'role_select_page.dart';
import 'splash_page.dart';

/// The way into the app: splash, then either the role picker or login.
///
/// Replaces `OnboardingPage` plus `SelectPortfolioPage`, which between
/// them dropped the invite token: the model signup received it, and the
/// brand and agency ones silently did not, so a brand invited by an
/// agency arrived as an ordinary signup with the invitation lost. The
/// token is threaded through all three here.
class OnboardingFlow extends StatelessWidget {
  final String? inviteToken;

  const OnboardingFlow({super.key, this.inviteToken});

  /// Records that the splash has been seen.
  ///
  /// Written when the user leaves the splash in either direction rather
  /// than when they finish signing up: somebody who backs out of the
  /// form has still seen it, and showing the carousel again would be
  /// tedious rather than helpful.
  static Future<void> _markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_onboarding', true);
    } catch (_) {
      // Worst case it shows once more next launch.
    }
  }

  void _open(BuildContext context, Widget page) {
    _markSeen();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        // The screens carry their own entrance animations, so the route
        // transition is a plain cross-fade rather than a second motion
        // competing with them.
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SplashPage(
      onCreateAccount: () => _open(context, _roleSelect(context)),
      onLogIn: () => _open(context, OnboardingLoginPage(inviteToken: inviteToken)),
    );
  }

  Widget _roleSelect(BuildContext context) => Builder(
    builder: (context) => RoleSelectPage(
      onBack: () => Navigator.of(context).pop(),
      onLogIn: () => _open(context, OnboardingLoginPage(inviteToken: inviteToken)),
      onSelected: (role) => _open(context, _signupFor(role)),
    ),
  );

  Widget _signupFor(SignupRole role) => switch (role) {
    SignupRole.model => SignupPage(
      userType: role.userType,
      inviteToken: inviteToken,
    ),
    // These two took no token before, which is what broke brand and
    // agency invite links.
    SignupRole.brand => BrandSignupPage(inviteToken: inviteToken),
    SignupRole.agency => AgencySignupPage(inviteToken: inviteToken),
  };
}

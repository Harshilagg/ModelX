import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'agency_signup_page.dart';
import 'brand_signup_page.dart';
import 'login_page.dart';
import 'model_signup_page.dart';
import 'role_select_page.dart';

/// Every way through the onboarding, defined once.
///
/// It was defined twice before: properly inside `OnboardingFlow`, and
/// again as a stub on the login screen for the case where login is the
/// first thing shown. The stub passed an empty `onSelected`, no
/// `onLogIn`, and used `pushReplacement`, so on the second launch of a
/// fresh install -- when AuthGate shows login rather than the splash --
/// tapping "Create an account" landed on a role picker where Continue
/// did nothing, the log-in button was missing, and there was nothing
/// left on the stack to go back to. The only way out was to kill the
/// app, which put you straight back in the same place.
class OnboardingRoutes {
  const OnboardingRoutes._();

  /// The screens carry their own entrance animations, so the route
  /// transition is a plain cross-fade rather than a second motion
  /// competing with them.
  static Route<void> _fade(Widget page) => PageRouteBuilder<void>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 200),
  );

  /// Records that the splash has been seen.
  ///
  /// Written on leaving the splash in either direction rather than on
  /// finishing signup: somebody who backs out has still seen it, and
  /// showing the carousel again would be tedious rather than helpful.
  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_onboarding', true);
    } catch (_) {
      // Worst case it shows once more next launch.
    }
  }

  static void login(BuildContext context, {String? inviteToken}) {
    markSeen();
    Navigator.of(
      context,
    ).push(_fade(OnboardingLoginPage(inviteToken: inviteToken)));
  }

  /// Opens the role picker, fully wired.
  ///
  /// [cameFromLogin] decides what its "Log in" control does: go back
  /// when login is the screen underneath, or open one when it is not.
  /// Popping unconditionally would drop somebody who arrived from the
  /// splash onto the splash instead of a login form.
  static void roleSelect(
    BuildContext context, {
    String? inviteToken,
    bool cameFromLogin = false,
  }) {
    markSeen();
    Navigator.of(context).push(
      _fade(
        Builder(
          builder: (context) => RoleSelectPage(
            onBack: () => Navigator.of(context).maybePop(),
            onLogIn: cameFromLogin
                ? () => Navigator.of(context).maybePop()
                : () => login(context, inviteToken: inviteToken),
            onSelected: (role) =>
                signup(context, role, inviteToken: inviteToken),
          ),
        ),
      ),
    );
  }

  static void signup(
    BuildContext context,
    SignupRole role, {
    String? inviteToken,
  }) {
    markSeen();
    Navigator.of(context).push(
      _fade(switch (role) {
        SignupRole.model => ModelSignupPage(
          userType: role.userType,
          inviteToken: inviteToken,
        ),
        // Neither of these took the token before, which is what broke
        // brand and agency invite links.
        SignupRole.brand => BrandSignupFlow(inviteToken: inviteToken),
        SignupRole.agency => AgencySignupFlow(inviteToken: inviteToken),
      }),
    );
  }
}

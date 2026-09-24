import 'package:flutter/material.dart';

import 'onboarding_routes.dart';
import 'splash_page.dart';

/// The way into the app for somebody who has not seen it before.
///
/// Only the splash lives here now. Where each button goes is
/// [OnboardingRoutes], so that the login screen -- which is what a
/// returning visitor sees instead of this -- reaches the same screens
/// wired the same way.
class OnboardingFlow extends StatelessWidget {
  final String? inviteToken;

  const OnboardingFlow({super.key, this.inviteToken});

  @override
  Widget build(BuildContext context) {
    return SplashPage(
      onCreateAccount: () =>
          OnboardingRoutes.roleSelect(context, inviteToken: inviteToken),
      onLogIn: () => OnboardingRoutes.login(context, inviteToken: inviteToken),
    );
  }
}

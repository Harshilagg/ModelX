import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

import '../agency/team_access/invite_acceptance_page.dart';
import '../ui/app_type.dart';
import '../ui/board_palette.dart';
import '../widgets/kit/kit.dart';
import 'auth_router.dart';
import 'onboarding_routes.dart';
import 'onboarding_theme.dart';
import 'splash_page.dart' show kWordmark;

enum _View { login, forgot, sent }

/// Log in, reset a password, and the confirmation after a reset.
///
/// Three views in one screen rather than three routes: they share the
/// email the user typed, and pushing a route for "check your inbox"
/// gives a back button that goes somewhere meaningless.
class OnboardingLoginPage extends StatefulWidget {
  /// Carried through from an invite deep link.
  final String? inviteToken;

  final VoidCallback? onBack;
  final VoidCallback? onSignUp;

  const OnboardingLoginPage({
    super.key,
    this.inviteToken,
    this.onBack,
    this.onSignUp,
  });

  @override
  State<OnboardingLoginPage> createState() => _OnboardingLoginPageState();
}

class _OnboardingLoginPageState extends State<OnboardingLoginPage> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _resetEmail = TextEditingController();

  _View _view = _View.login;
  bool _reversing = false;
  bool _busy = false;

  String? _identifierError;
  String? _passwordError;
  String? _formError;
  String? _resetError;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _resetEmail.dispose();
    super.dispose();
  }

  void _goTo(_View next, {bool back = false}) {
    setState(() {
      _view = next;
      _reversing = back;
    });
  }

  /// Clears errors as soon as the user starts fixing them. Leaving a
  /// red field red while it is being corrected reads as the correction
  /// not working.
  void _clearErrors() {
    if (_identifierError == null &&
        _passwordError == null &&
        _formError == null) {
      return;
    }
    setState(() {
      _identifierError = null;
      _passwordError = null;
      _formError = null;
    });
  }

  Future<void> _logIn() async {
    final identifier = _identifier.text.trim();
    final password = _password.text;

    setState(() {
      _identifierError = identifier.isEmpty
          ? 'Enter the email you signed up with.'
          : null;
      _passwordError = password.isEmpty ? 'Enter your password.' : null;
      _formError = null;
    });
    if (_identifierError != null || _passwordError != null) return;

    setState(() => _busy = true);
    try {
      final email = await AuthRouter.resolveEmail(identifier);
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      if (widget.inviteToken != null) {
        if (!mounted) return;
        _replaceWith(
          InviteAcceptancePage(
            token: widget.inviteToken!,
            autoAcceptOnLoad: true,
          ),
        );
        return;
      }

      final destination = await AuthRouter.destinationFor(uid);
      if (!mounted) return;

      if (destination == null) {
        // An auth user with no profile document. Signing out is what
        // AuthGate does, and leaving them signed in would just loop
        // them back here on the next launch.
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _formError =
              'That account has no profile yet. '
              'Create one to carry on.';
        });
        return;
      }

      _replaceWith(destination);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _formError = AuthRouter.messageFor(e);
      });
    }
  }

  /// Signs in with Google and routes exactly as a password login does.
  ///
  /// This is new on login -- previously Google was offered during signup
  /// only, so somebody who registered with Google had no way back in
  /// except the password they never set.
  ///
  /// It deliberately does not create a profile document. Signing in is
  /// not signing up: if there is no profile, the account is sent to
  /// create one rather than silently having a half-filled record
  /// written for it.
  Future<void> _logInWithGoogle() async {
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      final account = await GoogleSignIn().signIn();
      if (account == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final auth = await account.authentication;
      final credential = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        ),
      );

      if (widget.inviteToken != null) {
        if (!mounted) return;
        _replaceWith(
          InviteAcceptancePage(
            token: widget.inviteToken!,
            autoAcceptOnLoad: true,
          ),
        );
        return;
      }

      final destination = await AuthRouter.destinationFor(credential.user!.uid);
      if (!mounted) return;

      if (destination == null) {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _formError =
              'That Google account has no profile yet. Create one to carry on.';
        });
        return;
      }
      _replaceWith(destination);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _formError = AuthRouter.messageFor(e);
      });
    }
  }

  void _replaceWith(Widget page) {
    Navigator.of(
      context,
    ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => page), (_) => false);
  }

  Future<void> _sendReset() async {
    final email = _resetEmail.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _resetError = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _resetError = null;
      _busy = true;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (_) {
      // Deliberately swallowed. Reporting "no such account" here would
      // turn the reset form into a way of discovering which addresses
      // are registered, and the confirmation screen is already worded
      // so that it is true either way.
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _goTo(_View.sent);
  }

  void _back() {
    switch (_view) {
      case _View.login:
        if (widget.onBack != null) {
          widget.onBack!();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      case _View.forgot:
        _goTo(_View.login, back: true);
      case _View.sent:
        _goTo(_View.forgot, back: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = OnboardingTheme.palette;
    final reduced = AppMotion.reduced(context);

    return OnboardingTheme(
      child: Scaffold(
        backgroundColor: p.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    // The forgot and sent views always have somewhere
                    // to go -- back to the one before. The login view
                    // may not: it is the root when a returning visitor
                    // is sent straight here rather than to the splash,
                    // and a chevron that does nothing is worse than no
                    // chevron.
                    if (_view != _View.login ||
                        widget.onBack != null ||
                        Navigator.of(context).canPop())
                      AppIconButton(
                        icon: Icons.chevron_left,
                        onPressed: _back,
                        semanticLabel: 'Go back',
                      )
                    else
                      const SizedBox(
                        width: AppMetrics.tapTarget,
                        height: AppMetrics.tapTarget,
                      ),
                    Expanded(
                      child: Text(
                        kWordmark.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppType.label(
                          color: p.onSurface,
                        ).copyWith(letterSpacing: 4.4),
                      ),
                    ),
                    const SizedBox(width: AppMetrics.tapTarget),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppMetrics.gutter,
                    24,
                    AppMetrics.gutter,
                    AppMetrics.bottomInset(context, minimum: 24),
                  ),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_view),
                    tween: Tween(begin: reduced ? 1 : 0, end: 1),
                    duration: reduced ? Duration.zero : AppMotion.step,
                    curve: AppMotion.settle,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset((_reversing ? -18 : 18) * (1 - t), 0),
                        child: child,
                      ),
                    ),
                    child: switch (_view) {
                      _View.login => _loginView(p),
                      _View.forgot => _forgotView(p),
                      _View.sent => _sentView(p),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(BoardPalette p, String title, String hint) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppType.display(fontSize: 32, color: p.onSurface)),
      const SizedBox(height: 10),
      Text(hint, style: AppType.body(color: p.onSurfaceSoft)),
      const SizedBox(height: AppMetrics.titleGap),
    ],
  );

  Widget _loginView(BoardPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(p, 'Welcome back.', 'Log in to your $kWordmark account.'),

        if (_formError != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: AppMetrics.fieldGap),
            decoration: BoxDecoration(
              color: p.rejected.withValues(alpha: 0.12),
              border: Border.all(color: p.rejectedText.withValues(alpha: 0.4)),
              borderRadius: AppRadii.fieldRadius,
            ),
            child: Text(
              _formError!,
              style: AppType.body(fontSize: 14, color: p.rejectedText),
            ),
          ),
        ],

        AppField(
          label: 'Email or username',
          error: _identifierError,
          child: AppTextField(
            controller: _identifier,
            hintText: 'you@email.com',
            hasError: _identifierError != null,
            keyboardType: TextInputType.emailAddress,
            autofillHint: AutofillHints.username,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearErrors(),
          ),
        ),
        AppField(
          label: 'Password',
          error: _passwordError,
          spaced: false,
          child: AppPasswordField(
            hintText: 'Your password',
            controller: _password,
            hasError: _passwordError != null,
            isNew: false,
            textInputAction: TextInputAction.done,
            onChanged: (_) => _clearErrors(),
            onSubmitted: (_) => _logIn(),
          ),
        ),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              _resetEmail.text = _identifier.text.trim();
              _goTo(_View.forgot);
            },
            child: Text(
              'Forgot password?',
              style: AppType.label(fontSize: 14, color: p.onSurfaceSoft),
            ),
          ),
        ),
        const SizedBox(height: 12),

        AppPillButton(
          label: 'Log in',
          busyLabel: 'Logging in...',
          busy: _busy,
          onPressed: _logIn,
        ),

        const SizedBox(height: 24),
        OrDivider(label: 'or'),
        const SizedBox(height: 24),

        // The design also calls for "Continue with Apple" above this,
        // on iOS. It is not rendered because Sign in with Apple is not
        // implemented -- a button that does nothing is worse than no
        // button. It is not optional either: App Review requires Apple
        // wherever a third-party social login is offered, so this has
        // to be built before the iOS build ships with Google enabled.
        //
        // TODO(ios-release): implement Sign in with Apple and render it
        // above Google on iOS and macOS.
        AppPillButton(
          label: 'Continue with Google',
          kind: AppButtonKind.outlined,
          leading: const GoogleMark(),
          busyLabel: 'Signing in...',
          busy: _busy,
          onPressed: _logInWithGoogle,
        ),

        const SizedBox(height: 24),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'New to $kWordmark? ',
                style: AppType.body(fontSize: 14, color: p.onSurfaceSoft),
              ),
              GestureDetector(
                onTap:
                    widget.onSignUp ??
                    () => OnboardingRoutes.roleSelect(
                      context,
                      inviteToken: widget.inviteToken,
                      cameFromLogin: true,
                    ),
                child: Text(
                  'Create an account',
                  style: AppType.label(
                    fontSize: 14,
                    color: p.onSurface,
                  ).copyWith(decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _forgotView(BoardPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          p,
          'Reset your password',
          "Enter the email you signed up with and we'll send you a link to set a new password.",
        ),
        AppField(
          label: 'Email',
          error: _resetError,
          child: AppTextField(
            controller: _resetEmail,
            hintText: 'you@email.com',
            hasError: _resetError != null,
            keyboardType: TextInputType.emailAddress,
            autofillHint: AutofillHints.email,
            autocorrect: false,
            onChanged: (_) {
              if (_resetError != null) setState(() => _resetError = null);
            },
            onSubmitted: (_) => _sendReset(),
          ),
        ),
        AppPillButton(
          label: 'Send reset link',
          busyLabel: 'Sending...',
          busy: _busy,
          onPressed: _sendReset,
        ),
      ],
    );
  }

  Widget _sentView(BoardPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.mail_outline, size: 48, color: p.onSurface),
        const SizedBox(height: 20),
        _heading(
          p,
          'Check your inbox',
          "If there's an account for ${_resetEmail.text.trim()}, we've sent a "
              'link to reset your password. It can take a minute, so check '
              'your spam folder too.',
        ),
        AppPillButton(
          label: 'Back to log in',
          onPressed: () => _goTo(_View.login, back: true),
        ),
        const SizedBox(height: 8),
        AppPillButton(
          label: "Didn't get it? Send again",
          kind: AppButtonKind.ghost,
          busyLabel: 'Sending...',
          busy: _busy,
          onPressed: _sendReset,
        ),
      ],
    );
  }
}

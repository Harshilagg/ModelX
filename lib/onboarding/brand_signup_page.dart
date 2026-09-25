import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../agency/team_access/invite_acceptance_page.dart';
import '../brand/brand_dashboard_page.dart';
import '../ui/app_type.dart';
import '../ui/board_palette.dart';
import '../widgets/kit/kit.dart';
import 'onboarding_theme.dart';
import 'success_page.dart';

/// Brand signup, in three steps.
///
/// The `brands` document is small -- name, industry, location, email,
/// about -- so this mostly changes how it is asked for rather than what
/// is stored. Two fields the prototype wanted, a budget range and a
/// "what do you book talent for" list, have nowhere to live and are not
/// asked for.
class BrandSignupFlow extends StatefulWidget {
  final String? inviteToken;

  const BrandSignupFlow({super.key, this.inviteToken});

  /// The industries a brand can pick from. Single-select: a brand that
  /// is two of these is really the first one.
  static const industries = [
    'Fashion',
    'Beauty',
    'Luxury',
    'Retail',
    'Sportswear',
    'Jewellery',
    'Photography',
    'Advertising',
    'Entertainment',
    'Other',
  ];

  @override
  State<BrandSignupFlow> createState() => _BrandSignupFlowState();
}

class _BrandSignupFlowState extends State<BrandSignupFlow> {
  final _brandName = TextEditingController();
  final _location = TextEditingController();
  final _about = TextEditingController();

  String _email = '';
  String _password = '';
  List<String> _industry = [];

  int _step = 0;
  bool _reversing = false;
  bool _busy = false;

  /// Set once Google has made the auth user, so the final submit writes
  /// against it rather than registering the same address again.
  String? _googleUid;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _brandName.dispose();
    _location.dispose();
    _about.dispose();
    super.dispose();
  }

  void _set(VoidCallback change) => setState(() {
    change();
    if (_errors.isNotEmpty) _errors = {};
  });

  Map<String, String> _validate() {
    final e = <String, String>{};
    switch (_step) {
      case 0:
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.trim())) {
          e['email'] = 'Enter a valid email address.';
        }
        if (_password.length < 8) e['password'] = 'Use at least 8 characters.';
      case 1:
        if (_brandName.text.trim().isEmpty) {
          e['brandName'] = "Enter your brand's name.";
        }
        if (_industry.isEmpty) {
          e['industry'] = 'Pick the industry that fits best.';
        }
        if (_location.text.trim().isEmpty) {
          e['location'] = "Add the city you're based in.";
        }
    }
    return e;
  }

  void _next() {
    final errors = _validate();
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    setState(() {
      _reversing = false;
      _step++;
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _reversing = true;
      _step--;
      _errors = {};
    });
  }

  /// Signs up with Google, then carries on at step 2.
  ///
  /// Google gives an email and a name; everything this side of the app
  /// stores is still to come, so this advances one step rather than
  /// skipping ahead.
  ///
  /// Unlike the email path, the auth user exists from here on while the
  /// document is only written at the end. Quitting in between leaves an
  /// account with no document -- recoverable, since the same Google
  /// account signs straight back in, but it is why the final submit
  /// reuses this uid instead of registering again.
  Future<void> _signUpWithGoogle() async {
    setState(() {
      _busy = true;
      _errors = {};
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

      _googleUid = credential.user!.uid;
      _email = credential.user!.email ?? '';

      if (!mounted) return;
      setState(() {
        _busy = false;
        _reversing = false;
        _step = 1;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errors = {'form': 'Could not sign up with Google. Please try again.'};
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);

    // Null when Google already created the account: there is then
    // nothing of ours to roll back, because we did not create it.
    UserCredential? credential;
    try {
      final String uid;
      if (_googleUid != null) {
        uid = _googleUid!;
      } else {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.trim().toLowerCase(),
          password: _password,
        );
        uid = credential.user!.uid;
      }

      try {
        await FirebaseFirestore.instance.collection('brands').doc(uid).set({
          'uid': uid,
          'brandName': _brandName.text.trim(),
          'industry': _industry.isEmpty ? '' : _industry.first,
          'location': _location.text.trim(),
          'email': _email.trim().toLowerCase(),
          'about': _about.text.trim(),
          'profileCompleted': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Without this the account exists with no brand document, which
        // AuthGate cannot place: it checks users, then brands, then
        // agency, and signs out if none match.
        await credential?.user?.delete();
        rethrow;
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => widget.inviteToken != null
              ? InviteAcceptancePage(
                  token: widget.inviteToken!,
                  autoAcceptOnLoad: true,
                )
              : SuccessPage(
                  role: SuccessRole.brand,
                  onContinue: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const BrandDashboardPage(),
                    ),
                    (_) => false,
                  ),
                ),
        ),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errors = {
          if (e.code == 'email-already-in-use')
            'email': 'That email already has an account. Log in instead.'
          else
            'form': e.message ?? 'Could not create your account.',
        };
        if (_errors.containsKey('email')) _step = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errors = {'form': 'Could not save your brand. Please try again.'};
      });
    }
  }

  static const _titles = [
    (
      'Create your brand account',
      'Start with your login. It takes about two minutes.',
    ),
    ('Your brand', 'The basics talent will see first.'),
    (
      'Your brand page',
      'A complete page helps the right talent say yes. '
          'Everything here is optional.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = OnboardingTheme.palette;
    final isLast = _step == _titles.length - 1;

    return OnboardingTheme(
      child: Scaffold(
        backgroundColor: p.surface,
        body: AppStepShell(
          step: _step,
          total: _titles.length,
          reversing: _reversing,
          title: _titles[_step].$1,
          hint: _titles[_step].$2,
          onBack: _back,
          footer: Column(
            children: [
              if (_errors['form'] != null) ...[
                Text(
                  _errors['form']!,
                  textAlign: TextAlign.center,
                  style: AppType.body(fontSize: 14, color: p.rejectedText),
                ),
                const SizedBox(height: 12),
              ],
              AppPillButton(
                label: isLast ? 'Create brand account' : 'Continue',
                busyLabel: 'Creating your account...',
                busy: _busy,
                onPressed: isLast ? _submit : _next,
              ),
              if (isLast) ...[
                const SizedBox(height: 12),
                Text(
                  'You can edit your brand page anytime.',
                  textAlign: TextAlign.center,
                  style: AppType.label(
                    fontWeight: FontWeight.w400,
                    color: p.onSurfaceFaint,
                  ),
                ),
              ],
            ],
          ),
          children: switch (_step) {
            0 => _accountStep(p),
            1 => _brandStep(p),
            _ => _pageStep(p),
          },
        ),
      ),
    );
  }

  List<Widget> _accountStep(BoardPalette p) => [
    AppPillButton(
      label: 'Continue with Google',
      kind: AppButtonKind.outlined,
      busyLabel: 'Signing up...',
      busy: _busy,
      leading: const GoogleMark(),
      onPressed: _signUpWithGoogle,
    ),
    const SizedBox(height: 20),
    const OrDivider(label: 'or use your email'),
    const SizedBox(height: 20),
    AppField(
      label: 'Work email',
      hint: 'Use your company email if you have one.',
      error: _errors['email'],
      child: AppTextField(
        hintText: 'hello@yourbrand.com',
        hasError: _errors['email'] != null,
        keyboardType: TextInputType.emailAddress,
        autofillHint: AutofillHints.email,
        autocorrect: false,
        onChanged: (v) => _set(() => _email = v),
      ),
    ),
    AppField(
      label: 'Password',
      hint: 'At least 8 characters.',
      error: _errors['password'],
      spaced: false,
      child: AppPasswordField(
        hintText: 'At least 8 characters',
        hasError: _errors['password'] != null,
        onChanged: (v) => _set(() => _password = v),
      ),
    ),
  ];

  List<Widget> _brandStep(BoardPalette p) => [
    AppField(
      label: 'Brand name',
      error: _errors['brandName'],
      child: AppTextField(
        controller: _brandName,
        hintText: 'Lumiere Studio',
        hasError: _errors['brandName'] != null,
        autofillHint: AutofillHints.organizationName,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => _set(() {}),
      ),
    ),
    AppField(
      label: 'Industry',
      hint: 'Pick the one that fits best.',
      error: _errors['industry'],
      child: AppChipGroup(
        options: BrandSignupFlow.industries,
        selected: _industry,
        multiSelect: false,
        onChanged: (v) => _set(() => _industry = v),
      ),
    ),
    AppField(
      label: 'City',
      hint: "So talent know where you're based.",
      error: _errors['location'],
      spaced: false,
      child: AppTextField(
        controller: _location,
        hintText: 'Mumbai',
        hasError: _errors['location'] != null,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => _set(() {}),
      ),
    ),
  ];

  List<Widget> _pageStep(BoardPalette p) => [
    AppField(
      label: 'About your brand',
      optional: true,
      hint: '${_about.text.length}/500',
      spaced: false,
      child: AppTextField(
        controller: _about,
        hintText:
            'Your aesthetic, what you stand for, and the kind of '
            'campaigns you run.',
        maxLines: 5,
        maxLength: 500,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => _set(() {}),
      ),
    ),
  ];
}

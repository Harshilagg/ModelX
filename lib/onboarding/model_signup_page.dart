import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import '../agency/scouting/ai_scout_service.dart';
import '../agency/team_access/invite_acceptance_page.dart';
import '../pages/dashboard_page.dart';
import '../services/cloudinary_service.dart';
import '../ui/app_type.dart';
import '../ui/board_palette.dart';
import '../widgets/kit/kit.dart';
import 'model_signup_data.dart';
import 'onboarding_theme.dart';
import 'success_page.dart';

/// Model signup, in four steps.
///
/// Replaces the single-page form and absorbs `CreateProfilePage`, which
/// asked for a name, username and bio the user had already given. That
/// screen stays in the tree as a repair path: it is where AuthGate sends
/// anyone whose profile is unfinished, which now includes anyone who
/// abandons this form after step 2.
///
/// **When the account is created.** At the end of step 2, not step 1 and
/// not step 4. Creating it at step 1 would leave anyone who quits at
/// step 2 with an auth user and no profile document -- a state AuthGate
/// cannot classify, so they are signed out of an account they can
/// neither use nor register again. Leaving it to step 4 is no better:
/// steps 3 and 4 upload photographs, which needs an authenticated user.
class ModelSignupPage extends StatefulWidget {
  final String userType;
  final String? inviteToken;

  const ModelSignupPage({super.key, required this.userType, this.inviteToken});

  @override
  State<ModelSignupPage> createState() => _ModelSignupPageState();
}

class _ModelSignupPageState extends State<ModelSignupPage> {
  final _data = ModelSignupData();
  final _picker = ImagePicker();

  int _step = 0;
  bool _reversing = false;
  bool _busy = false;
  Map<String, String> _errors = {};

  /// Set once the account exists, so a retry after a failure later in
  /// the form does not try to create it twice.
  String? _uid;

  /// Filled slots, by index into [ModelSignupData.photoSlots].
  final Map<int, File> _slots = {};
  final List<File> _extras = [];

  void _set(VoidCallback change) => setState(() {
    change();
    // An error clears as soon as its field is touched.
    if (_errors.isNotEmpty) _errors = {};
  });

  Future<void> _next() async {
    final errors = _data.validate(_step);
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }

    // Leaving step 2 is where the account is created, and where the
    // username is checked. Checking at the end would send someone back
    // two steps after they had uploaded photographs.
    if (_step == 1 && _uid == null) {
      setState(() => _busy = true);
      final failure = await _createAccount();
      if (!mounted) return;
      setState(() => _busy = false);
      if (failure != null) {
        setState(() => _errors = failure);
        return;
      }
    }

    setState(() {
      _reversing = false;
      _step++;
    });
  }

  /// Creates the auth user and the profile document together.
  ///
  /// Returns null on success, or the errors to show.
  /// Signs up with Google and jumps to step 2.
  ///
  /// Google supplies the email and usually the name, so step 1 has
  /// nothing left to ask. It does not supply a username, which is why
  /// this lands on step 2 rather than skipping further in.
  ///
  /// The auth user exists the moment Google returns, which breaks the
  /// rule that the account is created at the end of step 2. So the
  /// profile document is written immediately, incomplete: an auth user
  /// with no document is the one state AuthGate cannot classify, and
  /// somebody who closes the app here would be signed out of an account
  /// they could neither use nor register again. Written this way they
  /// land on the repair path instead, like any other unfinished signup.
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

      final user = credential.user!;
      _data.email = user.email ?? '';
      _data.fullName = user.displayName ?? '';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
            _data.accountDocument(
              uid: user.uid,
              userType: widget.userType,
              viaGoogle: true,
            ),
            SetOptions(merge: true),
          );

      _uid = user.uid;
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

  Future<Map<String, String>?> _createAccount() async {
    final username = _data.username.trim();

    try {
      // Checked before the account is created, so a collision costs
      // nothing to recover from.
      if (await _usernameTaken(username)) {
        return {'username': 'That username is taken. Try another.'};
      }
    } catch (_) {
      // A failed lookup must not block signup. The write below is a
      // merge on the user's own document, and a duplicate username is
      // recoverable; being unable to register is not.
    }

    // Signed up with Google: the account exists and its document was
    // written at step 1, so this only has to merge what step 2 added.
    if (_uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .set(
              _data.accountDocument(
                uid: _uid!,
                userType: widget.userType,
                viaGoogle: true,
              ),
              SetOptions(merge: true),
            );
        return null;
      } catch (_) {
        return {'form': 'Could not save your details. Please try again.'};
      }
    }

    UserCredential? credential;
    try {
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _data.email.trim(),
        password: _data.password,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set(
            _data.accountDocument(
              uid: credential.user!.uid,
              userType: widget.userType,
              viaGoogle: false,
            ),
            SetOptions(merge: true),
          );

      _uid = credential.user!.uid;
      return null;
    } on FirebaseAuthException catch (e) {
      return {
        if (e.code == 'email-already-in-use')
          'email': 'That email already has an account. Log in instead.'
        else if (e.code == 'weak-password')
          'password': 'That password is too easy to guess.'
        else if (e.code == 'invalid-email')
          'email': 'That email address does not look right.'
        else
          'form': e.message ?? 'Could not create your account.',
      };
    } catch (e) {
      // The document write failed after the account was made. Roll the
      // account back rather than leaving one AuthGate cannot place.
      try {
        await credential?.user?.delete();
      } catch (_) {}
      return {'form': 'Could not save your profile. Please try again.'};
    }
  }

  Future<bool> _usernameTaken(String username) async {
    final users = FirebaseFirestore.instance.collection('users');
    final lower = username.toLowerCase();
    final byLower = await users
        .where('usernameLower', isEqualTo: lower)
        .limit(1)
        .get();
    if (byLower.docs.isNotEmpty) return true;
    // Documents written before the lowercase mirror existed.
    final exact = await users
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return exact.docs.isNotEmpty;
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

  Future<void> _pickSlot(int index) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() => _slots[index] = File(picked.path));
  }

  Future<void> _pickExtras() async {
    final picked = await _picker.pickMultiImage(imageQuality: 88);
    if (picked.isEmpty) return;
    setState(() => _extras.addAll(picked.map((x) => File(x.path))));
  }

  /// Uploads the chosen photographs and finishes the profile.
  Future<void> _finish() async {
    setState(() => _busy = true);

    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Should be unreachable: the account is made at step 2.
      setState(() {
        _busy = false;
        _errors = {'form': 'Your session expired. Please start again.'};
      });
      return;
    }

    // Slots first, so the headshot becomes the avatar.
    final files = [
      for (var i = 0; i < ModelSignupData.photoSlots.length; i++)
        if (_slots[i] != null) _slots[i]!,
      ..._extras,
    ];

    for (final file in files) {
      try {
        final publicId =
            'portfolio/${uid}_${DateTime.now().millisecondsSinceEpoch}';
        final url = await CloudinaryService.uploadPortfolioImage(
          file,
          publicId,
        );
        if (url == null) continue;

        await FirebaseFirestore.instance.collection('portfolio').add({
          'uid': uid,
          'mediaUrl': url,
          'mediaType': 'image',
          'cloudinaryPublicId': publicId,
          'timestamp': FieldValue.serverTimestamp(),
          'isPublic': true,
        });
        _data.photoUrls.add(url);
      } catch (_) {
        // One photo failing must not cost the whole profile. Anything
        // missed can be added from the profile page afterwards.
      }
    }

    try {
      final profile = _data.profileDocument();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(profile, SetOptions(merge: true));

      // Same indexing the old create-profile step did on completion.
      AiScoutService().indexProfile(uid, profile).catchError((_) {});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errors = {'form': 'Could not save your profile. Please try again.'};
      });
      return;
    }

    if (!mounted) return;

    if (widget.inviteToken != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => InviteAcceptancePage(
            token: widget.inviteToken!,
            autoAcceptOnLoad: true,
          ),
        ),
        (_) => false,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => SuccessPage(
          role: SuccessRole.model,
          photoUrl: _data.photoUrls.isEmpty ? null : _data.photoUrls.first,
          onContinue: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const DashboardPage()),
            (_) => false,
          ),
        ),
      ),
      (_) => false,
    );
  }

  static const _titles = [
    (
      'Create your account',
      'Start with the basics. It takes about two minutes.',
    ),
    ('About you', 'This is how brands and agencies will know you.'),
    ('Your stats', 'Castings are matched on these, so keep them accurate.'),
    (
      'Show your work',
      'Add a few photos so brands can see you. You can add more anytime.',
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
                label: isLast ? 'Create my profile' : 'Continue',
                busyLabel: isLast
                    ? 'Creating your profile...'
                    : 'Just a moment...',
                busy: _busy,
                onPressed: isLast ? _finish : _next,
              ),
              if (_step == 0) ...[
                const SizedBox(height: 14),
                Text(
                  'By continuing you agree to our Terms and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: AppType.caption(color: p.onSurfaceFaint),
                ),
              ],
              if (isLast) ...[
                const SizedBox(height: 12),
                Text(
                  'Not ready? You can finish your profile later.',
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
            1 => _aboutStep(p),
            2 => _statsStep(p),
            _ => _workStep(p),
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
      label: 'Email',
      error: _errors['email'],
      child: AppTextField(
        hintText: 'you@email.com',
        hasError: _errors['email'] != null,
        keyboardType: TextInputType.emailAddress,
        autofillHint: AutofillHints.email,
        autocorrect: false,
        onChanged: (v) => _set(() => _data.email = v),
      ),
    ),
    AppField(
      label: 'Password',
      hint: 'At least 8 characters.',
      error: _errors['password'],
      child: AppPasswordField(
        hasError: _errors['password'] != null,
        onChanged: (v) => _set(() => _data.password = v),
      ),
    ),
    AppField(
      label: 'Phone number',
      optional: true,
      spaced: false,
      child: AppTextField(
        hintText: '+91 98765 43210',
        keyboardType: TextInputType.phone,
        autofillHint: AutofillHints.telephoneNumber,
        onChanged: (v) => _set(() => _data.phone = v),
      ),
    ),
  ];

  List<Widget> _aboutStep(BoardPalette p) => [
    AppField(
      label: 'Full name',
      error: _errors['fullName'],
      child: AppTextField(
        hintText: 'Anya Sharma',
        hasError: _errors['fullName'] != null,
        autofillHint: AutofillHints.name,
        textCapitalization: TextCapitalization.words,
        onChanged: (v) => _set(() => _data.fullName = v),
      ),
    ),
    AppField(
      label: 'Username',
      hint: 'Letters, numbers and underscores.',
      error: _errors['username'],
      child: AppTextField(
        hintText: 'anyasharma',
        hasError: _errors['username'] != null,
        autocorrect: false,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
          LengthLimitingTextInputFormatter(30),
        ],
        onChanged: (v) => _set(() => _data.username = v),
      ),
    ),
    AppField(
      label: 'Date of birth',
      error: _errors['dob'],
      child: _DateField(
        value: _data.dob,
        hasError: _errors['dob'] != null,
        onChanged: (d) => _set(() => _data.dob = d),
      ),
    ),
    AppField(
      label: 'City',
      hint: "Where you're based, so we can show you nearby castings.",
      error: _errors['city'],
      spaced: false,
      child: AppTextField(
        hintText: 'Mumbai',
        hasError: _errors['city'] != null,
        textCapitalization: TextCapitalization.words,
        onChanged: (v) => _set(() => _data.city = v),
      ),
    ),
  ];

  List<Widget> _statsStep(BoardPalette p) => [
    AppField(
      label: 'Height',
      hint: _data.heightInFeet == null ? null : "That's ${_data.heightInFeet}.",
      error: _errors['height'],
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              hintText: '172',
              hasError: _errors['height'] != null,
              keyboardType: TextInputType.number,
              tabularFigures: true,
              onChanged: (v) => _set(() => _data.height = v),
            ),
          ),
          const SizedBox(width: 10),
          // Three options, not the prototype's two: heightUnit
          // already accepts cm, in and ft, and the profile editor
          // writes all three.
          AppSegmentedControl<String>(
            options: const [('cm', 'cm'), ('in', 'in'), ('ft', 'ft')],
            value: _data.heightUnit,
            dense: true,
            onChanged: (v) => _set(() => _data.heightUnit = v),
          ),
        ],
      ),
    ),
    AppField(
      label: 'Bust, waist and hips',
      // No unit toggle: there is no field to store the choice in,
      // and the existing editor documents this as centimetres.
      hint: 'In centimetres. Most castings ask for these.',
      optional: true,
      child: Row(
        children: [
          Expanded(child: _Measure('Bust', '82', (v) => _data.bust = v, _set)),
          const SizedBox(width: 8),
          Expanded(
            child: _Measure('Waist', '60', (v) => _data.waist = v, _set),
          ),
          const SizedBox(width: 8),
          Expanded(child: _Measure('Hips', '88', (v) => _data.hips = v, _set)),
        ],
      ),
    ),
    AppField(
      label: 'What can you do?',
      hint: 'Pick all that apply. Castings are matched on these.',
      error: _errors['skills'],
      spaced: false,
      child: AppChipGroup(
        options: ModelSignupData.skillOptions,
        selected: _data.skills,
        onChanged: (v) => _set(() => _data.skills = v),
      ),
    ),
  ];

  List<Widget> _workStep(BoardPalette p) => [
    AppField(
      label: 'Digitals',
      hint:
          'Natural light, no filters, minimal makeup. '
          'This is what agencies expect.',
      optional: true,
      child: Row(
        children: [
          for (var i = 0; i < ModelSignupData.photoSlots.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _PhotoSlot(
                label: ModelSignupData.photoSlots[i],
                file: _slots[i],
                onPick: () => _pickSlot(i),
                onClear: () => setState(() => _slots.remove(i)),
              ),
            ),
          ],
        ],
      ),
    ),
    Padding(
      padding: const EdgeInsets.only(bottom: AppMetrics.fieldGap),
      child: GestureDetector(
        onTap: _pickExtras,
        child: Text(
          _extras.isEmpty
              ? 'Add more photos'
              : 'Add more photos (${_extras.length} added)',
          style: AppType.label(
            fontSize: 14,
            color: p.onSurface,
          ).copyWith(decoration: TextDecoration.underline),
        ),
      ),
    ),
    AppField(
      label: 'Bio',
      optional: true,
      hint: '${_data.bio.length}/300',
      child: AppTextField(
        hintText: 'A few lines about your style, strengths and experience.',
        maxLines: 4,
        maxLength: 300,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (v) => _set(() => _data.bio = v),
      ),
    ),
    AppField(
      label: 'Instagram',
      optional: true,
      hint: 'Brands often check these before booking.',
      child: AppTextField(
        hintText: '@anya.model',
        autocorrect: false,
        onChanged: (v) => _set(() => _data.instagram = v),
      ),
    ),
    AppField(
      label: 'Website or portfolio',
      optional: true,
      spaced: false,
      child: AppTextField(
        hintText: 'anyamodel.com',
        keyboardType: TextInputType.url,
        autocorrect: false,
        onChanged: (v) => _set(() => _data.website = v),
      ),
    ),
  ];
}

class _Measure extends StatelessWidget {
  final String caption;
  final String hint;
  final ValueChanged<String> onChanged;
  final void Function(VoidCallback) wrap;

  const _Measure(this.caption, this.hint, this.onChanged, this.wrap);

  @override
  Widget build(BuildContext context) {
    final p = OnboardingTheme.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          hintText: hint,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          tabularFigures: true,
          onChanged: (v) => wrap(() => onChanged(v)),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(caption, style: AppType.caption(color: p.onSurfaceFaint)),
        ),
      ],
    );
  }
}

/// Date of birth, through the platform's own picker.
class _DateField extends StatelessWidget {
  final DateTime? value;
  final bool hasError;
  final ValueChanged<DateTime> onChanged;

  const _DateField({
    required this.value,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = OnboardingTheme.palette;

    return Semantics(
      button: true,
      label: 'Date of birth',
      child: GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime(now.year - 20),
            firstDate: DateTime(now.year - 110),
            // A date of birth cannot be in the future.
            lastDate: now,
            // The picker is a Material surface of its own and would
            // otherwise come up in the app's light theme over a dark
            // form.
            builder: (context, child) =>
                Theme(data: Theme.of(context), child: child!),
          );
          if (picked != null) onChanged(picked);
        },
        child: Container(
          height: AppMetrics.control,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: p.surfaceField,
            borderRadius: AppRadii.fieldRadius,
            border: Border.all(color: hasError ? p.rejectedText : p.line),
          ),
          child: Text(
            value == null
                ? 'Select your date of birth'
                : '${value!.day.toString().padLeft(2, '0')} '
                      '/ ${value!.month.toString().padLeft(2, '0')} '
                      '/ ${value!.year}',
            style: value == null
                ? AppType.body(fontSize: 16, color: p.onSurfaceFaint)
                : AppType.tabular(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: p.onSurface,
                  ),
          ),
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _PhotoSlot({
    required this.label,
    required this.file,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final p = OnboardingTheme.palette;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: GestureDetector(
        onTap: onPick,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                color: p.surfaceField,
                borderRadius: AppRadii.fieldRadius,
                border: Border.all(color: p.lineStrong),
              ),
              clipBehavior: Clip.antiAlias,
              child: file == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 20, color: p.onSurfaceFaint),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: AppType.caption(color: p.onSurfaceFaint),
                          ),
                        ),
                      ],
                    )
                  : Image.file(file!, fit: BoxFit.cover),
            ),
            if (file != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onClear,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: p.ink.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 15, color: p.onPanel),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

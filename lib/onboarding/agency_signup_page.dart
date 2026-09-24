import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../agency/agency_dashboard_page.dart';
import '../agency/team_access/invite_acceptance_page.dart';
import '../services/cloudinary_service.dart';
import '../ui/app_type.dart';
import '../ui/board_palette.dart';
import '../widgets/kit/kit.dart';
import 'onboarding_theme.dart';
import 'success_page.dart';

/// Agency signup, in three steps.
///
/// Keeps the existing `agency` document shape exactly, including the
/// nested `socialLinks` map and the two Cloudinary uploads. The
/// specialties and services lists are still written as arrays, and
/// still null rather than empty when nothing is picked, because that is
/// what the rest of the agency side reads.
class AgencySignupFlow extends StatefulWidget {
  final String? inviteToken;

  const AgencySignupFlow({super.key, this.inviteToken});

  static const specialties = [
    'Fashion',
    'Editorial',
    'Runway',
    'Commercial',
    'Fitness',
    'Plus size',
    'Kids and teens',
    'Influencers',
  ];

  static const services = [
    'Model management',
    'Casting',
    'Scouting',
    'Talent development',
    'Brand consulting',
    'Event staffing',
  ];

  @override
  State<AgencySignupFlow> createState() => _AgencySignupFlowState();
}

class _AgencySignupFlowState extends State<AgencySignupFlow> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _website = TextEditingController();
  final _bio = TextEditingController();
  final _instagram = TextEditingController();
  final _linkedin = TextEditingController();

  String _email = '';
  String _password = '';
  List<String> _specialties = [];
  List<String> _services = [];

  File? _logo;
  File? _cover;

  int _step = 0;
  bool _reversing = false;
  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _address,
      _website,
      _bio,
      _instagram,
      _linkedin,
    ]) {
      c.dispose();
    }
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
        if (_name.text.trim().isEmpty) {
          e['name'] = "Enter your agency's name.";
        }
        // Digits only, so formatting and country codes do not decide
        // whether a number counts.
        if (_phone.text.replaceAll(RegExp(r'\D'), '').length < 7) {
          e['phone'] = 'Enter a phone number brands can reach.';
        }
        if (_address.text.trim().isEmpty) {
          e['address'] = 'Add your office address or city.';
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

  Future<void> _pick({required bool logo}) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() {
      if (logo) {
        _logo = File(picked.path);
      } else {
        _cover = File(picked.path);
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    UserCredential? credential;
    try {
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.trim().toLowerCase(),
        password: _password,
      );
      final uid = credential.user!.uid;

      // Uploaded after the account exists, because the upload is keyed
      // by uid, and before the document is written so the URLs land in
      // the same write rather than needing a second one.
      final logoUrl = await _upload(_logo, 'agency/${uid}_logo');
      final coverUrl = await _upload(_cover, 'agency/${uid}_cover');

      try {
        await FirebaseFirestore.instance.collection('agency').doc(uid).set({
          'agencyId': uid,
          'agencyName': _name.text.trim(),
          'email': _email.trim().toLowerCase(),
          'phone': _phone.text.trim(),
          'address': _address.text.trim(),
          'website': _website.text.trim(),
          'bio': _bio.text.trim(),
          // Null rather than an empty list when nothing is picked,
          // matching what the agency screens already expect to read.
          'specialties': _specialties.isEmpty ? null : _specialties,
          'services': _services.isEmpty ? null : _services,
          'logoUrl': logoUrl,
          'coverImageUrl': coverUrl,
          'portfolioMedia': null,
          'socialLinks': {
            'instagram': _instagram.text.trim(),
            'linkedin': _linkedin.text.trim(),
            'website': _website.text.trim(),
          },
          'isVerified': false,
          'isPublished': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        await credential.user?.delete();
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
                  role: SuccessRole.agency,
                  photoUrl: logoUrl,
                  onContinue: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const AgencyDashboardPage(),
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
        _errors = {'form': 'Could not save your agency. Please try again.'};
      });
    }
  }

  Future<String?> _upload(File? file, String publicId) async {
    if (file == null) return null;
    try {
      return await CloudinaryService.uploadProfileImage(file, publicId);
    } catch (_) {
      // An image that will not upload should not cost the account. It
      // can be added again from the agency profile page.
      return null;
    }
  }

  static const _titles = [
    (
      'Create your agency account',
      'Start with your login. It takes about two minutes.',
    ),
    ('Your agency', 'How brands and talent will find and contact you.'),
    (
      'Your agency page',
      'Show who you represent and what you offer. '
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
                label: isLast ? 'Create agency account' : 'Continue',
                busyLabel: 'Creating your account...',
                busy: _busy,
                onPressed: isLast ? _submit : _next,
              ),
              if (isLast) ...[
                const SizedBox(height: 12),
                Text(
                  'You can edit your agency page anytime.',
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
            1 => _agencyStep(p),
            _ => _pageStep(p),
          },
        ),
      ),
    );
  }

  List<Widget> _accountStep(BoardPalette p) => [
    AppField(
      label: 'Work email',
      hint: "Use your agency's email address if you have one.",
      error: _errors['email'],
      child: AppTextField(
        hintText: 'bookings@youragency.com',
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
        hasError: _errors['password'] != null,
        onChanged: (v) => _set(() => _password = v),
      ),
    ),
  ];

  List<Widget> _agencyStep(BoardPalette p) => [
    AppField(
      label: 'Agency name',
      error: _errors['name'],
      child: AppTextField(
        controller: _name,
        hintText: 'Meridian Talent Co.',
        hasError: _errors['name'] != null,
        autofillHint: AutofillHints.organizationName,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => _set(() {}),
      ),
    ),
    AppField(
      label: 'Bookings phone',
      hint: 'The number brands should call about bookings.',
      error: _errors['phone'],
      child: AppTextField(
        controller: _phone,
        hintText: '+91 22 5555 0100',
        hasError: _errors['phone'] != null,
        keyboardType: TextInputType.phone,
        autofillHint: AutofillHints.telephoneNumber,
        onChanged: (_) => _set(() {}),
      ),
    ),
    AppField(
      label: 'Office address',
      error: _errors['address'],
      child: AppTextField(
        controller: _address,
        hintText: 'Street, area, city',
        hasError: _errors['address'] != null,
        autofillHint: AutofillHints.streetAddressLine1,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => _set(() {}),
      ),
    ),
    AppField(
      label: 'Website',
      optional: true,
      spaced: false,
      child: AppTextField(
        controller: _website,
        hintText: 'youragency.com',
        keyboardType: TextInputType.url,
        autocorrect: false,
        onChanged: (_) => _set(() {}),
      ),
    ),
  ];

  List<Widget> _pageStep(BoardPalette p) => [
    AppField(
      label: 'Logo and cover',
      optional: true,
      child: _ImagePickers(
        name: _name.text,
        logo: _logo,
        cover: _cover,
        onPickLogo: () => _pick(logo: true),
        onPickCover: () => _pick(logo: false),
      ),
    ),
    AppField(
      label: 'About your agency',
      optional: true,
      hint: '${_bio.text.length}/500',
      child: AppTextField(
        controller: _bio,
        hintText:
            'Your vision, the markets you work in, and what sets '
            'your agency apart.',
        maxLines: 5,
        maxLength: 500,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => _set(() {}),
      ),
    ),
    AppField(
      label: 'Who do you represent?',
      hint: 'Pick all that apply.',
      optional: true,
      child: AppChipGroup(
        options: AgencySignupFlow.specialties,
        selected: _specialties,
        onChanged: (v) => _set(() => _specialties = v),
      ),
    ),
    AppField(
      label: 'What services do you offer?',
      hint: 'Pick all that apply.',
      optional: true,
      child: AppChipGroup(
        options: AgencySignupFlow.services,
        selected: _services,
        onChanged: (v) => _set(() => _services = v),
      ),
    ),
    AppField(
      label: 'Instagram',
      optional: true,
      hint: 'Brands and talent often check these first.',
      child: AppTextField(
        controller: _instagram,
        hintText: '@youragency',
        autocorrect: false,
        onChanged: (_) => _set(() {}),
      ),
    ),
    AppField(
      label: 'LinkedIn',
      optional: true,
      spaced: false,
      child: AppTextField(
        controller: _linkedin,
        hintText: 'linkedin.com/company/youragency',
        keyboardType: TextInputType.url,
        autocorrect: false,
        onChanged: (_) => _set(() {}),
      ),
    ),
  ];
}

/// The cover-and-logo picker: a wide banner with a round logo
/// overlapping its lower edge, which is how the agency page renders it.
class _ImagePickers extends StatelessWidget {
  final String name;
  final File? logo;
  final File? cover;
  final VoidCallback onPickLogo;
  final VoidCallback onPickCover;

  const _ImagePickers({
    required this.name,
    required this.logo,
    required this.cover,
    required this.onPickLogo,
    required this.onPickCover,
  });

  @override
  Widget build(BuildContext context) {
    final p = OnboardingTheme.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onPickCover,
          child: Semantics(
            button: true,
            label: cover == null ? 'Add cover image' : 'Replace cover image',
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: Container(
                decoration: BoxDecoration(
                  color: p.surfaceField,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: p.lineStrong),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: cover == null
                    ? Text(
                        'Add a cover image',
                        style: AppType.label(
                          fontWeight: FontWeight.w400,
                          color: p.onSurfaceSoft,
                        ),
                      )
                    : Image.file(cover!, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -36),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onPickLogo,
                child: Semantics(
                  button: true,
                  label: logo == null ? 'Add logo' : 'Replace logo',
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: p.surfaceRaised,
                      shape: BoxShape.circle,
                      // Rings the logo in the page colour so it reads as
                      // sitting on top of the cover rather than in it.
                      border: Border.all(color: p.surface, width: 3),
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: logo == null
                        ? Text(
                            name.trim().isEmpty
                                ? '?'
                                : name.trim()[0].toUpperCase(),
                            style: AppType.display(
                              fontSize: 24,
                              color: p.onSurfaceFaint,
                            ),
                          )
                        : Image.file(logo!, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.trim().isEmpty ? 'Your agency' : name.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.label(fontSize: 15, color: p.onSurface),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: onPickLogo,
                        child: Text(
                          logo == null ? 'Add logo' : 'Change logo',
                          style: AppType.label(
                            color: p.onSurfaceSoft,
                          ).copyWith(decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Pulls the following field back up past the overlap.
        const SizedBox(height: 0),
      ],
    );
  }
}

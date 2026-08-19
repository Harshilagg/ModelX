import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'login_page.dart';
import 'dashboard_page.dart';
import 'create_profile_page.dart';
import '../agency/team_access/invite_acceptance_page.dart';
import '../ui/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class SignupPage extends StatefulWidget {
  final String userType; // 'model'
  final String? inviteToken;

  const SignupPage({
    super.key,
    required this.userType,
    this.inviteToken,
  });

  @override
  State<SignupPage> createState() => _SignupPageState();
}

final GoogleSignIn _googleSignIn = GoogleSignIn();


class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controllers
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController dobController = TextEditingController();

  DateTime? selectedDob;
  bool loading = false;
  bool isGoogleUser = false;
  String? _lastSaveError;

  // (username format validator removed to preserve original signup behavior)

  // ------------------ DATE PICKER ------------------
  Future<void> pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDob = picked;
        dobController.text =
            "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  // ------------------ EMAIL SIGNUP ------------------
  Future<void> signupWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim().toLowerCase(),
        password: passwordController.text.trim(),
      );

      // Set display name on the auth user from the provided full name (if any)
      final user = userCredential.user!;
      if (fullNameController.text.trim().isNotEmpty) {
        await user.updateDisplayName(fullNameController.text.trim());
      }

      // mark this as an email-created user
      isGoogleUser = false;

      // Save a basic user document including the chosen account `userType` so
      // downstream flows (create profile, dashboard) can branch correctly.
      final saved = await _saveUserProfile(user.uid);
      if (!saved) {
        // If Firestore write failed, remove the newly created auth user to
        // avoid leaving orphaned auth accounts. Best-effort only.
        try {
          await user.delete();
        } catch (_) {}
        _showError('Could not create user record. ' + (_lastSaveError ?? 'Please try again.'));
        return;
      }

      // send email verification (best-effort)
      try {
        await user.sendEmailVerification();
      } catch (_) {}

      // Ensure auth user is fresh, then send to CreateProfilePage to finish profile.
      await FirebaseAuth.instance.currentUser?.reload();
      if (!mounted) return;
      if (widget.inviteToken != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => InviteAcceptancePage(
              token: widget.inviteToken!,
              autoAcceptOnLoad: true,
            ),
          ),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CreateProfilePage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message);
    } finally {
      setState(() => loading = false);
    }
  }

  // ------------------ GOOGLE SIGNUP ------------------
Future<void> signupWithGoogle() async {
  try {
    setState(() => loading = true);

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      setState(() => loading = false);
      return;
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;

    // Mark that this flow created a Google user
    isGoogleUser = true;

    // Save user doc (best-effort). If saving fails, rollback auth and sign-out.
    final saved = await _saveUserProfile(user.uid);
    if (!saved) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      try {
        await _auth.signOut();
      } catch (_) {}
      try {
        await user.delete();
      } catch (_) {}
      _showError('Could not create user record. ' + (_lastSaveError ?? 'Please try again.'));
      return;
    }

    // Decide where to redirect: if user has completed profile, go to Dashboard,
    // otherwise send them to CreateProfilePage so they finish their profile.
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    final profileCompleted = data != null && (data['profileCompleted'] == true);

    if (!mounted) return;
    if (widget.inviteToken != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => InviteAcceptancePage(
            token: widget.inviteToken!,
            autoAcceptOnLoad: true,
          ),
        ),
        (route) => false,
      );
    } else if (profileCompleted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
    } else {
      await FirebaseAuth.instance.currentUser?.reload();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CreateProfilePage()),
        (route) => false,
      );
    }
  } catch (e) {
    _showError(e.toString());
  } finally {
    setState(() => loading = false);
  }
  }

  /// Save basic user document. Returns true on success, false on failure.
  Future<bool> _saveUserProfile(String uid) async {
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      final fullName = isGoogleUser
          ? (authUser?.displayName ?? fullNameController.text.trim())
          : fullNameController.text.trim();
      final email = (isGoogleUser ? (authUser?.email ?? emailController.text.trim()) : emailController.text.trim()).trim().toLowerCase();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': fullName,
        'fullNameLower': fullName.isNotEmpty ? fullName.toLowerCase() : null,
        'username': usernameController.text.trim(),
        'usernameLower': usernameController.text.trim().isNotEmpty ? usernameController.text.trim().toLowerCase() : null,
        'email': email,
        'phone': phoneController.text.trim(),
        'phoneVerified': false,
        'profileCompleted': false,
        'userType': widget.userType,
        'dob': selectedDob,
        'followers': [],
        'following': [],
        'authProvider': isGoogleUser ? 'google' : 'email',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e, st) {
      _lastSaveError = e.toString();
      // Log full error for debugging
      // ignore: avoid_print
      print('[_saveUserProfile] error: $_lastSaveError');
      // ignore: avoid_print
      print(st);
      return false;
    }
  }

  void _showError(String? msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg ?? 'Something went wrong')),
    );
  }

  // ------------------ UI ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        children: [
          _buildHero(context),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _field(fullNameController, 'Full Name'),
                      const SizedBox(height: 16),
                      _field(usernameController, 'Username'),
                      const SizedBox(height: 16),
                      _field(emailController, 'Email', readOnly: isGoogleUser),
                      const SizedBox(height: 16),
                      _field(phoneController, 'Phone Number', keyboard: TextInputType.phone),
                      if (!isGoogleUser) ...[
                        const SizedBox(height: 16),
                        _field(passwordController, 'Password', obscure: true),
                      ],
                      const SizedBox(height: 16),
                      _dobField(),
                      const SizedBox(height: 28),
                      AppButton(
                        label: 'Sign up',
                        onPressed: loading ? null : signupWithEmail,
                        loading: loading,
                        expand: true,
                      ),
                      const SizedBox(height: 14),
                      _orDivider(),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: loading ? null : signupWithGoogle,
                        icon: const _GoogleGLogo(size: 18),
                        label: const Text('Continue with Google'),
                      ),
                      const SizedBox(height: 24),
                      _loginRedirect(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dark "backstage" hero band — first impression for the signup screen,
  /// matching the same treatment used on login/agency/brand signup so the
  /// app reads consistently regardless of entry point.
  Widget _buildHero(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      width: double.infinity,
      color: AppColors.backstage,
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canPop)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back, color: AppColors.onBackstage, size: AppIconSize.md),
              ),
            ),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: 'Join ',
                style: AppTypography.display.copyWith(color: AppColors.onBackstage, fontSize: 32),
              ),
              TextSpan(
                text: 'ModelX',
                style: AppTypography.displayAccent(color: AppColors.goldOnBackstage, fontSize: 34),
              ),
              TextSpan(
                text: '.',
                style: AppTypography.display.copyWith(color: AppColors.onBackstage, fontSize: 32),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Text(
            'Create your profile and get discovered by agencies and brands.',
            style: AppTypography.body.copyWith(color: AppColors.onBackstageSoft, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: AppTypography.caption),
        ),
        const Expanded(child: Divider(color: AppColors.line)),
      ],
    );
  }

  // ------------------ UI HELPERS ------------------
  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    bool readOnly = false,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return AppTextField(
      label: label,
      controller: controller,
      obscureText: obscure,
      readOnly: readOnly,
      keyboardType: keyboard,
      validator: validator ?? (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  Widget _dobField() {
    return AppTextField(
      label: 'Date of Birth',
      controller: dobController,
      readOnly: true,
      onTap: pickDob,
      trailingIcon: const Icon(Icons.calendar_today, size: AppIconSize.sm, color: AppColors.inkFaint),
      validator: (_) => selectedDob == null ? 'Select date of birth' : null,
    );
  }

  Widget _loginRedirect() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account? ', style: AppTypography.body.copyWith(color: AppColors.inkSoft)),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
          child: Text(
            'Login',
            style: AppTypography.bodyEmphasized.copyWith(
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

/// The real Google "G" brand mark (official multi-color path, traced from
/// Google's own 18x18 SVG) for the "Continue with Google" button — the
/// standard convention for this button, not a design-system palette
/// violation. Drawn via CustomPainter (rather than an SVG asset/package)
/// since the project has no SVG-rendering dependency and adding one was
/// outside this redesign batch's scope.
class _GoogleGLogo extends StatelessWidget {
  final double size;
  const _GoogleGLogo({this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 18;
    canvas.save();
    canvas.scale(scale, scale);

    final blue = Paint()..color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(17.6400, 9.2045)
      ..cubicTo(17.6400, 8.5664, 17.5827, 7.9527, 17.4764, 7.3636)
      ..lineTo(9.0000, 7.3636)
      ..lineTo(9.0000, 10.8450)
      ..lineTo(13.8436, 10.8450)
      ..cubicTo(13.6350, 11.9700, 13.0009, 12.9232, 12.0477, 13.5614)
      ..lineTo(12.0477, 15.8195)
      ..lineTo(14.9564, 15.8195)
      ..cubicTo(16.6582, 14.2527, 17.6400, 11.9455, 17.6400, 9.2045)
      ..close();
    canvas.drawPath(bluePath, blue);

    final green = Paint()..color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(9.0000, 18.0000)
      ..cubicTo(11.4300, 18.0000, 13.4673, 17.1940, 14.9564, 15.8195)
      ..lineTo(12.0477, 13.5614)
      ..cubicTo(11.2418, 14.1018, 10.2109, 14.4204, 9.0000, 14.4204)
      ..cubicTo(6.6564, 14.4204, 4.6718, 12.8373, 3.9641, 10.7100)
      ..lineTo(0.9573, 10.7100)
      ..lineTo(0.9573, 13.0418)
      ..cubicTo(2.4382, 15.9832, 5.4818, 18.0000, 9.0000, 18.0000)
      ..close();
    canvas.drawPath(greenPath, green);

    final yellow = Paint()..color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(3.9641, 10.7100)
      ..cubicTo(3.7841, 10.1696, 3.6814, 9.5923, 3.6814, 9.0000)
      ..cubicTo(3.6814, 8.4077, 3.7841, 7.8304, 3.9641, 7.2900)
      ..lineTo(3.9641, 4.9582)
      ..lineTo(0.9573, 4.9582)
      ..cubicTo(0.3477, 6.1732, 0.0000, 7.5477, 0.0000, 9.0000)
      ..cubicTo(0.0000, 10.4523, 0.3477, 11.8268, 0.9573, 13.0418)
      ..lineTo(3.9641, 10.7100)
      ..close();
    canvas.drawPath(yellowPath, yellow);

    final red = Paint()..color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(9.0000, 3.5795)
      ..cubicTo(10.3214, 3.5795, 11.5077, 4.0336, 12.4405, 4.9255)
      ..lineTo(15.0219, 2.3441)
      ..cubicTo(13.4632, 0.8918, 11.4259, 0.0000, 9.0000, 0.0000)
      ..cubicTo(5.4818, 0.0000, 2.4382, 2.0168, 0.9573, 4.9582)
      ..lineTo(3.9641, 7.2900)
      ..cubicTo(4.6718, 5.1627, 6.6564, 3.5795, 9.0000, 3.5795)
      ..close();
    canvas.drawPath(redPath, red);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

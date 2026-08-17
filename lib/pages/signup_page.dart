import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'login_page.dart';
import 'dashboard_page.dart';
import 'create_profile_page.dart';
import '../agency/team_access/invite_acceptance_page.dart';

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
      appBar: AppBar(title: const Text('Create your account')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _field(fullNameController, 'Full Name'),
              _field(usernameController, 'Username'),
              _field(emailController, 'Email',
                  readOnly: isGoogleUser),
              _field(phoneController, 'Phone Number',
                  keyboard: TextInputType.phone),
              if (!isGoogleUser)
                _field(passwordController, 'Password',
                    obscure: true),
              _dobField(),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: loading ? null : signupWithEmail,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text('Sign up'),
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: signupWithGoogle,
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Continue with Google'),
              ),

              const SizedBox(height: 20),

              _loginRedirect(),
            ],
          ),
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        readOnly: readOnly,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
        validator: validator ?? (v) => v!.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _dobField() {
    return TextFormField(
      controller: dobController,
      readOnly: true,
      onTap: pickDob,
      decoration: const InputDecoration(
        labelText: 'Date of Birth',
        suffixIcon: Icon(Icons.calendar_today),
      ),
      validator: (_) =>
          selectedDob == null ? 'Select date of birth' : null,
    );
  }

  Widget _loginRedirect() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account? ',
            style: TextStyle(color: Colors.grey)),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
          child: const Text(
            'Login',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

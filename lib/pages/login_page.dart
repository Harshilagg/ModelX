import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart';
import '../brand/brand_dashboard_page.dart';
import '../agency/agency_dashboard_page.dart';
import '../agency/agency_edit_profile_page.dart';
import '../agency/team_access/invite_acceptance_page.dart';
import '../selectportfolio/select_portfolio_page.dart';

class LoginPage extends StatefulWidget {
  final String? inviteToken;

  const LoginPage({super.key, this.inviteToken});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController identifierController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool loading = false;

  // ---------------- LOGIN LOGIC ----------------
  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final input = identifierController.text.trim();
      final password = passwordController.text.trim();

      final bool isEmail = RegExp(
        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
      ).hasMatch(input);

      String emailToUse;

      if (isEmail) {
        // ✅ Email login (let Firebase Auth handle it)
        emailToUse = input;
      } else {
        // ✅ Username / full name login
        final normalized = input.replaceFirst(RegExp(r'^@'), '');
        final lower = normalized.toLowerCase();

        QuerySnapshot<Map<String, dynamic>> q;

        // 1️⃣ usernameLower
        q = await FirebaseFirestore.instance
            .collection('users')
            .where('usernameLower', isEqualTo: lower)
            .limit(1)
            .get();

        // 2️⃣ username (fallback)
        if (q.docs.isEmpty) {
          q = await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: normalized)
              .limit(1)
              .get();
        }

        // 3️⃣ fullNameLower
        if (q.docs.isEmpty) {
          q = await FirebaseFirestore.instance
              .collection('users')
              .where('fullNameLower', isEqualTo: lower)
              .limit(1)
              .get();
        }

        // 4️⃣ fullName (last fallback)
        if (q.docs.isEmpty) {
          q = await FirebaseFirestore.instance
              .collection('users')
              .where('fullName', isEqualTo: normalized)
              .limit(1)
              .get();
        }

        if (q.docs.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No account found for that username',
          );
        }

        final data = q.docs.first.data();
        if (data['email'] == null) {
          throw FirebaseAuthException(
            code: 'invalid-user',
            message: 'This account has no email linked',
          );
        }

        emailToUse = data['email'].toString().trim();
      }

      // 🔐 Firebase Auth login
      final credential = await _auth.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );

      final user = credential.user!;
      final uid = user.uid;

      if (widget.inviteToken != null) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
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

      // 🔍 1. Check MODEL (users) collection
      debugPrint('🔎 Checking users for $uid');
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      if (userDoc.exists) {
        debugPrint('➡️ Found model profile');
        // Mirror AuthGate logic: if profileCompleted -> Dashboard, else CreateProfilePage
        final data = userDoc.data();
        final profileCompleted = data != null && (data['profileCompleted'] == true);
        if (profileCompleted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DashboardPage()),
            (_) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SelectPortfolioPage()),
            (_) => false,
          );
        }
        return;
      }

      // 🔍 2. Check BRAND collection
      debugPrint('🔎 Checking brands for $uid');
      final brandDoc = await FirebaseFirestore.instance.collection('brands').doc(uid).get();
      if (brandDoc.exists) {
        debugPrint('➡️ Found brand profile');
        // ✅ BRAND LOGIN
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const BrandDashboardPage()),
          (_) => false,
        );
        return;
      }

      // 🔍 3. Check AGENCY collection
      debugPrint('🔎 Checking agency for $uid');
      final agencyDoc = await FirebaseFirestore.instance.collection('agency').doc(uid).get();
      if (agencyDoc.exists) {
        debugPrint('➡️ Found agency profile');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged in as Agency')));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AgencyDashboardPage()),
          (_) => false,
        );
        return;
      }

      // ❌ If none found
      debugPrint('❌ No profile found for $uid');

      if (!mounted) return;
      // Offer to create agency profile (handles case where auth user exists but Firestore doc was not created)
      final choice = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No profile found'),
          content: const Text('No model/brand/agency profile exists for this account. Would you like to create an Agency profile now?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, 'select'), child: const Text('Select role')),
            TextButton(onPressed: () => Navigator.pop(context, 'agency'), child: const Text('Create Agency')),
          ],
        ),
      );

      if (choice == 'agency') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AgencyEditProfilePage()));
        return;
      } else if (choice == 'select') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SelectPortfolioPage()));
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No profile found')));
        return;
      }
    }
    on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: identifierController,
                decoration: const InputDecoration(
                  labelText: 'Email or Username',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter email or username' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                ),
                validator: (v) =>
                    v == null || v.length < 6 ? 'Password too short' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: loading ? null : login,
                child: loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Login'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: Colors.grey),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SelectPortfolioPage(inviteToken: widget.inviteToken),
                        ),
                      );
                    },
                    child: const Text(
                      'Create your account',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

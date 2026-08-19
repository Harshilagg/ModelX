import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart';
import '../brand/brand_dashboard_page.dart';
import '../agency/agency_dashboard_page.dart';
import '../agency/agency_edit_profile_page.dart';
import '../agency/team_access/invite_acceptance_page.dart';
import '../selectportfolio/select_portfolio_page.dart';
import '../ui/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

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
                      AppTextField(
                        label: 'Email or Username',
                        controller: identifierController,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Enter email or username' : null,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Password',
                        controller: passwordController,
                        obscureText: true,
                        validator: (v) =>
                            v == null || v.length < 6 ? 'Password too short' : null,
                      ),
                      const SizedBox(height: 28),
                      AppButton(
                        label: 'Login',
                        onPressed: loading ? null : login,
                        loading: loading,
                        expand: true,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: AppTypography.body.copyWith(color: AppColors.inkSoft),
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
                            child: Text(
                              'Create your account',
                              style: AppTypography.bodyEmphasized.copyWith(
                                fontWeight: FontWeight.w700,
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
            ),
          ),
        ],
      ),
    );
  }

  /// Dark "backstage" hero band — first impression for the login screen.
  /// One word of the headline ("back") carries the Bodoni Moda display
  /// accent in the brass-on-dark tone; the rest is Archivo.
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
                text: 'Welcome ',
                style: AppTypography.display.copyWith(color: AppColors.onBackstage, fontSize: 32),
              ),
              TextSpan(
                text: 'back',
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
            'Sign in to continue to ModelX.',
            style: AppTypography.body.copyWith(color: AppColors.onBackstageSoft, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

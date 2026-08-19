import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'brand_dashboard_page.dart';
import '../ui/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class BrandSignupPage extends StatefulWidget {
  const BrandSignupPage({super.key});

  @override
  State<BrandSignupPage> createState() => _BrandSignupPageState();
}

class _BrandSignupPageState extends State<BrandSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controllers
  final TextEditingController brandNameController = TextEditingController();
  final TextEditingController industryController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController aboutController = TextEditingController();

  bool loading = false;

  // ------------------ BRAND SIGNUP ------------------
  Future<void> signupBrand() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);
    try {
      // Create user with email and password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim().toLowerCase(),
        password: passwordController.text.trim(),
      );

      // Save brand profile to Firestore
      await FirebaseFirestore.instance
          .collection('brands')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'brandName': brandNameController.text.trim(),
        'industry': industryController.text.trim(),
        'location': locationController.text.trim(),
        'email': emailController.text.trim().toLowerCase(),
        'about': aboutController.text.trim(),
        'profileCompleted': true,
        'createdAt': FieldValue.serverTimestamp(),
      });


      if (!mounted) return;

      // Redirect to BrandDashboardPage
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const BrandDashboardPage()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message);
    } finally {
      setState(() => loading = false);
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
                      _field(brandNameController, 'Brand Name'),
                      const SizedBox(height: 16),
                      _field(industryController, 'Industry'),
                      const SizedBox(height: 16),
                      _field(locationController, 'Location'),
                      const SizedBox(height: 16),
                      _field(emailController, 'Email'),
                      const SizedBox(height: 16),
                      _field(passwordController, 'Password', obscure: true),
                      const SizedBox(height: 16),
                      _field(aboutController, 'About the Brand', maxLines: 5),
                      const SizedBox(height: 28),
                      AppButton(
                        label: 'Sign up as Brand',
                        onPressed: loading ? null : signupBrand,
                        loading: loading,
                        expand: true,
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

  /// Dark "backstage" hero band, matching the treatment on login/signup/
  /// agency-signup so the first impression is consistent across entry points.
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
            'Set up your brand to discover and book talent.',
            style: AppTypography.body.copyWith(color: AppColors.onBackstageSoft, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    int maxLines = 1,
  }) {
    return AppTextField(
      label: label,
      controller: controller,
      obscureText: obscure,
      maxLines: maxLines,
      validator: (value) => value!.isEmpty ? 'Required' : null,
    );
  }
}
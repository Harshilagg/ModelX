import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'brand_dashboard_page.dart';

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
        email: emailController.text.trim(),
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
        'email': emailController.text.trim(),
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
      appBar: AppBar(title: const Text('Brand Signup')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _field(brandNameController, 'Brand Name'),
              _field(industryController, 'Industry'),
              _field(locationController, 'Location'),
              _field(emailController, 'Email'),
              _field(passwordController, 'Password', obscure: true),
              _field(aboutController, 'About the Brand', maxLines: 5),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: loading ? null : signupBrand,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text('Sign up as Brand'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: (value) => value!.isEmpty ? 'Required' : null,
      ),
    );
  }
}
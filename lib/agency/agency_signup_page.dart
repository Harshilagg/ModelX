import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_modelx/services/cloudinary_service.dart';
import 'agency_dashboard_page.dart';
import '../ui/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class AgencySignupPage extends StatefulWidget {
  const AgencySignupPage({super.key});

  @override
  State<AgencySignupPage> createState() => _AgencySignupPageState();
}

class _AgencySignupPageState extends State<AgencySignupPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController agencyNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController specialtiesController = TextEditingController();
  final TextEditingController servicesController = TextEditingController();
  final TextEditingController instagramController = TextEditingController();
  final TextEditingController linkedinController = TextEditingController();

  bool loading = false;
  String? logoUrl;
  String? coverUrl;

  Future<void> _pickAndUpload(bool isLogo) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    final file = File(picked.path);

    final uid = _auth.currentUser?.uid ?? DateTime.now().millisecondsSinceEpoch.toString();

    final uploaded = await CloudinaryService.uploadProfileImage(file, 'agency_$uid');
    if (uploaded == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed')));
      return;
    }

    setState(() {
      if (isLogo) logoUrl = uploaded; else coverUrl = uploaded;
    });
  }

  Future<void> signupAgency() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim().toLowerCase(),
        password: passwordController.text.trim(),
      );

      final uid = userCred.user!.uid;

      debugPrint('✅ Firebase Auth user created: $uid');

      try {
        await FirebaseFirestore.instance.collection('agency').doc(uid).set({
          'agencyId': uid,
          'agencyName': agencyNameController.text.trim(),
          'email': emailController.text.trim().toLowerCase(),
          'phone': phoneController.text.trim(),
          'address': addressController.text.trim(),
          'website': websiteController.text.trim(),
          'bio': bioController.text.trim(),
          'specialties': specialtiesController.text.trim().isEmpty ? null : specialtiesController.text.trim().split(',').map((s) => s.trim()).toList(),
          'services': servicesController.text.trim().isEmpty ? null : servicesController.text.trim().split(',').map((s) => s.trim()).toList(),
          'logoUrl': logoUrl,
          'coverImageUrl': coverUrl,
          'portfolioMedia': null,
          'socialLinks': {
            'instagram': instagramController.text.trim(),
            'linkedin': linkedinController.text.trim(),
            'website': websiteController.text.trim(),
          },
          'isVerified': false,
          'isPublished': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ Agency document created for $uid');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agency account created')));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AgencyDashboardPage()),
          (_) => false,
        );
      } catch (fireErr) {
        debugPrint('🔥 Firestore write failed for agency/$uid: $fireErr');
        // Attempt to delete the newly created auth user to avoid leaving an orphaned auth account
        try {
          await userCred.user?.delete();
          debugPrint('🧹 Deleted auth user after Firestore failure');
        } catch (delErr) {
          debugPrint('⚠️ Failed to delete auth user: $delErr');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create agency profile: $fireErr')));
        return;
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Signup failed')));
    } finally {
      setState(() => loading = false);
    }
  }

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
                        label: 'Agency Name',
                        controller: agencyNameController,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Email',
                        controller: emailController,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Password',
                        controller: passwordController,
                        obscureText: true,
                        validator: (v) => v == null || v.length < 6 ? 'Min 6 chars' : null,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(label: 'Phone', controller: phoneController),
                      const SizedBox(height: 16),
                      AppTextField(label: 'Address', controller: addressController),
                      const SizedBox(height: 16),
                      AppTextField(label: 'Website', controller: websiteController),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Upload Logo',
                              icon: Icons.photo,
                              variant: AppButtonVariant.secondary,
                              onPressed: () => _pickAndUpload(true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppButton(
                              label: 'Upload Cover',
                              icon: Icons.photo_library,
                              variant: AppButtonVariant.secondary,
                              onPressed: () => _pickAndUpload(false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppTextField(label: 'Bio', controller: bioController, maxLines: 4),
                      const SizedBox(height: 16),
                      AppTextField(label: 'Specialties (comma separated)', controller: specialtiesController),
                      const SizedBox(height: 16),
                      AppTextField(label: 'Services (comma separated)', controller: servicesController),
                      const SizedBox(height: 16),
                      AppTextField(label: 'Instagram handle', controller: instagramController),
                      const SizedBox(height: 16),
                      AppTextField(label: 'LinkedIn URL', controller: linkedinController),
                      const SizedBox(height: 28),
                      AppButton(
                        label: 'Sign up as Agency',
                        onPressed: loading ? null : signupAgency,
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
  /// brand-signup so the first impression is consistent across entry points.
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
            'Set up your agency to manage talent and bookings.',
            style: AppTypography.body.copyWith(color: AppColors.onBackstageSoft, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

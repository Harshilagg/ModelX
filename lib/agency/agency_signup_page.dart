import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_modelx/services/cloudinary_service.dart';
import 'agency_dashboard_page.dart';

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
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = userCred.user!.uid;

      debugPrint('✅ Firebase Auth user created: $uid');

      try {
        await FirebaseFirestore.instance.collection('agency').doc(uid).set({
          'agencyId': uid,
          'agencyName': agencyNameController.text.trim(),
          'email': emailController.text.trim(),
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
      appBar: AppBar(title: const Text('Agency Signup')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: agencyNameController, decoration: const InputDecoration(labelText: 'Agency Name'), validator: (v) => v==null||v.isEmpty? 'Required' : null,),
              TextFormField(controller: emailController, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => v==null||v.isEmpty? 'Required' : null,),
              TextFormField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true, validator: (v) => v==null||v.length<6? 'Min 6 chars' : null,),
              TextFormField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              TextFormField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
              TextFormField(controller: websiteController, decoration: const InputDecoration(labelText: 'Website')),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(onPressed: () => _pickAndUpload(true), icon: const Icon(Icons.photo), label: const Text('Upload Logo')),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(onPressed: () => _pickAndUpload(false), icon: const Icon(Icons.photo_library), label: const Text('Upload Cover')),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(controller: bioController, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 4),
              const SizedBox(height: 8),
              TextFormField(controller: specialtiesController, decoration: const InputDecoration(labelText: 'Specialties (comma separated)'),),
              TextFormField(controller: servicesController, decoration: const InputDecoration(labelText: 'Services (comma separated)'),),
              TextFormField(controller: instagramController, decoration: const InputDecoration(labelText: 'Instagram handle')),              
              TextFormField(controller: linkedinController, decoration: const InputDecoration(labelText: 'LinkedIn URL')),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: loading? null : signupAgency, child: loading? const CircularProgressIndicator() : const Text('Sign up as Agency')),
            ],
          ),
        ),
      ),
    );
  }
}

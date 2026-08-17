import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_modelx/services/cloudinary_service.dart';
import '../ui/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/state_views.dart';

class AgencyEditProfilePage extends StatefulWidget {
  const AgencyEditProfilePage({super.key});

  @override
  State<AgencyEditProfilePage> createState() => _AgencyEditProfilePageState();
}

class _AgencyEditProfilePageState extends State<AgencyEditProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController agencyNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController specialtiesController = TextEditingController();
  final TextEditingController servicesController = TextEditingController();
  final TextEditingController instagramController = TextEditingController();
  final TextEditingController linkedinController = TextEditingController();

  String? logoUrl;
  String? coverUrl;
  String? _email;
  bool loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('agency').doc(user.uid).get();
    final d = doc.data() ?? {};
    agencyNameController.text = d['agencyName'] ?? '';
    phoneController.text = d['phone'] ?? '';
    addressController.text = d['address'] ?? '';
    websiteController.text = d['website'] ?? '';
    bioController.text = d['bio'] ?? '';
    specialtiesController.text = (d['specialties'] is List) ? (d['specialties'] as List).join(', ') : (d['specialties'] ?? '');
    servicesController.text = (d['services'] is List) ? (d['services'] as List).join(', ') : (d['services'] ?? '');
    instagramController.text = (d['socialLinks']?['instagram']) ?? '';
    linkedinController.text = (d['socialLinks']?['linkedin']) ?? '';
    logoUrl = d['logoUrl'];
    coverUrl = d['coverImageUrl'];
    _email = (d['email'] ?? '').toString();
    setState(() => loading = false);
  }

  Future<void> _pickAndUpload(bool isLogo) async {
    final picker = ImagePicker();
    final p = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (p == null) return;
    final file = File(p.path);
    final uid = _auth.currentUser!.uid;
    final uploaded = await CloudinaryService.uploadProfileImage(file, 'agency_$uid');
    if (uploaded == null) return;
    setState(() {
      if (isLogo) {
        logoUrl = uploaded;
      } else {
        coverUrl = uploaded;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final uid = _auth.currentUser!.uid;
    await FirebaseFirestore.instance.collection('agency').doc(uid).set({
      'agencyName': agencyNameController.text.trim(),
      'phone': phoneController.text.trim(),
      'address': addressController.text.trim(),
      'website': websiteController.text.trim(),
      'bio': bioController.text.trim(),
      'specialties': specialtiesController.text.trim().isEmpty ? null : specialtiesController.text.trim().split(',').map((s) => s.trim()).toList(),
      'services': servicesController.text.trim().isEmpty ? null : servicesController.text.trim().split(',').map((s) => s.trim()).toList(),
      'logoUrl': logoUrl,
      'coverImageUrl': coverUrl,
      'socialLinks': {
        'instagram': instagramController.text.trim(),
        'linkedin': linkedinController.text.trim(),
      },
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: LoadingState());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Agency Profile')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: agencyNameController,
                decoration: const InputDecoration(labelText: 'Agency Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 12),
              TextFormField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 12),
              TextFormField(controller: websiteController, decoration: const InputDecoration(labelText: 'Website')),
              if (_email != null && _email!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.paperRaised,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 18, color: AppColors.inkFaint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _email!,
                          style: const TextStyle(color: AppColors.inkFaint, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text('Not editable', style: TextStyle(color: AppColors.inkFaint, fontSize: 11)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Change Logo',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.photo_outlined,
                      onPressed: () => _pickAndUpload(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'Change Cover',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.photo_library_outlined,
                      onPressed: () => _pickAndUpload(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(controller: bioController, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 4),
              const SizedBox(height: 12),
              TextFormField(controller: specialtiesController, decoration: const InputDecoration(labelText: 'Specialties (comma separated)')),
              const SizedBox(height: 12),
              TextFormField(controller: servicesController, decoration: const InputDecoration(labelText: 'Services (comma separated)')),
              const SizedBox(height: 12),
              TextFormField(controller: instagramController, decoration: const InputDecoration(labelText: 'Instagram')),
              const SizedBox(height: 12),
              TextFormField(controller: linkedinController, decoration: const InputDecoration(labelText: 'LinkedIn')),
              const SizedBox(height: 24),
              AppButton(
                label: 'Save',
                expand: true,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

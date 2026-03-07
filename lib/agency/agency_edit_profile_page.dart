import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_modelx/services/cloudinary_service.dart';

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
  bool loading = true;

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
      if (isLogo) logoUrl = uploaded; else coverUrl = uploaded;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
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
    setState(() => loading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Agency Profile')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: agencyNameController, decoration: const InputDecoration(labelText: 'Agency Name'), validator: (v) => v==null||v.isEmpty? 'Required' : null,),
              TextFormField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              TextFormField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
              TextFormField(controller: websiteController, decoration: const InputDecoration(labelText: 'Website')),
              const SizedBox(height: 12),
              Row(children: [
                ElevatedButton.icon(onPressed: () => _pickAndUpload(true), icon: const Icon(Icons.photo), label: const Text('Change Logo')),
                const SizedBox(width: 12),
                ElevatedButton.icon(onPressed: () => _pickAndUpload(false), icon: const Icon(Icons.photo_library), label: const Text('Change Cover')),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: bioController, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 4),
              TextFormField(controller: specialtiesController, decoration: const InputDecoration(labelText: 'Specialties (comma separated)')),
              TextFormField(controller: servicesController, decoration: const InputDecoration(labelText: 'Services (comma separated)')),
              TextFormField(controller: instagramController, decoration: const InputDecoration(labelText: 'Instagram')),
              TextFormField(controller: linkedinController, decoration: const InputDecoration(labelText: 'LinkedIn')),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}

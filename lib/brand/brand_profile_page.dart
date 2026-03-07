import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/login_page.dart';


class BrandProfilePage extends StatefulWidget {
  const BrandProfilePage({super.key});

  @override
  State<BrandProfilePage> createState() => _BrandProfilePageState();
}

class _BrandProfilePageState extends State<BrandProfilePage> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  bool isEdit = false;
  bool loading = true;

  // Controllers
  final brandName = TextEditingController();
  final industry = TextEditingController();
  final about = TextEditingController();
  final website = TextEditingController();
  final instagram = TextEditingController();
  final linkedin = TextEditingController();
  final locations = TextEditingController();

  double completion = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBrand();
  }

  Future<void> _loadBrand() async {
    final doc = await FirebaseFirestore.instance
        .collection('brands')
        .doc(uid)
        .get();

    final d = doc.data()!;
    brandName.text = d['brandName'] ?? '';
    industry.text = d['industry'] ?? '';
    about.text = d['aboutBrand'] ?? '';
    website.text = d['website'] ?? '';
    instagram.text = d['socialLinks']?['instagram'] ?? '';
    linkedin.text = d['socialLinks']?['linkedin'] ?? '';
    locations.text = (d['locations'] ?? []).join(', ');

    _calculateCompletion(d);
    setState(() => loading = false);
  }

  void _calculateCompletion(Map<String, dynamic> d) {
    int done = 0;
    const total = 6;

    if ((d['brandName'] ?? '').toString().isNotEmpty) done++;
    if ((d['industry'] ?? '').toString().isNotEmpty) done++;
    if ((d['aboutBrand'] ?? '').toString().length > 50) done++;
    if ((d['website'] ?? '').toString().isNotEmpty) done++;
    if ((d['locations'] ?? []).isNotEmpty) done++;
    if ((d['projects'] ?? []).isNotEmpty) done++;

    completion = done / total;
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance
        .collection('brands')
        .doc(uid)
        .update({
      'brandName': brandName.text.trim(),
      'industry': industry.text.trim(),
      'aboutBrand': about.text.trim(),
      'website': website.text.trim(),
      'locations':
          locations.text.split(',').map((e) => e.trim()).toList(),
      'socialLinks': {
        'instagram': instagram.text.trim(),
        'linkedin': linkedin.text.trim(),
      },
      'profileCompleted': completion >= 0.8,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    setState(() => isEdit = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  Future<void> _signOut() async {
  await FirebaseAuth.instance.signOut();

  if (!mounted) return;

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (_) => false,
  );
}


  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brand Profile'),
        actions: [
          TextButton(
            onPressed: () => setState(() => isEdit = !isEdit),
            child: Text(
              isEdit ? 'Cancel' : 'Edit',
              style: const TextStyle(color: Colors.black),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: _signOut,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ================= PROGRESS =================
            Text(
              'Profile Completion ${(completion * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: completion,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),

            const SizedBox(height: 30),

            _section('Basic Identity'),
            _field('Brand Name', brandName),
            _field('Industry', industry),

            _section('Brand Details'),
            _field('About Brand', about, maxLines: 6),
            _field('Locations (comma separated)', locations),

            _section('Online Presence'),
            _field('Website', website),
            _field('Instagram', instagram),
            _field('LinkedIn', linkedin),

            _section('Past Projects'),
            _projectPlaceholder(),

            const SizedBox(height: 30),

            if (isEdit)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _field(String label, TextEditingController c,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        enabled: isEdit,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _projectPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Upload 3–20 campaign images\n(Coming next)',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }
}

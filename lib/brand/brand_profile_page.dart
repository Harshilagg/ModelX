import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/login_page.dart';
import '../ui/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';


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

    final d = doc.data() ?? <String, dynamic>{};
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
        body: LoadingState(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brand Profile'),
        actions: [
          TextButton(
            onPressed: () => setState(() => isEdit = !isEdit),
            child: Text(isEdit ? 'Cancel' : 'Edit'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ================= HERO =================
            Row(
              children: [
                ProfileAvatar(name: brandName.text, size: 72),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    brandName.text.isEmpty ? 'Your Brand' : brandName.text,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // ================= PROGRESS =================
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Completion ${(completion * 100).toInt()}%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: LinearProgressIndicator(
                      value: completion,
                      minHeight: 8,
                      color: AppColors.gold,
                      backgroundColor: AppColors.line,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            SectionHeader(title: 'Basic Identity'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: [
                  _field('Brand Name', brandName),
                  _field('Industry', industry, last: true),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            SectionHeader(title: 'Brand Details'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: [
                  _field('About Brand', about, maxLines: 6),
                  _field('Locations (comma separated)', locations, last: true),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            SectionHeader(title: 'Online Presence'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: [
                  _field('Website', website),
                  _field('Instagram', instagram),
                  _field('LinkedIn', linkedin, last: true),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            SectionHeader(title: 'Campaign Gallery'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: _projectPlaceholder(),
            ),

            const SizedBox(height: AppSpacing.xl),

            if (isEdit)
              AppButton(
                label: 'Save Changes',
                onPressed: _save,
                expand: true,
              ),
          ],
        ),
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _field(String label, TextEditingController c,
      {int maxLines = 1, bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        enabled: isEdit,
        decoration: InputDecoration(
          labelText: label,
        ),
      ),
    );
  }

  Widget _projectPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Text(
        'Campaign gallery — not yet available in the app.',
        style: TextStyle(color: AppColors.inkFaint),
      ),
    );
  }
}

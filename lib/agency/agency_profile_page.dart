import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../pages/login_page.dart';
import '../ui/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import 'agency_edit_profile_page.dart';

class AgencyProfilePage extends StatefulWidget {
  const AgencyProfilePage({super.key});

  @override
  State<AgencyProfilePage> createState() => _AgencyProfilePageState();
}

class _AgencyProfilePageState extends State<AgencyProfilePage> {
  final _auth = FirebaseAuth.instance;
  Map<String, dynamic> data = {};
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
    if (doc.exists && doc.data() != null) {
      setState(() {
        data = doc.data()!;
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  Future<void> _openEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgencyEditProfilePage()),
    );
    if (!mounted) return;
    setState(() => loading = true);
    _load();
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Widget _buildCover(BuildContext context) {
    final cover = (data['coverImageUrl'] ?? '').toString();
    final logo = (data['logoUrl'] ?? '').toString();
    final agencyName = (data['agencyName'] ?? '').toString();

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 160,
          width: double.infinity,
          color: AppColors.paperRaised,
          child: cover.isNotEmpty
              ? Image.network(cover, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const SizedBox())
              : const Center(child: Icon(Icons.photo_library_outlined, size: 44, color: AppColors.inkFaint)),
        ),
        Positioned(
          bottom: -40,
          child: Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.paper, shape: BoxShape.circle),
            child: ProfileAvatar(
              imageUrl: logo.isNotEmpty ? logo : null,
              name: agencyName,
              size: 80,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.line),
      ),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: LoadingState());
    }

    final agencyName = (data['agencyName'] ?? '').toString();
    final website = (data['website'] ?? '').toString();
    final bio = (data['bio'] ?? '').toString();
    final specialties = (data['specialties'] is List) ? List.from(data['specialties'] as List) : <dynamic>[];
    final services = (data['services'] is List) ? List.from(data['services'] as List) : <dynamic>[];
    final portfolio = (data['portfolioMedia'] is List) ? List.from(data['portfolioMedia'] as List) : <dynamic>[];
    final isFreshProfile = agencyName.isEmpty && bio.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(agencyName.isNotEmpty ? agencyName : 'Agency'),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openEdit,
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCover(context),
            const SizedBox(height: 56),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          agencyName.isNotEmpty ? agencyName : 'Unnamed Agency',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        if (data['isVerified'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.goldBg,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.verified, color: AppColors.gold, size: 15),
                                SizedBox(width: 5),
                                Text('Verified', style: TextStyle(color: AppColors.gold, fontSize: 12.5, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        if (website.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(website, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13.5)),
                        ]
                      ],
                    ),
                  ),

                  if (isFreshProfile) ...[
                    const SizedBox(height: 16),
                    EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Set up your agency profile',
                      message: 'Add your agency name, bio, specialties and contact details so brands and models can find you.',
                      actionLabel: 'Edit profile',
                      onAction: _openEdit,
                    ),
                  ],

                  const SizedBox(height: 12),
                  if (bio.isNotEmpty)
                    AppCard(
                      child: Text(bio, style: const TextStyle(height: 1.6, color: AppColors.ink, fontSize: 14.5)),
                    ),

                  const SizedBox(height: 20),
                  if (specialties.isNotEmpty) ...[
                    const SectionHeader(title: 'Specialties'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, i) => _chip(specialties[i].toString()),
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: specialties.length,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (services.isNotEmpty) ...[
                    const SectionHeader(title: 'Services'),
                    const SizedBox(height: 8),
                    Column(
                      children: services
                          .map((s) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.check_circle_outline, color: AppColors.inkFaint),
                                title: Text(s.toString(), style: const TextStyle(color: AppColors.ink)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (portfolio.isNotEmpty) ...[
                    const SectionHeader(title: 'Portfolio'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final item = portfolio[index];
                          final url = item is String ? item : (item is Map && item['url'] != null ? item['url'].toString() : '');
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: url.isNotEmpty
                                ? Image.network(
                                    url,
                                    width: 160,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(width: 160, height: 120, color: AppColors.paperRaised),
                                  )
                                : Container(width: 160, height: 120, color: AppColors.paperRaised),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: portfolio.length,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 4),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Contact'),
                        const SizedBox(height: 8),
                        if ((data['phone'] ?? '').toString().isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.phone_outlined, color: AppColors.inkFaint),
                            title: Text(data['phone'].toString(), style: const TextStyle(color: AppColors.ink)),
                            trailing: IconButton(
                              icon: const Icon(Icons.copy_outlined, color: AppColors.inkFaint),
                              onPressed: () => _copyToClipboard('Phone', data['phone'].toString()),
                            ),
                          ),
                        if ((data['email'] ?? '').toString().isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.email_outlined, color: AppColors.inkFaint),
                            title: Text(data['email'].toString(), style: const TextStyle(color: AppColors.ink)),
                            trailing: IconButton(
                              icon: const Icon(Icons.copy_outlined, color: AppColors.inkFaint),
                              onPressed: () => _copyToClipboard('Email', data['email'].toString()),
                            ),
                          ),
                        if ((data['address'] ?? '').toString().isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.location_on_outlined, color: AppColors.inkFaint),
                            title: Text(data['address'].toString(), style: const TextStyle(color: AppColors.ink)),
                          ),
                        if (website.isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.link, color: AppColors.inkFaint),
                            title: Text(website, style: const TextStyle(color: AppColors.ink)),
                            trailing: IconButton(
                              icon: const Icon(Icons.copy_outlined, color: AppColors.inkFaint),
                              onPressed: () => _copyToClipboard('Website', website),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Social'),
                        const SizedBox(height: 8),
                        if (data['socialLinks'] != null && (data['socialLinks'] is Map)) ...[
                          if ((data['socialLinks']['instagram'] ?? '').toString().isNotEmpty)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.inkFaint),
                              title: Text(data['socialLinks']['instagram'].toString(), style: const TextStyle(color: AppColors.ink)),
                              trailing: IconButton(
                                icon: const Icon(Icons.copy_outlined, color: AppColors.inkFaint),
                                onPressed: () => _copyToClipboard('Instagram', data['socialLinks']['instagram'].toString()),
                              ),
                            ),
                          if ((data['socialLinks']['linkedin'] ?? '').toString().isNotEmpty)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.business_outlined, color: AppColors.inkFaint),
                              title: Text(data['socialLinks']['linkedin'].toString(), style: const TextStyle(color: AppColors.ink)),
                              trailing: IconButton(
                                icon: const Icon(Icons.copy_outlined, color: AppColors.inkFaint),
                                onPressed: () => _copyToClipboard('LinkedIn', data['socialLinks']['linkedin'].toString()),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

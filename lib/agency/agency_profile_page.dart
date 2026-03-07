import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../pages/login_page.dart';

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

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Widget _buildCover(BuildContext context) {
    final cover = (data['coverImageUrl'] ?? '').toString();
    final logo = (data['logoUrl'] ?? '').toString();

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 160,
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: cover.isNotEmpty
              ? Image.network(cover, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const SizedBox())
              : Center(child: Icon(Icons.photo_library, size: 44, color: Colors.grey[400])),
        ),
        Positioned(
          bottom: -40,
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: ClipOval(
              child: logo.isNotEmpty
                  ? Image.network(logo, width: 76, height: 76, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())
                  : Icon(Icons.business, size: 40, color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final agencyName = (data['agencyName'] ?? '').toString();
    final website = (data['website'] ?? '').toString();
    final bio = (data['bio'] ?? '').toString();
    final specialties = (data['specialties'] is List) ? List.from(data['specialties'] as List) : <dynamic>[];
    final services = (data['services'] is List) ? List.from(data['services'] as List) : <dynamic>[];
    final portfolio = (data['portfolioMedia'] is List) ? List.from(data['portfolioMedia'] as List) : <dynamic>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(agencyName.isNotEmpty ? agencyName : 'Agency'),
        actions: [
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
                        Text(agencyName.isNotEmpty ? agencyName : 'Unnamed Agency', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        if (data['isVerified'] == true)
                          Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.check_circle, color: Colors.green, size: 16), SizedBox(width: 6), Text('Verified', style: TextStyle(color: Colors.green))]),
                        if (website.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(website, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                        ]
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  if (bio.isNotEmpty)
                    Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(12), child: Text(bio, style: const TextStyle(height: 1.6)))),

                  const SizedBox(height: 12),
                  if (specialties.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Specialties', style: TextStyle(fontWeight: FontWeight.w700))),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, i) => Chip(label: Text(specialties[i].toString())),
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: specialties.length,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (services.isNotEmpty) ...[
                    const Text('Services', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Column(children: services.map((s) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_circle_outline), title: Text(s.toString()))).toList()),
                    const SizedBox(height: 12),
                  ],

                  if (portfolio.isNotEmpty) ...[
                    const Text('Portfolio', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final item = portfolio[index];
                          final url = item is String ? item : (item is Map && item['url'] != null ? item['url'].toString() : '');
                          return ClipRRect(borderRadius: BorderRadius.circular(8), child: url.isNotEmpty ? Image.network(url, width: 160, height: 120, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[200])) : Container(width: 160, height: 120, color: Colors.grey[200]));
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: portfolio.length,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 6),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Contact', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if ((data['phone'] ?? '').toString().isNotEmpty)
                          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.phone), title: Text(data['phone'].toString()), trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () => _copyToClipboard('Phone', data['phone'].toString()))),
                        if ((data['email'] ?? '').toString().isNotEmpty)
                          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.email), title: Text(data['email'].toString()), trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () => _copyToClipboard('Email', data['email'].toString()))),
                        if ((data['address'] ?? '').toString().isNotEmpty)
                          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.location_on), title: Text(data['address'].toString())),
                        if (website.isNotEmpty)
                          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.link), title: Text(website), trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () => _copyToClipboard('Website', website))),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Social', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if (data['socialLinks'] != null && (data['socialLinks'] is Map)) ...[
                          if ((data['socialLinks']['instagram'] ?? '').toString().isNotEmpty)
                            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.camera_alt), title: Text(data['socialLinks']['instagram'].toString()), trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () => _copyToClipboard('Instagram', data['socialLinks']['instagram'].toString()))),
                          if ((data['socialLinks']['linkedin'] ?? '').toString().isNotEmpty)
                            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.business), title: Text(data['socialLinks']['linkedin'].toString()), trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () => _copyToClipboard('LinkedIn', data['socialLinks']['linkedin'].toString()))),
                        ],
                      ]),
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

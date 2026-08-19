import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import '../ui/app_theme.dart';
import '../widgets/app_action_bar.dart';
import '../widgets/app_card.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/app_stat_row.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';

class UserProfilePage extends StatefulWidget {
  final String uid;
  const UserProfilePage({super.key, required this.uid});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}



class _UserProfilePageState extends State<UserProfilePage> {
  final currentUser = FirebaseAuth.instance.currentUser!;

  Map<String, dynamic>? userData;
  bool loading = true;
  bool isRequestSent = false;
  bool isConnected = false;
  bool isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }
  Future<void> _loadUser() async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(widget.uid)
      .get();

  if (!doc.exists) return;

  userData = doc.data()!;
  isOwnProfile = widget.uid == currentUser.uid;

  if (!isOwnProfile) {
    await _checkConnectionStatus();
  }

  setState(() => loading = false);
}


  Future<void> _checkConnectionStatus() async {
    final otherUserId = widget.uid;

    final me = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final connections = me.data()?['connections'] ?? [];
    if (connections.contains(otherUserId)) {
      setState(() => isConnected = true);
      return;
    }

    final req = await FirebaseFirestore.instance
        .collection('connection_requests')
        .where('senderId', isEqualTo: currentUser.uid)
        .where('receiverId', isEqualTo: otherUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (req.docs.isNotEmpty) {
      setState(() => isRequestSent = true);
    }
  }

  Future<void> sendConnectionRequest() async {
    final me = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    await FirebaseFirestore.instance.collection('connection_requests').add({
      'senderId': currentUser.uid,
      'receiverId': widget.uid,
      'senderUsername': me.data()?['username'] ?? '',
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() => isRequestSent = true);
  }

  // -------------------- Helper Widgets --------------------

  /// Formats a stat value for [AppStatRow]/[_info]: trims, appends an
  /// optional unit suffix, and falls back to an em dash when empty.
  String _statValue(dynamic raw, [String suffix = '']) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return '—';
    return suffix.isEmpty ? value : '$value $suffix';
  }

  Widget _sectionCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }

  Widget _info(String label, dynamic value) {
    final v = (value ?? '').toString();
    if (v.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: 6),
          Text(
            v,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String title, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: AppColors.inkSoft, height: 1.6, fontSize: 14)),
        ],
      );

  Widget _loadingSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSkeleton.circle(84),
              const SizedBox(width: 18),
              Expanded(child: AppSkeleton.text(lines: 2)),
            ],
          ),
          const SizedBox(height: 24),
          const AppSkeleton(width: 220, height: 40),
          const SizedBox(height: 28),
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 3 ? 0 : 10),
                  child: const AppSkeleton(height: 52),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          AppSkeleton.card(height: 90),
          const SizedBox(height: 16),
          AppSkeleton.card(height: 140),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String title) {
    return AppBar(
      backgroundColor: AppColors.backstage,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.onBackstage),
      titleTextStyle: const TextStyle(color: AppColors.onBackstage, fontWeight: FontWeight.w700, fontSize: 18),
      title: Text(title),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading || userData == null) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: _buildAppBar('Profile'),
        body: _loadingSkeleton(),
      );
    }

  final u = userData!;
  final fullName = (u['fullName'] ?? '').toString();
  final username = (u['username'] ?? '').toString();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: _buildAppBar(fullName.isNotEmpty ? fullName : 'Profile'),
      bottomNavigationBar: isOwnProfile ? null : _actionBar(u),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HERO (backstage) =================
            Container(
              width: double.infinity,
              color: AppColors.backstage,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatar(
                    imageUrl: (u['profileImage'] ?? '').toString().isNotEmpty ? u['profileImage'] : null,
                    name: fullName,
                    size: 84,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    fullName.isEmpty ? 'Profile' : fullName,
                    style: AppTypography.displayAccent(fontSize: 44, color: AppColors.onBackstage),
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '@$username',
                      style: const TextStyle(color: AppColors.onBackstageSoft, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),

            // ================= PRIMARY STATS (anchored to hero) =================
            AppStatRow(
              stats: [
                AppStat('Height', _statValue(u['height'], (u['heightUnit'] ?? '').toString())),
                AppStat('Measurements', _statValue(u['measurements'])),
                AppStat('Weight', _statValue(u['weight'])),
                AppStat('Availability', _statValue(u['availability'])),
              ],
            ),

            // ================= ABOUT =================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: SectionHeader(title: "About"),
            ),
            _sectionCard(
              child: Text(
                (u['bio'] ?? '').toString().isEmpty ? 'No bio available' : u['bio'].toString(),
                style: const TextStyle(color: AppColors.inkSoft, height: 1.6, fontSize: 15),
              ),
            ),

            // ================= BASICS =================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: SectionHeader(title: "Basics"),
            ),
            _sectionCard(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _info("Age", u['age']),
                  _info("Gender", u['gender']),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= APPEARANCE =================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SectionHeader(title: "Appearance"),
            ),
            _sectionCard(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _info("Skin Tone", u['skinColor']),
                  _info("Eye Color", u['eyeColor']),
                  _info("Hair Color", u['hairColor']),
                  _info("Tattoos", u['tattoos']),
                  _info("Piercing", u['piercing']),
                ],
              ),
            ),

            // ================= PROFESSIONAL =================
            if ((u['skills'] ?? '').toString().isNotEmpty ||
                (u['experience'] ?? '').toString().isNotEmpty ||
                (u['preferredWork'] ?? '').toString().isNotEmpty ||
                (u['availability'] ?? '').toString().isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: SectionHeader(title: "Professional"),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if ((u['skills'] ?? '').toString().isNotEmpty) ...[
                      _sectionCard(child: _bullet("Skills", u['skills'].toString())),
                      const SizedBox(height: 20),
                    ],
                    if ((u['experience'] ?? '').toString().isNotEmpty) ...[
                      _sectionCard(child: _bullet("Experience", u['experience'].toString())),
                      const SizedBox(height: 20),
                    ],
                    if ((u['preferredWork'] ?? '').toString().isNotEmpty) ...[
                      _sectionCard(child: _bullet("Preferred Work", u['preferredWork'].toString())),
                      const SizedBox(height: 20),
                    ],
                    if ((u['availability'] ?? '').toString().isNotEmpty)
                      _sectionCard(child: _bullet("Availability", u['availability'].toString())),
                  ],
                ),
              ),
            ],

            // ================= CAREER HISTORY =================
            if ((u['projects'] is List && (u['projects'] as List).isNotEmpty) ||
                (u['agencies'] is List && (u['agencies'] as List).isNotEmpty)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: SectionHeader(title: "Career History"),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if (u['projects'] is List && (u['projects'] as List).isNotEmpty) ...[
                      _sectionCard(child: _bullet("Projects", (u['projects'] as List).join('\n'))),
                      const SizedBox(height: 20),
                    ],
                    if (u['agencies'] is List && (u['agencies'] as List).isNotEmpty)
                      _sectionCard(child: _bullet("Agency Associations", (u['agencies'] as List).join('\n'))),
                  ],
                ),
              ),
            ],

            // ================= PORTFOLIO =================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: SectionHeader(title: "Portfolio"),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('portfolio')
                    .where('uid', isEqualTo: u['uid'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: LoadingState(),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const EmptyState(
                      icon: Icons.photo_library_outlined,
                      title: "No portfolio uploaded yet",
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.9,
                    ),
                    itemBuilder: (context, index) {
                      final media = docs[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Image.network(
                          media['mediaUrl'],
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ================= ACTION BAR =================

  Widget _actionBar(Map<String, dynamic> user) {
    if (isConnected) {
      return AppActionBar(
        primaryLabel: 'Message',
        primaryIcon: Icons.chat_bubble_outline,
        onPrimary: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                peerId: user['uid'],
                peerName: user['fullName'] ?? '',
                peerImage: user['profileImage'] ?? '',
              ),
            ),
          );
        },
      );
    }

    if (isRequestSent) {
      return const AppActionBar(
        primaryLabel: 'Request Sent',
        onPrimary: null,
      );
    }

    return AppActionBar(
      primaryLabel: 'Follow',
      primaryIcon: Icons.person_add_alt,
      onPrimary: sendConnectionRequest,
    );
  }
}

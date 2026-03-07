import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

const textPrimary = Color(0xFF111827);
const textSecondary = Color(0xFF6B7280);
const cardColor = Colors.white;

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

  @override
  Widget build(BuildContext context) {
    if (loading || userData == null) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  final u = userData!;

    return Scaffold(
      appBar: AppBar(
        title: Text(u['fullName'] ?? 'Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HERO =================
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: u['profileImage'] != null
                        ? NetworkImage(u['profileImage'])
                        : const AssetImage('assets/avatar.jpg')
                            as ImageProvider,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    u['fullName'] ?? '',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (u['username'] != null && u['username'].toString().isNotEmpty)
                    Text(
                      '@${u['username']}',
                      style: const TextStyle(color: textSecondary),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (!isOwnProfile) Center(child: _actionButton(u)),

            const SizedBox(height: 24),

            // ================= ABOUT =================
            _sectionTitle("About"),
            _card(Text(
              u['bio'] ?? 'No bio available',
              style: const TextStyle(color: textSecondary, height: 1.6),
            )),

            // ================= PROFILE OVERVIEW =================
            _sectionTitle("Profile Overview"),
            _card(Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _info("Age", u['age']),
                _info("Gender", u['gender']),
                _info("Height", "${u['height'] ?? ''} ${u['heightUnit'] ?? ''}"),
                _info("Weight", u['weight']),
                _info("Measurements", u['measurements']),
                _info("Skin Tone", u['skinColor']),
                _info("Eye Color", u['eyeColor']),
                _info("Hair Color", u['hairColor']),
                _info("Tattoos", u['tattoos']),
                _info("Piercing", u['piercing']),
              ],
            )),

            // ================= PROFESSIONAL =================
            _sectionTitle("Professional"),
            if ((u['skills'] ?? '').toString().isNotEmpty)
              _card(_bullet("Skills", u['skills'])),
            if ((u['experience'] ?? '').toString().isNotEmpty)
              _card(_bullet("Experience", u['experience'])),
            if ((u['preferredWork'] ?? '').toString().isNotEmpty)
              _card(_bullet("Preferred Work", u['preferredWork'])),
            if ((u['availability'] ?? '').toString().isNotEmpty)
              _card(_bullet("Availability", u['availability'])),

            // ================= PROJECTS =================
            if (u['projects'] != null && (u['projects'] as List).isNotEmpty) ...[
              _sectionTitle("Projects"),
              _card(Text(
                (u['projects'] as List).join('\n'),
                style: const TextStyle(color: textSecondary),
              )),
            ],

            // ================= AGENCIES =================
            if (u['agencies'] != null && (u['agencies'] as List).isNotEmpty) ...[
              _sectionTitle("Agency Associations"),
              _card(Text(
                (u['agencies'] as List).join('\n'),
                style: const TextStyle(color: textSecondary),
              )),
            ],

            // ================= PORTFOLIO =================
            _sectionTitle("Portfolio"),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('portfolio')
                  .where('uid', isEqualTo: u['uid'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Text(
                    'No portfolio uploaded yet.',
                    style: TextStyle(color: textSecondary),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (context, index) {
                    final media = docs[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        media['mediaUrl'],
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );

  Widget _info(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: textSecondary)),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _bullet(String title, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(color: textSecondary, height: 1.6)),
        ],
      );

  Widget _actionButton(Map<String, dynamic> user) {
    if (isConnected) {
      return ElevatedButton(
        child: const Text('Message'),
        onPressed: () {
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
      return ElevatedButton(
        onPressed: null,
        child: const Text('Request Sent'),
      );
    }

    return ElevatedButton(
      onPressed: sendConnectionRequest,
      child: const Text('Follow'),
    );
  }
}

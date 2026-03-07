import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/user_profile_page.dart';
import '../widgets/portfolio_carousel.dart';

class ModelApplicationCard extends StatelessWidget {
  final String gigId;
  final String modelId;
  final String status;

  const ModelApplicationCard({
    super.key,
    required this.gigId,
    required this.modelId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(modelId);

    final portfolioRef = FirebaseFirestore.instance
        .collection('portfolio')
        .where('uid', isEqualTo: modelId)
        .limit(6);

    return StreamBuilder<DocumentSnapshot>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const SizedBox();
        }

        final user = userSnap.data!.data() as Map<String, dynamic>;
        final followersCount =
            (user['followers'] is List) ? user['followers'].length : 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ================= IMAGE SECTION =================
                SizedBox(
                  width: 115,
                  height: 160,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: portfolioRef.snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData || snap.data!.docs.isEmpty) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image),
                        );
                      }

                      final images = snap.data!.docs
                          .map((e) => e.data() as Map<String, dynamic>)
                          .where((d) =>
                              d['mediaUrl'] != null &&
                              d['mediaUrl'].toString().isNotEmpty &&
                              d['mediaUrl'].toString().startsWith('http'))
                          .map((d) => d['mediaUrl'].toString())
                          .toList();

                      if (images.isEmpty) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image),
                        );
                      }

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: PortfolioCarousel(
                          key: ValueKey(images.first), // IMPORTANT FIX
                          images: images,
                        ),
                      );
                    },
                  ),
                ),


                const SizedBox(width: 12),

                // ================= INFO SECTION =================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // NAME
                      Text(
                        user['fullName'] ?? 'Unnamed',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '${user['preferredWork'] ?? '—'} • ${user['availability'] ?? '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '$followersCount followers',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ACTION BUTTONS WRAP (FIX OVERFLOW)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _actionButton(
                            label: status == 'shortlisted'
                                ? 'Shortlisted'
                                : 'Shortlist',
                            color: Colors.green,
                            onTap: status == 'shortlisted'
                                ? null
                                : () => _updateStatus(context, 'shortlisted'),
                          ),
                          _actionButton(
                            label: 'Reject',
                            color: Colors.red,
                            onTap: () => _updateStatus(context, 'rejected'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // PROFILE + SAVE ROW
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.person_outline),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UserProfilePage(uid: modelId),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite_border),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.grey.shade300
              : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null ? Colors.grey : color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    String newStatus,
  ) async {
    await FirebaseFirestore.instance
        .collection('gigs')
        .doc(gigId)
        .collection('applications')
        .doc(modelId)
        .update({'status': newStatus});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus == 'shortlisted'
              ? 'Added to shortlist'
              : 'Applicant rejected',
        ),
      ),
    );
  }
}

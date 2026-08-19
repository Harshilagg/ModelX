import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../ui/app_theme.dart';
import '../../pages/user_profile_page.dart';
import '../../pages/chat_page.dart';
import '../../services/chat_service.dart';
import '../../widgets/portfolio_carousel.dart';
import '../../widgets/status_pill.dart';

/// The casting equivalent of `lib/widgets/model_application_card.dart` —
/// same live-fetched-profile-and-portfolio treatment (photo carousel, real
/// name, shortlist/connect/message/reject/view-profile actions), applied to
/// `castings/{castingId}/applicants/{modelId}` instead of
/// `gigs/{gigId}/applications/{modelId}`. Exists as its own widget rather
/// than a shared one because the two collections differ in path shape and
/// in which `ChatService` method starts the conversation.
class CastingApplicantCard extends StatelessWidget {
  final String castingId;
  final String modelId;
  final String status;

  const CastingApplicantCard({
    super.key,
    required this.castingId,
    required this.modelId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(modelId);
    final portfolioRef = FirebaseFirestore.instance.collection('portfolio').where('uid', isEqualTo: modelId).limit(6);

    return StreamBuilder<DocumentSnapshot>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const SizedBox();
        }

        final user = userSnap.data!.data() as Map<String, dynamic>;
        final followersCount = (user['followers'] is List) ? user['followers'].length : 0;

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadows.card,
          ),
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
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(color: AppColors.paperRaised, child: const Icon(Icons.image_outlined, color: AppColors.inkFaint)),
                      );
                    }

                    final images = snap.data!.docs
                        .map((e) => e.data() as Map<String, dynamic>)
                        .where((d) => d['mediaUrl'] != null && d['mediaUrl'].toString().isNotEmpty && d['mediaUrl'].toString().startsWith('http'))
                        .map((d) => d['mediaUrl'].toString())
                        .toList();

                    if (images.isEmpty) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(color: AppColors.paperRaised, child: const Icon(Icons.image_outlined, color: AppColors.inkFaint)),
                      );
                    }

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: PortfolioCarousel(key: ValueKey(images.first), images: images),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            user['fullName'] ?? 'Unnamed',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyEmphasized.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        StatusPill(status: status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user['preferredWork'] ?? '—'} • ${user['availability'] ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: 4),
                    Text('$followersCount followers', style: AppTypography.metadata),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (status == 'pending' || status == 'applied')
                          _actionButton(label: 'Shortlist', color: AppColors.gold, onTap: () => _updateStatus(context, 'SHORTLISTED'))
                        else if (status == 'SHORTLISTED' || status == 'shortlisted')
                          _actionButton(
                            label: 'Connect',
                            color: AppColors.gold,
                            onTap: () async {
                              final current = FirebaseAuth.instance.currentUser;
                              if (current == null) return;
                              final agencyId = current.uid;
                              final chatService = ChatService();
                              try {
                                final chatId = await chatService.createChat(castingId, modelId, agencyId);
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatPage(
                                        peerId: modelId,
                                        peerName: user['fullName'] ?? '',
                                        peerImage: user['profileImage'] ?? '',
                                        chatId: chatId,
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) showAppToast(context, 'Failed to connect: $e', isError: true);
                              }
                            },
                          )
                        else if (status == 'NEGOTIATING')
                          _actionButton(
                            label: 'Message',
                            color: AppColors.ink,
                            onTap: () {
                              final list = [FirebaseAuth.instance.currentUser!.uid, modelId]..sort();
                              final chatId = list.join('--');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    peerId: modelId,
                                    peerName: user['fullName'] ?? '',
                                    peerImage: user['profileImage'] ?? '',
                                    chatId: chatId,
                                  ),
                                ),
                              );
                            },
                          ),
                        if (status != 'rejected')
                          _actionButton(label: 'Reject', color: AppColors.select, onTap: () => _updateStatus(context, 'rejected')),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.person_outline, color: AppColors.inkSoft),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(uid: modelId)));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButton({required String label, required Color color, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.paperRaised : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label, style: TextStyle(color: onTap == null ? AppColors.inkFaint : color, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    await FirebaseFirestore.instance.collection('castings').doc(castingId).collection('applicants').doc(modelId).update({'status': newStatus});

    if (!context.mounted) return;
    showAppToast(context, newStatus.toUpperCase() == 'SHORTLISTED' ? 'Added to shortlist' : 'Applicant rejected');
  }
}

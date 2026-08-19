import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ui/app_theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/state_views.dart';
import '../widgets/app_skeleton.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final currentUser = FirebaseAuth.instance.currentUser!;

  Future<void> _respondToRequest(
      String docId,
      String senderId,
      bool accepted,
    ) async {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final requestRef =
          firestore.collection('connection_requests').doc(docId);
      final meRef = firestore.collection('users').doc(currentUser.uid);
      final senderRef = firestore.collection('users').doc(senderId);

      // Update request status
      batch.update(requestRef, {
        'status': accepted ? 'accepted' : 'rejected',
      });

      if (accepted) {

        // ADD CONNECTIONS (both sides)
        batch.update(meRef, {
          'connections': FieldValue.arrayUnion([senderId]),
          'followers': FieldValue.arrayUnion([senderId]),
          'following': FieldValue.arrayUnion([senderId]),
        });

        batch.update(senderRef, {
          'connections': FieldValue.arrayUnion([currentUser.uid]),
          'followers': FieldValue.arrayUnion([currentUser.uid]),
          'following': FieldValue.arrayUnion([currentUser.uid]),
        });
      }

      await batch.commit();
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('connection_requests')
            .where('receiverId', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorStateView(message: 'Could not load notifications.');
          }

          if (!snapshot.hasData) {
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (_, __) => AppSkeleton.listTile(),
            );
          }

          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No new notifications',
              message: 'Connection requests will show up here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.line,
              indent: 84,
              endIndent: AppSpacing.md,
            ),
            itemBuilder: (_, index) {
              final req = requests[index];
              final senderId = req['senderId'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
                builder: (context, senderSnap) {
                  if (!senderSnap.hasData) {
                    return const SizedBox(height: 0);
                  }

                  final sender = senderSnap.data!;
                  final senderData = sender.data() as Map<String, dynamic>? ?? {};
                  final name = senderData['username'] ?? senderData['fullName'] ?? 'User';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    leading: ProfileAvatar(
                      imageUrl: senderData['profileImage'],
                      name: senderData['fullName'] ?? senderData['username'],
                      size: 52,
                    ),
                    title: Text(
                      '@$name',
                      style: AppTypography.bodyEmphasized.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Wants to follow you', style: AppTypography.caption),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RoundIconButton(
                          icon: Icons.check_rounded,
                          color: AppColors.success,
                          onPressed: () => _respondToRequest(req.id, senderId, true),
                        ),
                        const SizedBox(width: 8),
                        _RoundIconButton(
                          icon: Icons.close_rounded,
                          color: AppColors.select,
                          onPressed: () => _respondToRequest(req.id, senderId, false),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _RoundIconButton({required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: AppIconSize.sm, color: color),
        ),
      ),
    );
  }
}

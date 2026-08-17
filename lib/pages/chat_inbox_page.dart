import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import '../ui/app_theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/state_views.dart';

class ChatInboxPage extends StatelessWidget {
  const ChatInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Read the current user fresh on every build rather than capturing it
    // once at construction — avoids a null force-unwrap if this is built
    // before auth state settles, and avoids querying a stale uid if the
    // signed-in user ever changes without this widget being recreated.
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        appBar: null,
        body: Center(child: Text('Please sign in to view messages')),
      );
    }

    final inboxRef = FirebaseFirestore.instance
    .collection('user_chats')
    .doc(currentUser.uid)
    .collection('chats')
    .orderBy('lastTimestamp', descending: true);



    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<QuerySnapshot>(
        stream: inboxRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorStateView(message: 'Failed to load inbox');
          }

          if (!snapshot.hasData) {
            return const LoadingState();
          }

          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No messages yet',
              message: 'Conversations you start will show up here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.line,
              indent: 84,
              endIndent: AppSpacing.md,
            ),
            itemBuilder: (_, index) {
              final data = chats[index].data() as Map<String, dynamic>;

              final peerId = data['peerId'] ?? '';
              final peerName = data['peerName'] ?? 'User';
              final peerUsername = data['peerUsername'] ?? '';
              final peerImage = data['peerImage'] ?? '';
              final lastMessage = data['lastMessage'] ?? '';
              final unreadCount = data['unreadCount'] ?? 0;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                leading: ProfileAvatar(imageUrl: peerImage, name: peerName, size: 52),
                title: Text(
                  peerUsername.toString().isNotEmpty
                      ? '@$peerUsername'
                      : peerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    lastMessage.toString().isNotEmpty ? lastMessage : 'No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.inkFaint, fontSize: 13.5),
                  ),
                ),
                trailing: unreadCount > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.select,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        constraints: const BoxConstraints(minWidth: 20),
                        child: Text(
                          unreadCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.paper,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : null,
                onTap: () async {
                  await chats[index].reference.update({
                    'unreadCount': 0,
                  });

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        peerId: peerId,
                        peerName: peerName,
                        peerImage: peerImage,
                        chatId: chats[index].id,
                      ),
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

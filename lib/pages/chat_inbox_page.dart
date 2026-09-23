import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import '../ui/board_theme.dart';
import '../widgets/board_widgets.dart';
import '../widgets/state_views.dart';
import '../widgets/app_skeleton.dart';

/// Messages (style board 7b).
///
/// Deliberately the quietest screen in the app: ink and paper only, no
/// section accent, no tiles, no flap. Every other board screen is
/// competing for attention; a conversation list should not. Rows carry
/// exactly what the inbox documents hold — a name (or a "?" when the
/// peer never set one), and the last message.
class ChatInboxPage extends StatelessWidget {
  const ChatInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Read the current user fresh on every build rather than capturing
    // it once at construction — avoids a null force-unwrap if this is
    // built before auth state settles, and avoids querying a stale uid
    // if the signed-in user changes without this widget being recreated.
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: BoardColors.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            Expanded(
              child: currentUser == null
                  ? const EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Not signed in',
                      message: 'Sign in to see your messages.',
                    )
                  : _list(currentUser.uid),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(
              Icons.arrow_back,
              size: 18,
              color: BoardColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Messages',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BoardType.display(
                fontSize: 26,
                height: 1,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(String uid) {
    final inboxRef = FirebaseFirestore.instance
        .collection('user_chats')
        .doc(uid)
        .collection('chats')
        .orderBy('lastTimestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: inboxRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ErrorStateView(message: 'Failed to load inbox');
        }

        if (!snapshot.hasData) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, __) => AppSkeleton.listTile(),
          );
        }

        final chats = snapshot.data!.docs;

        if (chats.isEmpty) {
          return const EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No messages yet',
            message: 'Conversations you start show up here.',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: chats.length,
          itemBuilder: (_, index) {
            final doc = chats[index];
            final data = doc.data() as Map<String, dynamic>;

            final peerId = (data['peerId'] ?? '').toString();
            final peerName = (data['peerName'] ?? '').toString().trim();
            final peerUsername = (data['peerUsername'] ?? '').toString().trim();
            final peerImage = (data['peerImage'] ?? '').toString();
            final lastMessage = (data['lastMessage'] ?? '').toString();
            final unreadCount = (data['unreadCount'] is int)
                ? data['unreadCount'] as int
                : 0;

            // Some inbox documents were written before names were
            // captured. Rather than printing "User" over and over, an
            // unnamed peer keeps the bare "?" mark and gives its whole
            // row to the message.
            final displayName = peerName.isNotEmpty
                ? peerName
                : (peerUsername.isNotEmpty ? '@$peerUsername' : '');

            return _ChatRow(
              name: displayName,
              imageUrl: peerImage,
              lastMessage: lastMessage,
              unread: unreadCount,
              isLast: index == chats.length - 1,
              onTap: () async {
                await doc.reference.update({'unreadCount': 0});
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      peerId: peerId,
                      peerName: peerName,
                      peerImage: peerImage,
                      chatId: doc.id,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ChatRow extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String lastMessage;
  final int unread;
  final bool isLast;
  final VoidCallback onTap;

  const _ChatRow({
    required this.name,
    required this.imageUrl,
    required this.lastMessage,
    required this.unread,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasName = name.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: BoardColors.inkLine),
            bottom: isLast
                ? BorderSide(color: BoardColors.inkLine)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: ClipOval(
                child: imageUrl.isNotEmpty
                    ? BoardMedia(url: imageUrl)
                    : Container(
                        color: BoardColors.ink,
                        alignment: Alignment.center,
                        child: Text(
                          hasName ? name[0].toUpperCase() : '?',
                          style: BoardType.mono(
                            fontSize: 15,
                            color: BoardColors.onInk,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: hasName
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.title(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.body(
                            fontSize: 12.5,
                            height: 1.3,
                            color: BoardColors.inkSoft,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BoardType.body(
                        fontSize: 12.5,
                        height: 1.3,
                        color: BoardColors.inkSoft,
                      ),
                    ),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: BoardColors.ink,
                  borderRadius: BorderRadius.circular(BoardRadius.tile),
                ),
                child: Text(
                  unread > 99 ? '99+' : unread.toString(),
                  style: BoardType.mono(
                    fontSize: 9.5,
                    color: BoardColors.onInk,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

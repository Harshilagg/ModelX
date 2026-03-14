import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../pages/chat_page.dart';

class ConversationListPage extends StatelessWidget {
  const ConversationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
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
          if (snapshot.hasError) return const Center(child: Text('Failed to load conversations'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No conversations yet'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final chatId = docs[index].id;
              final peerId = data['peerId'] ?? '';
              final peerName = data['peerName'] ?? 'User';
              final peerImage = data['peerImage'] ?? '';
              final lastMessage = data['lastMessage'] ?? '';
              final unreadCount = (data['unreadCount'] ?? 0) as int;

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: peerImage.isNotEmpty ? NetworkImage(peerImage) : const AssetImage('assets/avatar.jpg') as ImageProvider,
                ),
                title: Text(peerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: unreadCount > 0
                    ? CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))
                    : null,
                onTap: () async {
                  // mark unread as read in inbox
                  await docs[index].reference.update({'unreadCount': 0});
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatPage(peerId: peerId, peerName: peerName, peerImage: peerImage, chatId: chatId)),
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

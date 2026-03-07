import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class ChatInboxPage extends StatelessWidget {
  ChatInboxPage({super.key});

  final User currentUser = FirebaseAuth.instance.currentUser!;

  @override
  Widget build(BuildContext context) {
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
            return Center(
              child: Text(
                'Failed to load inbox',
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!.docs;
          if (chats.isEmpty) {
            return const Center(child: Text('No conversations yet'));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (_, index) {
              final data = chats[index].data() as Map<String, dynamic>;

              final peerId = data['peerId'] ?? '';
              final peerName = data['peerName'] ?? 'User';
              final peerUsername = data['peerUsername'] ?? '';
              final peerImage = data['peerImage'] ?? '';
              final lastMessage = data['lastMessage'] ?? '';
              final unreadCount = data['unreadCount'] ?? 0;

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: peerImage.isNotEmpty
                      ? NetworkImage(peerImage)
                      : const AssetImage('assets/avatar.jpg')
                          as ImageProvider,
                ),
                title: Text(
                  peerUsername.toString().isNotEmpty
                      ? '@$peerUsername'
                      : peerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: unreadCount > 0
                    ? CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.red,
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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

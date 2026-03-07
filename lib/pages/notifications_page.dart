import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('connection_requests')
            .where('receiverId', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return const Center(child: Text('No new connection requests.'));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (_, index) {
              final req = requests[index];
              final senderId = req['senderId'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
                builder: (context, senderSnap) {
                  if (!senderSnap.hasData) return const SizedBox.shrink();

                  final sender = senderSnap.data!;
                  final senderData = sender.data() as Map<String, dynamic>? ?? {};

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: senderData['profileImage'] != null
                          ? NetworkImage(senderData['profileImage'])
                          : null,
                    ),
                    subtitle: Text(
                      '@${senderData['username'] ?? senderData['fullName'] ?? 'User'} wants to follow you',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => _respondToRequest(req.id, senderId, true),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
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

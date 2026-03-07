import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart'; // Make sure ChatPage accepts peerId, peerName, peerImage

class ConnectedUsersPage extends StatelessWidget {
  const ConnectedUsersPage({super.key});

  Future<List<Map<String, dynamic>>> _fetchConnections() async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    final data = doc.data() ?? {};
    final connections = data['connections'] ?? [];

    List<Map<String, dynamic>> connectedUsers = [];
    for (var uid in connections) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      userData['uid'] = uid; // include uid for chat
      connectedUsers.add(userData);
    }
    return connectedUsers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Connections'), backgroundColor: Colors.blue),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchConnections(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final connections = snapshot.data!;
          if (connections.isEmpty) return const Center(child: Text('No connections yet.'));
          return ListView.builder(
            itemCount: connections.length,
            itemBuilder: (context, index) {
              final user = connections[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user['profileImage'] != null ? NetworkImage(user['profileImage']) : null,
                ),
                title: Text(user['fullName'] ?? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'),
                subtitle: Text(user['bio'] ?? ''),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        peerId: user['uid'],
                        peerName: user['fullName'] ?? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
                        peerImage: user['profileImage'] ?? '',
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_page.dart';

class NetworkPage extends StatefulWidget {
  const NetworkPage({super.key});

  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  final currentUser = FirebaseAuth.instance.currentUser!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final connections = userData['connections'] ?? [];

          if (connections.isEmpty) {
            return const Center(child: Text('No connections yet.'));
          }

          return ListView.builder(
            itemCount: connections.length,
            itemBuilder: (_, index) {
              final connId = connections[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(connId).get(),
                builder: (context, connSnap) {
                  if (!connSnap.hasData) return const SizedBox.shrink();
                  final connData = connSnap.data!.data() as Map<String, dynamic>? ?? {};
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: connData['profileImage'] != null
                          ? NetworkImage(connData['profileImage'])
                          : null,
                    ),
                    title: Text(connData['fullName'] ?? '${connData['firstName'] ?? ''} ${connData['lastName'] ?? ''}'),
                    subtitle: Text(connData['bio'] ?? ''),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfilePage(uid: connData['uid']),
                        ),
                      );
                    },
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

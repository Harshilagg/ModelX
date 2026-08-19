import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart'; // Make sure ChatPage accepts peerId, peerName, peerImage
import '../ui/app_theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/state_views.dart';
import '../widgets/app_skeleton.dart';

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
      appBar: AppBar(title: const Text('My Connections')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchConnections(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorStateView(message: 'Could not load your connections.');
          }

          if (!snapshot.hasData) {
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (_, __) => AppSkeleton.listTile(),
            );
          }

          final connections = snapshot.data!;
          if (connections.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No connections yet',
              message: 'Every accepted connection will show up here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: connections.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.line,
              indent: 84,
              endIndent: AppSpacing.md,
            ),
            itemBuilder: (context, index) {
              final user = connections[index];
              final name = user['fullName'] ?? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                leading: ProfileAvatar(imageUrl: user['profileImage'], name: name, size: 52),
                title: Text(
                  name.isNotEmpty ? name : 'User',
                  style: AppTypography.bodyEmphasized.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: (user['bio'] ?? '').toString().isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          user['bio'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption,
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        peerId: user['uid'],
                        peerName: name.isNotEmpty ? name : 'User',
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

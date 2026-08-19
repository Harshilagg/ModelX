import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_page.dart';
import '../ui/app_theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/state_views.dart';
import '../widgets/app_skeleton.dart';

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
      appBar: AppBar(title: const Text('Network')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorStateView(message: 'Could not load your network.');
          }

          if (!snapshot.hasData) {
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (_, __) => AppSkeleton.listTile(),
            );
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final connections = userData['connections'] ?? [];

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
            itemBuilder: (_, index) {
              final connId = connections[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(connId).get(),
                builder: (context, connSnap) {
                  if (!connSnap.hasData) {
                    return const SizedBox(height: 0);
                  }
                  final connData = connSnap.data!.data() as Map<String, dynamic>? ?? {};
                  final name = connData['fullName'] ?? '${connData['firstName'] ?? ''} ${connData['lastName'] ?? ''}'.trim();

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    leading: ProfileAvatar(imageUrl: connData['profileImage'], name: name, size: 52),
                    title: Text(
                      name.isNotEmpty ? name : 'User',
                      style: AppTypography.bodyEmphasized.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: (connData['bio'] ?? '').toString().isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              connData['bio'],
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

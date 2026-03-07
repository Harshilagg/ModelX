import 'package:flutter/material.dart';
import '../../pages/user_profile_page.dart';

class ModelCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool compact;
  const ModelCard({super.key, this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final displayName = data != null ? (data!['fullName'] ?? data!['displayName'] ?? data!['username'] ?? 'Model') : 'Model Name';
    final avatar = data != null ? (data!['profileImage'] ?? data!['avatarUrl']) : null;
    final subtitle = data != null ? (((data!['age']?.toString() ?? '') + (data!['age'] != null ? ' • ' : '') + (data!['height'] ?? '') + (data!['height'] != null ? ' • ' : '') + (data!['location'] ?? ''))) : 'Age • Height • Location';

    if (compact) {
      return InkWell(
        onTap: () {
          final uid = data != null ? (data!['id'] ?? data!['uid']) : null;
          if (uid != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UserProfilePage(uid: uid)),
            );
          }
        },
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                CircleAvatar(radius: 28, backgroundColor: Colors.grey[300], backgroundImage: avatar != null ? NetworkImage(avatar) as ImageProvider : null),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () {
                  final uid = data != null ? (data!['id'] ?? data!['uid']) : null;
                  if (uid != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UserProfilePage(uid: uid)),
                    );
                  }
                }, child: const Text('View'))
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        final uid = data != null ? (data!['id'] ?? data!['uid']) : null;
        if (uid != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserProfilePage(uid: uid)),
          );
        }
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 36, backgroundColor: Colors.grey[300], backgroundImage: avatar != null ? NetworkImage(avatar) as ImageProvider : null),
              const SizedBox(height: 8),
              Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: () {
                final uid = data != null ? (data!['id'] ?? data!['uid']) : null;
                if (uid != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => UserProfilePage(uid: uid)),
                  );
                }
              }, child: const Text('View'))
            ],
          ),
        ),
      ),
    );
  }
}

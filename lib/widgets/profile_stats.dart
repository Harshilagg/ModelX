import 'package:flutter/material.dart';
class ProfileStats extends StatelessWidget {
  final int followers;
  final int following;
  final VoidCallback onFollowers;
  final VoidCallback onFollowing;
  final VoidCallback onEdit;

  const ProfileStats({super.key, required this.followers, required this.following, required this.onFollowers, required this.onFollowing, required this.onEdit});

  Widget _stat(String label, int value, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Text(value.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stat('Followers', followers, onFollowers),
        _stat('Following', following, onFollowing),
        Expanded(
          child: InkWell(
            onTap: onEdit,
            child: Column(
              children: const [
                Icon(Icons.edit, size: 20),
                SizedBox(height: 6),
                Text('Edit', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

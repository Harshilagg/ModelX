import 'package:flutter/material.dart';
import '../widgets/post_card.dart';

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Announcements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(child: ListView.separated(itemCount: 8, separatorBuilder: (_,__) => const SizedBox(height: 12), itemBuilder: (context, index) => const PostCard())),
        ]),
      ),
    );
  }
}

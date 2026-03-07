import 'package:flutter/material.dart';

class PostCard extends StatelessWidget {
  const PostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Post title', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Post content preview goes here...'),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: const [Icon(Icons.thumb_up_alt_outlined, size: 18), SizedBox(width: 8), Text('12')]), Text('2h')])
        ]),
      ),
    );
  }
}

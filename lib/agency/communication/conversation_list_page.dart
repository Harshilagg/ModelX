import 'package:flutter/material.dart';

class ConversationListPage extends StatelessWidget {
  const ConversationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: 8,
        separatorBuilder: (_,__) => const Divider(),
        itemBuilder: (context, index) => ListTile(
          leading: CircleAvatar(backgroundColor: Colors.grey[300]),
          title: Text('Conversation ${index+1}'),
          subtitle: const Text('Last message preview'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SizedBox())),
        ),
      ),
    );
  }
}

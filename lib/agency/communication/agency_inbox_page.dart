import 'package:flutter/material.dart';

class AgencyInboxPage extends StatelessWidget {
  const AgencyInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Inbox', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(child: ListView.separated(itemCount: 8, separatorBuilder: (_,__) => const Divider(), itemBuilder: (context, index) => ListTile(leading: CircleAvatar(backgroundColor: Colors.grey[300]), title: Text('Conversation ${index+1}'), subtitle: const Text('Message preview goes here'), trailing: const Text('2m')))),
        ]),
      ),
    );
  }
}

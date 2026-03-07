import 'package:flutter/material.dart';

class TeamAccessPage extends StatelessWidget {
  const TeamAccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Team Access', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () {}, child: const Text('Invite Member')),
          const SizedBox(height: 12),
          Expanded(child: ListView.separated(itemCount: 6, separatorBuilder: (_,__) => const Divider(), itemBuilder: (context, index) => ListTile(title: Text('Member ${index+1}'), subtitle: const Text('Role: Booker')))),
        ]),
      ),
    );
  }
}

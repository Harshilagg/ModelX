import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(children: [Expanded(child: ListView()), SafeArea(child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Message'))), IconButton(onPressed: () {}, icon: const Icon(Icons.send))])))]),
    );
  }
}

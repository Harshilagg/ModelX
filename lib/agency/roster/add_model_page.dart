import 'package:flutter/material.dart';
import 'roster_service.dart';

class AddModelPage extends StatefulWidget {
  const AddModelPage({super.key});

  @override
  State<AddModelPage> createState() => _AddModelPageState();
}

class _AddModelPageState extends State<AddModelPage> {
  final _emailCtl = TextEditingController();
  final _service = RosterService();
  bool _sending = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final email = _emailCtl.text.trim();
    if (email.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.inviteModel('', email, {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite sent')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invite failed: $e')));
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Model')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [TextField(controller: _emailCtl, decoration: const InputDecoration(labelText: 'Model email')), const SizedBox(height: 12), ElevatedButton(onPressed: _sending ? null : _invite, child: _sending ? const CircularProgressIndicator() : const Text('Send Invite'))]),
      ),
    );
  }
}

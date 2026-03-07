import 'package:flutter/material.dart';
import 'roster_service.dart';

class ModelDetailPage extends StatefulWidget {
  final String modelId;
  const ModelDetailPage({super.key, required this.modelId});

  @override
  State<ModelDetailPage> createState() => _ModelDetailPageState();
}

class _ModelDetailPageState extends State<ModelDetailPage> {
  final _service = RosterService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await _service.getModelById(widget.modelId);
    setState(() {
      _data = doc.exists ? doc.data() as Map<String, dynamic> : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final d = _data ?? {};
    return Scaffold(
      appBar: AppBar(title: Text(d['displayName'] ?? 'Model')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (d['coverUrl'] != null) Image.network(d['coverUrl'], height: 180, width: double.infinity, fit: BoxFit.cover),
        const SizedBox(height: 12),
        Row(children: [if (d['avatarUrl'] != null) CircleAvatar(radius: 36, backgroundImage: NetworkImage(d['avatarUrl'])), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d['displayName'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if ((d['location'] ?? '').toString().isNotEmpty) Text(d['location'])])]),
        const SizedBox(height: 12),
        if ((d['bio'] ?? '').toString().isNotEmpty) Text(d['bio']),
        const SizedBox(height: 12),
        const Text('Portfolio', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (d['portfolio'] is List)
          Column(children: (d['portfolio'] as List).map<Widget>((p) => Padding(padding: const EdgeInsets.only(bottom: 8), child: p.toString().contains('http') ? Image.network(p, height: 120, fit: BoxFit.cover) : const SizedBox())).toList()),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: () {}, child: const Text('Edit Portfolio'))
      ])),
    );
  }
}

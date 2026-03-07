import 'package:flutter/material.dart';
import 'roster_service.dart';
import 'model_detail_page.dart';
import 'add_model_page.dart';

class ModelRosterPage extends StatefulWidget {
  const ModelRosterPage({super.key});

  @override
  State<ModelRosterPage> createState() => _ModelRosterPageState();
}

class _ModelRosterPageState extends State<ModelRosterPage> {
  final _service = RosterService();
  bool _gridView = true;
  List<dynamic> _models = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // attempt to find current agency id via auth (defer to service caller in future)
    // For now leave agencyId blank which will return empty set in dev
    try {
      final snapshot = await _service.fetchAgencyModels('');
      setState(() {
        _models = snapshot.docs.map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id}).toList();
      });
    } catch (_) {
      // ignore for now
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Models'), actions: [IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddModelPage())), icon: const Icon(Icons.person_add))]),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [ElevatedButton(onPressed: _load, child: const Text('Refresh')), const SizedBox(width: 12), ElevatedButton(onPressed: () => setState(() => _gridView = !_gridView), child: Text(_gridView ? 'List' : 'Grid'))]),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _gridView
                    ? GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, crossAxisSpacing: 12, mainAxisSpacing: 12),
                        itemCount: _models.length,
                        itemBuilder: (context, index) {
                          final m = _models[index];
                          return GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModelDetailPage(modelId: m['id']))),
                            child: Container(
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 40, backgroundColor: Colors.grey[300], backgroundImage: m['avatarUrl'] != null ? NetworkImage(m['avatarUrl']) as ImageProvider : null), const SizedBox(height: 8), Text(m['displayName'] ?? 'Model')]),
                            ),
                          );
                        },
                      )
                    : ListView.separated(
                        itemCount: _models.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final m = _models[index];
                          return ListTile(
                            leading: CircleAvatar(backgroundImage: m['avatarUrl'] != null ? NetworkImage(m['avatarUrl']) : null, backgroundColor: Colors.grey[300]),
                            title: Text(m['displayName'] ?? 'Model'),
                            subtitle: Text(m['headline'] ?? ''),
                            trailing: IconButton(onPressed: () => _confirmUnlink(m['id']), icon: const Icon(Icons.link_off)),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModelDetailPage(modelId: m['id']))),
                          );
                        },
                      ),
          )
        ]),
      ),
    );
  }

  void _confirmUnlink(String modelId) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Remove model'), content: const Text('Unlink this model from your agency?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove'))]));
    if (ok == true) {
      await _service.unlinkModel(modelId);
      _load();
    }
  }
}

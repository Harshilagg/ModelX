import 'package:flutter/material.dart';
import 'casting_service.dart';
import '../widgets/applicant_card.dart';

class CastingDetailPage extends StatefulWidget {
  final String castingId;
  const CastingDetailPage({super.key, required this.castingId});

  @override
  State<CastingDetailPage> createState() => _CastingDetailPageState();
}

class _CastingDetailPageState extends State<CastingDetailPage> {
  final _service = CastingService();
  Map<String, dynamic>? _data;
  List<dynamic> _applicants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final doc = await _service.getCasting(widget.castingId);
    final apps = await _service.fetchApplicants(widget.castingId);
    setState(() {
      _data = doc.exists ? doc.data() as Map<String, dynamic> : null;
      _applicants = apps.docs.map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id}).toList();
      _loading = false;
    });
  }

  Future<void> _updateApplicant(String id, String status) async {
    await _service.updateApplicantStatus(widget.castingId, id, status);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(_data?['title'] ?? 'Casting')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_data?['description'] ?? ''),
          const SizedBox(height: 12),
          const Text('Applicants', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: _applicants.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final a = _applicants[index] as Map<String, dynamic>;
                return ApplicantCard(castingId: widget.castingId, applicant: a, onUpdate: (id, status) => _updateApplicant(id, status));
              },
            ),
          ),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../ui/app_theme.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_pill.dart';
import 'casting_service.dart';
import '../widgets/casting_applicant_card.dart';

class CastingDetailPage extends StatefulWidget {
  final String castingId;
  const CastingDetailPage({super.key, required this.castingId});

  @override
  State<CastingDetailPage> createState() => _CastingDetailPageState();
}

class _CastingDetailPageState extends State<CastingDetailPage> {
  final _service = CastingService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final doc = await _service.getCasting(widget.castingId);
    setState(() {
      _data = doc.exists ? doc.data() as Map<String, dynamic> : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: AppColors.paper, body: LoadingState());
    }

    final data = _data;
    if (data == null) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(title: const Text('Casting')),
        body: const ErrorStateView(message: 'This casting could not be found.'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text(data['title'] ?? 'Casting')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.ink,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // ================= COMPACT POSTING SUMMARY =================
            // A condensed reference card, not the full detail dump — the
            // rich, browsable version of these facts lives on the model
            // side (CastingFullDetailPage). Here, applicant review is the
            // primary task, so the posting itself stays out of the way.
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.paperRaised,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        data['title'] ?? '',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ),
                    StatusPill(status: (data['status'] ?? 'open').toString()),
                  ]),
                  if ((data['description'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      data['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm + 2),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: 6,
                    children: [
                      if ((data['location'] ?? '').toString().isNotEmpty) _quickFact(Icons.location_on_outlined, data['location']),
                      _quickFact(Icons.payments_outlined, _compensation(data)),
                      if (data['shootingStart'] != null) _quickFact(Icons.event_outlined, _formatTimestamp(data['shootingStart'])),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            Text('Applicants', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: AppSpacing.sm + 4),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('castings')
                  .doc(widget.castingId)
                  .collection('applicants')
                  .orderBy('appliedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ErrorStateView(message: 'Could not load applicants.');
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: LoadingState(),
                  );
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No applicants yet',
                      message: 'Models who apply to this casting will show up here.',
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final a = doc.data() as Map<String, dynamic>;
                    final modelId = (a['modelId'] ?? doc.id).toString();
                    final status = (a['status'] ?? 'pending').toString();
                    return CastingApplicantCard(castingId: widget.castingId, modelId: modelId, status: status);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickFact(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.inkFaint),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
      ],
    );
  }

  String _compensation(Map<String, dynamic> data) {
    final min = data['compensationMin']?.toString();
    final max = data['compensationMax']?.toString();
    if ((min == null || min.isEmpty) && (max == null || max.isEmpty)) {
      final budgetType = (data['budgetType'] ?? '').toString();
      final budgetAmount = (data['budgetAmount'] ?? '').toString();
      if (budgetType.isNotEmpty && budgetAmount.isNotEmpty) return '$budgetType: ₹$budgetAmount';
      return '—';
    }
    return '₹${min ?? '-'} – ₹${max ?? '-'}';
  }

  String _formatTimestamp(dynamic v) {
    if (v is Timestamp) {
      final dt = v.toDate();
      return dt.toLocal().toString().split('.').first;
    }
    return 'Not set';
  }

}

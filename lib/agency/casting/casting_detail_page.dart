import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../ui/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_pill.dart';
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
    try {
      // optimistic local update for immediate UI feedback
      setState(() {
        _applicants = _applicants.map((a) {
          if ((a['id'] ?? '') == id) {
            return {...a, 'status': status};
          }
          return a;
        }).toList();
      });

      await _service.updateApplicantStatus(widget.castingId, id, status);

      // reload from server to ensure canonical state
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Applicant status updated to $status')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      // reload to restore correct UI
      await _load();
    }
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
            Row(children: [
              Expanded(
                child: Text(
                  data['title'] ?? '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              StatusPill(status: (data['status'] ?? 'open').toString()),
            ]),
            const SizedBox(height: AppSpacing.sm + 4),
            Text(
              data['description'] ?? '',
              style: const TextStyle(fontSize: 14.5, color: AppColors.inkSoft, height: 1.5),
            ),

            const SizedBox(height: AppSpacing.lg),
            const Text('Casting details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkFaint, letterSpacing: 0.3)),
            const SizedBox(height: AppSpacing.sm + 2),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _metaRow(Icons.location_on_outlined, 'Location', _orDash(data['location'])),
                  _metaDivider(),
                  _metaRow(Icons.payments_outlined, 'Compensation', _compensation(data)),
                  _metaDivider(),
                  _metaRow(Icons.event_outlined, 'Shooting starts', _formatTimestamp(data['shootingStart'])),
                  _metaDivider(),
                  _metaRow(Icons.event_available_outlined, 'Shooting ends', _formatTimestamp(data['shootingEnd'])),
                  if ((data['outfitRequirements'] ?? '').toString().isNotEmpty) ...[
                    _metaDivider(),
                    _metaRow(Icons.checkroom_outlined, 'Outfit requirements', data['outfitRequirements'].toString()),
                  ],
                  if ((data['requirements'] ?? '').toString().isNotEmpty) ...[
                    _metaDivider(),
                    _metaRow(Icons.notes_outlined, 'Additional requirements', data['requirements'].toString()),
                  ],
                ],
              ),
            ),

            if (data['talentRequirements'] is Map) ...[
              const SizedBox(height: AppSpacing.lg),
              const Text('Talent requirements', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkFaint, letterSpacing: 0.3)),
              const SizedBox(height: AppSpacing.sm + 2),
              AppCard(child: _talentRequirements(Map<String, dynamic>.from(data['talentRequirements'] as Map))),
            ],

            const SizedBox(height: AppSpacing.lg),
            Text('Applicants (${_applicants.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: AppSpacing.sm + 4),
            if (_applicants.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No applicants yet',
                  message: 'Models who apply to this casting will show up here.',
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _applicants.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final a = _applicants[index] as Map<String, dynamic>;
                  return ApplicantCard(castingId: widget.castingId, applicant: a, onUpdate: (id, status) => _updateApplicant(id, status));
                },
              ),
          ],
        ),
      ),
    );
  }

  String _orDash(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
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

  Widget _metaRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.inkFaint),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkFaint)),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaDivider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        child: Divider(height: 1),
      );

  Widget _talentRequirements(Map<String, dynamic> t) {
    final gender = (t['gender'] ?? 'any').toString();
    final minAge = t['minAge']?.toString();
    final maxAge = t['maxAge']?.toString();
    final looksRaw = t['looks'];
    final looks = (looksRaw is List) ? looksRaw.cast<String>() : (looksRaw != null ? [looksRaw.toString()] : <String>[]);
    final skills = (t['skills'] is List) ? (t['skills'] as List).cast<String>() : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metaRow(Icons.wc_rounded, 'Gender', gender == 'any' ? 'Any' : gender[0].toUpperCase() + gender.substring(1)),
        if (minAge != null || maxAge != null) ...[
          _metaDivider(),
          _metaRow(Icons.calendar_today_outlined, 'Age range', '${minAge ?? '-'} – ${maxAge ?? '-'}'),
        ],
        if (looks.isNotEmpty) ...[
          _metaDivider(),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('Preferred looks', style: const TextStyle(fontSize: 12, color: AppColors.inkFaint)),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: looks.map(_tag).toList()),
        ],
        if (skills.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm + 4),
          const Text('Required skills', style: TextStyle(fontSize: 12, color: AppColors.inkFaint)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: skills.map(_tag).toList()),
        ],
      ],
    );
  }

  Widget _tag(String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppColors.goldBg, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gold)),
      );
}

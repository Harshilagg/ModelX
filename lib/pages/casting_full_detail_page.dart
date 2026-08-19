import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ui/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_action_bar.dart';
import '../widgets/status_pill.dart';

/// Full, untruncated detail view of a casting for a model deciding whether
/// to apply — the destination for taps on a casting in [JobsPage]'s feed,
/// which today only ever shows the compact browsing card. Shows every
/// field the compact card omits or truncates (full description, shooting
/// dates) with the primary Apply action pinned to the bottom.
class CastingFullDetailPage extends StatefulWidget {
  final String castingId;
  final Map<String, dynamic> data;
  final String posterName;

  const CastingFullDetailPage({
    super.key,
    required this.castingId,
    required this.data,
    required this.posterName,
  });

  @override
  State<CastingFullDetailPage> createState() => _CastingFullDetailPageState();
}

class _CastingFullDetailPageState extends State<CastingFullDetailPage> {
  bool _applying = false;

  Future<void> _apply() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _applying) return;
    setState(() => _applying = true);

    try {
      String displayName = user.displayName ?? '';
      if (displayName.isEmpty) {
        try {
          final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (profile.exists) {
            final pd = profile.data() as Map<String, dynamic>;
            displayName = (pd['displayName'] ?? pd['fullName'] ?? pd['name'] ?? '').toString();
          }
        } catch (_) {}
      }

      final applicantsRef = FirebaseFirestore.instance.collection('castings').doc(widget.castingId).collection('applicants');
      final docRef = applicantsRef.doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (snap.exists) return;
        tx.set(docRef, {
          'modelId': user.uid,
          'displayName': displayName.isNotEmpty ? displayName : 'Anonymous',
          'message': '',
          'status': 'applied',
          'appliedAt': FieldValue.serverTimestamp(),
        });
        tx.update(
          FirebaseFirestore.instance.collection('castings').doc(widget.castingId),
          {'applicationsCount': FieldValue.increment(1)},
        );
      });

      if (!mounted) return;
      showAppToast(context, 'Application submitted');
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Failed to apply: $e', isError: true);
    }
    if (mounted) setState(() => _applying = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final modelId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text(data['title'] ?? data['projectTitle'] ?? 'Casting')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(children: [
            Expanded(
              child: Text(
                data['title'] ?? data['projectTitle'] ?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
            ),
            StatusPill(status: (data['status'] ?? 'open').toString()),
          ]),
          const SizedBox(height: 4),
          Text(widget.posterName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
          const SizedBox(height: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
      bottomNavigationBar: modelId == null
          ? null
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('castings')
                  .doc(widget.castingId)
                  .collection('applicants')
                  .doc(modelId)
                  .snapshots(),
              builder: (context, snapshot) {
                final hasApplied = snapshot.data?.exists ?? false;
                return AppActionBar(
                  primaryLabel: hasApplied ? 'Applied' : 'Apply now',
                  onPrimary: hasApplied ? null : _apply,
                  primaryLoading: _applying,
                );
              },
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
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('Preferred looks', style: TextStyle(fontSize: 12, color: AppColors.inkFaint)),
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

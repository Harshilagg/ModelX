import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ui/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_action_bar.dart';
import '../widgets/app_tag.dart';
import '../widgets/status_pill.dart';

/// Full, untruncated detail view of a brand-posted gig for a model deciding
/// whether to apply — the destination for taps on a gig in [JobsPage]'s
/// feed, which today only ever shows the compact browsing card (and, for
/// grid tiles, no detail at all).
class GigFullDetailPage extends StatefulWidget {
  final String gigId;
  final Map<String, dynamic> data;
  final String brandName;

  const GigFullDetailPage({
    super.key,
    required this.gigId,
    required this.data,
    required this.brandName,
  });

  @override
  State<GigFullDetailPage> createState() => _GigFullDetailPageState();
}

class _GigFullDetailPageState extends State<GigFullDetailPage> {
  bool _applying = false;

  Future<void> _apply() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _applying) return;
    setState(() => _applying = true);

    final gigRef = FirebaseFirestore.instance.collection('gigs').doc(widget.gigId);
    final appRef = gigRef.collection('applications').doc(user.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final appSnap = await tx.get(appRef);
        if (appSnap.exists) return;
        tx.set(appRef, {
          'modelId': user.uid,
          'gigId': widget.gigId,
          'brandName': widget.brandName,
          'projectTitle': widget.data['projectTitle'],
          'status': 'applied',
          'appliedAt': FieldValue.serverTimestamp(),
        });
        tx.update(gigRef, {'applicationsCount': FieldValue.increment(1)});
      });

      if (!mounted) return;
      showAppToast(context, 'Applied successfully');
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Failed to apply. Try again.', isError: true);
    }
    if (mounted) setState(() => _applying = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final modelId = FirebaseAuth.instance.currentUser?.uid;
    final roleReq = data['roleRequirements'] as Map<String, dynamic>? ?? {};
    final physical = roleReq['physicalAttributes'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text(data['projectTitle'] ?? 'Gig')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(children: [
            Expanded(
              child: Text(
                data['projectTitle'] ?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
            ),
            StatusPill(status: (data['status'] ?? 'open').toString()),
          ]),
          const SizedBox(height: 4),
          Text(widget.brandName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
          const SizedBox(height: AppSpacing.md),
          Text(
            data['description'] ?? '',
            style: const TextStyle(fontSize: 14.5, color: AppColors.inkSoft, height: 1.5),
          ),

          const SizedBox(height: AppSpacing.lg),
          const Text('Job details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkFaint, letterSpacing: 0.3)),
          const SizedBox(height: AppSpacing.sm + 2),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metaRow(Icons.schedule_outlined, 'Timeline', _orDash(data['timeline'])),
                _metaDivider(),
                _metaRow(Icons.hourglass_bottom_rounded, 'Duration', '${data['durationHours'] ?? '—'} hrs'),
                _metaDivider(),
                _metaRow(Icons.payments_outlined, 'Budget', _budget(data)),
              ],
            ),
          ),

          if (physical.isNotEmpty || (data['eyeColor'] != null) || (roleReq['eyeColor'] != null)) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text('Talent requirements', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkFaint, letterSpacing: 0.3)),
            const SizedBox(height: AppSpacing.sm + 2),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _chipSection('Eye color', List<String>.from(physical['eyeColor'] ?? const [])),
                  _chipSection('Hair color', List<String>.from(physical['hairColor'] ?? const [])),
                  _chipSection('Skin complexion', List<String>.from(physical['skinComplexion'] ?? const [])),
                  _measurements(physical),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
      bottomNavigationBar: modelId == null
          ? null
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('gigs')
                  .doc(widget.gigId)
                  .collection('applications')
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

  String _budget(Map<String, dynamic> data) {
    final type = (data['budgetType'] ?? '').toString();
    final amount = (data['budgetAmount'] ?? '').toString();
    if (type.isEmpty && amount.isEmpty) return '—';
    return '$type: ₹$amount';
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

  Widget _chipSection(String label, List<String> values) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkFaint)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: values.map((v) => AppTag(v)).toList()),
        ],
      ),
    );
  }

  Widget _measurements(Map<String, dynamic> physical) {
    final rows = <Widget>[];
    void addRange(String label, Map<String, dynamic>? range, String unit) {
      if (range == null || range['min'] == null || range['max'] == null) return;
      rows.add(AppTag('$label: ${range['min']}–${range['max']} $unit'));
    }

    addRange('Height', physical['height'], 'cm');
    addRange('Chest', physical['chest'], 'in');
    addRange('Waist', physical['waist'], 'in');
    addRange('Hips', physical['hips'], 'in');
    addRange('Shoulder', physical['shoulderWidth'], 'in');
    addRange('Inseam', physical['inseam'], 'in');

    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Measurements', style: TextStyle(fontSize: 12, color: AppColors.inkFaint)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: rows),
      ],
    );
  }
}

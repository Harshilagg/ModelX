import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ui/app_theme.dart' show showAppToast;
import '../widgets/job_detail_view.dart';

/// Full detail of an agency-posted casting — the destination for a tap
/// on a casting in the Jobs feed.
///
/// Shares [BoardJobDetail] with the gig page so a model reads both the
/// same way; only the field mapping differs.
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
          final profile =
              await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (profile.exists) {
            final pd = profile.data() as Map<String, dynamic>;
            displayName =
                (pd['displayName'] ?? pd['fullName'] ?? pd['name'] ?? '').toString();
          }
        } catch (_) {}
      }

      final applicantsRef = FirebaseFirestore.instance
          .collection('castings')
          .doc(widget.castingId)
          .collection('applicants');
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

  String _orDash(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
  }

  String _compensation() {
    final data = widget.data;
    final min = (data['compensationMin'] ?? '').toString().trim();
    final max = (data['compensationMax'] ?? '').toString().trim();
    if (min.isNotEmpty || max.isNotEmpty) {
      return '₹${min.isEmpty ? '—' : min} – ₹${max.isEmpty ? '—' : max}';
    }
    final budgetType = (data['budgetType'] ?? '').toString();
    final budgetAmount = (data['budgetAmount'] ?? '').toString();
    if (budgetAmount.isNotEmpty) {
      return budgetType.isEmpty
          ? '₹$budgetAmount'
          : '${budgetType.toUpperCase()} · ₹$budgetAmount';
    }
    return '—';
  }

  static String _stamp(dynamic v) {
    if (v is! Timestamp) return 'NOT SET';
    final d = v.toDate().toLocal();
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year} · $hh:$mm';
  }

  List<String> _strings(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? const [] : [s];
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final modelId = FirebaseAuth.instance.currentUser?.uid;

    final title = (data['title'] ?? data['projectTitle'] ?? 'Casting').toString();
    final location = (data['location'] ?? '').toString().trim();
    final posterLine = [
      widget.posterName.trim(),
      if (location.isNotEmpty) location,
    ].where((s) => s.isNotEmpty).join(' · ');

    final details = <(String, String)>[
      if (location.isNotEmpty) ('Location', location.toUpperCase()),
      ('Compensation', _compensation()),
      if (data['shootingStart'] is Timestamp)
        ('Shooting starts', _stamp(data['shootingStart'])),
      if (data['shootingEnd'] is Timestamp)
        ('Shooting ends', _stamp(data['shootingEnd'])),
      if ((data['timeline'] ?? '').toString().trim().isNotEmpty)
        ('Timeline', data['timeline'].toString().toUpperCase()),
      if ((data['outfitRequirements'] ?? '').toString().trim().isNotEmpty)
        ('Outfit', data['outfitRequirements'].toString().toUpperCase()),
      if ((data['requirements'] ?? '').toString().trim().isNotEmpty)
        ('Additional', data['requirements'].toString()),
    ];

    final talent = (data['talentRequirements'] is Map)
        ? Map<String, dynamic>.from(data['talentRequirements'] as Map)
        : <String, dynamic>{};

    final gender = (talent['gender'] ?? '').toString().trim();
    final minAge = talent['minAge'], maxAge = talent['maxAge'];
    final highlights = <(String, String)>[
      if (gender.isNotEmpty)
        ('Gender', gender.toLowerCase() == 'any' ? 'ANY' : gender.toUpperCase()),
      if (minAge != null || maxAge != null)
        ('Age range', '${minAge ?? '—'} – ${maxAge ?? '—'}'),
    ];

    final applicants = data['applicationsCount'] ?? data['applicantsCount'] ?? 0;
    final createdAt = data['createdAt'];
    final ago = createdAt is Timestamp
        ? '${DateTime.now().difference(createdAt.toDate()).inDays}D AGO'
        : '';

    BoardJobDetail detail({required bool hasApplied, required String appliedLabel}) {
      return BoardJobDetail(
        title: title,
        posterLine: posterLine,
        description: (data['description'] ?? '').toString(),
        status: (data['status'] ?? 'open').toString(),
        details: details,
        highlights: highlights,
        chipGroups: [
          ('Preferred looks', _strings(talent['looks'])),
          ('Required skills', _strings(talent['skills'])),
          ('Eye color', _strings(talent['eyeColor'])),
          ('Hair color', _strings(talent['hairColor'])),
          ('Skin complexion', _strings(talent['skinComplexion'])),
        ],
        applicationsLine:
            '$applicants application${applicants == 1 ? '' : 's'}${ago.isEmpty ? '' : ' · posted $ago'}',
        depValue: data['shootingStart'] is Timestamp
            ? _stamp(data['shootingStart'])
            : _orDash(data['timeline']),
        hasApplied: hasApplied,
        applying: _applying,
        onApply: modelId == null ? null : _apply,
        appliedLabel: appliedLabel,
      );
    }

    if (modelId == null) {
      return detail(hasApplied: false, appliedLabel: 'Applied');
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('castings')
          .doc(widget.castingId)
          .collection('applicants')
          .doc(modelId)
          .snapshots(),
      builder: (context, snapshot) {
        final hasApplied = snapshot.data?.exists ?? false;
        final status = hasApplied
            ? ((snapshot.data!.data() as Map<String, dynamic>?)?['status'] ?? 'applied')
                .toString()
            : 'Applied';
        return detail(hasApplied: hasApplied, appliedLabel: status);
      },
    );
  }
}

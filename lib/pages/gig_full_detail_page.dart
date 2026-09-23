import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ui/app_theme.dart' show showAppToast;
import '../widgets/job_detail_view.dart';

/// Full detail of a brand-posted gig for a model deciding whether to
/// apply — the destination for a tap on a gig in the Jobs feed.
///
/// Rendered through [BoardJobDetail] so it reads identically to a
/// casting; only the field mapping differs, because the two collections
/// store their facts under different keys.
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

    final gigRef = FirebaseFirestore.instance
        .collection('gigs')
        .doc(widget.gigId);
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

  String _orDash(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
  }

  String _budget() {
    final type = (widget.data['budgetType'] ?? '').toString();
    final amount = (widget.data['budgetAmount'] ?? '').toString();
    if (type.isEmpty && amount.isEmpty) return '—';
    if (amount.isEmpty) return type.toUpperCase();
    return type.isEmpty ? '₹$amount' : '${type.toUpperCase()} · ₹$amount';
  }

  static String _stamp(dynamic v) {
    if (v is! Timestamp) return 'NOT SET';
    final d = v.toDate().toLocal();
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year} · $hh:$mm';
  }

  List<String> _strings(dynamic v) {
    if (v is List)
      return v
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? const [] : [s];
  }

  List<String> _measurements(Map<String, dynamic> physical) {
    final rows = <String>[];
    void addRange(String label, dynamic range, String unit) {
      if (range is! Map) return;
      final min = range['min'], max = range['max'];
      if (min == null || max == null) return;
      rows.add('$label $min–$max $unit');
    }

    addRange('Height', physical['height'], 'cm');
    addRange('Chest', physical['chest'], 'in');
    addRange('Waist', physical['waist'], 'in');
    addRange('Hips', physical['hips'], 'in');
    addRange('Shoulder', physical['shoulderWidth'], 'in');
    addRange('Inseam', physical['inseam'], 'in');
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final modelId = FirebaseAuth.instance.currentUser?.uid;
    final roleReq = data['roleRequirements'] as Map<String, dynamic>? ?? {};
    final physical =
        roleReq['physicalAttributes'] as Map<String, dynamic>? ?? {};

    // Gigs store `city` and `jobLocations`, not `location` — that key
    // belongs to castings.
    final locations = data['jobLocations'];
    final location = [
      (data['location'] ?? '').toString().trim(),
      (data['city'] ?? '').toString().trim(),
      if (locations is List && locations.isNotEmpty)
        locations.first.toString().trim(),
    ].firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final posterLine = [
      widget.brandName.trim(),
      if (location.isNotEmpty) location,
    ].where((s) => s.isNotEmpty).join(' · ');

    final details = <(String, String)>[
      if (location.isNotEmpty) ('Location', location.toUpperCase()),
      ('Budget', _budget()),
      ('Timeline', _orDash(data['timeline']).toUpperCase()),
      if ((data['durationHours'] ?? '').toString().isNotEmpty)
        ('Duration', '${data['durationHours']} HRS'),
      if (data['shootingStart'] is Timestamp)
        ('Shooting starts', _stamp(data['shootingStart'])),
      if (data['shootingEnd'] is Timestamp)
        ('Shooting ends', _stamp(data['shootingEnd'])),
      if ((data['outfitRequirements'] ?? '').toString().trim().isNotEmpty)
        ('Outfit', data['outfitRequirements'].toString().toUpperCase()),
    ];

    final gender = (roleReq['gender'] ?? data['gender'] ?? '')
        .toString()
        .trim();
    final minAge = roleReq['minAge'] ?? data['minAge'];
    final maxAge = roleReq['maxAge'] ?? data['maxAge'];
    final highlights = <(String, String)>[
      if (gender.isNotEmpty) ('Gender', gender.toUpperCase()),
      if (minAge != null || maxAge != null)
        ('Age range', '${minAge ?? '—'} – ${maxAge ?? '—'}'),
    ];

    final applications = data['applicationsCount'] ?? 0;
    final createdAt = data['createdAt'];
    final ago = createdAt is Timestamp
        ? '${DateTime.now().difference(createdAt.toDate()).inDays}D AGO'
        : '';

    BoardJobDetail detail({
      required bool hasApplied,
      required String appliedLabel,
    }) {
      return BoardJobDetail(
        title: (data['projectTitle'] ?? 'Gig').toString(),
        posterLine: posterLine,
        description: (data['description'] ?? '').toString(),
        status: (data['status'] ?? 'open').toString(),
        details: details,
        highlights: highlights,
        chipGroups: [
          ('Eye color', _strings(physical['eyeColor'])),
          ('Hair color', _strings(physical['hairColor'])),
          ('Skin complexion', _strings(physical['skinComplexion'])),
          ('Preferred looks', _strings(roleReq['looks'])),
          ('Required skills', _strings(roleReq['skills'])),
        ],
        measurements: _measurements(physical),
        applicationsLine:
            '$applications application${applications == 1 ? '' : 's'}${ago.isEmpty ? '' : ' · posted $ago'}',
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

    // The Applied state tracks the application document live, so the bar
    // flips the moment the write lands rather than on the next rebuild.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gigs')
          .doc(widget.gigId)
          .collection('applications')
          .doc(modelId)
          .snapshots(),
      builder: (context, snapshot) {
        final hasApplied = snapshot.data?.exists ?? false;
        final status = hasApplied
            ? ((snapshot.data!.data() as Map<String, dynamic>?)?['status'] ??
                      'applied')
                  .toString()
            : 'Applied';
        return detail(hasApplied: hasApplied, appliedLabel: status);
      },
    );
  }
}

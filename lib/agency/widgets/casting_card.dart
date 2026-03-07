import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../casting/casting_service.dart';

class CastingCard extends StatefulWidget {
  final String id;
  final String title;
  final String description;
  final String? posterName;
  final String location;
  final String timeline;
  final String budgetType;
  final String budgetAmount;
  final String? compensationMin;
  final String? compensationMax;
  final DateTime? shootingStart;
  final DateTime? shootingEnd;
  final Map<String, dynamic>? talentRequirements;
  final List<String> media;
  final int applicants;
  final String status;
  final DateTime createdAt;

  final Widget? actionWidget;
  final bool showApply;
  final VoidCallback? onTap;

  const CastingCard({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    this.posterName,
    this.location = '',
    this.timeline = '',
    this.budgetType = '',
    this.budgetAmount = '',
    this.compensationMin,
    this.compensationMax,
    this.shootingStart,
    this.shootingEnd,
    this.talentRequirements,
    this.media = const [],
    this.applicants = 0,
    this.status = 'open',
    required this.createdAt,
    this.actionWidget,
    this.showApply = true,
    this.onTap,
  });

  @override
  State<CastingCard> createState() => _CastingCardState();

}

class _CastingCardState extends State<CastingCard> {
  final _service = CastingService();
  bool _sending = false;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    _applied = !widget.showApply;
  }

  Future<void> _applyNow() async {
    if (_sending || _applied) return;
    setState(() => _sending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String displayName = user?.displayName ?? '';
      if ((displayName).isEmpty && user != null) {
        try {
          final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (profile.exists) {
            final pd = profile.data() as Map<String, dynamic>;
            displayName = (pd['displayName'] ?? pd['fullName'] ?? pd['name'] ?? '').toString();
          }
        } catch (_) {}
      }

      await _service.applyToCasting(widget.id, {
        'modelId': user?.uid,
        'displayName': displayName.isNotEmpty ? displayName : 'Anonymous',
        'message': '',
        'status': 'applied',
        'appliedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _applied = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to apply: $e')));
    }
    setState(() => _sending = false);
  }
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // header
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: Colors.blue.withOpacity(0.12), child: const Icon(Icons.business, size: 18, color: Colors.blue)),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.posterName ?? 'Agency', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          if (widget.actionWidget != null) widget.actionWidget!,
        ]),
        const SizedBox(height: 12),

        // title
        Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // description
        Text('About the Casting', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 6),
        Text(widget.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
        const SizedBox(height: 12),

        Wrap(spacing: 12, runSpacing: 8, children: [
          if (widget.timeline.isNotEmpty) _detailText('Timeline: ${widget.timeline}'),
          if ((widget.compensationMin != null && widget.compensationMin!.isNotEmpty) || (widget.compensationMax != null && widget.compensationMax!.isNotEmpty))
            _detailText('Compensation: ${widget.compensationMin ?? '-'} - ${widget.compensationMax ?? '-'}'),
          if (widget.budgetType.isNotEmpty && widget.budgetAmount.isNotEmpty) _detailText('${widget.budgetType}: ₹${widget.budgetAmount}'),
          if (widget.location.isNotEmpty) _detailText('Location: ${widget.location}'),
        ]),
        const SizedBox(height: 8),

        // talent summary placed below compensation/details to avoid horizontal overflow
        if (widget.talentRequirements != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: _talentSummary(widget.talentRequirements!)),

        const SizedBox(height: 8),

        Row(children: [
          Text('${widget.applicants} Applications', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          _dot(),
          _statusBadge(widget.status),
          _dot(),
          _meta(_timeAgo(widget.createdAt)),
          const Spacer(),
          if (!_applied && widget.showApply)
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(80, 36), padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: _sending ? null : _applyNow,
              child: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Apply', style: TextStyle(fontSize: 14)),
            )
          else if (_applied)
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: const Text('Applied', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700))),
        ])
      ]),
        ),
      ),
    );
  }

  Widget _detailText(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13));

  Widget _meta(String text) => Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey));

  Widget _dot() => Container(margin: const EdgeInsets.symmetric(horizontal: 6), width: 4, height: 4, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle));

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Widget _statusBadge(String status) {
    late String label;
    late Color color;
    late Color bgColor;
    switch (status.toLowerCase()) {
      case 'open':
        label = 'Live';
        color = Colors.green;
        bgColor = Colors.green.withOpacity(0.12);
        break;
      case 'closed':
        label = 'Closed';
        color = Colors.red;
        bgColor = Colors.red.withOpacity(0.12);
        break;
      default:
        label = status;
        color = Colors.grey.shade700;
        bgColor = Colors.grey.withOpacity(0.15);
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)));
  }

  Widget _talentSummary(Map<String, dynamic> t) {
    final gender = (t['gender'] ?? 'any').toString();
    final minAge = t['minAge']?.toString();
    final maxAge = t['maxAge']?.toString();
    final looks = t['looks']?.toString();
    final skills = (t['skills'] is List) ? (t['skills'] as List).cast<String>() : null;
    final parts = <String>[];
    if (gender != 'any') parts.add(gender);
    if (minAge != null || maxAge != null) parts.add('${minAge ?? '-'}-${maxAge ?? '-'}');
    if (looks != null && looks.isNotEmpty) parts.add(looks);
    if (skills != null && skills.isNotEmpty) parts.add(skills.take(3).join(', '));
    if (parts.isEmpty) return const SizedBox.shrink();
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.06), borderRadius: BorderRadius.circular(8)), child: Text(parts.join(' • '), style: const TextStyle(fontSize: 12, color: Colors.blue)));
  }

}


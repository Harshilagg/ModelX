import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../ui/app_theme.dart';
import '../../widgets/status_pill.dart';
import '../casting/casting_service.dart';

/// Job card for agency-posted castings, shown to models in the jobs feed
/// and to agencies in their own casting list. Shares its visual language
/// (card shell, chip style, meta row) with `GigCard` even though the two
/// stay separate widgets — they render different data shapes.
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadows.card,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // header
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: AppColors.paperRaised, shape: BoxShape.circle),
                child: const Icon(Icons.business_rounded, size: 18, color: AppColors.inkSoft),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.posterName ?? 'Agency',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
              if (widget.actionWidget != null) widget.actionWidget!,
            ]),
            const SizedBox(height: AppSpacing.sm + 4),

            // title
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: AppSpacing.sm + 4),

            // description
            const Text('About the casting', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
            const SizedBox(height: 6),
            Text(widget.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.5)),
            const SizedBox(height: AppSpacing.sm + 4),

            Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, children: [
              if (widget.timeline.isNotEmpty) _detailText('Timeline: ${widget.timeline}'),
              if ((widget.compensationMin != null && widget.compensationMin!.isNotEmpty) || (widget.compensationMax != null && widget.compensationMax!.isNotEmpty))
                _detailText('Compensation: ${widget.compensationMin ?? '-'} - ${widget.compensationMax ?? '-'}'),
              if (widget.budgetType.isNotEmpty && widget.budgetAmount.isNotEmpty) _detailText('${widget.budgetType}: ₹${widget.budgetAmount}'),
              if (widget.location.isNotEmpty) _detailText('Location: ${widget.location}'),
            ]),

            // talent summary placed below compensation/details to avoid horizontal overflow
            if (widget.talentRequirements != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _talentSummary(widget.talentRequirements!),
            ],

            const SizedBox(height: AppSpacing.sm + 4),

            Row(children: [
              Text('${widget.applicants} applications', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
              _dot(),
              StatusPill(status: widget.status),
              _dot(),
              _meta(_timeAgo(widget.createdAt)),
              const Spacer(),
              if (!_applied && widget.showApply)
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(80, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    onPressed: _sending ? null : _applyNow,
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.paper),
                          )
                        : const Text('Apply', style: TextStyle(fontSize: 13.5)),
                  ),
                )
              else if (_applied)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.paperRaised, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.lineStrong)),
                  child: const Text('Applied', style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _detailText(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink));

  Widget _meta(String text) => Text(text, style: const TextStyle(fontSize: 12, color: AppColors.inkFaint));

  Widget _dot() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 3,
        height: 3,
        decoration: const BoxDecoration(color: AppColors.lineStrong, shape: BoxShape.circle),
      );

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Widget _talentSummary(Map<String, dynamic> t) {
    final gender = (t['gender'] ?? 'any').toString();
    final minAge = t['minAge']?.toString();
    final maxAge = t['maxAge']?.toString();
    // 'looks' may be stored either as a legacy comma-string or as a
    // List<String> (current shape) — handle both for backwards compatibility.
    final looksRaw = t['looks'];
    final looks = (looksRaw is List)
        ? looksRaw.cast<String>().join(', ')
        : looksRaw?.toString();
    final skills = (t['skills'] is List) ? (t['skills'] as List).cast<String>() : null;
    final parts = <String>[];
    if (gender != 'any') parts.add(gender);
    if (minAge != null || maxAge != null) parts.add('${minAge ?? '-'}-${maxAge ?? '-'}');
    if (looks != null && looks.isNotEmpty) parts.add(looks);
    if (skills != null && skills.isNotEmpty) parts.add(skills.take(3).join(', '));
    if (parts.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: AppColors.goldBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Text(parts.join(' • '), style: const TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600)),
    );
  }
}

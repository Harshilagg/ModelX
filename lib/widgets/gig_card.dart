import 'package:flutter/material.dart';
import '../ui/app_theme.dart';
import 'status_pill.dart';
import 'app_tag.dart';

/// Job card for brand-posted gigs, shown to models in the jobs feed and to
/// brands in their own gig management screens. Shares its visual language
/// (card shell, chip style, meta row) with [CastingCard] even though the two
/// stay separate widgets — they render different data shapes.
class GigCard extends StatelessWidget {
  final String projectTitle;
  final String description;
  final String? brandName;
  final Widget? actionWidget;
  final bool showBrandHeader;
  final Map<String, dynamic> physicalAttributes;
  final List<String> eyeColors;
  final List<String> hairColors;
  final List<String> skinComplexion;

  final String timeline;
  final int durationHours;
  final String budgetType;
  final String budgetAmount;

  final int applications;
  final String status;
  final DateTime createdAt;

  const GigCard({
    super.key,
    this.brandName,
    this.actionWidget,
    this.showBrandHeader = false,
    required this.projectTitle,
    required this.description,
    required this.physicalAttributes,
    required this.eyeColors,
    required this.hairColors,
    required this.skinComplexion,
    required this.timeline,
    required this.durationHours,
    required this.budgetType,
    required this.budgetAmount,
    required this.applications,
    required this.status,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= BRAND HEADER =================
          if (showBrandHeader && brandName != null) ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.paperRaised,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.business_rounded, size: 18, color: AppColors.inkSoft),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    brandName!,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                if (actionWidget != null) actionWidget!,
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 4),
          ],
          // ================= TITLE =================
          Text(
            projectTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),

          const SizedBox(height: AppSpacing.sm + 4),

          // ================= ATTRIBUTES =================
          _attributeSection('Eye color', _listChips(eyeColors)),
          _attributeSection('Hair color', _listChips(hairColors)),
          _attributeSection('Skin complexion', _listChips(skinComplexion)),
          _measurementsSection(),

          // ================= DESCRIPTION =================
          const Text(
            'About the job',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.5),
          ),

          const SizedBox(height: AppSpacing.sm + 4),

          // ================= JOB DETAILS =================
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _detailText('Timeline: $timeline'),
              _detailText('Duration: ${durationHours}hrs'),
              _detailText('$budgetType: ₹$budgetAmount'),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ================= META =================
          Row(
            children: [
              Text(
                '$applications applications',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink),
              ),
              _dot(),
              StatusPill(status: status),
              _dot(),
              _meta(_timeAgo(createdAt)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
            ],
          ),
        ],
      ),
    );
  }

  // ================= CHIPS =================

  Widget _chip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: AppTag(text),
    );
  }

  // ================= HELPERS =================

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

  Widget _measurementsSection() {
    final List<Widget> chips = [];

    void addRange(String label, Map<String, dynamic>? range, String unit) {
      if (range == null || range['min'] == null || range['max'] == null) return;
      chips.add(_chip('$label: ${range['min']}–${range['max']} $unit'));
    }

    addRange('Height', physicalAttributes['height'], 'cm');
    addRange('Chest', physicalAttributes['chest'], 'in');
    addRange('Waist', physicalAttributes['waist'], 'in');
    addRange('Hips', physicalAttributes['hips'], 'in');
    addRange('Shoulder', physicalAttributes['shoulderWidth'], 'in');
    addRange('Inseam', physicalAttributes['inseam'], 'in');

    if (chips.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Measurements',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: chips),
          ),
        ],
      ),
    );
  }

  Widget _attributeSection(String title, List<Widget> chips) {
    if (chips.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: chips),
          ),
        ],
      ),
    );
  }

  List<Widget> _listChips(List<String> values) {
    return values.map((v) => _chip(v)).toList();
  }
}

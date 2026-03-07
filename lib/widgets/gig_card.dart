import 'package:flutter/material.dart';

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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= BRAND HEADER =================
          if (showBrandHeader && brandName != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blue.withOpacity(0.15),
                  child: const Icon(Icons.business, size: 18, color: Colors.blue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    brandName!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (actionWidget != null) actionWidget!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          // ================= TITLE =================
          Text(
            projectTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

         // ================= ATTRIBUTES =================
          _attributeSection(
            'Eye Color',
            _listChips(eyeColors),
          ),

          _attributeSection(
            'Hair Color',
            _listChips(hairColors),
          ),

          _attributeSection(
            'Skin Complexion',
            _listChips(skinComplexion),
          ),

          _measurementsSection(),


          const SizedBox(height: 12),

          // ================= DESCRIPTION =================
          const Text(
            'About the Job',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500, // 🔥 more visible
              color: Colors.black87,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 12),

          // ================= JOB DETAILS =================
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _detailText('Timeline: $timeline'),
              _detailText('Duration: ${durationHours}hrs'),
              _detailText('$budgetType: ₹$budgetAmount'),
            ],
          ),

          const SizedBox(height: 16),

          // ================= META =================
          Row(
            children: [
              Text(
                '$applications Applications',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // 🔥 bigger & clearer
                ),
              ),
              _dot(),
              _statusBadge(status),
              _dot(),
              _meta(_timeAgo(createdAt)),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  // ================= ATTRIBUTES =================

  Widget _chip(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ================= HELPERS =================

  Widget _detailText(String text) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      );

  Widget _meta(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      );

  Widget _dot() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
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
    if (range == null ||
        range['min'] == null ||
        range['max'] == null) return;

    chips.add(
      _chip('$label: ${range['min']}–${range['max']} $unit'),
    );
  }

  addRange('Height', physicalAttributes['height'], 'cm');
  addRange('Chest', physicalAttributes['chest'], 'in');
  addRange('Waist', physicalAttributes['waist'], 'in');
  addRange('Hips', physicalAttributes['hips'], 'in');
  addRange('Shoulder', physicalAttributes['shoulderWidth'], 'in');
  addRange('Inseam', physicalAttributes['inseam'], 'in');

  if (chips.isEmpty) return const SizedBox();

  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Measurements',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: chips,
          ),
        ),
      ],
    ),
  );
}

Widget _attributeSection(String title, List<Widget> chips) {
  if (chips.isEmpty) return const SizedBox();

  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: chips,
          ),
        ),
      ],
    ),
  );
}

List<Widget> _listChips( List<String> values) {
  return values.map((v) => _chip('$v')).toList();
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
    case 'draft':
      label = 'Draft';
      color = Colors.grey.shade700;
      bgColor = Colors.grey.withOpacity(0.15);
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

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}



}

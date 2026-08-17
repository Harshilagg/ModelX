import 'package:flutter/material.dart';
import '../ui/app_theme.dart';

/// A single, consistent status indicator for casting/gig application
/// status — replaces the duplicated `_statusBadge` helpers previously
/// reimplemented separately in GigCard, CastingCard, and JobsPage.
///
/// Accepts the raw status string as stored in Firestore (case-insensitive,
/// e.g. 'applied', 'SHORTLISTED', 'Negotiating', 'ACCEPTED', 'open',
/// 'draft', 'rejected', 'booked') and maps it to a consistent look.
class StatusPill extends StatelessWidget {
  final String status;

  const StatusPill({super.key, required this.status});

  _StatusStyle get _style {
    switch (status.toUpperCase()) {
      case 'APPLIED':
      case 'PENDING':
        return _StatusStyle(
          label: 'Applied',
          fg: AppColors.inkSoft,
          bg: AppColors.paperRaised,
          border: AppColors.lineStrong,
        );
      case 'SHORTLISTED':
        return _StatusStyle(
          label: 'Shortlisted',
          fg: AppColors.gold,
          bg: AppColors.goldBg,
          border: Colors.transparent,
        );
      case 'NEGOTIATING':
        return _StatusStyle(
          label: 'Negotiating',
          fg: AppColors.gold,
          bg: AppColors.goldBg,
          border: Colors.transparent,
        );
      case 'ACCEPTED':
      case 'BOOKED':
        return _StatusStyle(
          label: status.toUpperCase() == 'BOOKED' ? 'Booked' : 'Accepted',
          fg: AppColors.paper,
          bg: AppColors.ink,
          border: Colors.transparent,
        );
      case 'OPEN':
        return _StatusStyle(
          label: 'Open',
          fg: AppColors.success,
          bg: AppColors.successBg,
          border: Colors.transparent,
        );
      case 'DRAFT':
        return _StatusStyle(
          label: 'Draft',
          fg: AppColors.inkFaint,
          bg: AppColors.paperRaised,
          border: AppColors.lineStrong,
        );
      case 'REJECTED':
      case 'CLOSED':
        return _StatusStyle(
          label: status.toUpperCase() == 'CLOSED' ? 'Closed' : 'Not selected',
          fg: AppColors.select,
          bg: AppColors.paperRaised,
          border: Colors.transparent,
        );
      default:
        return _StatusStyle(
          label: status,
          fg: AppColors.inkSoft,
          bg: AppColors.paperRaised,
          border: AppColors.lineStrong,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: s.border == Colors.transparent ? null : Border.all(color: s.border),
      ),
      child: Text(
        s.label,
        style: TextStyle(
          color: s.fg,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _StatusStyle {
  final String label;
  final Color fg;
  final Color bg;
  final Color border;
  _StatusStyle({required this.label, required this.fg, required this.bg, required this.border});
}

import 'package:flutter/material.dart';
import '../ui/app_theme.dart';

enum AppTagVariant { neutral, outline, gold, success }

/// A single, consistent tag/chip primitive — extracts the identical
/// private `_chip()` helper previously hand-rolled separately in
/// `gig_card.dart` and `casting_card.dart` (their own comments flagged
/// it as duplicated). Named `AppTag`, not `Badge`, to avoid the
/// existing unused `badge.dart`, whose `Badge` class shadows Flutter
/// Material's own built-in `Badge` widget.
class AppTag extends StatelessWidget {
  final String label;
  final AppTagVariant variant;
  final IconData? icon;

  const AppTag(this.label, {super.key, this.variant = AppTagVariant.neutral, this.icon});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color? border) = switch (variant) {
      AppTagVariant.neutral => (AppColors.paperRaised, AppColors.inkSoft, AppColors.line),
      AppTagVariant.outline => (Colors.transparent, AppColors.inkSoft, AppColors.lineStrong),
      AppTagVariant.gold => (AppColors.goldBg, AppColors.gold, null),
      AppTagVariant.success => (AppColors.successBg, AppColors.success, null),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppIconSize.xs, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

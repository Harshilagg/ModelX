import 'package:flutter/material.dart';
import '../ui/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool flat;

  const AppCard({super.key, required this.child, this.padding, this.onTap, this.flat = false});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
        boxShadow: flat ? null : AppShadows.card,
      ),
      child: child,
    );

    if (onTap != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(onTap: onTap, child: card),
      );
    }
    return card;
  }
}

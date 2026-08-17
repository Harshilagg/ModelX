import 'package:flutter/material.dart';
import '../ui/app_theme.dart';

enum AppButtonVariant { primary, secondary, ghost, destructive }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = false,
    this.icon,
  });

  /// Kept for backwards compatibility with existing call sites built
  /// against the old `primary: bool` API.
  const AppButton.legacy({
    super.key,
    required this.label,
    this.onPressed,
    bool primary = true,
    this.loading = false,
    this.expand = false,
    this.icon,
  }) : variant = primary ? AppButtonVariant.primary : AppButtonVariant.secondary;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: variant == AppButtonVariant.primary || variant == AppButtonVariant.destructive
                  ? AppColors.paper
                  : AppColors.ink,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Text(label),
            ],
          );

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(onPressed: disabled ? null : onPressed, child: child);
        break;
      case AppButtonVariant.destructive:
        button = ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.select),
          child: child,
        );
        break;
      case AppButtonVariant.secondary:
        button = OutlinedButton(onPressed: disabled ? null : onPressed, child: child);
        break;
      case AppButtonVariant.ghost:
        button = TextButton(onPressed: disabled ? null : onPressed, child: child);
        break;
    }

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

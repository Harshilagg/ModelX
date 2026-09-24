import 'package:flutter/material.dart';
import 'kit/kit.dart';

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
  }) : variant = primary
           ? AppButtonVariant.primary
           : AppButtonVariant.secondary;

  @override
  Widget build(BuildContext context) {
    // Forwards to the shared pill rather than drawing its own button.
    //
    // Every brand and agency screen is built from this one, so routing
    // it here moves all of them onto the new shape without editing each
    // in turn -- the same approach the type roles take.
    //
    // The destructive variant collapses into the outlined one. The
    // palette has a rejected hue but it is a fill for status, and a red
    // button in a design with a single accent reads as an error state
    // rather than an action. The wording carries the warning instead.
    return AppPillButton(
      label: label,
      onPressed: onPressed,
      busy: loading,
      expand: expand,
      leading: icon == null ? null : Icon(icon, size: 18),
      kind: switch (variant) {
        AppButtonVariant.primary => AppButtonKind.filled,
        AppButtonVariant.secondary ||
        AppButtonVariant.destructive => AppButtonKind.outlined,
        AppButtonVariant.ghost => AppButtonKind.ghost,
      },
    );
  }
}

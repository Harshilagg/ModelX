import 'package:flutter/material.dart';
import '../ui/app_theme.dart';
import 'app_button.dart';

/// A bottom-anchored, safe-area-aware primary action bar — the app's
/// thumb-reachable primary-action pattern. Use on any screen with one
/// clear main action (Save, Post, Apply, Message) instead of an inline
/// button wherever a `Column` happens to end.
class AppActionBar extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData? primaryIcon;

  const AppActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoading = false,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: const Border(top: BorderSide(color: AppColors.line)),
        boxShadow: AppShadows.raised,
      ),
      child: Row(
        children: [
          if (secondaryLabel != null && onSecondary != null) ...[
            AppButton(
              label: secondaryLabel!,
              onPressed: onSecondary,
              variant: AppButtonVariant.secondary,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: AppButton(
              label: primaryLabel,
              onPressed: onPrimary,
              loading: primaryLoading,
              icon: primaryIcon,
              expand: true,
            ),
          ),
        ],
      ),
    );
  }
}

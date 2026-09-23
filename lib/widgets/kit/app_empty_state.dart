import 'package:flutter/material.dart';

import '../../ui/app_type.dart';
import '../../ui/board_theme.dart';
import 'app_metrics.dart';
import 'app_pill_button.dart';

/// What a list says when it has nothing in it.
///
/// Worded as a next step rather than a report of absence: "Applying to a
/// job brings it here" tells someone what to do, where "No items" tells
/// them only that the screen works.
class AppEmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData? icon;

  /// Optional way out of the empty state.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Inline empties -- inside a card -- get less vertical room than a
  /// whole-screen one.
  final bool compact;

  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppMetrics.gutter,
        vertical: compact ? 20 : 48,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 24 : 32, color: p.onSurfaceFaint),
            const SizedBox(height: 14),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppType.heading(fontSize: compact ? 16 : 18, color: p.onSurface),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppType.body(fontSize: 14, color: p.onSurfaceSoft),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            AppPillButton(
              label: actionLabel!,
              onPressed: onAction,
              kind: AppButtonKind.outlined,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}

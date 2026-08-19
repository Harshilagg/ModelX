import 'package:flutter/material.dart';
import '../ui/app_theme.dart';

/// Extracts `post_gig_page.dart`'s existing bottom-sheet recipe
/// (`paperRaised` background, rounded top corners) into one place, so
/// the several screens getting their first bottom sheet in this
/// redesign don't each reinvent it.
class AppSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool scrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: scrollControlled,
      backgroundColor: AppColors.paperRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: builder,
    );
  }
}

/// A themed dialog wrapper, matching the sheet's surface/radius so a
/// modal and a sheet read as the same family of overlay.
class AppModal {
  static Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder}) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: builder(context),
      ),
    );
  }
}

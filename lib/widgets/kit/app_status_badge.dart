import 'package:flutter/material.dart';

import '../../ui/app_type.dart';
import '../../ui/board_palette.dart';
import '../../ui/board_theme.dart';
import 'app_metrics.dart';

/// The five states an application or posting can be in, as far as the
/// interface is concerned.
///
/// Firestore stores free-ish text -- 'applied', 'SHORTLISTED',
/// 'Negotiating', 'accepted', 'not selected', 'closed' -- written by
/// several different screens over time. Nothing normalises it and
/// nothing will, because changing stored values is out of scope. So the
/// classification lives here instead, in one place, and every surface
/// that shows a status agrees by construction.
enum AppStatus {
  /// The default. Deliberately not a hue -- it is the absence of news.
  applied,

  /// Someone is looking: shortlisted, called back, invited, under review.
  shortlisted,

  /// Terms are moving.
  negotiating,

  /// Confirmed work.
  booked,

  /// Over, one way or another.
  rejected,

  /// A posting accepting applicants. Carries no fill: it is the normal
  /// state of a job, not news about one.
  open;

  /// Classifies a stored status string.
  ///
  /// Substring matching, not equality, because the stored vocabulary is
  /// inconsistent and always has been. Order matters: 'not selected'
  /// must lose to rejection before 'select' can win for booking.
  static AppStatus parse(String raw) {
    final s = raw.trim().toLowerCase();

    if (s.contains('reject') ||
        s.contains('declin') ||
        s.contains('not selected') ||
        s.contains('closed')) {
      return AppStatus.rejected;
    }
    if (s.contains('book') ||
        s.contains('confirm') ||
        s.contains('accept') ||
        (s.contains('select') && !s.contains('not'))) {
      return AppStatus.booked;
    }
    if (s.contains('negotiat')) return AppStatus.negotiating;
    if (s.contains('callback') ||
        s.contains('shortlist') ||
        s.contains('invite') ||
        s.contains('review')) {
      return AppStatus.shortlisted;
    }
    if (s.contains('open')) return AppStatus.open;
    return AppStatus.applied;
  }

  /// Sentence case, and worded for the person reading it: a model is
  /// told "Not selected", never "Rejected".
  String get label => switch (this) {
        AppStatus.applied => 'Applied',
        AppStatus.shortlisted => 'Shortlisted',
        AppStatus.negotiating => 'Negotiating',
        AppStatus.booked => 'Booked',
        AppStatus.rejected => 'Not selected',
        AppStatus.open => 'Open',
      };

  /// True once a posting has moved past the initial application -- the
  /// thing worth telling someone about.
  bool get hasMoved => this != AppStatus.applied && this != AppStatus.open;

  /// Whether this belongs in the "needs your attention" slot.
  ///
  /// A rejection needs nothing from anyone and leading with it is a poor
  /// first thing to see, so it is excluded even though it is news.
  bool get needsAttention => switch (this) {
        AppStatus.booked || AppStatus.negotiating || AppStatus.shortlisted => true,
        _ => false,
      };

  /// Sort key for choosing between several. Lower comes first.
  int get urgency => switch (this) {
        AppStatus.booked => 0,
        AppStatus.negotiating => 1,
        AppStatus.shortlisted => 2,
        AppStatus.applied => 3,
        AppStatus.open => 4,
        AppStatus.rejected => 5,
      };

  Color fill(BoardPalette p) => switch (this) {
        AppStatus.applied => p.applied,
        AppStatus.shortlisted => p.negotiating,
        AppStatus.negotiating => p.negotiating,
        AppStatus.booked => p.booked,
        AppStatus.rejected => p.rejected,
        AppStatus.open => Colors.transparent,
      };
}

/// A status, shown the same way everywhere.
///
/// Replaces the board's `FlapTile.status` and the older `StatusPill`,
/// which had drifted apart: one rendered tracked uppercase on a square
/// tile, the other a bold pill on a different palette entirely.
class AppStatusBadge extends StatelessWidget {
  final AppStatus status;

  /// Overrides the wording. The counts on the Up next card reuse the
  /// badge with their own labels ("To review"), and a brand reads the
  /// same stored status differently from a model.
  final String? label;

  final bool dense;

  const AppStatusBadge(
    this.status, {
    super.key,
    this.label,
    this.dense = false,
  });

  /// Convenience for the common case: a raw Firestore value.
  factory AppStatusBadge.parse(
    String raw, {
    Key? key,
    String? label,
    bool dense = false,
  }) =>
      AppStatusBadge(AppStatus.parse(raw), key: key, label: label, dense: dense);

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    final fill = status.fill(p);
    final isOpen = status == AppStatus.open;

    // The hues are fills and nothing is tinted on top of them, which is
    // what keeps a mixed list reading flat. Amber is the one that needs
    // thought: it is light enough that bone-white on it fails to read,
    // so it alone takes ink.
    final Color foreground = isOpen
        ? p.onSurfaceSoft
        : (status == AppStatus.shortlisted || status == AppStatus.negotiating)
            ? p.ink
            : p.onPanel;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: isOpen ? Colors.transparent : fill,
        borderRadius: AppRadii.pill,
        border: isOpen ? Border.all(color: p.line) : null,
      ),
      child: Text(
        label ?? status.label,
        style: AppType.label(
          fontSize: dense ? 11 : 12,
          color: foreground,
        ),
      ),
    );
  }
}

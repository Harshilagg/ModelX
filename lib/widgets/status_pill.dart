import 'package:flutter/material.dart';

import 'kit/kit.dart';

/// A status indicator, as the agency and brand screens ask for it.
///
/// Forwards to [AppStatusBadge] rather than keeping its own mapping.
/// There were two classifiers in the app doing the same job from
/// different vocabularies -- this one and the board's -- and they
/// disagreed: it rendered 'shortlisted' and 'negotiating' identically
/// while the board gave them different meanings, and its "not selected"
/// branch could be reached by a value the board read as a booking.
///
/// Kept as a name rather than deleted because six screens reference it,
/// and swapping a type across all of them is a rename for the day those
/// screens are rebuilt, not for today.
class StatusPill extends StatelessWidget {
  /// The raw status as stored -- case and wording vary by which screen
  /// wrote it.
  final String status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) => AppStatusBadge.parse(status);
}

import 'package:flutter/material.dart';

import '../../ui/app_type.dart';
import '../../ui/board_theme.dart';
import 'app_metrics.dart';
import 'app_pill_button.dart';
import 'app_status_badge.dart';

/// One tally on the Up next card.
class UpNextCount {
  final String label;
  final int value;
  final VoidCallback? onTap;

  const UpNextCount({required this.label, required this.value, this.onTap});
}

/// What needs attention, and how much of everything else there is.
///
/// Replaces the departures board. The board showed a list of rows
/// styled as a split-flap display, with a countdown reading
/// "NO CALL SCHEDULED" whenever nothing was booked -- which for most
/// people was most of the time, so the most prominent thing on Home
/// said nothing.
///
/// This shows the single item that needs a decision, and four counts
/// that each open the jobs list already filtered. It is the same widget
/// for models, brands and agencies; only the feed and the labels differ.
class UpNextCard extends StatelessWidget {
  /// Null when nothing needs attention, which shows the empty state
  /// rather than a stale item.
  final UpNextItem? item;

  final List<UpNextCount> counts;

  /// Shown in place of the item when there is nothing to act on.
  final String emptyMessage;

  final bool loading;

  const UpNextCard({
    super.key,
    required this.item,
    required this.counts,
    required this.emptyMessage,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: p.ink,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Up next', style: AppType.label(color: p.onPanelSoft)),
          const SizedBox(height: 12),
          if (loading)
            _Placeholder(colour: p.onPanel.withValues(alpha: 0.08))
          else if (item == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                emptyMessage,
                style: AppType.body(fontSize: 14, color: p.onPanelSoft),
              ),
            )
          else
            _Item(item!),
          if (counts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: p.onPanel.withValues(alpha: 0.12), height: 1),
            _Counts(counts: counts),
          ],
        ],
      ),
    );
  }
}

/// The headline item.
class UpNextItem {
  final String title;

  /// One line of context: who posted it, and when it shoots.
  final String subtitle;

  final AppStatus status;
  final VoidCallback onOpen;

  const UpNextItem({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onOpen,
  });
}

class _Item extends StatelessWidget {
  final UpNextItem item;
  const _Item(this.item);

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.heading(color: p.onPanel),
              ),
            ),
            const SizedBox(width: 12),
            AppStatusBadge(item.status, dense: true),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          item.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppType.body(fontSize: 14, color: p.onPanelSoft),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: AppPillButton(
            label: 'Open',
            kind: AppButtonKind.outlined,
            expand: false,
            height: AppMetrics.tapTarget,
            onPressed: item.onOpen,
          ),
        ),
      ],
    );
  }
}

class _Counts extends StatelessWidget {
  final List<UpNextCount> counts;
  const _Counts({required this.counts});

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);

    return Row(
      children: [
        for (final c in counts)
          Expanded(
            child: Semantics(
              button: c.onTap != null,
              label: '${c.value} ${c.label}',
              child: GestureDetector(
                onTap: c.onTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        '${c.value}',
                        // Tabular, so a count ticking 9 to 10 does not
                        // shift the three beside it.
                        style: AppType.tabular(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: p.onPanel,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppType.caption(color: p.onPanelSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  final Color colour;
  const _Placeholder({required this.colour});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final width in [0.7, 0.45]) ...[
        FractionallySizedBox(
          widthFactor: width,
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ],
  );
}

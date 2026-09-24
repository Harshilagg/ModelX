import 'package:flutter/material.dart';
import '../ui/board_theme.dart';
import 'board_widgets.dart';

/// The opened job posting (style board 7a).
///
/// Gigs and castings store different fields but a model reads them the
/// same way: what is it, who's calling, when does it shoot, what are
/// they asking for, and am I in. Both detail pages map their own
/// document onto this one view so the two never drift apart visually.
///
/// Every section is optional. A posting that never filled in talent
/// requirements simply doesn't render that band, rather than printing a
/// column of dashes.
class BoardJobDetail extends StatelessWidget {
  final String title;
  final String posterLine;
  final String description;
  final String status;

  /// Ordered key/value pairs for the top spec table.
  final List<(String, String)> details;

  /// The two big wells — usually gender and age range.
  final List<(String, String)> highlights;

  /// Label → the values that posting actually requires.
  final List<(String, List<String>)> chipGroups;

  /// Free-form measurement ranges, already formatted.
  final List<String> measurements;

  final String applicationsLine;
  final String depLabel;
  final String depValue;

  final bool hasApplied;
  final bool applying;
  final VoidCallback? onApply;
  final String appliedLabel;

  const BoardJobDetail({
    super.key,
    required this.title,
    required this.posterLine,
    required this.description,
    required this.status,
    required this.details,
    this.highlights = const [],
    this.chipGroups = const [],
    this.measurements = const [],
    required this.applicationsLine,
    this.depLabel = 'DEP DATE',
    this.depValue = '—',
    required this.hasApplied,
    this.applying = false,
    this.onApply,
    this.appliedLabel = 'Applied',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoardColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _breadcrumb(context),
            _heroBand(),
            Expanded(child: _body()),
          ],
        ),
      ),
      bottomNavigationBar: _actionBar(),
    );
  }

  Widget _breadcrumb(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(
              Icons.arrow_back,
              size: 18,
              color: BoardColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BoardType.title(fontSize: 14, letterSpacing: 1.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBand() {
    return Container(
      color: BoardColors.ink,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      // Two lines, not three. Sentence case fits more
                      // per line than the condensed capitals this
                      // replaced, and a third line of 32pt type pushed
                      // the hero past the screen at large text sizes --
                      // the band does not scroll.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BoardType.display(
                        fontSize: 32,
                        color: BoardColors.onInk,
                      ),
                    ),
                    if (posterLine.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        posterLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BoardType.mono(
                          fontSize: 10.5,
                          color: BoardColors.onInkSoft,
                          letterSpacing: 0.6,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FlapTile.status(status),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: BoardType.body(
                fontSize: 13,
                color: BoardColors.onInk.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        if (details.isNotEmpty) ...[
          const BoardSectionLabel('Casting details'),
          const SizedBox(height: 7),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < details.length; i++)
                SpecRow(
                  label: details[i].$1,
                  value: details[i].$2,
                  bottomBorder: i == details.length - 1,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        if (highlights.isNotEmpty) ...[
          const BoardSectionLabel('Talent requirements'),
          const SizedBox(height: 7),
          // IntrinsicHeight, not a bare stretch: inside a ListView the
          // Row's height is unbounded, and stretching against an
          // unbounded cross axis asks children to lay out at infinite
          // height. This measures the taller well first, then matches
          // the other to it.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < highlights.length; i++) ...[
                  Expanded(
                    child: BoardStatWell(
                      label: highlights[i].$1,
                      value: highlights[i].$2,
                      flap: false,
                      valueSize: 15,
                    ),
                  ),
                  if (i != highlights.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        for (final group in chipGroups)
          if (group.$2.isNotEmpty) ...[
            BoardSectionLabel(group.$1),
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                // Mushroom, not brass: these state a requirement, they
                // don't signal a status. Keeping the hues off them is
                // what leaves green/amber/red meaning something.
                for (final v in group.$2)
                  MonoChip(
                    v,
                    neutral: true,
                    fontSize: 10,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

        if (measurements.isNotEmpty) ...[
          const BoardSectionLabel('Measurements'),
          const SizedBox(height: 6),
          // A wrap rather than a fixed 2-column grid: a range like
          // "SHOULDER 34–43 IN" is much wider than "CHEST 32–46 IN", and
          // forcing both into one column width is what clipped them.
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final m in measurements)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: BoardColors.card,
                    border: Border.all(color: BoardColors.inkLine),
                  ),
                  child: Text(m, style: BoardType.mono(fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        Container(
          color: BoardColors.ink,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  applicationsLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BoardType.mono(
                    fontSize: 9.5,
                    color: BoardColors.onInkSoft,
                    letterSpacing: 0.95,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionBar() {
    return Container(
      color: BoardColors.ink,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    depLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.mono(
                      fontSize: 9.5,
                      color: BoardColors.onInkSoft,
                      letterSpacing: 0.95,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    depValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.mono(
                      fontSize: 13,
                      color: BoardColors.onInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (applying)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: BoardColors.onInk,
                ),
              )
            else if (hasApplied)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: BoardColors.onInk.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  appliedLabel,
                  style: BoardType.title(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.35,
                    color: BoardColors.onInkFaint,
                  ),
                ),
              )
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onApply,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: BoardColors.brass,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Apply',
                    style: BoardType.title(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.35,
                      color: BoardColors.ink,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// A "featured item + varied grid" layout — for discovery/browse
/// screens (open castings, gigs) that would otherwise render as a
/// uniform vertical stack of identical cards. Not for a chronological
/// post feed, where the real content — who posted, when, likes,
/// comments — is a linear stream and shouldn't be reordered into a
/// grid; use this only where the underlying content is genuinely a
/// browsable set (jobs/castings, search results), not a timeline.
///
/// [featured] renders full-width and large. [tiles] are grouped into
/// repeating mosaic blocks (one tall tile beside two stacked small
/// ones) so the eye has a path, with any remainder rendered as a
/// plain 2-column grid.
class AppFeaturedGrid extends StatelessWidget {
  final Widget? featured;
  final List<Widget> tiles;
  final double gap;
  final double mosaicHeight;

  const AppFeaturedGrid({
    super.key,
    this.featured,
    required this.tiles,
    this.gap = 6,
    this.mosaicHeight = 226,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    if (featured != null) blocks.add(featured!);

    var i = 0;
    while (i + 3 <= tiles.length) {
      blocks.add(_MosaicBlock(
        tall: tiles[i],
        smallTop: tiles[i + 1],
        smallBottom: tiles[i + 2],
        gap: gap,
        height: mosaicHeight,
      ));
      i += 3;
    }

    final remainder = tiles.sublist(i);
    if (remainder.isNotEmpty) {
      blocks.add(
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio: 3 / 4,
          children: remainder,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in blocks) ...[b, SizedBox(height: gap * 2)],
      ],
    );
  }
}

class _MosaicBlock extends StatelessWidget {
  final Widget tall;
  final Widget smallTop;
  final Widget smallBottom;
  final double gap;
  final double height;

  const _MosaicBlock({
    required this.tall,
    required this.smallTop,
    required this.smallBottom,
    required this.gap,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 13, child: tall),
          SizedBox(width: gap),
          Expanded(
            flex: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: smallTop),
                SizedBox(height: gap),
                Expanded(child: smallBottom),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

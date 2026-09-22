import 'package:flutter/material.dart';

/// A two-column masonry for portfolio shots.
///
/// A uniform grid crops every photograph to the same rectangle, which is
/// the one thing a portfolio must not do: a full-length and a headshot
/// are different shapes, and flattening them makes a book of strong work
/// look like a contact sheet.
///
/// Heights come from a repeating set of ratios rather than from the
/// images themselves. Measuring each file would mean downloading it
/// before laying anything out — a blank screen, then a reflow. The cycle
/// is chosen so the two columns stagger against each other and no tile
/// ever drops below [minHeight], because a shot too small to read is
/// worse than a uniform one.
class PortfolioMasonry extends StatelessWidget {
  final int itemCount;

  /// Builds one tile. The height is supplied so the tile can size its
  /// own media; it is already at least [minHeight].
  final Widget Function(BuildContext context, int index, double height) itemBuilder;

  final double gap;
  final double minHeight;

  const PortfolioMasonry({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.gap = 8,
    this.minHeight = 168,
  });

  /// Portrait-leaning, because most of this work is people standing up.
  /// The two columns read different positions in the cycle, so they never
  /// line up into rows.
  static const _ratios = [1.42, 1.06, 1.24, 0.98, 1.34, 1.12];

  double _heightFor(int index, double width) {
    final ratio = _ratios[index % _ratios.length];
    final height = width * ratio;
    return height < minHeight ? minHeight : height;
  }

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - gap) / 2;

        // Shortest-column placement rather than strict alternation:
        // alternating leaves one column dangling when the run of ratios
        // happens to favour it.
        final columns = <List<Widget>>[[], []];
        final heights = <double>[0, 0];

        for (var i = 0; i < itemCount; i++) {
          final target = heights[0] <= heights[1] ? 0 : 1;
          final height = _heightFor(i, columnWidth);

          columns[target].add(
            Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: SizedBox(
                height: height,
                child: itemBuilder(context, i, height),
              ),
            ),
          );
          heights[target] += height + gap;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, children: columns[0]),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, children: columns[1]),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../ui/app_type.dart';
import 'app_metrics.dart';
import 'nav_glyphs.dart';

/// One destination in the bar.
class NavDestination {
  final String label;
  final NavGlyph glyph;

  const NavDestination({required this.label, required this.glyph});
}

/// The bottom bar: a dark pill of icons where only the chosen one is
/// named.
///
/// Labels appear on selection rather than sitting under every icon.
/// Five permanent labels at a legible size is most of the bar's width,
/// which is why the old one had none at all and left the glyphs to
/// explain themselves.
class AppNavBar extends StatelessWidget {
  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Fills the circle behind the chosen glyph.
  final Color accent;

  const AppNavBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
    this.accent = const Color(0xFFF2EFE8),
  });

  /// The bar's own height. The glyphs are drawn shapes rather than
  /// text, so this does not move with the system font scale -- which is
  /// what lets the shell place the assistant button above it without
  /// measuring anything.
  static const double height = 62;

  static const Color _bar = Color(0xFF141413);
  static const Color _barEdge = Color(0xFF262624);
  static const Color _selectedPill = Color(0xFF232322);
  static const Color _restGlyph = Color(0xFF9A9892);
  static const Color _label = Color(0xFFF2EFE8);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _bar,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: _barEdge),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          const resting = 48.0;

          // The selected pill takes whatever is left once every other
          // destination has its circle. The design fixes it at 112,
          // which fits four destinations on a 390pt phone exactly --
          // and overflows the moment there is a fifth.
          final free =
              constraints.maxWidth -
              resting * (destinations.length - 1) -
              gap * (destinations.length - 1);
          final selectedWidth = free.clamp(resting, 112.0);

          return Row(
            children: [
              for (var i = 0; i < destinations.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                _Tab(
                  destination: destinations[i],
                  selected: i == currentIndex,
                  width: i == currentIndex ? selectedWidth : resting,
                  accent: accent,
                  onTap: () => onTap(i),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final NavDestination destination;
  final bool selected;
  final double width;
  final Color accent;
  final VoidCallback onTap;

  const _Tab({
    required this.destination,
    required this.selected,
    required this.width,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : AppMotion.medium,
          curve: AppMotion.settle,
          width: width,
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? AppNavBar._selectedPill : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          // The label is clipped away rather than removed, so the pill
          // slides open over it instead of the text appearing in place.
          child: ClipRect(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: reduced ? Duration.zero : AppMotion.medium,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? accent : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: NavGlyphIcon(
                      glyph: destination.glyph,
                      size: 20,
                      color: selected
                          ? const Color(0xFF0B0B0B)
                          : AppNavBar._restGlyph,
                    ),
                  ),
                ),
                if (selected)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: AnimatedOpacity(
                        opacity: selected ? 1 : 0,
                        duration: AppMotion.medium,
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: AppType.label(
                            fontSize: 14,
                            color: AppNavBar._label,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

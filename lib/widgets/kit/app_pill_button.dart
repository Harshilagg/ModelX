import 'package:flutter/material.dart';

import '../../ui/app_type.dart';
import '../../ui/board_theme.dart';
import 'app_metrics.dart';

enum AppButtonKind {
  /// The one action on the screen. Solid, reversed out of the surface.
  filled,

  /// The alternative. Hairline outline, no fill.
  outlined,

  /// A quiet third option -- "Back to start", "Send again".
  ghost,
}

/// The 52px pill every primary action in the new design uses.
///
/// Replaces the old rounded-rectangle `ElevatedButton` styling. Three
/// details from the prototype that are easy to lose and matter:
///
/// * The press feedback is a 1.5% scale-down, not a ripple. On a fully
///   rounded dark button a Material ink splash reads as a smudge.
/// * A busy button swaps its *label* rather than showing a spinner, so
///   the button does not change size and the user is told what is
///   happening ("Creating your profile...") rather than merely that
///   something is.
/// * It keeps its height when the label wraps, because every one of
///   these sits in a footer next to others.
class AppPillButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;

  /// Replaces the label and blocks input while an action runs.
  final String? busyLabel;
  final bool busy;

  /// Drawn before the label. Used by the social buttons.
  final Widget? leading;

  /// Ghost buttons are shorter -- they are not primary actions and
  /// should not carry the same weight.
  final double? height;

  final bool expand;

  const AppPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.filled,
    this.busyLabel,
    this.busy = false,
    this.leading,
    this.height,
    this.expand = true,
  });

  @override
  State<AppPillButton> createState() => _AppPillButtonState();
}

class _AppPillButtonState extends State<AppPillButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    final reduced = AppMotion.reduced(context);

    final (Color bg, Color fg, Color? border) = switch (widget.kind) {
      AppButtonKind.filled => (p.onSurface, p.surface, null),
      AppButtonKind.outlined => (Colors.transparent, p.onSurface, p.lineStrong),
      AppButtonKind.ghost => (Colors.transparent, p.onSurfaceFaint, null),
    };

    final height =
        widget.height ??
        (widget.kind == AppButtonKind.ghost
            ? AppMetrics.tapTarget
            : AppMetrics.control);

    final label = widget.busy
        ? (widget.busyLabel ?? widget.label)
        : widget.label;

    Widget content = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppType.label(
        fontSize: widget.kind == AppButtonKind.ghost ? 14 : 15,
        color: fg,
      ),
    );

    if (widget.leading != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.leading!,
          const SizedBox(width: 10),
          Flexible(child: content),
        ],
      );
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: _enabled ? () => setState(() => _down = false) : null,
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _down && !reduced ? 0.985 : 1,
          duration: AppMotion.quick,
          child: AnimatedOpacity(
            // Disabled is dimmed rather than recoloured, so a disabled
            // primary button still reads as the primary button.
            opacity: _enabled ? 1 : 0.6,
            duration: AppMotion.quick,
            child: Container(
              height: height,
              width: widget.expand ? double.infinity : null,
              padding: EdgeInsets.symmetric(
                horizontal: widget.expand ? 20 : 24,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: AppRadii.pill,
                border: border == null ? null : Border.all(color: border),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

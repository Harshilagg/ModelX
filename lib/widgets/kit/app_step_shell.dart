import 'package:flutter/material.dart';

import '../../ui/app_type.dart';
import '../../ui/board_theme.dart';
import 'app_metrics.dart';

/// A circular 44px icon button -- the back chevron, and the close on a
/// filled photo slot.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final bool bordered;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.bordered = true,
    this.size = AppMetrics.tapTarget,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: bordered ? Border.all(color: p.lineStrong) : null,
          ),
          child: Icon(icon, size: size * 0.45, color: p.onSurface),
        ),
      ),
    );
  }
}

/// The segmented progress rail above a multi-step form.
class AppStepProgress extends StatelessWidget {
  final int step;
  final int total;

  const AppStepProgress({super.key, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    return Semantics(
      value: 'Step ${step + 1} of $total',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: AppMetrics.progressGap),
            Expanded(
              child: AnimatedContainer(
                duration: AppMotion.slow,
                height: AppMetrics.progressBar,
                decoration: BoxDecoration(
                  color: i <= step ? p.onSurface : p.line,
                  borderRadius: AppRadii.pill,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Header, progress, an animated body and a footer pinned above the
/// keyboard.
///
/// Every signup step in the design is this. Three things it takes care
/// of that are easy to get wrong once per screen:
///
/// * The body scrolls back to the top on each step change. Without it,
///   step 3 opens halfway down because step 2 was scrolled.
/// * The footer sits above [MediaQuery.viewInsets], so the primary
///   button is never under the keyboard on a short device.
/// * The step body slides in from the side it came from, so going back
///   looks like going back.
class AppStepShell extends StatefulWidget {
  final int step;
  final int total;

  /// True when the last change was a retreat -- drives the slide
  /// direction.
  final bool reversing;

  final String title;
  final String? hint;

  /// Called on back. On step 0 this leaves the flow entirely, which is
  /// why the label changes with it.
  final VoidCallback onBack;

  final List<Widget> children;

  /// The primary action, plus anything under it.
  final Widget footer;

  const AppStepShell({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    required this.onBack,
    required this.children,
    required this.footer,
    this.hint,
    this.reversing = false,
  });

  @override
  State<AppStepShell> createState() => _AppStepShellState();
}

class _AppStepShellState extends State<AppStepShell> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(AppStepShell old) {
    super.didUpdateWidget(old);
    if (old.step != widget.step && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    final reduced = AppMotion.reduced(context);
    final offset = widget.reversing ? -18.0 : 18.0;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            AppMetrics.topInset(context),
            12,
            0,
          ),
          child: Row(
            children: [
              AppIconButton(
                icon: Icons.chevron_left,
                onPressed: widget.onBack,
                semanticLabel: widget.step == 0 ? 'Go back' : 'Previous step',
              ),
              Expanded(
                child: Text(
                  'Step ${widget.step + 1} of ${widget.total}',
                  textAlign: TextAlign.center,
                  style: AppType.tabular(color: p.onSurfaceSoft),
                ),
              ),
              // Balances the back button so the count is actually
              // centred rather than centred-ish.
              const SizedBox(width: AppMetrics.tapTarget),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.gutter, 16, AppMetrics.gutter, 0),
          child: AppStepProgress(step: widget.step, total: widget.total),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(
              AppMetrics.gutter, 28, AppMetrics.gutter, 24),
            child: TweenAnimationBuilder<double>(
              // Keyed on the step so the tween restarts each time.
              key: ValueKey(widget.step),
              tween: Tween(begin: reduced ? 1 : 0, end: 1),
              duration: reduced ? Duration.zero : AppMotion.step,
              curve: AppMotion.settle,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(offset * (1 - t), 0),
                  child: child,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: AppType.title(color: p.onSurface)),
                  if (widget.hint != null) ...[
                    const SizedBox(height: 10),
                    Text(widget.hint!, style: AppType.body(color: p.onSurfaceSoft)),
                  ],
                  const SizedBox(height: AppMetrics.titleGap),
                  ...widget.children,
                ],
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(top: BorderSide(color: p.line)),
          ),
          padding: EdgeInsets.fromLTRB(
            AppMetrics.gutter,
            16,
            AppMetrics.gutter,
            AppMetrics.bottomInset(context),
          ),
          child: widget.footer,
        ),
      ],
    );
  }
}

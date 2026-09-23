import 'package:flutter/material.dart';

import '../../ui/app_type.dart';
import '../../ui/board_theme.dart';
import 'app_metrics.dart';

/// A 40px selectable pill.
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          height: AppMetrics.chip,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? p.onSurface : Colors.transparent,
            borderRadius: AppRadii.pill,
            border: Border.all(color: selected ? p.onSurface : p.lineStrong),
          ),
          child: Text(
            label,
            style: AppType.label(
              fontSize: 14,
              color: selected ? p.surface : p.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// A wrapped row of chips, single- or multi-select.
///
/// Both modes are one widget because they differ only in what a tap
/// does, and having two would guarantee they drift apart visually.
///
/// Values are held as a list of strings and joined by the caller on
/// write, because the fields these feed are stored as comma-separated
/// text and that shape is not changing.
class AppChipGroup extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  /// When false, choosing one clears the rest. Tapping the chosen one
  /// again clears it -- there is no other way to undo a single-select
  /// that has no "none" option.
  final bool multiSelect;

  const AppChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multiSelect = true,
  });

  void _toggle(String value) {
    if (!multiSelect) {
      onChanged(selected.contains(value) ? const [] : [value]);
      return;
    }
    final next = [...selected];
    next.contains(value) ? next.remove(value) : next.add(value);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          AppChip(
            label: o,
            selected: selected.contains(o),
            onTap: () => _toggle(o),
          ),
      ],
    );
  }
}

/// A segmented control -- the height unit switch, and anything else that
/// is a small set of mutually exclusive choices sitting inline.
///
/// Distinct from [AppChipGroup] with `multiSelect: false` in that this
/// always has exactly one value and cannot be cleared.
class AppSegmentedControl<T> extends StatelessWidget {
  final List<(T value, String label)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// The inline version sits in a label row and is smaller.
  final bool dense;

  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    final height = dense ? 28.0 : AppMetrics.chip;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: p.surfaceField,
        borderRadius: AppRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in options)
            Semantics(
              inMutuallyExclusiveGroup: true,
              selected: v == value,
              button: true,
              child: GestureDetector(
                onTap: () => onChanged(v),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppMotion.quick,
                  height: height,
                  constraints: BoxConstraints(minWidth: dense ? 40 : 64),
                  padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? p.onSurface : Colors.transparent,
                    borderRadius: AppRadii.pill,
                  ),
                  child: Text(
                    label,
                    style: AppType.label(
                      fontSize: dense ? 12 : 14,
                      color: v == value ? p.surface : p.onSurfaceSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

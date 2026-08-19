import 'package:flutter/material.dart';
import '../ui/app_theme.dart';

/// Shared "raised chrome" search box used by all three dashboard shells'
/// top bars. Promoted from the agency-only `agency/widgets/search_bar.dart`
/// so model, brand, and agency dashboards draw from one styled widget
/// instead of three hand-rolled `Container`s with three different shadow
/// recipes. Purely presentational: callers own the controller/behavior
/// (search-as-you-type, submit-to-search-service, recent-search overlays,
/// etc.) via the optional callbacks below — nothing here changes what any
/// existing call site does, only how it looks.
class AppSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  /// Shows a trailing clear ("x") button that clears the field and fires
  /// [onSubmitted] with an empty string — matching the original agency
  /// search bar's clear behavior (`_ctl.clear(); SearchService.setQuery('')`).
  final bool showClearButton;

  const AppSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.showClearButton = false,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  TextEditingController? _internalController;
  TextEditingController get _controller => widget.controller ?? (_internalController ??= TextEditingController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.raised,
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.inkFaint, size: AppIconSize.md),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              onTap: widget.onTap,
              textInputAction: TextInputAction.search,
              style: AppTypography.body,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: widget.hintText,
                hintStyle: AppTypography.body.copyWith(color: AppColors.inkFaint),
              ),
            ),
          ),
          if (widget.showClearButton)
            IconButton(
              onPressed: () {
                _controller.clear();
                widget.onSubmitted?.call('');
              },
              icon: const Icon(Icons.clear, color: AppColors.inkFaint),
              iconSize: AppIconSize.sm,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/app_type.dart';
import '../../ui/board_theme.dart';
import 'app_metrics.dart';

/// Label, control, and the one line underneath that is either a hint or
/// an error -- never both.
///
/// Keeping them in one widget is what stops a form drifting: the label
/// size, the "Optional" marker, the gap to the next field and the error
/// wording all live here rather than being retyped per screen.
class AppField extends StatelessWidget {
  final String label;
  final Widget child;

  /// Shown greyed to the right of the label. The prototype marks what is
  /// optional rather than what is required, which is the right way round
  /// when most fields are required.
  final bool optional;

  /// Guidance shown while there is no error.
  final String? hint;

  /// Replaces the hint when present, and turns the control's border.
  final String? error;

  /// Set to false for the last field in a step.
  final bool spaced;

  const AppField({
    super.key,
    required this.label,
    required this.child,
    this.optional = false,
    this.hint,
    this.error,
    this.spaced = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    final message = error ?? hint;

    return Padding(
      padding: EdgeInsets.only(bottom: spaced ? AppMetrics.fieldGap : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppType.label(color: p.onSurface.withValues(alpha: 0.8)),
                ),
              ),
              if (optional)
                Text('Optional', style: AppType.caption(color: p.onSurfaceFaint)),
            ],
          ),
          const SizedBox(height: 8),
          child,
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message,
              // Errors are announced; hints are not, or a screen reader
              // re-reads every hint on the screen whenever one changes.
              semanticsLabel: error != null ? 'Error: $error' : null,
              style: AppType.label(
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: error != null ? p.rejectedText : p.onSurfaceFaint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The 52px input the whole design uses.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final bool hasError;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? autofillHint;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool autocorrect;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  /// Drawn inside the field at the right -- the "cm" on height.
  final Widget? suffix;

  /// Figures that should not jitter as they are typed or compared.
  final bool tabularFigures;

  final TextAlign textAlign;

  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.hasError = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHint,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.suffix,
    this.tabularFigures = false,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    final multiline = maxLines > 1;

    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autocorrect: autocorrect,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLines: maxLines,
      maxLength: maxLength,
      textAlign: textAlign,
      autofillHints: autofillHint == null ? null : [autofillHint!],
      cursorColor: p.onSurface,
      // 16px is not a style choice: below it, iOS Safari-style zoom
      // kicks in on focus on some webviews and the field jumps.
      style: tabularFigures
          ? AppType.tabular(fontSize: 16, fontWeight: FontWeight.w400, color: p.onSurface)
          : AppType.body(fontSize: 16, color: p.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppType.body(fontSize: 16, color: p.onSurfaceFaint),
        filled: true,
        fillColor: p.surfaceField,
        counterText: '',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: multiline ? 14 : 0,
        ),
        // A fixed height only works for a single line; a textarea has to
        // grow, so the constraint is applied per case.
        constraints: multiline
            ? null
            : const BoxConstraints(minHeight: AppMetrics.control, maxHeight: AppMetrics.control),
        suffixIcon: suffix,
        suffixIconConstraints:
            const BoxConstraints(minHeight: AppMetrics.control, minWidth: 0),
        border: _border(p.line),
        enabledBorder: _border(hasError ? p.rejectedText : p.line),
        focusedBorder: _border(hasError ? p.rejectedText : p.onSurfaceSoft, width: 1.4),
        disabledBorder: _border(p.line),
      ),
    );

    return field;
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadii.fieldRadius,
        borderSide: BorderSide(color: color, width: width),
      );
}

/// A password field with a worded Show / Hide toggle.
///
/// Words rather than an eye icon: the crossed-eye glyph is genuinely
/// ambiguous -- people read it as both "password is hidden" and "tap to
/// hide" -- and the prototype spells it out.
class AppPasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final bool hasError;
  final bool isNew;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  const AppPasswordField({
    super.key,
    this.controller,
    this.hintText,
    this.hasError = false,
    this.isNew = true,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
  });

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);

    return TextField(
      controller: widget.controller,
      obscureText: !_shown,
      // Autocorrect on an obscured field suggests words from the
      // password to the keyboard's dictionary.
      autocorrect: false,
      enableSuggestions: false,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      autofillHints: [widget.isNew ? AutofillHints.newPassword : AutofillHints.password],
      cursorColor: p.onSurface,
      style: AppType.body(fontSize: 16, color: p.onSurface),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: AppType.body(fontSize: 16, color: p.onSurfaceFaint),
        filled: true,
        fillColor: p.surfaceField,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        constraints: const BoxConstraints(
          minHeight: AppMetrics.control,
          maxHeight: AppMetrics.control,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton(
            onPressed: () => setState(() => _shown = !_shown),
            style: TextButton.styleFrom(
              minimumSize: const Size(56, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _shown ? 'Hide' : 'Show',
              style: AppType.label(color: p.onSurfaceSoft),
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minHeight: 36, minWidth: 0),
        border: AppTextField._border(p.line),
        enabledBorder: AppTextField._border(widget.hasError ? p.rejectedText : p.line),
        focusedBorder: AppTextField._border(
          widget.hasError ? p.rejectedText : p.onSurfaceSoft,
          width: 1.4,
        ),
      ),
    );
  }
}

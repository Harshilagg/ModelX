import 'package:flutter/material.dart';
import '../ui/app_theme.dart';

/// A themed input wrapper — the existing `InputDecorationTheme` in
/// `app_theme.dart` already styles a plain `TextFormField` correctly,
/// so this adds only what that theme alone can't: a consistent
/// label/error/helper layout above the field and a password-visibility
/// toggle, for the auth screens that currently have neither.
class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final bool obscureText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final Widget? leadingIcon;

  /// Only used when [obscureText] is false — the built-in password
  /// visibility toggle takes precedence over this for obscured fields.
  final Widget? trailingIcon;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.obscureText = false,
    this.controller,
    this.onChanged,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.leadingIcon,
    this.trailingIcon,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: AppTypography.label.copyWith(color: AppColors.inkSoft, letterSpacing: 0.08),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          obscureText: _obscured,
          maxLines: _obscured ? 1 : widget.maxLines,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          style: AppTypography.bodyEmphasized,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            helperText: widget.helperText,
            prefixIcon: widget.leadingIcon,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: AppIconSize.sm,
                      color: AppColors.inkFaint,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : widget.trailingIcon,
          ),
        ),
      ],
    );
  }
}

/// Zuralog Design System — Text Input Component.
///
/// A styled text input with a Sage Green cursor/caret.
/// Wraps [TextFormField] and delegates decoration to [AppTheme]'s
/// `inputDecorationTheme` for automatic light/dark adaptation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/app_colors.dart';

/// Styled text input field for the Zuralog design system.
///
/// Renders with a Sage Green cursor/caret (`AppColors.primary`) and
/// delegates all border and background styling to the active [ThemeData].
/// Validation is supported via [validator] (use inside a [Form] widget).
///
/// Example usage:
/// ```dart
/// AppTextField(
///   hintText: 'Email address',
///   keyboardType: TextInputType.emailAddress,
///   controller: _emailController,
///   validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
/// )
/// ```
class AppTextField extends StatelessWidget {
  /// Placeholder text shown when the field is empty.
  final String? hintText;

  /// Optional label displayed above the field when focused.
  final String? labelText;

  /// Controller for reading and manipulating the field's text content.
  final TextEditingController? controller;

  /// Validation callback used by [Form.validate()].
  ///
  /// Returns a non-null string to show an error message.
  /// Returns `null` when the input is valid.
  final String? Function(String?)? validator;

  /// The keyboard type to display (e.g., email, number, text).
  final TextInputType? keyboardType;

  /// Whether to obscure input (e.g., for password fields).
  ///
  /// Defaults to `false`.
  final bool obscureText;

  /// Optional widget displayed before the text (e.g., an icon).
  final Widget? prefixIcon;

  /// Optional widget displayed after the text (e.g., clear or visibility toggle).
  final Widget? suffixIcon;

  /// Maximum number of lines for multi-line inputs.
  ///
  /// Defaults to `1` for single-line fields.
  /// Pass `null` for unlimited lines.
  final int? maxLines;

  /// Optional input formatters (e.g., numeric-only, length limit).
  final List<TextInputFormatter>? inputFormatters;

  /// Callback invoked on every character change.
  final ValueChanged<String>? onChanged;

  /// Callback invoked when the user submits the field (e.g., presses Enter).
  final VoidCallback? onSubmitted;

  /// Whether to auto-focus this field when the screen loads.
  ///
  /// Defaults to `false`.
  final bool autofocus;

  /// The action button to show on the keyboard (e.g., done, next, search).
  final TextInputAction? textInputAction;

  /// Creates an [AppTextField].
  const AppTextField({
    super.key,
    this.hintText,
    this.labelText,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
      autofocus: autofocus,
      textInputAction: textInputAction,
      // Sage Green cursor — the brand's primary identity color.
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

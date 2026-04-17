/// Zuralog Design System — Text Input Component.
///
/// A styled text input with a Sage Green cursor/caret.
/// Wraps [TextFormField] and delegates decoration to [AppTheme]'s
/// `inputDecorationTheme` for automatic light/dark adaptation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/theme.dart';

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

  /// Hints for the platform's autofill service (e.g., iOS Keychain, Android autofill).
  ///
  /// Pass values from [AutofillHints] — e.g., `[AutofillHints.email]` or
  /// `[AutofillHints.password]`. When `null`, autofill is not enabled.
  final List<String>? autofillHints;

  /// An optional [FocusNode] to control when this field gains or loses focus.
  ///
  /// Pass a node to programmatically shift focus between fields (e.g., moving
  /// from the email field to the password field on keyboard action).
  final FocusNode? focusNode;

  /// Called when the user presses the keyboard action button (e.g., "Next" or "Done").
  ///
  /// Use this to move focus to the next field or trigger form submission
  /// without consuming the submitted text value.
  final VoidCallback? onEditingComplete;

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
    this.autofillHints,
    this.focusNode,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    // EXPLICIT unfocused border — do not delete. The inputDecorationTheme would
    // otherwise cover this, but having it here locally protects against any
    // future theme change that forgets the dark-mode branch. Phase 6 Plan 6
    // locked this in.
    final unfocusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      borderSide: BorderSide(color: colors.border, width: 1),
    );
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
      autofillHints: autofillHints,
      focusNode: focusNode,
      onEditingComplete: onEditingComplete,
      // Brand primary cursor color — Sage in dark mode, Deep Forest in light.
      cursorColor: colors.primary,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: unfocusedBorder,
        enabledBorder: unfocusedBorder,
      ),
    );
  }
}

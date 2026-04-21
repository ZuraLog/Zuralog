/// Zuralog Design System — Labeled Text Field Component.
///
/// A free-text input with a persistent label above the field. Free-text
/// sibling of [ZLabeledNumberField] — shares the exact same outer layout
/// and border treatment, but accepts arbitrary text (names, notes,
/// descriptions) instead of numeric values.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A labeled free-text input with a persistent label drawn above the field.
///
/// Renders a two-line layout: a secondary-color `labelMedium` label, a
/// small vertical gap, then a [TextFormField] configured for free-text
/// entry. The outline is visible when unfocused and switches to the
/// nutrition category accent color when focused, so users can always see
/// the field boundary even when empty.
///
/// Example usage:
/// ```dart
/// ZLabeledTextField(
///   label: 'Meal name',
///   controller: _nameController,
///   hint: 'e.g. Grilled chicken salad',
/// )
/// ```
class ZLabeledTextField extends StatelessWidget {
  /// The label drawn above the field.
  final String label;

  /// Controller for reading and manipulating the field's text.
  final TextEditingController controller;

  /// Optional placeholder text shown inside the field when it is empty.
  final String? hint;

  /// The action button to show on the keyboard (e.g., next, done).
  final TextInputAction? textInputAction;

  /// The keyboard type. Defaults to [TextInputType.text].
  final TextInputType? keyboardType;

  /// Whether the entered text should be obscured (e.g. for passwords).
  /// When `true`, [maxLines] is forced to 1.
  final bool obscureText;

  /// Maximum number of lines to display. Defaults to `1`. Pass `null` for
  /// an unlimited, vertically-expanding field.
  final int? maxLines;

  /// Optional maximum character count. When set, Flutter draws the
  /// built-in character counter below the field.
  final int? maxLength;

  /// Callback invoked on every character change.
  final ValueChanged<String>? onChanged;

  /// Callback invoked when the user submits the field (e.g. taps the
  /// keyboard action button).
  final ValueChanged<String>? onSubmitted;

  /// Optional [FocusNode] to control focus externally.
  final FocusNode? focusNode;

  /// Optional autofill hints so the platform can offer saved values.
  final List<String>? autofillHints;

  /// Whether the field should request focus when first built.
  final bool autofocus;

  /// Whether the field accepts input. When `false`, the field is visually
  /// dimmed and non-interactive.
  final bool enabled;

  /// Creates a [ZLabeledTextField].
  const ZLabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofillHints,
    this.autofocus = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    // Explicit outline — part of the Phase 6 Plan 6 guarantee.
    final unfocusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      borderSide: BorderSide(color: colors.border, width: 1),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    );

    return Semantics(
      label: label,
      textField: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXxs),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: textInputAction,
            keyboardType: keyboardType ?? TextInputType.text,
            obscureText: obscureText,
            maxLines: obscureText ? 1 : maxLines,
            maxLength: maxLength,
            autofocus: autofocus,
            enabled: enabled,
            autofillHints: autofillHints,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            cursorColor: colors.primary,
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              border: unfocusedBorder,
              enabledBorder: unfocusedBorder,
              focusedBorder: focusedBorder,
            ),
          ),
        ],
      ),
    );
  }
}

/// Zuralog Design System — Labeled Number Field Component.
///
/// A numeric text input with a persistent label above the field and an
/// optional unit suffix inside the field (e.g. "g", "kcal"). Used across
/// the meal edit and meal review flows where multiple macros are entered
/// in a vertical stack.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A labeled numeric input with a persistent label drawn above the field.
///
/// Renders a two-line layout: a secondary-color `labelMedium` label, a
/// small vertical gap, then a [TextFormField] configured for numeric
/// entry. The outline is visible when unfocused and switches to the
/// nutrition category accent color when focused, so users can always see
/// the field boundary even when empty.
///
/// Example usage:
/// ```dart
/// ZLabeledNumberField(
///   label: 'Protein',
///   controller: _proteinController,
///   unit: 'g',
/// )
/// ```
class ZLabeledNumberField extends StatelessWidget {
  /// The label drawn above the field.
  final String label;

  /// Controller for reading and manipulating the field's numeric text.
  final TextEditingController controller;

  /// Optional unit suffix shown at the right edge of the field
  /// (e.g. "g", "kcal"). Renders in `bodySmall` at the secondary color.
  final String? unit;

  /// Whether to allow a decimal point in the input.
  ///
  /// When `true`, the keyboard is `numberWithOptions(decimal: true)` and
  /// digits plus `.` are accepted. When `false`, the keyboard is integer
  /// and only digits are accepted. Defaults to `true`.
  final bool allowDecimal;

  /// The action button to show on the keyboard (e.g., next, done).
  final TextInputAction? textInputAction;

  /// Callback invoked on every character change.
  final ValueChanged<String>? onChanged;

  /// Optional [FocusNode] to control focus externally.
  final FocusNode? focusNode;

  /// Creates a [ZLabeledNumberField].
  const ZLabeledNumberField({
    super.key,
    required this.label,
    required this.controller,
    this.unit,
    this.allowDecimal = true,
    this.textInputAction,
    this.onChanged,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    final unfocusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      borderSide: BorderSide(color: colors.border, width: 1),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      borderSide: const BorderSide(
        color: AppColors.categoryNutrition,
        width: 1.5,
      ),
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
            onChanged: onChanged,
            cursorColor: colors.primary,
            keyboardType: TextInputType.numberWithOptions(
              decimal: allowDecimal,
            ),
            inputFormatters: allowDecimal
                ? [_singleDecimalFormatter]
                : [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              border: unfocusedBorder,
              enabledBorder: unfocusedBorder,
              focusedBorder: focusedBorder,
              suffixText: unit,
              suffixStyle: unit == null
                  ? null
                  : AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Allows digits and at most one decimal point.
///
/// Rejects any edit that would introduce a second `.` (e.g. typing `1.2.3`
/// is blocked so only `1.2` survives), ensuring the resulting text always
/// parses cleanly via `double.tryParse`.
final TextInputFormatter _singleDecimalFormatter =
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;
      if (text.isEmpty) return newValue;
      if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
        return oldValue;
      }
      return newValue;
    });

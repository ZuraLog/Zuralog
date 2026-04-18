/// Zuralog Design System — Text Area Component.
///
/// Multi-line text input with Surface fill, Sage focus border, and
/// consistent styling with the design system text field.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A brand-styled multi-line text area.
///
/// Same visual treatment as AppTextField but built for multi-line content.
/// Uses Surface fill (#1E1E20), shapeSm (12px) radius, and a Sage border
/// on focus at rgba(207,225,185,0.3).
class ZTextArea extends StatelessWidget {
  const ZTextArea({
    super.key,
    this.controller,
    this.placeholder,
    this.label,
    this.errorText,
    this.maxLines = 5,
    this.minLines = 4,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
  });

  /// Controller for reading and manipulating the text content.
  final TextEditingController? controller;

  /// Placeholder text shown when the field is empty.
  final String? placeholder;

  /// Optional label shown above the text area.
  final String? label;

  /// Error message shown below the text area in red.
  final String? errorText;

  /// Maximum number of visible lines before scrolling.
  final int maxLines;

  /// Minimum number of visible lines (controls initial height).
  final int minLines;

  /// Optional character limit. Shows a counter below the field when set.
  final int? maxLength;

  /// Whether the text area accepts input.
  final bool enabled;

  /// Whether the text area should request focus when first built.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final sageFocusBorder = colors.primary.withValues(alpha: 0.3);

    // Visible outline when empty — matches ZLabeledTextField.
    // Do not set BorderSide.none here.
    final unfocusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      borderSide: BorderSide(color: colors.border, width: 1),
    );

    final field = IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
      opacity: enabled ? 1.0 : AppDimens.disabledOpacity,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        cursorColor: colors.primary,
        style: AppTextStyles.bodyMedium.copyWith(
          color: colors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
          filled: true,
          fillColor: colors.surface,
          contentPadding: const EdgeInsets.all(AppDimens.spaceMd),
          border: unfocusedBorder,
          enabledBorder: unfocusedBorder,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimens.shapeSm),
            borderSide: BorderSide(color: sageFocusBorder, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimens.shapeSm),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimens.shapeSm),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          errorText: errorText,
          errorStyle: AppTextStyles.bodySmall.copyWith(
            color: AppColors.error,
          ),
          constraints: const BoxConstraints(minHeight: 120),
        ),
      ),
      ),
    );

    if (label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label!,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        field,
      ],
    );
  }
}

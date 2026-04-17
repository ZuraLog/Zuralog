/// ZuraLog Design System — Meal Type Picker.
///
/// A shared dropdown for selecting a [MealType] (breakfast, lunch, dinner,
/// snack). Each option renders with the meal type's icon in the amber
/// nutrition accent plus the human-readable label. Used anywhere a meal
/// needs a type — Meal Review, Meal Edit, and the bottom of the log-meal
/// sheet.
///
/// When [label] is non-null, the picker is wrapped in a [Column] with a
/// `labelMedium` text label above the dropdown, matching the vertical
/// rhythm of [ZLabeledTextField] and [ZLabeledNumberField].
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';

/// Dropdown picker for a [MealType], styled to match the nutrition flow.
///
/// Example:
/// ```dart
/// ZMealTypePicker(
///   value: _selectedMealType,
///   onChanged: (v) => setState(() => _selectedMealType = v),
///   label: 'Meal type',
/// )
/// ```
class ZMealTypePicker extends StatelessWidget {
  /// Creates a [ZMealTypePicker].
  const ZMealTypePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  /// The currently selected [MealType], or `null` if nothing has been
  /// selected yet (the dropdown renders with no value).
  final MealType? value;

  /// Called when the user picks a new value. The callback only fires when
  /// the new value is non-null.
  final ValueChanged<MealType> onChanged;

  /// Optional label drawn above the dropdown in `labelMedium` / secondary
  /// color. When null, no label or wrapping [Column] is rendered.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    final picker = Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<MealType>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: colors.textSecondary),
          dropdownColor: colors.cardBackground,
          style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
          items: MealType.values.map((t) {
            return DropdownMenuItem<MealType>(
              value: t,
              child: Row(
                children: [
                  Icon(
                    t.icon,
                    size: AppDimens.iconSm,
                    color: AppColors.categoryNutrition,
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Text(t.label),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );

    if (label == null) return picker;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label!,
          style: AppTextStyles.labelMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXxs),
        picker,
      ],
    );
  }
}

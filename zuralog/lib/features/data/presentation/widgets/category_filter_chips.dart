/// Zuralog — Category Filter Chips widget.
///
/// A horizontally scrolling row of filter chips for the data dashboard.
///
/// Chips: "All" (first) + one per [HealthCategory] in enum order.
///
/// Behavior:
/// - Single-select only.
/// - Tapping a selected chip deselects it (calls onSelected(null)).
/// - Tapping "All" calls onSelected(null).
/// - Active category chip: filled with [categoryColor], white label + dot.
/// - Inactive chip: outline pill, secondary text color.
/// - "All" chip active: filled with [AppColorsOf.primary], white label.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';

// ── CategoryFilterChips ───────────────────────────────────────────────────────

/// Horizontally scrollable row of category filter chips.
///
/// Reads selection from [selected] and fires [onSelected] on tap.
/// Does not read or write any provider directly — the parent screen is
/// responsible for wiring to [tileFilterProvider].
class CategoryFilterChips extends StatelessWidget {
  const CategoryFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// Currently active category. `null` means "All" is selected.
  final HealthCategory? selected;

  /// Called with the newly selected category, or `null` when deselecting.
  final ValueChanged<HealthCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Row(
        children: [
          // "All" chip
          _AllChip(
            isActive: selected == null,
            colors: colors,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          // One chip per category
          ...HealthCategory.values.expand((cat) => [
                _CategoryChip(
                  category: cat,
                  isActive: selected == cat,
                  colors: colors,
                  onTap: () {
                    if (selected == cat) {
                      onSelected(null);
                    } else {
                      onSelected(cat);
                    }
                  },
                ),
                const SizedBox(width: AppDimens.spaceSm),
              ]),
        ],
      ),
    );
  }
}

// ── _AllChip ──────────────────────────────────────────────────────────────────

class _AllChip extends StatelessWidget {
  const _AllChip({
    required this.isActive,
    required this.colors,
    required this.onTap,
  });

  final bool isActive;
  final AppColorsOf colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive ? colors.primary : Colors.transparent;
    final borderColor = isActive ? colors.primary : colors.border;
    final textColor = isActive ? Colors.white : colors.textSecondary;

    return Semantics(
      label: 'All categories filter',
      button: true,
      selected: isActive,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                border: Border.all(color: borderColor, width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                'All',
                style: AppTextStyles.labelMedium.copyWith(
                  color: textColor,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── _CategoryChip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.isActive,
    required this.colors,
    required this.onTap,
  });

  final HealthCategory category;
  final bool isActive;
  final AppColorsOf colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final catColor = categoryColor(category);
    final bgColor = isActive ? catColor : Colors.transparent;
    final borderColor = isActive ? catColor : colors.border;
    final textColor = isActive ? Colors.white : colors.textSecondary;

    return Semantics(
      label: '${category.displayName} filter',
      button: true,
      selected: isActive,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive) ...[
                    Container(
                      key: Key('chip_dot_${category.name}'),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    category.displayName,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: textColor,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

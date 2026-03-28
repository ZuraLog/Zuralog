/// Zuralog Design System — Radio Group Component.
///
/// Renders a vertical list of radio buttons with brand-styled circles.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/theme.dart';

/// Represents a single option in a [ZRadioGroup].
class ZRadioOption<T> {
  const ZRadioOption({required this.value, required this.label});

  /// The value this option represents.
  final T value;

  /// Human-readable label for this option.
  final String label;
}

/// A brand-styled radio button group.
///
/// Shows a vertical list of radio options. The selected radio has a Sage
/// border with a solid Sage inner dot. Unselected radios have a textSecondary
/// border with transparent fill. Each radio is 20px visually but 44px hit area.
class ZRadioGroup<T> extends StatelessWidget {
  const ZRadioGroup({
    super.key,
    required this.value,
    this.onChanged,
    required this.options,
    this.enabled = true,
  });

  /// Currently selected value, or null if nothing is selected.
  final T? value;

  /// Called when the user taps an option.
  final ValueChanged<T>? onChanged;

  /// The list of options to display.
  final List<ZRadioOption<T>> options;

  /// Whether the radio group is interactive.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: AppDimens.spaceSm),
            _ZRadioItem<T>(
              option: options[i],
              isSelected: options[i].value == value,
              onTap: enabled && onChanged != null
                  ? () {
                      HapticFeedback.selectionClick();
                      onChanged!(options[i].value);
                    }
                  : null,
            ),
          ],
        ],
        ),
      ),
    );
  }
}

class _ZRadioItem<T> extends StatelessWidget {
  const _ZRadioItem({
    required this.option,
    required this.isSelected,
    this.onTap,
  });

  final ZRadioOption<T> option;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Semantics(
      checked: isSelected,
      inMutuallyExclusiveGroup: true,
      label: option.label,
      button: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 44x44 hit area, 20x20 visual.
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: AppMotion.durationFast,
                curve: AppMotion.curveEntrance,
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : colors.textSecondary,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: AppMotion.durationFast,
                    curve: AppMotion.curveEntrance,
                    width: isSelected ? 10 : 0,
                    height: isSelected ? 10 : 0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Text(
            option.label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

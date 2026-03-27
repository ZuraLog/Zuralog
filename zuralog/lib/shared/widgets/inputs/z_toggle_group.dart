/// Zuralog Design System — Toggle Group Component.
///
/// A multi-select button group that looks like a segmented control but allows
/// multiple buttons to be active at once. Container is Surface (#1E1E20) with
/// rounded corners; active buttons get warmWhite fill with dark text.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

/// A single item inside a [ZToggleGroup].
class ZToggleGroupItem<T> {
  const ZToggleGroupItem({required this.value, required this.label});

  /// The value this item represents.
  final T value;

  /// Human-readable label shown on the button.
  final String label;
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// A brand-styled multi-select toggle group.
///
/// Each button can be independently toggled on or off. The container uses
/// Surface (#1E1E20) with SM radius (12 px). Active buttons show warmWhite
/// fill with dark text; inactive buttons show secondary text on transparent.
class ZToggleGroup<T> extends StatelessWidget {
  const ZToggleGroup({
    super.key,
    required this.items,
    required this.selectedValues,
    required this.onChanged,
    this.enabled = true,
  });

  /// The list of toggle buttons to display.
  final List<ZToggleGroupItem<T>> items;

  /// Currently selected values. Pass an empty set for no selection.
  final Set<T> selectedValues;

  /// Called with the updated set whenever a button is tapped.
  final ValueChanged<Set<T>> onChanged;

  /// Whether the toggle group is interactive.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Toggle group',
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          decoration: BoxDecoration(
            color: AppColorsOf(context).surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeSm),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                Expanded(
                  child: _ToggleButton<T>(
                    item: items[i],
                    isSelected: selectedValues.contains(items[i].value),
                    enabled: enabled,
                    onTap: () => _handleTap(items[i].value),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(T value) {
    if (!enabled) return;
    final updated = Set<T>.of(selectedValues);
    if (updated.contains(value)) {
      updated.remove(value);
    } else {
      updated.add(value);
    }
    onChanged(updated);
  }
}

// ---------------------------------------------------------------------------
// Individual toggle button (private)
// ---------------------------------------------------------------------------

class _ToggleButton<T> extends StatelessWidget {
  const _ToggleButton({
    required this.item,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final ZToggleGroupItem<T> item;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration =
        reduceMotion ? Duration.zero : AppMotion.durationMedium;
    final curve = AppMotion.curveEntrance;

    return Semantics(
      toggled: isSelected,
      button: true,
      label: item.label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: AnimatedContainer(
            duration: duration,
            curve: curve,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.warmWhite : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: AnimatedDefaultTextStyle(
              duration: duration,
              curve: curve,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected
                    ? AppColors.textOnWarmWhite
                    : colors.textSecondary,
              ),
              child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}

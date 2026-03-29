/// Zuralog Design System — Select / Dropdown Component.
///
/// A styled trigger button that opens a modal bottom sheet with selectable
/// options. Matches the text field styling for visual consistency.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A brand-styled select dropdown.
///
/// The trigger looks like a text field (Surface background, shapeSm radius)
/// with a chevron on the right. Tapping it opens a modal bottom sheet at
/// surfaceOverlay level showing the list of options.
class ZSelect extends StatefulWidget {
  const ZSelect({
    super.key,
    this.value,
    this.onChanged,
    required this.options,
    this.placeholder,
    this.label,
    this.enabled = true,
  });

  /// Currently selected value, or null if nothing is selected.
  final String? value;

  /// Called when the user picks an option.
  final ValueChanged<String>? onChanged;

  /// Available options to choose from.
  final List<String> options;

  /// Placeholder text when no value is selected.
  final String? placeholder;

  /// Optional label shown above the trigger.
  final String? label;

  /// Whether the select is interactive.
  final bool enabled;

  @override
  State<ZSelect> createState() => _ZSelectState();
}

class _ZSelectState extends State<ZSelect> {
  bool _sheetOpen = false;

  bool get _canOpen =>
      widget.enabled && widget.onChanged != null && widget.options.isNotEmpty;

  void _showOptions(BuildContext context) {
    if (_sheetOpen) return;
    setState(() => _sheetOpen = true);

    showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColorsOf(context).surfaceOverlay,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.shapeXl),
        ),
      ),
      builder: (context) {
        final sheetColors = AppColorsOf(context);
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle.
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spaceSm),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sheetColors.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                // Option list.
                ...widget.options.map((option) {
                  final isSelected = option == widget.value;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onChanged?.call(option);
                    },
                    child: Container(
                      height: 48,
                      color: sheetColors.surface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: sheetColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check,
                              size: 20,
                              color: sheetColors.primary,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppDimens.spaceMd),
              ],
            ),
          ),
        );
      },
    ).then((_) => setState(() => _sheetOpen = false));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final hasValue = widget.value != null && widget.value!.isNotEmpty;

    final trigger = IgnorePointer(
      ignoring: !widget.enabled,
      child: Opacity(
      opacity: widget.enabled ? 1.0 : AppDimens.disabledOpacity,
      child: GestureDetector(
      onTap: _canOpen ? () => _showOptions(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm + 4,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.shapeSm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? widget.value! : (widget.placeholder ?? ''),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: hasValue
                      ? colors.textPrimary
                      : colors.textSecondary,
                ),
              ),
            ),
            Icon(
              Icons.expand_more,
              size: 20,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    ),
      ),
    );

    if (widget.label == null) return trigger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label!,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        trigger,
      ],
    );
  }
}

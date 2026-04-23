/// Zuralog Design System — Single-Select Chip Group.
library;

import 'package:flutter/material.dart';

import 'z_chip.dart';

/// One tappable option inside a chip group.
class ZChipOption<T> {
  const ZChipOption({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Single-selection chip group.
///
/// Wraps [ZChip] so every chip group in the app inherits the same brand
/// styling, haptics, and animated pattern fill when selected.
class ZChipSingleSelect<T> extends StatelessWidget {
  const ZChipSingleSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  final List<ZChipOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        for (final opt in options)
          ZChip(
            label: opt.label,
            icon: opt.icon,
            isActive: opt.value == value,
            onTap: () => onChanged(opt.value),
          ),
      ],
    );
  }
}

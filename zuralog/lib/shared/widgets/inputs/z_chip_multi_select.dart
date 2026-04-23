/// Zuralog Design System — Multi-Select Chip Group.
library;

import 'package:flutter/material.dart';

import 'z_chip.dart';
import 'z_chip_single_select.dart' show ZChipOption;

/// Multi-selection chip group with an optional mutually-exclusive pill.
///
/// When [exclusiveLabel] is provided, an extra pill renders after all regular
/// chips. Tapping it clears the selection (emits `[]`). Tapping any regular
/// chip while the exclusive pill is active (selection is empty) selects only
/// that chip — emulating "none → specific" behaviour.
///
/// Used for the dietary-restrictions question (exclusive "None") and the
/// injuries/limitations question (exclusive "I'm good") in onboarding.
class ZChipMultiSelect<T> extends StatelessWidget {
  const ZChipMultiSelect({
    super.key,
    required this.options,
    required this.values,
    required this.onChanged,
    this.exclusiveLabel,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  final List<ZChipOption<T>> options;
  final List<T> values;
  final ValueChanged<List<T>> onChanged;

  /// When non-null, an additional chip renders last. Tapping it clears the
  /// selection — the emitted result is always an empty list.
  final String? exclusiveLabel;

  final double spacing;
  final double runSpacing;

  bool get _exclusiveActive => values.isEmpty && exclusiveLabel != null;

  void _onTapRegular(T value) {
    if (values.contains(value)) {
      onChanged(values.where((v) => v != value).toList(growable: false));
    } else {
      onChanged([...values, value]);
    }
  }

  void _onTapExclusive() => onChanged(const []);

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
            isActive: values.contains(opt.value),
            onTap: () => _onTapRegular(opt.value),
          ),
        if (exclusiveLabel != null)
          ZChip(
            label: exclusiveLabel!,
            isActive: _exclusiveActive,
            onTap: _onTapExclusive,
          ),
      ],
    );
  }
}

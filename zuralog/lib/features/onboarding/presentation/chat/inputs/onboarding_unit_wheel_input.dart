/// Zuralog — Onboarding Unit-Aware Wheel Inputs.
///
/// Thin wrappers around the shared [ZHeightPicker] and [ZWeightPicker]
/// components. Both widgets always submit metric values (cm or kg) regardless
/// of the display unit chosen by the user.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/shared/widgets/widgets.dart';

// ── Height Input ──────────────────────────────────────────────────────────────

/// Height picker with Metric / Imperial toggle. Submits cm as [int].
class OnboardingHeightInput extends StatelessWidget {
  const OnboardingHeightInput({super.key, required this.onSubmit});

  /// Called with the selected height in **centimetres**.
  final ValueChanged<int> onSubmit;

  @override
  Widget build(BuildContext context) {
    return ZHeightPicker(
      onSubmit: (cm) => onSubmit(cm.round()),
      actionLabel: 'Confirm',
    );
  }
}

// ── Weight Input ──────────────────────────────────────────────────────────────

/// Weight picker with Metric / Imperial toggle. Submits kg as [int].
class OnboardingWeightInput extends StatelessWidget {
  const OnboardingWeightInput({super.key, required this.onSubmit});

  /// Called with the selected weight in **kilograms**.
  final ValueChanged<int> onSubmit;

  @override
  Widget build(BuildContext context) {
    return ZWeightPicker(
      onSubmit: (kg) => onSubmit(kg.round()),
      actionLabel: 'Confirm',
    );
  }
}

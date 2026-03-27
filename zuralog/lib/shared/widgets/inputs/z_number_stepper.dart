/// Zuralog Design System — Number Stepper Component.
///
/// Horizontal plus/minus stepper for integer values. Named ZNumberStepper
/// to avoid conflict with Flutter's built-in Stepper widget.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A brand-styled number stepper with plus/minus buttons.
///
/// Layout: [minus circle] — [value text] — [plus circle].
/// Buttons are 32px surfaceRaised circles with textPrimary icons.
/// The value displays in displaySmall style.
class ZNumberStepper extends StatelessWidget {
  const ZNumberStepper({
    super.key,
    required this.value,
    this.onChanged,
    this.min = 0,
    this.max = 99,
    this.step = 1,
  });

  /// Current integer value.
  final int value;

  /// Called when the user taps plus or minus. Null disables interaction.
  final ValueChanged<int>? onChanged;

  /// Minimum allowed value.
  final int min;

  /// Maximum allowed value.
  final int max;

  /// Amount to increment or decrement per tap.
  final int step;

  void _decrement() {
    if (onChanged == null) return;
    final next = (value - step).clamp(min, max);
    if (next != value) onChanged!(next);
  }

  void _increment() {
    if (onChanged == null) return;
    final next = (value + step).clamp(min, max);
    if (next != value) onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    final canDecrement = value > min;
    final canIncrement = value < max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minus button.
        _StepperButton(
          icon: Icons.remove,
          onTap: canDecrement ? _decrement : null,
          enabled: canDecrement && onChanged != null,
        ),
        // Value display.
        SizedBox(
          width: 64,
          child: Center(
            child: AnimatedSwitcher(
              duration: AppMotion.durationFast,
              child: Text(
                '$value',
                key: ValueKey(value),
                style: AppTextStyles.displaySmall.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
          ),
        ),
        // Plus button.
        _StepperButton(
          icon: Icons.add,
          onTap: canIncrement ? _increment : null,
          enabled: canIncrement && onChanged != null,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.surfaceRaised,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.textPrimaryDark,
          ),
        ),
      ),
    );
  }
}

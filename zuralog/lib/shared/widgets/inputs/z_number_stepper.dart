/// Zuralog Design System — Number Stepper Component.
///
/// Horizontal plus/minus stepper for integer values. Named ZNumberStepper
/// to avoid conflict with Flutter's built-in Stepper widget.
library;

import 'dart:async';

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
    final colors = AppColorsOf(context);
    final canDecrement = value > min;
    final canIncrement = value < max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minus button.
        Semantics(
          label: 'Decrease value',
          button: true,
          child: _StepperButton(
            icon: Icons.remove,
            onTap: canDecrement ? _decrement : null,
            enabled: canDecrement && onChanged != null,
          ),
        ),
        // Value display.
        SizedBox(
          width: 64,
          child: Center(
            child: AnimatedSwitcher(
              duration: AppMotion.durationFast,
              child: Semantics(
                value: '$value',
                liveRegion: true,
                child: Text(
                  '$value',
                  key: ValueKey(value),
                  style: AppTextStyles.displaySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Plus button.
        Semantics(
          label: 'Increase value',
          button: true,
          child: _StepperButton(
            icon: Icons.add,
            onTap: canIncrement ? _increment : null,
            enabled: canIncrement && onChanged != null,
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatefulWidget {
  const _StepperButton({
    required this.icon,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  Timer? _timer;

  void _startLongPress() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      widget.onTap?.call();
    });
  }

  void _stopLongPress() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: widget.onTap != null ? (_) => _startLongPress() : null,
      onLongPressEnd: (_) => _stopLongPress(),
      onLongPressCancel: _stopLongPress,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Opacity(
            opacity: widget.enabled ? 1.0 : AppDimens.disabledOpacity,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 18,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

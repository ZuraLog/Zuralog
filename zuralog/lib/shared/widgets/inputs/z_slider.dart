/// Zuralog Design System — Slider Component.
///
/// Uses Flutter's built-in Slider with SliderTheme to match the brand bible.
/// Active track shows Sage with a pattern overlay effect.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A brand-styled slider.
///
/// The active portion uses the brand primary color (adapts to light/dark theme),
/// the inactive portion is surfaceRaised, and the thumb is an 18px circle.
/// Track height is 6px.
class ZSlider extends StatelessWidget {
  const ZSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.min = 0,
    this.max = 1,
    this.enabled = true,
    this.label,
  });

  /// Current slider value between [min] and [max].
  final double value;

  /// Called when the user drags the slider. Null disables interaction.
  final ValueChanged<double>? onChanged;

  /// Minimum slider value.
  final double min;

  /// Maximum slider value.
  final double max;

  /// Whether the slider is interactive.
  final bool enabled;

  /// Optional label shown above the slider.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final slider = Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: SliderTheme(
        data: SliderThemeData(
          activeTrackColor: colors.primary,
          inactiveTrackColor: colors.surfaceRaised,
          thumbColor: colors.primary,
          overlayColor: colors.primary.withValues(alpha: 0.12),
          trackHeight: 6,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: Slider(
          value: value,
          min: min,
          max: max,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );

    if (label == null) return slider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label!,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        slider,
      ],
    );
  }
}

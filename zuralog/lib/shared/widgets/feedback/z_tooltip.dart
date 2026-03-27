/// Zuralog Design System — Tooltip Component.
///
/// A long-press tooltip with brand-correct surface color and typography.
/// Wraps Flutter's built-in [Tooltip] with design system theming.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A themed tooltip that appears on long-press and dismisses on tap.
///
/// Uses [surfaceRaised] background, [shapeXs] radius, and [bodySmall]
/// typography. Wraps Flutter's [Tooltip] widget for positioning and
/// pointer-triangle behavior.
class ZTooltip extends StatelessWidget {
  const ZTooltip({
    super.key,
    required this.child,
    required this.message,
  });

  /// The widget that triggers the tooltip on long-press.
  final Widget child;

  /// The text displayed inside the tooltip bubble.
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Tooltip(
      message: message,
      preferBelow: false,
      triggerMode: TooltipTriggerMode.longPress,
      waitDuration: const Duration(milliseconds: 500),
      showDuration: const Duration(seconds: 2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm + 4,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDimens.shapeXs),
      ),
      textStyle: AppTextStyles.bodySmall.copyWith(
        color: colors.textPrimary,
      ),
      child: child,
    );
  }
}

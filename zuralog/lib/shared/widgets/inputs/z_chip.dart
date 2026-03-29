/// Zuralog Design System — Chip Component.
///
/// Pill-shaped selectable chip with Sage tint and pattern overlay when active.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart'
    show ZPatternVariant, effectivePatternVariant;

/// A brand-styled selectable chip.
///
/// When active:
///   - Light mode: solid Deep Forest (#344E41) background, no pattern.
///   - Dark mode: sage→original pattern fill.
/// When inactive, uses Surface fill with textSecondary text. Always pill-shaped.
class ZChip extends StatelessWidget {
  const ZChip({
    super.key,
    required this.label,
    this.isActive = false,
    this.onTap,
    this.icon,
    this.enabled = true,
  });

  /// Text displayed inside the chip.
  final String label;

  /// Whether the chip is currently selected/active.
  final bool isActive;

  /// Called when the user taps the chip.
  final VoidCallback? onTap;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether the chip is interactive.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Active chip: solid in light mode, pattern fill in dark mode.
    final Color? activeBackgroundColor =
        (isActive && isLight) ? colors.primary : (isActive ? null : colors.surface);
    final DecorationImage? activeImage = (isActive && !isLight)
        ? DecorationImage(
            image: AssetImage(
              effectivePatternVariant(ZPatternVariant.sage, isLight).assetPath,
            ),
            fit: BoxFit.cover,
            opacity: 0.6,
          )
        : null;

    // Text/icon color: textOnSage resolves per-mode (light/dark automatically).
    final Color contentColor = isActive
        ? colors.textOnSage
        : colors.textSecondary;

    return Semantics(
      checked: isActive,
      label: label,
      button: true,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
        opacity: enabled ? 1.0 : AppDimens.disabledOpacity,
        child: GestureDetector(
          onTap: enabled && onTap != null
              ? () {
                  HapticFeedback.selectionClick();
                  onTap!();
                }
              : null,
          child: AnimatedContainer(
          duration: AppMotion.durationFast,
          curve: AppMotion.curveEntrance,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.shapePill),
            color: activeBackgroundColor,
            image: activeImage,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: contentColor,
                ),
                const SizedBox(width: AppDimens.spaceXs),
              ],
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: contentColor,
                ),
              ),
            ],
          ),
          ),
        ),
        ),
      ),
    );
  }
}

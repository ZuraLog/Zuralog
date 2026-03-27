/// Zuralog Design System — Chip Component.
///
/// Pill-shaped selectable chip with Sage tint and pattern overlay when active.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// A brand-styled selectable chip.
///
/// When active, the chip has a Sage-tinted background with a subtle topographic
/// pattern and Sage text. When inactive, it uses Surface fill with
/// textSecondary text. Always pill-shaped.
class ZChip extends StatelessWidget {
  const ZChip({
    super.key,
    required this.label,
    this.isActive = false,
    this.onTap,
    this.icon,
  });

  /// Text displayed inside the chip.
  final String label;

  /// Whether the chip is currently selected/active.
  final bool isActive;

  /// Called when the user taps the chip.
  final VoidCallback? onTap;

  /// Optional leading icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final sageTint = AppColors.primary.withValues(alpha: 0.15);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveEntrance,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? sageTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.shapePill),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.shapePill),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pattern overlay — only when active.
              if (isActive)
                const Positioned.fill(
                  child: ZPatternOverlay(
                    variant: ZPatternVariant.original,
                    opacity: 0.08,
                    blendMode: BlendMode.screen,
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 16,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppDimens.spaceXs),
                  ],
                  Text(
                    label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

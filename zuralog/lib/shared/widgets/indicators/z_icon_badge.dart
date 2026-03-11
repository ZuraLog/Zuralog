/// Zuralog Design System — Icon Badge Component.
///
/// A rounded icon container with a translucent color fill.
/// Replaces the inline pattern of a colored Container + centered Icon
/// used throughout the codebase.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A rounded icon container with a translucent color fill.
///
/// Renders a square container of [size] × [size] with a 15% opacity
/// background in [color], and a centered [icon] drawn in full [color].
///
/// Common usage patterns:
/// - Category tile icon: `ZIconBadge(icon: Icons.favorite_rounded, color: AppColors.categoryHeart)`
/// - Activity summary: `ZIconBadge(icon: Icons.directions_run, color: AppColors.primary, size: 40)`
///
/// Example usage:
/// ```dart
/// ZIconBadge(
///   icon: Icons.favorite_rounded,
///   color: AppColors.categoryHeart,
/// )
/// ```
class ZIconBadge extends StatelessWidget {
  /// The icon to display inside the badge.
  final IconData icon;

  /// The accent color used for both the icon and the translucent background.
  final Color color;

  /// The width and height of the container in logical pixels. Defaults to 36.
  final double size;

  /// The rendered size of the icon in logical pixels.
  /// Defaults to [size] × 0.55 (~20 px at the default size of 36).
  final double? iconSize;

  /// The corner radius of the container.
  /// Defaults to [AppDimens.radiusSm].
  final double? borderRadius;

  /// Creates a [ZIconBadge].
  const ZIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
    this.iconSize,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(borderRadius ?? AppDimens.radiusSm),
      ),
      child: Icon(
        icon,
        size: iconSize ?? size * 0.55,
        color: color,
      ),
    );
  }
}

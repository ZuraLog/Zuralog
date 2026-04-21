/// Zuralog Design System — Category Icon Tile.
///
/// A rounded square tile filled with a category (or Sage) color, with
/// the matching topographic pattern overlaid at 15% opacity, animated
/// drift. Renders a single flat-colored glyph centered.
///
/// Per `docs/design.md`: any colored small interactive surface (Sage
/// button, FAB, achievement tile, category card icon) gets the matching
/// pattern variant at 15% color-burn opacity.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

class ZCategoryIconTile extends StatelessWidget {
  const ZCategoryIconTile({
    super.key,
    required this.color,
    required this.icon,
    this.size = AppDimens.iconContainerMd, // 44
    this.iconSize = 22,
    this.iconColor = Colors.white,
    this.borderRadius = AppDimens.shapeSm, // 12
  });

  /// Tile fill color. Pass an `AppColors.category*` constant or
  /// `AppColors.primary` (Sage) — the right pattern variant is picked
  /// automatically.
  final Color color;

  final IconData icon;

  /// Tile size in logical pixels. Defaults to 44 (IconContainerMd).
  /// Use 36 for compact rows, 56-72 for hero contexts.
  final double size;

  /// Glyph size. Defaults to 22.
  final double iconSize;

  /// Glyph color. Defaults to white. For a Sage tile, pass [AppColors.textOnSage].
  final Color iconColor;

  /// Tile corner radius. Defaults to 12 (shapeSm).
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final variant = _variantFor(color);
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              key: const ValueKey('z-category-icon-tile-fill'),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                borderRadius: radius,
              ),
            ),
            Positioned.fill(
              child: ZPatternOverlay(
                variant: variant,
                opacity: 0.15,
                animate: true,
              ),
            ),
            Icon(icon, size: iconSize, color: iconColor),
          ],
        ),
      ),
    );
  }

  static ZPatternVariant _variantFor(Color color) {
    if (color == AppColors.primary) return ZPatternVariant.sage;
    if (color == AppColors.streakWarm) return ZPatternVariant.amber;
    return patternForCategory(color);
  }
}

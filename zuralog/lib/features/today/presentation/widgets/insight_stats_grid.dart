/// Shared 2×2 stat grid used by every category-specific insight body.
/// Each tile is icon + label + value on a category-tinted icon chip.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class InsightStatTile {
  const InsightStatTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
}

class InsightStatsGrid extends StatelessWidget {
  const InsightStatsGrid({
    super.key,
    required this.title,
    required this.categoryColor,
    required this.tiles,
    this.delay = const Duration(milliseconds: 240),
  });

  final String title;
  final Color categoryColor;
  final List<InsightStatTile> tiles;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZFadeSlideIn(
        delay: delay,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppDimens.spaceSm,
              mainAxisSpacing: AppDimens.spaceSm,
              childAspectRatio: 2.3,
              children: [
                for (final t in tiles)
                  _StatTileView(tile: t, accent: categoryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTileView extends StatelessWidget {
  const _StatTileView({required this.tile, required this.accent});
  final InsightStatTile tile;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppDimens.shapeSm),
            ),
            child: Icon(tile.icon, size: 16, color: accent),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tile.label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tile.value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

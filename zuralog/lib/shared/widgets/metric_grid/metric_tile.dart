/// Zuralog — Metric Tile widget.
///
/// A single tile in the Today tab's user-configurable metric grid.
///
/// Visual states:
///   - Lit: full category colour, shows today's value.
///   - Greyscale: muted/grey, shows '—' placeholder. Used when the metric
///     has not been logged or synced today.
///
/// Edit mode:
///   - When [inEditMode] is true, a red ✕ badge appears in the top-right
///     corner. Tapping it calls [onRemove].
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/domain/metric_grid_models.dart';

// ── MetricTile ────────────────────────────────────────────────────────────────

/// A single user-pinned metric tile.
class MetricTile extends StatelessWidget {
  /// Creates a [MetricTile].
  const MetricTile({
    super.key,
    required this.data,
    this.inEditMode = false,
    this.onRemove,
  });

  /// The tile's data — metric type, value, colour.
  final MetricTileData data;

  /// When true, shows a remove button in the corner.
  final bool inEditMode;

  /// Called when the remove button is tapped. Only relevant when
  /// [inEditMode] is true.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final categoryColor = Color(data.categoryColor);

    Widget tile = Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppDimens.spaceSm,
        horizontal: AppDimens.spaceXs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji
          Text(data.emoji, style: TextStyle(fontSize: AppDimens.emojiSm)),
          const SizedBox(height: AppDimens.spaceXxs),
          // Value or dash
          Text(
            data.isLit ? (data.value ?? '—') : '—',
            style: AppTextStyles.labelMedium.copyWith(
              color: data.isLit ? categoryColor : colors.textTertiary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Label
          Text(
            data.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    // Apply greyscale filter when not lit
    if (!data.isLit) {
      tile = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      0.7, 0,
        ]),
        child: tile,
      );
    }

    // Edit mode: add remove badge
    if (inEditMode) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          tile,
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.translucent,
              child: SizedBox(
                width: AppDimens.touchTargetMin,
                height: AppDimens.touchTargetMin,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.statusError,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return tile;
  }
}

/// Zuralog — TileExpandedView widget.
///
/// Inline expansion rendered in place of a normal [MetricTile] when the user
/// taps a tile in the dashboard grid. The parent grid manages which tile is
/// expanded via an `expandedTileId` state variable; this widget is purely
/// presentational.
///
/// Layout (top-to-bottom):
/// 1. Category header + primary value + optional visualization
/// 2. Stats row — Avg / Best / Worst / Change chips
/// 3. Action buttons — "View Details ›" (outlined) + "Ask Coach" (filled)
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';

// ── TileExpandedView ──────────────────────────────────────────────────────────

/// Expanded inline view for a dashboard metric tile.
///
/// Renders inside the same grid cell as the collapsed tile, replacing
/// [MetricTile] when the tile is in an expanded state managed by the parent.
class TileExpandedView extends StatelessWidget {
  const TileExpandedView({
    super.key,
    required this.tileId,
    required this.size,
    required this.visualization,
    required this.primaryValue,
    this.unit,
    this.colorOverride,
    this.avgValue,
    this.bestValue,
    this.worstValue,
    this.changeValue,
    required this.onViewDetails,
    required this.onAskCoach,
  });

  /// Which metric this expanded view represents.
  final TileId tileId;

  /// Tile layout size (used for layout decisions).
  final TileSize size;

  /// Larger version of the chart / visualization widget. May be null.
  final Widget? visualization;

  /// Primary metric value string (e.g. "8,432").
  final String primaryValue;

  /// Unit label (e.g. "steps", "bpm").
  final String? unit;

  /// ARGB color int override. Overrides the default category color.
  final int? colorOverride;

  /// Average value string for the stats row.
  final String? avgValue;

  /// Best value string for the stats row.
  final String? bestValue;

  /// Worst value string for the stats row.
  final String? worstValue;

  /// Change value string (e.g. "↑ 12%") for the stats row.
  final String? changeValue;

  /// Called when the "View Details ›" button is tapped.
  final VoidCallback onViewDetails;

  /// Called when the "Ask Coach" button is tapped.
  final VoidCallback onAskCoach;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Color _effectiveColor() {
    if (colorOverride != null) return Color(colorOverride!);
    return categoryColor(tileId.category);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final effectiveColor = _effectiveColor();

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: colors.isDark ? null : AppDimens.cardShadowLight,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Category header ──────────────────────────────────────────────
          _CategoryHeader(
            categoryName: tileId.category.displayName,
            color: effectiveColor,
          ),
          const SizedBox(height: 10),

          // ── Primary value ────────────────────────────────────────────────
          Text(
            primaryValue,
            style: AppTextStyles.displayLarge.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),

          // ── Unit label ───────────────────────────────────────────────────
          if (unit != null) ...[
            const SizedBox(height: 2),
            Text(
              unit!,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
          ],

          // ── Visualization ────────────────────────────────────────────────
          if (visualization != null) ...[
            const SizedBox(height: 12),
            visualization!,
          ],

          const SizedBox(height: 16),

          // ── Stats row ────────────────────────────────────────────────────
          _StatsRow(
            avgValue: avgValue,
            bestValue: bestValue,
            worstValue: worstValue,
            changeValue: changeValue,
          ),

          const SizedBox(height: 16),

          // ── Action buttons ───────────────────────────────────────────────
          _ActionButtons(
            onViewDetails: onViewDetails,
            onAskCoach: onAskCoach,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

// ── _CategoryHeader ───────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.categoryName,
    required this.color,
  });

  final String categoryName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          categoryName,
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 12,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── _StatsRow ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    this.avgValue,
    this.bestValue,
    this.worstValue,
    this.changeValue,
  });

  final String? avgValue;
  final String? bestValue;
  final String? worstValue;
  final String? changeValue;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(child: _StatChip(label: 'Avg', value: avgValue)),
          VerticalDivider(width: 1, thickness: 1, color: colors.border),
          Expanded(child: _StatChip(label: 'Best', value: bestValue)),
          VerticalDivider(width: 1, thickness: 1, color: colors.border),
          Expanded(child: _StatChip(label: 'Worst', value: worstValue)),
          VerticalDivider(width: 1, thickness: 1, color: colors.border),
          Expanded(child: _StatChip(label: 'Change', value: changeValue)),
        ],
      ),
    );
  }
}

// ── _StatChip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: colors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value ?? '—',
            style: TextStyle(
              fontSize: 14,
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── _ActionButtons ────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onViewDetails,
    required this.onAskCoach,
    required this.colors,
  });

  final VoidCallback onViewDetails;
  final VoidCallback onAskCoach;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onViewDetails,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
              ),
            ),
            child: const Text('View Details ›'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: onAskCoach,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: AppColors.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
              ),
            ),
            child: const Text('Ask Coach'),
          ),
        ),
      ],
    );
  }
}

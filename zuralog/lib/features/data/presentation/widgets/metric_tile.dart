/// Zuralog — MetricTile widget.
///
/// Base tile widget for the data dashboard. Every metric on the dashboard is
/// rendered as a [MetricTile]. It handles:
///
/// - Category header row (color dot + category name)
/// - Primary value display
/// - Unit/context label
/// - Visualization area (or appropriate empty state)
/// - Stats footer (avg + delta — tall/wide tiles only)
/// - State routing to the correct empty-state widget
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_empty_states.dart';

// ── MetricTile ────────────────────────────────────────────────────────────────

/// Base tile widget representing one metric on the data dashboard.
///
/// Routes to the correct content based on [dataState]:
/// - [TileDataState.loaded]         → [visualization] + header/value/footer
/// - [TileDataState.noSource]       → [GhostTileContent]
/// - [TileDataState.syncing]        → [SyncingTileContent]
/// - [TileDataState.noDataForRange] → [NoDataForRangeTileContent]
/// - [TileDataState.hidden]         → [SizedBox.shrink]
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.tileId,
    required this.dataState,
    required this.size,
    this.visualization,
    this.primaryValue,
    this.unit,
    this.avgLabel,
    this.deltaLabel,
    this.lastUpdated,
    this.colorOverride,
    this.onConnect,
  });

  /// Which metric this tile represents.
  final TileId tileId;

  /// Current data state — drives content rendering.
  final TileDataState dataState;

  /// Tile layout size.
  final TileSize size;

  /// Chart/graphic widget. Non-null only when [dataState] == [TileDataState.loaded].
  final Widget? visualization;

  /// Primary metric value (e.g. "8,432"). Falls back to "—" when null.
  final String? primaryValue;

  /// Unit label (e.g. "steps", "bpm").
  final String? unit;

  /// Average label for the stats footer (e.g. "Avg 7.9k").
  final String? avgLabel;

  /// Delta label for the stats footer (e.g. "↑ 12%").
  final String? deltaLabel;

  /// ISO-8601 last-updated timestamp — used by [NoDataForRangeTileContent].
  final String? lastUpdated;

  /// ARGB color int override (from DashboardLayout). Overrides the default
  /// category color for the dot and chart accent.
  final int? colorOverride;

  /// Called when the user taps the "Connect" CTA in ghost state.
  final VoidCallback? onConnect;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Returns the effective category color, respecting [colorOverride].
  Color _effectiveColor() {
    if (colorOverride != null) return Color(colorOverride!);
    return categoryColor(tileId.category);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Hidden tiles take zero space.
    if (dataState == TileDataState.hidden) return const SizedBox.shrink();

    final colors = AppColorsOf(context);
    final effectiveColor = _effectiveColor();
    final isSquare = size == TileSize.square;

    return Container(
      constraints: BoxConstraints(
        minHeight: isSquare ? 120 : 0,
      ),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: colors.isDark ? null : AppDimens.cardShadowLight,
      ),
      padding: const EdgeInsets.all(12),
      child: _buildContent(context, colors, effectiveColor, isSquare),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppColorsOf colors,
    Color effectiveColor,
    bool isSquare,
  ) {
    // Non-loaded states: render full-content replacements.
    switch (dataState) {
      case TileDataState.noSource:
        return GhostTileContent(
          categoryColor: effectiveColor,
          onConnect: onConnect ?? () {},
        );

      case TileDataState.syncing:
        return const SyncingTileContent();

      case TileDataState.noDataForRange:
        return NoDataForRangeTileContent(
          lastKnownValue: primaryValue ?? '—',
          lastUpdated: lastUpdated ?? '',
        );

      case TileDataState.hidden:
        // Handled above in build() — unreachable here.
        return const SizedBox.shrink();

      case TileDataState.loaded:
        break;
    }

    // Loaded state: full tile layout.
    final showFooter =
        !isSquare && visualization != null && (avgLabel != null || deltaLabel != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Category header row ──────────────────────────────────────────────
        _CategoryHeader(
          categoryName: tileId.category.displayName,
          color: effectiveColor,
        ),
        const SizedBox(height: 8),

        // ── Primary value ────────────────────────────────────────────────────
        Text(
          primaryValue ?? '—',
          style: (isSquare
                  ? AppTextStyles.displayMedium
                  : AppTextStyles.displayMedium.copyWith(fontSize: 28))
              .copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),

        // ── Unit label ───────────────────────────────────────────────────────
        if (unit != null) ...[
          const SizedBox(height: 2),
          Text(
            unit!,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10,
              color: colors.textTertiary,
            ),
          ),
        ],

        // ── Visualization area ───────────────────────────────────────────────
        if (visualization != null) ...[
          const SizedBox(height: 8),
          visualization!,
        ],

        // ── Stats footer ─────────────────────────────────────────────────────
        if (showFooter) ...[
          const SizedBox(height: 6),
          _StatsFooter(avgLabel: avgLabel, deltaLabel: deltaLabel),
        ],
      ],
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
          key: const Key('category_color_dot'),
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

// ── _StatsFooter ──────────────────────────────────────────────────────────────

class _StatsFooter extends StatelessWidget {
  const _StatsFooter({this.avgLabel, this.deltaLabel});

  final String? avgLabel;
  final String? deltaLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final parts = [
      ?avgLabel,
      ?deltaLabel,
    ];
    final text = parts.join(' · ');

    return SizedBox(
      key: const Key('stats_footer'),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          fontSize: 10,
          color: colors.textTertiary,
        ),
      ),
    );
  }
}

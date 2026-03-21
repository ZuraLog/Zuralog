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
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_empty_states.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_visualizations.dart';

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
    this.vizConfig,
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

  /// Visualization configuration. When provided, [buildTileVisualization] is
  /// called inside the tile to render the chart. Takes precedence over [visualization].
  final TileVisualizationConfig? vizConfig;

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

    final label = switch (dataState) {
      TileDataState.loaded =>
        '${tileId.displayName}: ${primaryValue ?? '—'}${unit != null ? ' $unit' : ''}',
      TileDataState.noSource =>
        '${tileId.displayName}: not connected',
      TileDataState.syncing =>
        '${tileId.displayName}: syncing',
      TileDataState.noDataForRange =>
        '${tileId.displayName}: last known value ${primaryValue ?? '—'}, data may be outdated',
      _ => tileId.displayName,
    };

    return Semantics(
      label: label,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = AppColorsOf(context);
    final effectiveColor = _effectiveColor();
    final isSquare = size == TileSize.square;

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: colors.isDark ? null : AppDimens.cardShadowLight,
      ),
      padding: const EdgeInsets.all(12),
      child: _buildTileContent(context, colors, effectiveColor, isSquare),
    );
  }

  Widget _buildTileContent(
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
        !isSquare && (avgLabel != null || deltaLabel != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        // ── Metric header row ────────────────────────────────────────────────
        _MetricHeader(
          tileId: tileId,
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
        if (vizConfig != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: buildTileVisualization(
                config: vizConfig!,
                categoryColor: effectiveColor,
                size: size,
              ),
            ),
          )
        else if (visualization != null) ...[
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

// ── _MetricHeader ─────────────────────────────────────────────────────────────

class _MetricHeader extends StatelessWidget {
  const _MetricHeader({required this.tileId, required this.color});
  final TileId tileId;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tileId.displayName.toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              _CategoryPill(category: tileId.category, color: color),
            ],
          ),
        ),
        Text(
          tileId.icon,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}

// ── _CategoryPill ─────────────────────────────────────────────────────────────

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category, required this.color});
  final HealthCategory category;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '● ${category.displayName}',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
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
    final labelStyle = AppTextStyles.labelSmall.copyWith(
      fontSize: 10,
      color: colors.textTertiary,
    );

    return SizedBox(
      key: const Key('stats_footer'),
      child: Row(
        children: [
          if (avgLabel != null) Text(avgLabel!, style: labelStyle),
          if (avgLabel != null && deltaLabel != null)
            Text(' · ', style: labelStyle),
          if (deltaLabel != null) Text(deltaLabel!, style: labelStyle),
        ],
      ),
    );
  }
}

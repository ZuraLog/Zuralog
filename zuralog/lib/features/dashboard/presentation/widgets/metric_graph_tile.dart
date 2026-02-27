/// Zuralog Dashboard — Metric Graph Tile Widget.
///
/// A card-shaped container that wraps one graph widget for a single
/// [HealthMetric]. Used on both the category detail screen (full size)
/// and inside category hub cards as a compact preview.
///
/// The correct graph widget is selected automatically based on
/// [HealthMetric.graphType] via an internal switch dispatch. In full mode
/// a stats row (Avg / Min / Max / Trend%) is shown below the graph.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/dashboard/domain/graph_type.dart';
import 'package:zuralog/features/dashboard/domain/health_metric.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/metric_stats.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/bar_chart_graph.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/calendar_heatmap.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/calendar_marker.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/combo_chart.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/dual_line_chart.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/line_chart_graph.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/mood_timeline.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/range_line_chart.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/single_value_display.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/stacked_bar_chart.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/threshold_line_chart.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Graph area height in logical pixels for the full (non-compact) layout.
const double _kFullGraphHeight = 200;

/// Graph area height in logical pixels for the compact (embedded) layout.
const double _kCompactGraphHeight = 80;

// ── Widget ────────────────────────────────────────────────────────────────────

/// A [ZuralogCard]-wrapped tile that displays one health metric's graph.
///
/// Shows a header row (icon + metric name + unit), the appropriate chart
/// widget dispatched by [HealthMetric.graphType], and — in full mode — a
/// stats summary row (Avg / Min / Max / Trend%).
///
/// Set [compact] = `true` when embedding inside a [CategoryCard] miniature
/// preview; this reduces the graph height to 80px and hides the stats row.
///
/// Example:
/// ```dart
/// MetricGraphTile(
///   metric: stepsMetric,
///   series: stepsSeries,
///   accentColor: AppColors.primary,
///   onTap: () => navigateToDetail(stepsMetric),
/// )
/// ```
class MetricGraphTile extends StatelessWidget {
  /// Creates a [MetricGraphTile].
  ///
  /// [metric] — the [HealthMetric] definition providing display metadata and
  /// graph type.
  ///
  /// [series] — the time-series data for [metric] to pass to the graph widget.
  ///
  /// [accentColor] — the category accent colour applied to the graph and icon.
  ///
  /// [onTap] — optional callback invoked when the tile is tapped. The parent
  /// screen is responsible for navigation.
  ///
  /// [compact] — when `true`, renders a shorter 80px graph area with no
  /// stats row, suitable for embedding inside summary cards.
  const MetricGraphTile({
    super.key,
    required this.metric,
    required this.series,
    required this.accentColor,
    this.onTap,
    this.compact = false,
  });

  /// The health metric definition.
  final HealthMetric metric;

  /// The time-series data for this metric.
  final MetricSeries series;

  /// Category accent colour used for the graph and icon badge.
  final Color accentColor;

  /// Optional tap handler; the parent screen handles navigation.
  final VoidCallback? onTap;

  /// When `true`, uses the compact layout (80px graph, no stats row).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ZuralogCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderRow(metric: metric, accentColor: accentColor),
            const SizedBox(height: AppDimens.spaceSm),
            _UnitSubtitle(unit: metric.unit),
            const SizedBox(height: AppDimens.spaceMd),
            SizedBox(
              height: compact ? _kCompactGraphHeight : _kFullGraphHeight,
              child: _buildGraph(),
            ),
            if (!compact) ...[
              const SizedBox(height: AppDimens.spaceMd),
              _StatsRow(stats: series.stats, accentColor: accentColor),
            ],
          ],
        ),
      ),
    );
  }

  /// Dispatches to the correct graph widget based on [metric.graphType].
  ///
  /// Returns a [Widget] appropriate for the [GraphType] of the metric.
  /// All graph widgets receive [series], [accentColor], and [compact].
  /// The [series.timeRange] is forwarded to widgets that require it.
  Widget _buildGraph() {
    switch (metric.graphType) {
      case GraphType.bar:
        return BarChartGraph(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: compact,
        );

      case GraphType.line:
        return LineChartGraph(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: compact,
        );

      case GraphType.rangeLine:
        return RangeLineChart(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: compact,
        );

      case GraphType.dualLine:
        return DualLineChart(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: compact,
        );

      case GraphType.stackedBar:
        return StackedBarChart(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: compact,
        );

      case GraphType.thresholdLine:
        return ThresholdLineChart(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: compact,
        );

      case GraphType.calendarHeatmap:
        return CalendarHeatmap(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: compact,
        );

      case GraphType.calendarMarker:
        return CalendarMarker(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: compact,
        );

      case GraphType.moodTimeline:
        return MoodTimeline(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: compact,
        );

      case GraphType.singleValue:
        return SingleValueDisplay(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: compact,
        );

      case GraphType.combo:
        return ComboChart(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: compact,
        );
    }
  }
}

// ── Private sub-widgets ───────────────────────────────────────────────────────

/// Displays the metric icon badge and display name in a horizontal row.
///
/// The icon is rendered inside a small rounded square filled with [accentColor]
/// at 20% opacity, with the icon glyph in [accentColor].
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.metric,
    required this.accentColor,
  });

  /// The health metric whose icon and name are displayed.
  final HealthMetric metric;

  /// Accent colour for the icon badge background and icon glyph.
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Row(
      children: [
        _IconBadge(icon: metric.icon, accentColor: accentColor),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: Text(
            metric.displayName,
            style: AppTextStyles.h3.copyWith(color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A small rounded-square badge wrapping a metric icon.
///
/// The background is [accentColor] at 20% opacity; the icon glyph is
/// rendered in [accentColor] at full opacity.
class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.accentColor,
  });

  /// The icon glyph to render.
  final IconData icon;

  /// The accent colour for both the badge background (at 20% opacity) and
  /// the icon itself.
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimens.iconMd + AppDimens.spaceMd,
      height: AppDimens.iconMd + AppDimens.spaceMd,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Icon(icon, color: accentColor, size: AppDimens.iconMd),
    );
  }
}

/// Renders the metric unit as a secondary caption below the header row.
///
/// Displays the [unit] string in [AppColors.textSecondary] using
/// [AppTextStyles.caption].
class _UnitSubtitle extends StatelessWidget {
  const _UnitSubtitle({required this.unit});

  /// The measurement unit abbreviation (e.g. `'bpm'`, `'steps'`).
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Text(
      unit,
      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    );
  }
}

/// A horizontal summary row showing Avg / Min / Max / Trend% statistics.
///
/// Hidden when the parent [MetricGraphTile] is in compact mode. Renders four
/// stat chips separated by thin `|` dividers.
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.stats,
    required this.accentColor,
  });

  /// The pre-computed statistics to display.
  final MetricStats stats;

  /// Colour for the trend percentage when it is positive.
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final trendPositive = stats.trendPercent >= 0;
    final trendLabel =
        '${trendPositive ? '+' : ''}${stats.trendPercent.toStringAsFixed(1)}%';
    final trendColor = trendPositive ? accentColor : AppColors.textSecondary;

    return Row(
      children: [
        _StatChip(label: 'Avg', value: stats.average.toStringAsFixed(1)),
        _kDivider,
        _StatChip(label: 'Min', value: stats.min.toStringAsFixed(1)),
        _kDivider,
        _StatChip(label: 'Max', value: stats.max.toStringAsFixed(1)),
        _kDivider,
        _StatChip(
          label: 'Trend',
          value: trendLabel,
          valueColor: trendColor,
        ),
      ],
    );
  }
}

/// Thin vertical separator used between stat chips in [_StatsRow].
///
/// Uses [AppTextStyles.labelXs] (10pt Medium) coloured with
/// [AppColors.textSecondary] to keep the pipe character visually recessive.
/// Declared as a non-const top-level variable because [AppTextStyles.labelXs]
/// is a non-const getter.
// ignore: prefer_const_declarations
final Widget _kDivider = Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceXs),
  child: Text(
    '|',
    style: AppTextStyles.labelXs.copyWith(color: AppColors.textSecondary),
  ),
);

/// A single label + value pair for the stats row.
///
/// [label] is shown in [AppTextStyles.labelXs] secondary style; [value] is
/// shown in [AppTextStyles.caption] with semi-bold weight. An optional
/// [valueColor] overrides the default text colour (used for trend colouring).
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.valueColor,
  });

  /// The stat label (e.g. `'Avg'`, `'Min'`).
  final String label;

  /// The formatted stat value string.
  final String value;

  /// Optional colour override for the value text.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelXs.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.caption.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

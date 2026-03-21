/// Zuralog — TileVisualizationConfig sealed class hierarchy.
///
/// Defines the data models that drive the 12 reusable visualization widgets.
///
/// Model overview:
/// - [TileVisualizationConfig]  — sealed base class
/// - [LineChartConfig]          — sparkline trend chart
/// - [BarChartConfig]           — vertical bar chart with optional goal line
/// - [AreaChartConfig]          — filled area chart with optional delta
/// - [RingConfig]               — circular progress ring with optional week bars
/// - [GaugeConfig]              — semicircular gauge with color zones
/// - [SegmentedBarConfig]       — horizontal bar split into colored segments
/// - [FillGaugeConfig]          — vertical fill gauge (e.g. water intake)
/// - [DotRowConfig]             — row of colored dots for categorical data
/// - [CalendarGridConfig]       — month-view calendar grid
/// - [HeatmapConfig]            — contribution heatmap grid
/// - [StatCardConfig]           — large value + optional status label
/// - [DualValueConfig]          — paired values (e.g. blood pressure)
/// Supporting models: [ChartPoint], [BarPoint], [GaugeZone], [Segment],
/// [DotPoint], [CalendarDay], [HeatmapCell].
library;

import 'package:flutter/material.dart';

// ── Supporting models ──────────────────────────────────────────────────────────

class ChartPoint {
  const ChartPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}

class BarPoint {
  const BarPoint({required this.label, required this.value, required this.isToday});
  final String label;
  final double value;
  final bool isToday;
}

class GaugeZone {
  const GaugeZone({required this.min, required this.max, required this.label, required this.color});
  final double min;
  final double max;
  final String label;
  final Color color;
}

class Segment {
  const Segment({required this.label, required this.value, required this.color, this.icon});
  final String label;
  final double value;
  final Color color;
  final String? icon;
}

class DotPoint {
  const DotPoint({required this.value, this.label, this.emoji});
  final double value; // 0.0–1.0
  final String? label;
  final String? emoji;
}

class CalendarDay {
  const CalendarDay({required this.dayNumber, required this.value, this.phase, this.phaseColor});
  final int dayNumber;
  final double value; // 0.0–1.0
  final String? phase;
  final Color? phaseColor;
}

class HeatmapCell {
  const HeatmapCell({required this.date, required this.value});
  final DateTime date;
  final double value;
}

// ── TileVisualizationConfig sealed class ──────────────────────────────────────

sealed class TileVisualizationConfig {
  const TileVisualizationConfig();

  /// Whether this config has sufficient data to render a chart.
  ///
  /// [buildTileVisualization] checks this before dispatching — returning
  /// [_VizEmptyPlaceholder] when false. Default is `true` (value-based configs
  /// always render).
  bool get hasChartData => true;
}

class LineChartConfig extends TileVisualizationConfig {
  const LineChartConfig({
    required this.points,
    this.referenceLine,
    this.rangeMin,
    this.rangeMax,
    this.positiveIsUp = true,
  });
  final List<ChartPoint> points;
  final double? referenceLine;
  final double? rangeMin;
  final double? rangeMax;
  final bool positiveIsUp;

  @override
  bool get hasChartData => points.isNotEmpty;
}
// LineChartConfig is always single-line. Paired metrics use DualValueConfig.

class BarChartConfig extends TileVisualizationConfig {
  const BarChartConfig({
    required this.bars,
    this.goalValue,
    this.showAvgLine = false,
  });
  final List<BarPoint> bars;
  final double? goalValue;
  final bool showAvgLine;

  @override
  bool get hasChartData => bars.isNotEmpty;
}

class AreaChartConfig extends TileVisualizationConfig {
  const AreaChartConfig({
    required this.points,
    this.targetLine,
    this.fillOpacity = 0.15,
    this.delta,
    this.positiveIsUp = true,
  });
  final List<ChartPoint> points;
  final double? targetLine;
  final double fillOpacity;
  final double? delta; // e.g. -0.03 = ↓ 3%
  final bool positiveIsUp;

  @override
  bool get hasChartData => points.isNotEmpty;
}

class RingConfig extends TileVisualizationConfig {
  const RingConfig({
    required this.value,
    required this.maxValue,
    required this.unit,
    this.weeklyBars,
  });
  final double value;
  final double maxValue;
  final String unit;
  // Non-null enables the 7-day bar row on 1×2 tiles. No separate bool flag.
  final List<BarPoint>? weeklyBars;
}

class GaugeConfig extends TileVisualizationConfig {
  const GaugeConfig({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.zones,
  });
  final double value;
  final double minValue;
  final double maxValue;
  final List<GaugeZone> zones;
}

class SegmentedBarConfig extends TileVisualizationConfig {
  const SegmentedBarConfig({required this.segments, required this.totalLabel});
  final List<Segment> segments;
  final String totalLabel;
}

class FillGaugeConfig extends TileVisualizationConfig {
  const FillGaugeConfig({
    required this.value,
    required this.maxValue,
    required this.unit,
    this.unitIcon,
    this.unitSize,
  });
  final double value;
  final double maxValue;
  final String unit;
  final String? unitIcon;
  final double? unitSize; // e.g. 0.3 for 0.3L per glass
}

class DotRowConfig extends TileVisualizationConfig {
  const DotRowConfig({required this.points, this.invertedScale = false});
  final List<DotPoint> points;
  final bool invertedScale; // true for Stress — lower is better

  @override
  bool get hasChartData => points.isNotEmpty;
}

class CalendarGridConfig extends TileVisualizationConfig {
  const CalendarGridConfig({required this.days, required this.totalDays});
  final List<CalendarDay> days;
  final int totalDays; // 28 for cycle, 30/31 for month

  @override
  bool get hasChartData => days.isNotEmpty;
}

class HeatmapConfig extends TileVisualizationConfig {
  const HeatmapConfig({
    required this.cells,
    required this.colorLow,
    required this.colorHigh,
    required this.legendLabel,
  });
  final List<HeatmapCell> cells;
  final Color colorLow;
  final Color colorHigh;
  final String legendLabel;

  @override
  bool get hasChartData => cells.isNotEmpty;
}

class StatCardConfig extends TileVisualizationConfig {
  const StatCardConfig({
    required this.value,
    required this.unit,
    this.statusColor,
    this.statusLabel,
    this.secondaryValue,
    this.trendNote,
  });
  final String value;
  final String unit;
  final Color? statusColor;
  final String? statusLabel;
  final String? secondaryValue;
  final String? trendNote;
}

class DualValueConfig extends TileVisualizationConfig {
  const DualValueConfig({
    required this.value1,
    required this.label1,
    required this.value2,
    required this.label2,
    this.points1,
    this.points2,
  });
  final String value1;
  final String label1;
  final String value2;
  final String label2;
  final List<ChartPoint>? points1;
  final List<ChartPoint>? points2;
}

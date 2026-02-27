/// Zuralog Dashboard — Threshold Line Chart Widget.
///
/// Renders a smooth line chart overlaid with horizontal coloured zone bands
/// that visually communicate safe, warning, and danger thresholds.
///
/// Supports the following metrics (detected via [MetricSeries.metricId]):
///   - `oxygen_saturation` — SpO₂ thresholds (danger/warning/normal).
///   - `blood_glucose` — Glucose zones (low/normal/high).
///   - `environmental_audio_exposure` / `headphone_audio_exposure` —
///     Audio exposure threshold (safe / warning).
///   - `walking_steadiness` — Steadiness zones (limited/low/OK).
///   - Any other metric — plain line with gradient fill (no bands).
///
/// Uses `fl_chart`'s [LineChart] with [RangeAnnotations] for zone bands.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/graph_utils.dart';

// ── Internal types ────────────────────────────────────────────────────────────

/// A single horizontal zone band definition.
class _ThresholdBand {
  const _ThresholdBand({
    required this.from,
    required this.to,
    required this.color,
    required this.label,
  });

  final double from;
  final double to;
  final Color color;
  final String label;
}

// ── Band definitions per metric ───────────────────────────────────────────────

List<_ThresholdBand> _bandsForMetric(String metricId) {
  switch (metricId) {
    case 'oxygen_saturation':
      return [
        _ThresholdBand(
          from: 0,
          to: 90,
          color: Colors.red.withValues(alpha: 0.12),
          label: 'Danger',
        ),
        _ThresholdBand(
          from: 90,
          to: 95,
          color: Colors.orange.withValues(alpha: 0.12),
          label: 'Warning',
        ),
        _ThresholdBand(
          from: 95,
          to: 101,
          color: Colors.green.withValues(alpha: 0.10),
          label: 'Normal',
        ),
      ];
    case 'blood_glucose':
      return [
        _ThresholdBand(
          from: 0,
          to: 70,
          color: Colors.orange.withValues(alpha: 0.12),
          label: 'Low',
        ),
        _ThresholdBand(
          from: 70,
          to: 140,
          color: Colors.green.withValues(alpha: 0.10),
          label: 'Normal',
        ),
        _ThresholdBand(
          from: 140,
          to: 400,
          color: Colors.red.withValues(alpha: 0.12),
          label: 'High',
        ),
      ];
    case 'environmental_audio_exposure':
    case 'headphone_audio_exposure':
      return [
        _ThresholdBand(
          from: 0,
          to: 85,
          color: Colors.green.withValues(alpha: 0.10),
          label: 'Safe',
        ),
        _ThresholdBand(
          from: 85,
          to: 140,
          color: Colors.orange.withValues(alpha: 0.12),
          label: 'Warning',
        ),
      ];
    case 'walking_steadiness':
      return [
        _ThresholdBand(
          from: 0,
          to: 60,
          color: Colors.red.withValues(alpha: 0.12),
          label: 'Limited',
        ),
        _ThresholdBand(
          from: 60,
          to: 80,
          color: Colors.orange.withValues(alpha: 0.12),
          label: 'Low',
        ),
        _ThresholdBand(
          from: 80,
          to: 101,
          color: Colors.green.withValues(alpha: 0.10),
          label: 'OK',
        ),
      ];
    default:
      return [];
  }
}

/// Returns the zone label for a given [value] and list of [bands].
String _zoneLabel(double value, List<_ThresholdBand> bands) {
  for (final band in bands) {
    if (value >= band.from && value < band.to) return band.label;
  }
  return '';
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// A line chart with optional horizontal threshold zone bands.
///
/// Identifies the active threshold scheme from [MetricSeries.metricId] and
/// renders coloured background bands behind the data line. The tooltip
/// appends the zone label (e.g. "98% — Normal") in full mode.
///
/// Example usage:
/// ```dart
/// ThresholdLineChart(
///   series: spo2Series,
///   timeRange: TimeRange.week,
///   accentColor: Colors.red,
/// )
/// ```
class ThresholdLineChart extends StatefulWidget {
  /// Creates a [ThresholdLineChart].
  ///
  /// [series] — the metric time-series to plot.
  ///
  /// [timeRange] — the selected time window (controls x-axis).
  ///
  /// [accentColor] — the primary colour for the line and gradient fill.
  ///
  /// [interactive] — enables touch tooltip when `true`.
  ///
  /// [compact] — when `true`, renders a 48 px sparkline with gradient fill
  /// but without threshold bands, axes, or tooltip.
  const ThresholdLineChart({
    super.key,
    required this.series,
    required this.timeRange,
    required this.accentColor,
    this.interactive = true,
    this.compact = false,
  });

  /// The metric time-series to visualise.
  final MetricSeries series;

  /// The selected time window (controls x-axis labelling).
  final TimeRange timeRange;

  /// The primary line/gradient colour for this metric.
  final Color accentColor;

  /// Enables touch/tap interactions when `true`.
  final bool interactive;

  /// When `true`, renders a compact 48 px gradient sparkline with no bands.
  final bool compact;

  @override
  State<ThresholdLineChart> createState() => _ThresholdLineChartState();
}

class _ThresholdLineChartState extends State<ThresholdLineChart> {
  int? _touchedIndex;

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.series.dataPoints.isEmpty) {
      return GraphEmptyState(compact: widget.compact);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    final points = widget.series.dataPoints;
    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    final minY = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.15;

    final bands = widget.compact ? <_ThresholdBand>[] : _bandsForMetric(widget.series.metricId);

    final rangeAnnotations = bands.map((band) {
      return HorizontalRangeAnnotation(
        y1: band.from.toDouble(),
        y2: band.to.toDouble(),
        color: band.color,
      );
    }).toList();

    final lineData = LineChartData(
      minY: (minY - padding).clamp(0, double.infinity),
      maxY: maxY + padding,
      rangeAnnotations: RangeAnnotations(
        horizontalRangeAnnotations: rangeAnnotations,
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: widget.accentColor,
          barWidth: widget.compact ? 1.5 : 2,
          dotData: FlDotData(
            show: !widget.compact,
            getDotPainter: (spot, percent, bar, index) {
              final isTouched = index == _touchedIndex;
              return FlDotCirclePainter(
                radius: isTouched ? 5 : 3,
                color: widget.accentColor,
                strokeWidth: 1.5,
                strokeColor: isDark
                    ? AppColors.surfaceDark
                    : AppColors.surfaceLight,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.accentColor.withValues(alpha: 0.25),
                widget.accentColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
      gridData: FlGridData(
        show: !widget.compact,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          strokeWidth: 0.5,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: widget.compact
          ? const FlTitlesData(show: false)
          : FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) => Text(
                    value.toStringAsFixed(0),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      graphXLabel(points[idx].timestamp, widget.timeRange),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
      lineTouchData: (widget.interactive && !widget.compact)
          ? LineTouchData(
              touchCallback: (event, response) {
                if (!event.isInterestedForInteractions) {
                  setState(() => _touchedIndex = null);
                  return;
                }
                setState(
                  () => _touchedIndex =
                      response?.lineBarSpots?.firstOrNull?.spotIndex,
                );
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => isDark
                    ? AppColors.surfaceDark
                    : AppColors.surfaceLight,
                getTooltipItems: (spots) {
                  return spots.map((spot) {
                    final zoneName = _zoneLabel(
                      spot.y,
                      _bandsForMetric(widget.series.metricId),
                    );
                    final text = zoneName.isNotEmpty
                        ? '${spot.y.toStringAsFixed(1)} — $zoneName'
                        : spot.y.toStringAsFixed(1);
                    return LineTooltipItem(
                      text,
                      AppTextStyles.caption.copyWith(color: labelColor),
                    );
                  }).toList();
                },
              ),
            )
          : LineTouchData(enabled: false),
    );

    if (widget.compact) {
      return SizedBox(height: 48, child: LineChart(lineData));
    }

    return LineChart(lineData);
  }
}



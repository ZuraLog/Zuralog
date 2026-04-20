library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/interactions/scrub_controller.dart';

/// Renders a [LineChart] driven by [LineChartConfig] and [ChartRenderContext].
///
/// When [scrubController] is provided and [ChartRenderContext.showTooltip]
/// is true, enables the scrubbing crosshair via fl_chart's [LineTouchData].
/// The crosshair is a dashed Sage vertical line with a category-color dot at
/// the snapped data point. Touch state is written to [scrubController] so the
/// parent shell can render the [ZChartTooltip] overlay.
class LineRenderer extends StatefulWidget {
  const LineRenderer({
    super.key,
    required this.config,
    required this.color,
    required this.renderCtx,
    this.scrubController,
    this.unit = '',
  });

  final LineChartConfig config;
  final Color color;
  final ChartRenderContext renderCtx;

  /// When non-null and [ChartRenderContext.showTooltip] is true, the renderer
  /// activates the scrubbing crosshair and writes touch state here.
  final ScrubController? scrubController;

  /// Unit string passed through to the scrub state for tooltip display.
  final String unit;

  @override
  State<LineRenderer> createState() => _LineRendererState();
}

class _LineRendererState extends State<LineRenderer> {
  static const _monthAbbrev = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  int? _lastSpotIndex;

  List<ChartPoint> _downsample(List<ChartPoint> points) {
    if (points.length <= 100) return points;
    final step = (points.length / 100).ceil();
    return [
      for (var i = 0; i < points.length; i += step) points[i],
      points.last,
    ];
  }

  void _handleTouch(FlTouchEvent event, LineTouchResponse? response) {
    final controller = widget.scrubController;
    if (controller == null) return;

    final spots = response?.lineBarSpots;
    final isActive =
        event.isInterestedForInteractions && spots != null && spots.isNotEmpty;

    if (!isActive) {
      if (controller.value != null) controller.value = null;
      _lastSpotIndex = null;
      return;
    }

    final spot = spots.first;
    final points = _downsample(widget.config.points);
    final idx = spot.spotIndex.clamp(0, points.length - 1);
    final point = points[idx];

    if (_lastSpotIndex != spot.spotIndex) {
      _lastSpotIndex = spot.spotIndex;
      HapticFeedback.lightImpact();
    }

    controller.value = ScrubState(
      spotIndex: spot.spotIndex,
      value: point.value.isFinite ? point.value : 0.0,
      date: point.date,
      pixelX: event.localPosition?.dx ?? 0.0,
    );
  }

  String _formatY(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.config.points.isEmpty) return const SizedBox.shrink();

    final progress = widget.renderCtx.animationProgress;
    final points = _downsample(widget.config.points);

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(
          i.toDouble(),
          (points[i].value.isFinite ? points[i].value : 0.0) * progress,
        ),
    ];

    final lastIndex = points.length - 1;

    final lineBarData = LineChartBarData(
      spots: spots,
      color: widget.color,
      barWidth: widget.renderCtx.strokeWidth,
      isCurved: widget.renderCtx.isCurved,
      preventCurveOverShooting: widget.renderCtx.preventCurveOverShooting,
      dotData: FlDotData(
        show: widget.renderCtx.showDots,
        checkToShowDot: (spot, barData) => spot.x == lastIndex.toDouble(),
        getDotPainter: (spot, xPercentage, barData, index) =>
            FlDotCirclePainter(
          radius: 3,
          color: widget.color,
          strokeWidth: 0,
        ),
      ),
      belowBarData: BarAreaData(show: false),
    );

    final minY = widget.renderCtx.minY ?? widget.config.rangeMin;
    final maxY = widget.renderCtx.maxY ?? widget.config.rangeMax;

    final scrubEnabled =
        widget.scrubController != null && widget.renderCtx.showTooltip;

    final textSecondary = AppColorsOf(context).textSecondary;

    // Compute which x-indices should display a date label (first, ~1/3, ~2/3, last).
    final n = points.length;
    final Set<int> labelIndices = n <= 1
        ? {0}
        : {0, (n * 1 / 3).round(), (n * 2 / 3).round(), n - 1};

    return LineChart(
      LineChartData(
        lineBarsData: [lineBarData],
        gridData: FlGridData(
          show: widget.renderCtx.showGrid,
          drawVerticalLine: false,
          horizontalInterval: null,
          getDrawingHorizontalLine: (value) => FlLine(
            color: textSecondary.withValues(alpha: 0.08),
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: !widget.renderCtx.showAxes
            ? const FlTitlesData(show: false)
            : FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      // Hide the extreme tick labels — they overlap the chart edge.
                      if (value == meta.min || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          _formatY(value),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 16,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (!labelIndices.contains(idx)) {
                        return const SizedBox.shrink();
                      }
                      final date = points[idx].date;
                      final label =
                          '${_monthAbbrev[date.month - 1]} ${date.day}';
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          label,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
        lineTouchData: scrubEnabled
            ? LineTouchData(
                enabled: true,
                handleBuiltInTouches: false,
                touchCallback: _handleTouch,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: AppColors.primary,
                        strokeWidth: 1,
                        dashArray: [4, 3],
                      ),
                      FlDotData(
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: widget.color,
                          strokeWidth: 0,
                        ),
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Colors.transparent,
                  tooltipBorderRadius: BorderRadius.zero,
                  getTooltipItems: (spots) =>
                      spots.map((_) => null).toList(),
                ),
              )
            : const LineTouchData(enabled: false),
        clipData: const FlClipData.all(),
        minY: minY,
        maxY: maxY,
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (widget.config.referenceLine != null)
              HorizontalLine(
                y: widget.config.referenceLine!,
                color: widget.color.withValues(alpha: 0.4),
                strokeWidth: 0.75,
                dashArray: [4, 3],
              ),
          ],
        ),
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            if (widget.config.rangeMin != null &&
                widget.config.rangeMax != null)
              HorizontalRangeAnnotation(
                y1: widget.config.rangeMin!,
                y2: widget.config.rangeMax!,
                color: widget.color.withValues(alpha: 0.08),
              ),
          ],
        ),
      ),
      duration: widget.renderCtx.flChartDuration,
      curve: Curves.easeOut,
    );
  }
}

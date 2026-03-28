library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/interactions/scrub_controller.dart';

/// Renders an area chart (filled line chart) driven by [AreaChartConfig].
///
/// Delegates all mode-specific decisions (stroke width, curved lines, dot
/// visibility, animation timing) to the supplied [ChartRenderContext].
///
/// When [scrubController] is provided and [ChartRenderContext.showTooltip]
/// is true, enables the scrubbing crosshair via fl_chart's [LineTouchData].
/// The crosshair is a dashed Sage vertical line with a category-color dot at
/// the snapped data point. Touch state is written to [scrubController] so the
/// parent shell can render the [ZChartTooltip] overlay.
class AreaRenderer extends StatefulWidget {
  const AreaRenderer({
    super.key,
    required this.config,
    required this.color,
    required this.renderCtx,
    this.scrubController,
    this.unit = '',
  });

  final AreaChartConfig config;
  final Color color;
  final ChartRenderContext renderCtx;

  /// When non-null and [ChartRenderContext.showTooltip] is true, the renderer
  /// activates the scrubbing crosshair and writes touch state here.
  final ScrubController? scrubController;

  /// Unit string passed through to the scrub state for tooltip display.
  final String unit;

  @override
  State<AreaRenderer> createState() => _AreaRendererState();
}

class _AreaRendererState extends State<AreaRenderer> {
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

  @override
  Widget build(BuildContext context) {
    if (widget.config.points.isEmpty) return const SizedBox.shrink();

    final progress = widget.renderCtx.animationProgress;
    final points = _downsample(widget.config.points);

    final lastIndex = points.length - 1;

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), (points[i].value.isFinite ? points[i].value : 0.0) * progress),
    ];

    final lineBarData = LineChartBarData(
      spots: spots,
      color: widget.color,
      barWidth: widget.renderCtx.strokeWidth,
      isCurved: widget.renderCtx.isCurved,
      preventCurveOverShooting: widget.renderCtx.preventCurveOverShooting,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: widget.renderCtx.showDots,
        checkToShowDot: (spot, barData) => spot.x.toInt() == lastIndex,
        getDotPainter: (spot, percent, barData, index) =>
            FlDotCirclePainter(radius: 3, color: widget.color, strokeWidth: 0),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.color.withValues(alpha: widget.config.fillOpacity),
            widget.color.withValues(alpha: 0),
          ],
        ),
      ),
    );

    final scrubEnabled = widget.scrubController != null && widget.renderCtx.showTooltip;

    final chartData = LineChartData(
      lineBarsData: [lineBarData],
      gridData: FlGridData(
        show: widget.renderCtx.showGrid,
        drawVerticalLine: false,
        horizontalInterval: null,
        getDrawingHorizontalLine: (value) => FlLine(
          color: AppColors.warmWhite.withValues(alpha: 0.04),
          strokeWidth: 0.5,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      lineTouchData: scrubEnabled
          ? LineTouchData(
              enabled: true,
              handleBuiltInTouches: true,
              touchCallback: _handleTouch,
              getTouchedSpotIndicator: (barData, spotIndexes) {
                return spotIndexes.map((index) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                      color: AppColors.primary.withValues(alpha: 0.4),
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
      extraLinesData: widget.config.targetLine != null
          ? ExtraLinesData(horizontalLines: [
              HorizontalLine(
                y: widget.config.targetLine!,
                color: widget.color.withValues(alpha: 0.5),
                strokeWidth: 0.75,
                dashArray: [4, 3],
              ),
            ])
          : const ExtraLinesData(),
    );

    return Stack(
      children: [
        LineChart(
          chartData,
          duration: widget.renderCtx.flChartDuration,
          curve: Curves.easeOut,
        ),
        if (widget.config.delta != null)
          Positioned(
            top: 4,
            right: 4,
            child: DeltaBadge(
              delta: widget.config.delta!,
              positiveIsUp: widget.config.positiveIsUp,
            ),
          ),
      ],
    );
  }
}

/// A small badge showing a percentage change with an up/down arrow.
///
/// Displays green for "good" changes and dark accent for "bad" changes,
/// where "good" depends on whether higher values are desirable
/// ([positiveIsUp]).
class DeltaBadge extends StatelessWidget {
  const DeltaBadge({
    super.key,
    required this.delta,
    required this.positiveIsUp,
  });

  final double delta;
  final bool positiveIsUp;

  @override
  Widget build(BuildContext context) {
    final isPositive = delta >= 0;
    final isGood = positiveIsUp ? isPositive : !isPositive;
    final badgeColor =
        isGood ? AppColors.categoryActivity : AppColors.categoryHeart;
    final arrow = isPositive ? '\u25B2' : '\u25BC';
    final pct = '$arrow ${(delta.abs() * 100).toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        pct,
        style: AppTextStyles.labelSmall.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

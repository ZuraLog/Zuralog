library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_mode.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/interactions/chart_tooltip.dart';
import 'package:zuralog/shared/widgets/charts/interactions/scrub_controller.dart';
import 'package:zuralog/shared/widgets/charts/modes/tile_chart_shell.dart';

/// Renders two datasets overlaid on one chart for [ChartMode.comparison].
///
/// **Line / Area:** Two [LineChartBarData] in a single [LineChart].
///   Current period: solid line, full [color] opacity.
///   Previous period: dashed line (`dashArray: [4,3]`), [color] at 40% opacity.
///   Scrubbing writes both [ScrubState.value] and [ScrubState.comparisonValue].
///
/// **Bar:** Two rods per [BarChartGroupData] — current (full) + previous (30%).
///
/// **Ring / Gauge / FillGauge:** Side-by-side [Row] with two [TileChartShell]
///   instances in square mode at half width.
///
/// A legend row appears at the bottom of all variants.
class ComparisonChartShell extends StatefulWidget {
  const ComparisonChartShell({
    super.key,
    required this.config,
    required this.comparisonConfig,
    required this.color,
    required this.renderCtx,
    this.unit = '',
    this.primaryLabel = 'This week',
    this.comparisonLabel = 'Last week',
  });

  final TileVisualizationConfig config;
  final TileVisualizationConfig comparisonConfig;
  final Color color;
  final ChartRenderContext renderCtx;
  final String unit;
  final String primaryLabel;
  final String comparisonLabel;

  @override
  State<ComparisonChartShell> createState() => _ComparisonChartShellState();
}

class _ComparisonChartShellState extends State<ComparisonChartShell> {
  late final ScrubController _scrubController;
  int? _lastSpotIndex;

  @override
  void initState() {
    super.initState();
    _scrubController = ScrubController();
  }

  @override
  void dispose() {
    _scrubController.dispose();
    super.dispose();
  }

  // ── Line / Area comparison ─────────────────────────────────────────────────

  List<ChartPoint> _downsample(List<ChartPoint> points) {
    if (points.length <= 100) return points;
    final step = (points.length / 100).ceil();
    return [
      for (var i = 0; i < points.length; i += step) points[i],
      points.last,
    ];
  }

  void _handleLineTouch(
    FlTouchEvent event,
    LineTouchResponse? response,
    List<ChartPoint> primaryPoints,
    List<ChartPoint> comparisonPoints,
  ) {
    final spots = response?.lineBarSpots;
    final isActive =
        event.isInterestedForInteractions && spots != null && spots.isNotEmpty;

    if (!isActive) {
      if (_scrubController.value != null) _scrubController.value = null;
      _lastSpotIndex = null;
      return;
    }

    final spot = spots.first;
    final idx = spot.spotIndex.clamp(0, primaryPoints.length - 1);
    final point = primaryPoints[idx];

    if (_lastSpotIndex != spot.spotIndex) {
      _lastSpotIndex = spot.spotIndex;
      HapticFeedback.lightImpact();
    }

    final compVal = idx < comparisonPoints.length
        ? (comparisonPoints[idx].value.isFinite
            ? comparisonPoints[idx].value
            : null)
        : null;

    _scrubController.value = ScrubState(
      spotIndex: spot.spotIndex,
      value: point.value.isFinite ? point.value : 0.0,
      date: point.date,
      pixelX: event.localPosition?.dx ?? 0.0,
      comparisonValue: compVal,
    );
  }

  Widget _buildLineComparison(
    LineChartConfig primary,
    LineChartConfig comparison,
  ) {
    final progress = widget.renderCtx.animationProgress;
    final primaryPts = _downsample(primary.points);
    final compPts = _downsample(comparison.points);

    // Shared Y axis — scale to fit both datasets.
    final allValues = [
      ...primaryPts.map((p) => p.value.isFinite ? p.value : 0.0),
      ...compPts.map((p) => p.value.isFinite ? p.value : 0.0),
    ];
    // Guard against empty list: fold on [] returns the identity value, so
    // minVal would be +infinity and maxVal 0.0, producing a NaN Y range.
    final maxVal = allValues.isEmpty
        ? 1.0
        : allValues.fold(0.0, (a, b) => a > b ? a : b);
    final minVal = allValues.isEmpty
        ? 0.0
        : allValues.fold(double.infinity, (a, b) => a < b ? a : b);
    final padding = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal) * 0.15;

    final primarySpots = [
      for (var i = 0; i < primaryPts.length; i++)
        FlSpot(
          i.toDouble(),
          (primaryPts[i].value.isFinite ? primaryPts[i].value : 0.0) *
              progress,
        ),
    ];

    final compSpots = [
      for (var i = 0; i < compPts.length; i++)
        FlSpot(
          i.toDouble(),
          (compPts[i].value.isFinite ? compPts[i].value : 0.0) * progress,
        ),
    ];

    final primaryBar = LineChartBarData(
      spots: primarySpots,
      color: widget.color,
      barWidth: widget.renderCtx.strokeWidth,
      isCurved: widget.renderCtx.isCurved,
      preventCurveOverShooting: widget.renderCtx.preventCurveOverShooting,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );

    final compBar = LineChartBarData(
      spots: compSpots,
      color: widget.color.withValues(alpha: 0.4),
      barWidth: widget.renderCtx.strokeWidth,
      isCurved: widget.renderCtx.isCurved,
      preventCurveOverShooting: widget.renderCtx.preventCurveOverShooting,
      dashArray: [4, 3],
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );

    return ValueListenableBuilder<ScrubState?>(
      valueListenable: _scrubController,
      builder: (context, scrubState, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [primaryBar, compBar],
                  minY: minVal - padding,
                  maxY: maxVal + padding,
                  gridData: FlGridData(
                    show: widget.renderCtx.showGrid,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.warmWhite.withValues(alpha: 0.04),
                      strokeWidth: 0.5,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    touchCallback: (event, response) => _handleLineTouch(
                      event,
                      response,
                      primaryPts,
                      compPts,
                    ),
                    getTouchedSpotIndicator: (barData, spotIndexes) {
                      return spotIndexes.map((_) {
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
                  ),
                  clipData: const FlClipData.all(),
                ),
                duration: widget.renderCtx.flChartDuration,
                curve: Curves.easeOut,
              ),
            ),
            if (scrubState != null)
              _ScrubTooltipOverlay(
                scrubState: scrubState,
                unit: widget.unit,
              ),
          ],
        );
      },
    );
  }

  // ── Bar comparison ─────────────────────────────────────────────────────────

  Widget _buildBarComparison(
    BarChartConfig primary,
    BarChartConfig comparison,
  ) {
    final progress = widget.renderCtx.animationProgress;
    final len = primary.bars.length;
    // Align comparison bars — take up to len bars from comparison.
    final compBars = comparison.bars.length >= len
        ? comparison.bars.sublist(comparison.bars.length - len)
        : comparison.bars;

    final maxPrimary =
        primary.bars.map((b) => b.value).fold(0.0, (a, b) => a > b ? a : b);
    final maxComp =
        compBars.map((b) => b.value).fold(0.0, (a, b) => a > b ? a : b);
    final maxY = (maxPrimary > maxComp ? maxPrimary : maxComp) * 1.15;

    final groups = <BarChartGroupData>[
      for (var i = 0; i < len; i++)
        BarChartGroupData(
          x: i,
          groupVertically: false,
          barRods: [
            BarChartRodData(
              toY: (primary.bars[i].value.isFinite
                      ? primary.bars[i].value
                      : 0.0) *
                  progress,
              color: widget.color,
              width: 6,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(2)),
            ),
            if (i < compBars.length)
              BarChartRodData(
                toY: (compBars[i].value.isFinite ? compBars[i].value : 0.0) *
                    progress,
                color: widget.color.withValues(alpha: 0.3),
                width: 6,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(2)),
              ),
          ],
        ),
    ];

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY > 0 ? maxY : 1.0,
          minY: 0,
          barGroups: groups,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: const BarTouchData(enabled: false),
          titlesData: const FlTitlesData(show: false),
          extraLinesData: const ExtraLinesData(),
        ),
        duration: widget.renderCtx.flChartDuration,
        curve: Curves.easeOut,
      ),
    );
  }

  // ── Side-by-side fallback (Ring / Gauge / FillGauge) ─────────────────────

  Widget _buildSideBySide() {
    return _SideBySideShell(
      primary: widget.config,
      comparison: widget.comparisonConfig,
      color: widget.color,
      primaryLabel: widget.primaryLabel,
      comparisonLabel: widget.comparisonLabel,
    );
  }

  // ── Legend row ─────────────────────────────────────────────────────────────

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendDot(color: widget.color, filled: true),
          const SizedBox(width: 4),
          Text(
            widget.primaryLabel,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColorsOf(context).textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          _LegendDot(
              color: widget.color.withValues(alpha: 0.4), filled: false),
          const SizedBox(width: 4),
          Text(
            widget.comparisonLabel,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColorsOf(context).textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSideBySide = widget.config is RingConfig ||
        widget.config is GaugeConfig ||
        widget.config is FillGaugeConfig;

    final Widget chartArea = switch (widget.config) {
      final LineChartConfig c when widget.comparisonConfig is LineChartConfig =>
        _buildLineComparison(c, widget.comparisonConfig as LineChartConfig),
      final AreaChartConfig _ when widget.comparisonConfig is LineChartConfig =>
        _buildLineComparison(
          LineChartConfig(
            points: (widget.config as AreaChartConfig).points,
          ),
          widget.comparisonConfig as LineChartConfig,
        ),
      final BarChartConfig c when widget.comparisonConfig is BarChartConfig =>
        _buildBarComparison(c, widget.comparisonConfig as BarChartConfig),
      _ when isSideBySide => _buildSideBySide(),
      _ => () {
          assert(
            false,
            'ComparisonChartShell: incompatible config types '
            '${widget.config.runtimeType} vs ${widget.comparisonConfig.runtimeType}',
          );
          return const SizedBox.shrink();
        }(),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        chartArea,
        if (!isSideBySide) _buildLegend(),
      ],
    );
  }
}

// ── Scrub tooltip overlay ─────────────────────────────────────────────────────

class _ScrubTooltipOverlay extends StatelessWidget {
  const _ScrubTooltipOverlay({
    required this.scrubState,
    required this.unit,
  });

  final ScrubState scrubState;
  final String unit;

  @override
  Widget build(BuildContext context) {
    const tooltipWidth = 100.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final rawX = scrubState.pixelX - tooltipWidth / 2;
    // Guard: if screenWidth < tooltipWidth (e.g., very narrow host), the upper
    // bound would be negative, causing a RangeError in Dart's clamp.
    final clampMax = math.max(0.0, screenWidth - tooltipWidth);
    final clampedX = rawX.clamp(0.0, clampMax);

    return Positioned(
      left: clampedX,
      top: 0,
      child: ZChartTooltip(
        value: scrubState.value,
        unit: unit,
        date: scrubState.date,
        comparisonValue: scrubState.comparisonValue,
      ),
    );
  }
}

// ── Side-by-side shell ────────────────────────────────────────────────────────

/// Renders two [TileChartShell] instances in square mode at half width for
/// ring/gauge/fill gauge comparison.
class _SideBySideShell extends StatelessWidget {
  const _SideBySideShell({
    required this.primary,
    required this.comparison,
    required this.color,
    required this.primaryLabel,
    required this.comparisonLabel,
  });

  final TileVisualizationConfig primary;
  final TileVisualizationConfig comparison;
  final Color color;
  final String primaryLabel;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _ZChartFullProxy(config: primary, color: color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      primaryLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColorsOf(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _ZChartFullProxy(
                        config: comparison,
                        color: color.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comparisonLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColorsOf(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Renders a config using [TileChartShell] in square mode — used for side-by-side
/// ring/gauge/fill gauge comparison to avoid a circular import with [ZChart].
class _ZChartFullProxy extends StatelessWidget {
  const _ZChartFullProxy({required this.config, required this.color});

  final TileVisualizationConfig config;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final renderCtx = ChartRenderContext.fromMode(ChartMode.square);
    return TileChartShell(
      config: config,
      color: color,
      mode: ChartMode.square,
      renderCtx: renderCtx,
    );
  }
}

// ── Legend dot ────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: filled ? null : Border.all(color: color, width: 1.5),
      ),
    );
  }
}

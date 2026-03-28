library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';

/// Renders a [BarChart] driven by [BarChartConfig] and [ChartRenderContext].
///
/// This widget is a pure rendering primitive — it does not wrap itself in
/// Semantics, size-switching logic, or entrance animation controllers. Those
/// concerns belong in the chart shell that hosts this renderer.
class BarRenderer extends StatelessWidget {
  const BarRenderer({
    super.key,
    required this.config,
    required this.color,
    required this.renderCtx,
    this.onBarTap,
  });

  final BarChartConfig config;
  final Color color;
  final ChartRenderContext renderCtx;
  final void Function(int barIndex, double value, String label)? onBarTap;

  @override
  Widget build(BuildContext context) {
    // Apply bar-count truncation from render context.
    final allBars = config.bars;
    final bars = renderCtx.maxBars != null && allBars.length > renderCtx.maxBars!
        ? allBars.sublist(allBars.length - renderCtx.maxBars!)
        : allBars;

    if (bars.isEmpty) return const SizedBox.shrink();

    final barWidth = renderCtx.showAxes ? 12.0 : 8.0;

    // Compute ceiling: 110% of whichever is greater — the tallest bar or the
    // goal line — so there's always breathing room above the data.
    final maxVal = bars.map((b) => b.value).fold(0.0, (a, b) => a > b ? a : b);
    final goalVal = config.goalValue ?? 0;
    final ceiling = maxVal > goalVal ? maxVal : goalVal;
    final maxY = ceiling > 0 ? ceiling * 1.1 : 1.0;

    // ── Horizontal reference lines ────────────────────────────────────────
    final horizontalLines = <HorizontalLine>[];

    if (config.goalValue != null && config.goalValue! > 0) {
      horizontalLines.add(
        HorizontalLine(
          y: config.goalValue!,
          color: color.withValues(alpha: 0.5),
          strokeWidth: 1,
          dashArray: [4, 3],
        ),
      );
    }

    if (config.showAvgLine && bars.isNotEmpty) {
      final avg =
          bars.map((b) => b.value).reduce((a, b) => a + b) / bars.length;
      horizontalLines.add(
        HorizontalLine(
          y: avg,
          color: color.withValues(alpha: 0.5),
          strokeWidth: 1,
          dashArray: [4, 3],
        ),
      );
    }

    // ── Bar groups ────────────────────────────────────────────────────────
    final groups = <BarChartGroupData>[
      for (var i = 0; i < bars.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: (bars[i].value.isFinite ? bars[i].value : 0.0) * renderCtx.animationProgress,
              color: bars[i].isToday ? color : color.withValues(alpha: 0.3),
              width: barWidth,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
          ],
        ),
    ];

    // ── Chart ─────────────────────────────────────────────────────────────
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barGroups: groups,
        barTouchData: onBarTap != null
            ? BarTouchData(
                enabled: true,
                handleBuiltInTouches: false,
                touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
                  if (!event.isInterestedForInteractions) return;
                  final spot = response?.spot;
                  if (spot == null) return;
                  final idx = spot.touchedBarGroupIndex;
                  if (idx < 0 || idx >= bars.length) return;
                  onBarTap!(idx, bars[idx].value, bars[idx].label);
                },
              )
            : const BarTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: horizontalLines,
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: renderCtx.showAxes
              ? AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 14,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= bars.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          bars[idx].label,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColorsOf(context).textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                )
              : const AxisTitles(),
        ),
      ),
      duration: renderCtx.flChartDuration,
      curve: Curves.easeOut,
    );
  }
}

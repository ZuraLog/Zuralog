library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class BarChartViz extends StatelessWidget {
  const BarChartViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final BarChartConfig config;
  final Color color;
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    final bars = switch (size) {
      TileSize.square => config.bars.length > 5
          ? config.bars.sublist(config.bars.length - 5)
          : config.bars,
      _ => config.bars,
    };

    if (bars.isEmpty) return const SizedBox.shrink();

    final showLabels = size != TileSize.square;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final barWidth = switch (size) {
      TileSize.square => 8.0,
      _ => 12.0,
    };

    final maxVal = bars.map((b) => b.value).fold(0.0, (a, b) => a > b ? a : b);
    final goalVal = config.goalValue ?? 0;
    final ceiling = maxVal > goalVal ? maxVal : goalVal;
    final maxY = ceiling > 0 ? ceiling * 1.1 : 1.0;

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

    final groups = <BarChartGroupData>[
      for (var i = 0; i < bars.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: bars[i].value,
              color:
                  bars[i].isToday ? color : color.withValues(alpha: 0.3),
              width: barWidth,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
          ],
        ),
    ];

    return Semantics(
      label: 'Bar chart with ${bars.length} bars',
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          barGroups: groups,
          barTouchData: const BarTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: horizontalLines,
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: showLabels
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
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

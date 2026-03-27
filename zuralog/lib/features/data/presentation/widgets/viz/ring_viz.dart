library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class RingViz extends StatelessWidget {
  const RingViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final RingConfig config;
  final Color color;
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      TileSize.square => _buildSquare(context),
      TileSize.wide   => _buildWide(context),
      TileSize.tall   => _buildTall(context),
    };
  }

  String get _pct {
    if (config.maxValue == 0) return '0%';
    return '${(config.value / config.maxValue * 100).round()}%';
  }

  Widget _buildRing(BuildContext context, double diameter) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final radius = diameter * 0.12;
    final filled = config.value.clamp(0.0, config.maxValue);
    final empty = (config.maxValue - config.value).clamp(0.0, config.maxValue);

    return Semantics(
      label: '${config.maxValue > 0 ? (config.value / config.maxValue * 100).round() : 0} percent',
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              duration:
                  reduceMotion ? Duration.zero : const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 0,
                centerSpaceRadius: diameter / 2 - radius,
                pieTouchData: PieTouchData(enabled: false),
                sections: [
                  PieChartSectionData(
                    value: filled,
                    color: color,
                    radius: radius,
                    showTitle: false,
                  ),
                  if (empty > 0)
                    PieChartSectionData(
                      value: empty,
                      color: color.withValues(alpha: 0.15),
                      radius: radius,
                      showTitle: false,
                    ),
                ],
              ),
            ),
            Text(
              _pct,
              style: AppTextStyles.labelLarge.copyWith(
                fontSize: diameter * 0.2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquare(BuildContext context) =>
      Center(child: _buildRing(context, 80));

  Widget _buildWide(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        _buildRing(context, 90),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${config.value.round()}',
                style: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '/ ${config.maxValue.round()} ${config.unit}',
                style: AppTextStyles.labelSmall
                    .copyWith(color: colors.textSecondary),
              ),
              Text(
                '${(config.maxValue - config.value).round()} remaining',
                style: AppTextStyles.labelSmall
                    .copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTall(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildRing(context, 110),
        if (config.weeklyBars != null) ...[
          const SizedBox(height: 8),
          _BarRow(bars: config.weeklyBars!, color: color),
        ],
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.bars, required this.color});
  final List<BarPoint> bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxVal = bars.map((b) => b.value).reduce((a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bars.map((bar) {
        final h = maxVal > 0 ? 24.0 * bar.value / maxVal : 0.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: h.clamp(2.0, 24.0),
                  decoration: BoxDecoration(
                    color: bar.isToday ? color : color.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 2),
                Text(bar.label, style: AppTextStyles.labelSmall.copyWith(
                  color: AppColorsOf(context).textSecondary,
                )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

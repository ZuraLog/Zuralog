library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';

/// Renders a horizontal stacked bar with colored segments and animated
/// entrance width.
///
/// This widget owns only the bar graphic — no labels, totals, or legend.
/// The mode shell provides those.
class SegmentedBarRenderer extends StatelessWidget {
  const SegmentedBarRenderer({
    super.key,
    required this.config,
    required this.color,
    required this.renderCtx,
    required this.barHeight,
  });

  final SegmentedBarConfig config;
  final Color color;
  final ChartRenderContext renderCtx;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final total =
        config.segments.fold<double>(0, (sum, seg) => sum + seg.value);
    if (total == 0) return SizedBox(height: barHeight);

    return FractionallySizedBox(
      widthFactor: renderCtx.animationProgress,
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: config.segments
              .map(
                (seg) => Expanded(
                  flex: math.max(1, (seg.value.clamp(0, total) / total * 1000).round()),
                  child: Container(height: barHeight, color: seg.color),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

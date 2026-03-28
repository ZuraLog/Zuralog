library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/renderers/area_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/bar_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/line_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/segmented_bar_renderer.dart';

/// Renders a sparkline — a tiny 16px-tall chart with zero chrome.
///
/// No axes, no labels, no dots, no grid. Just the trend shape.
/// Non-interactive — no GestureDetector.
///
/// Supported types: [LineChartConfig], [AreaChartConfig], [BarChartConfig],
/// [SegmentedBarConfig]. All others render [SizedBox.shrink].
class SparklineChartShell extends StatelessWidget {
  const SparklineChartShell({
    super.key,
    required this.config,
    required this.color,
    required this.renderCtx,
  });

  final TileVisualizationConfig config;
  final Color color;
  final ChartRenderContext renderCtx;

  @override
  Widget build(BuildContext context) {
    final Widget inner = switch (config) {
      final LineChartConfig c => LineRenderer(
          config: c,
          color: color,
          renderCtx: renderCtx,
        ),
      final AreaChartConfig c => AreaRenderer(
          config: c,
          color: color,
          renderCtx: renderCtx,
        ),
      final BarChartConfig c => BarRenderer(
          config: c,
          color: color,
          renderCtx: renderCtx,
        ),
      final SegmentedBarConfig c => SegmentedBarRenderer(
          config: c,
          color: color,
          renderCtx: renderCtx,
          barHeight: 16,
        ),
      _ => () {
          assert(
            false,
            'SparklineChartShell: ${config.runtimeType} has no sparkline representation',
          );
          debugPrint(
            'SparklineChartShell: unsupported config type ${config.runtimeType}',
          );
          return const SizedBox.shrink();
        }(),
    };

    return SizedBox(height: 16, child: inner);
  }
}

library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/calendar_grid_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/dot_row_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/dual_value_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/heatmap_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/stat_card_viz.dart';
import 'package:zuralog/shared/widgets/charts/chart_mode.dart';
import 'package:zuralog/shared/widgets/charts/z_chart.dart';

// ── _VizEmptyPlaceholder ──────────────────────────────────────────────────────

/// Shown in place of a chart when [TileVisualizationConfig.hasChartData] is
/// false — prevents silent chart-area collapse.
class _VizEmptyPlaceholder extends StatelessWidget {
  const _VizEmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Center(
      child: Icon(
        Icons.show_chart_rounded,
        size: 20,
        color: colors.textTertiary.withValues(alpha: 0.35),
      ),
    );
  }
}

/// Dispatches to the correct viz widget based on [config] type and [size].
Widget buildTileVisualization({
  required TileVisualizationConfig config,
  required Color categoryColor,
  required TileSize size,
}) {
  // ── Chart types → ZChart unified system ───────────────────────────────
  if (config is LineChartConfig ||
      config is BarChartConfig ||
      config is AreaChartConfig ||
      config is RingConfig ||
      config is GaugeConfig ||
      config is FillGaugeConfig ||
      config is SegmentedBarConfig) {
    return ZChart(
      config: config,
      mode: size.toChartMode(),
      color: categoryColor,
    );
  }

  // ── Non-chart types → standalone widgets ─────────────────────────────
  if (!config.hasChartData) return const _VizEmptyPlaceholder();

  return switch (config) {
    DotRowConfig()       => DotRowViz(config: config, color: categoryColor, size: size),
    CalendarGridConfig() => CalendarGridViz(config: config, color: categoryColor, size: size),
    HeatmapConfig()      => HeatmapViz(config: config, color: categoryColor, size: size),
    StatCardConfig()     => StatCardViz(config: config, color: categoryColor, size: size),
    DualValueConfig()    => DualValueViz(config: config, color: categoryColor, size: size),
    _ => const _VizEmptyPlaceholder(),
  };
}

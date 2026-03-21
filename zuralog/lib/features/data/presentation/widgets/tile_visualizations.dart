library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/area_chart_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/bar_chart_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/calendar_grid_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/dot_row_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/dual_value_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/fill_gauge_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/gauge_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/heatmap_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/line_chart_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/ring_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/segmented_bar_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/stat_card_viz.dart';

/// Dispatches to the correct viz widget based on [config] type and [size].
Widget buildTileVisualization({
  required TileVisualizationConfig config,
  required Color categoryColor,
  required TileSize size,
}) {
  return switch (config) {
    LineChartConfig()    => LineChartViz(config: config, color: categoryColor, size: size),
    BarChartConfig()     => BarChartViz(config: config, color: categoryColor, size: size),
    AreaChartConfig()    => AreaChartViz(config: config, color: categoryColor, size: size),
    RingConfig()         => RingViz(config: config, color: categoryColor, size: size),
    GaugeConfig()        => GaugeViz(config: config, color: categoryColor, size: size),
    SegmentedBarConfig() => SegmentedBarViz(config: config, color: categoryColor, size: size),
    FillGaugeConfig()    => FillGaugeViz(config: config, color: categoryColor, size: size),
    DotRowConfig()       => DotRowViz(config: config, color: categoryColor, size: size),
    CalendarGridConfig() => CalendarGridViz(config: config, color: categoryColor, size: size),
    HeatmapConfig()      => HeatmapViz(config: config, color: categoryColor, size: size),
    StatCardConfig()     => StatCardViz(config: config, color: categoryColor, size: size),
    DualValueConfig()    => DualValueViz(config: config, color: categoryColor, size: size),
  };
}

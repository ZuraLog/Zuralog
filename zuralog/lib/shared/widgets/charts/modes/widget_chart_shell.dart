library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_mode.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/modes/tile_chart_shell.dart';

/// Stub shell for [ChartMode.widget].
///
/// Delegates to [TileChartShell] in square mode until the home screen widget
/// feature ships. When the widget is implemented, this shell will apply
/// widget-specific visual adjustments (20% larger text, 2px stroke, higher
/// contrast, semi-transparent dark surface background).
///
/// See spec §12 for the full implementation notes.
class WidgetChartShell extends StatelessWidget {
  const WidgetChartShell({
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
    // Stub: render square tile mode as a placeholder.
    // TODO(widget-feature): implement widget-specific visual treatment per spec §12.
    return TileChartShell(
      config: config,
      color: color,
      mode: ChartMode.square,
      renderCtx: renderCtx,
    );
  }
}

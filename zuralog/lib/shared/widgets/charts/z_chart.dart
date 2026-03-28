library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/animations/chart_entrance_controller.dart';
import 'package:zuralog/shared/widgets/charts/chart_mode.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/modes/full_chart_shell.dart';
import 'package:zuralog/shared/widgets/charts/modes/mini_progress.dart';
import 'package:zuralog/shared/widgets/charts/modes/sparkline_shell.dart';
import 'package:zuralog/shared/widgets/charts/modes/tile_chart_shell.dart';
import 'package:zuralog/shared/widgets/charts/z_chart_empty_state.dart';

/// Unified entry point for all chart visualizations in Zuralog.
///
/// Accepts any [TileVisualizationConfig] subtype (line, bar, area, ring,
/// gauge, fill gauge, segmented bar) and renders it in the requested
/// [ChartMode] with entrance animation, accessibility semantics, and
/// optional tap handling.
///
/// Modes that are not yet implemented (full, sparkline, widget, comparison,
/// mini) fall back to the square tile layout with a debug message.
class ZChart extends StatefulWidget {
  const ZChart({
    super.key,
    required this.config,
    required this.mode,
    required this.color,
    this.onTap,
    this.unit = '',
    this.goalValue,
  });

  final TileVisualizationConfig config;
  final ChartMode mode;
  final Color color;
  final VoidCallback? onTap;
  final String unit;
  final double? goalValue;

  @override
  State<ZChart> createState() => _ZChartState();
}

class _ZChartState extends State<ZChart>
    with SingleTickerProviderStateMixin, ChartEntranceController {
  @override
  Object get entranceKey => widget.config;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;

    // ── Guard: unsupported config type ──────────────────────────────────
    if (config is! LineChartConfig &&
        config is! BarChartConfig &&
        config is! AreaChartConfig &&
        config is! RingConfig &&
        config is! GaugeConfig &&
        config is! FillGaugeConfig &&
        config is! SegmentedBarConfig) {
      assert(
        false,
        'ZChart: unsupported config type: ${config.runtimeType}',
      );
      debugPrint('ZChart: unsupported config type: ${config.runtimeType}');
      return const SizedBox.shrink();
    }

    // ── Guard: empty data ───────────────────────────────────────────────
    if (!config.hasChartData) {
      return ZChartEmptyState(
        configType: config.runtimeType,
        mode: widget.mode,
        color: widget.color,
      );
    }

    // ── Build render context ────────────────────────────────────────────
    final renderCtx = ChartRenderContext.fromMode(
      widget.mode,
      animationProgress: animationProgress,
    );

    // ── Build chart body ────────────────────────────────────────────────
    final Widget chart;

    switch (widget.mode) {
      case ChartMode.square:
      case ChartMode.wide:
      case ChartMode.tall:
        chart = TileChartShell(
          config: config,
          color: widget.color,
          mode: widget.mode,
          renderCtx: renderCtx,
        );
      case ChartMode.full:
        chart = FullChartShell(
          config: config,
          color: widget.color,
          renderCtx: renderCtx,
          unit: widget.unit,
        );
      case ChartMode.sparkline:
        chart = SparklineChartShell(
          config: config,
          color: widget.color,
          renderCtx: renderCtx,
        );
      case ChartMode.widget:
      case ChartMode.comparison:
        assert(() {
          debugPrint('ZChart: ${widget.mode.name} mode not yet implemented');
          return true;
        }());
        chart = TileChartShell(
          config: config,
          color: widget.color,
          mode: ChartMode.square,
          renderCtx: ChartRenderContext.fromMode(
            ChartMode.square,
            animationProgress: animationProgress,
          ),
        );
      case ChartMode.mini:
        // Mini mode only applies to RingConfig and FillGaugeConfig.
        if (config is RingConfig) {
          return Semantics(
            label: _semanticsLabel(config),
            child: ZMiniProgress(
              value: config.value,
              goal: widget.goalValue ?? config.maxValue,
              color: widget.color,
              variant: MiniProgressVariant.ring,
            ),
          );
        }
        if (config is FillGaugeConfig) {
          return Semantics(
            label: _semanticsLabel(config),
            child: ZMiniProgress(
              value: config.value,
              goal: widget.goalValue ?? config.maxValue,
              color: widget.color,
              variant: MiniProgressVariant.linear,
            ),
          );
        }
        // Unsupported config type for mini mode.
        assert(
          false,
          'ZChart: mini mode not supported for ${config.runtimeType}',
        );
        debugPrint(
          'ZChart: mini mode not supported for ${config.runtimeType}',
        );
        return const SizedBox.shrink();
    }

    // ── Wrap with semantics ─────────────────────────────────────────────
    Widget result = Semantics(
      label: _semanticsLabel(config),
      child: chart,
    );

    // ── Wrap with tap handler ───────────────────────────────────────────
    if (widget.onTap != null) {
      result = GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: result,
      );
    }

    return result;
  }

  String _semanticsLabel(TileVisualizationConfig config) {
    return switch (config) {
      final LineChartConfig c =>
        'Line chart with ${c.points.length} data points',
      final BarChartConfig c => 'Bar chart with ${c.bars.length} bars',
      final AreaChartConfig c =>
        'Area chart with ${c.points.length} data points',
      final RingConfig c =>
        '${c.maxValue > 0 ? (c.value / c.maxValue * 100).round() : 0} percent ring',
      final GaugeConfig c => 'Gauge at ${c.value}',
      final FillGaugeConfig c => '${c.value} of ${c.maxValue} ${c.unit}',
      final SegmentedBarConfig c => 'Segmented bar: ${c.totalLabel}',
      _ => 'Chart',
    };
  }
}

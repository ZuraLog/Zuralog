library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_mode.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/renderers/area_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/bar_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/fill_gauge_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/gauge_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/line_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/ring_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/segmented_bar_renderer.dart';

/// Shows a ghost (very faint) chart when there is no real data to display.
///
/// The ghost uses deterministic dummy data so the shape is always the same.
/// Larger modes overlay a "No data yet" message on top.
class ZChartEmptyState extends StatelessWidget {
  const ZChartEmptyState({
    super.key,
    required this.configType,
    required this.mode,
    required this.color,
  });

  final Type configType;
  final ChartMode mode;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    final ghost = ExcludeSemantics(
      child: Opacity(
        opacity: 0.06,
        child: _buildGhost(),
      ),
    );

    return switch (mode) {
      ChartMode.square ||
      ChartMode.sparkline ||
      ChartMode.mini ||
      ChartMode.widget =>
        ghost,
      ChartMode.wide || ChartMode.tall => Stack(
          children: [
            Positioned.fill(child: ghost),
            Center(
              child: Text(
                'No data yet',
                style: AppTextStyles.labelSmall
                    .copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ChartMode.full => Stack(
          children: [
            Positioned.fill(child: ghost),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No data yet',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect a source to get started',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ChartMode.comparison => Stack(
          children: [
            Positioned.fill(child: ghost),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Not enough data to compare',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try a longer date range',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
    };
  }

  Widget _buildGhost() {
    // Completed context — no entrance animation on ghosts.
    final ctx = ChartRenderContext.fromMode(mode);

    if (configType == LineChartConfig) {
      return LineRenderer(
          config: _kGhostLine, color: color, renderCtx: ctx);
    }
    if (configType == BarChartConfig) {
      return BarRenderer(config: _kGhostBar, color: color, renderCtx: ctx);
    }
    if (configType == AreaChartConfig) {
      return AreaRenderer(config: _kGhostArea, color: color, renderCtx: ctx);
    }
    if (configType == RingConfig) {
      return RingRenderer(
          config: _kGhostRing, color: color, renderCtx: ctx, diameter: 80);
    }
    if (configType == GaugeConfig) {
      return GaugeRenderer(
          config: _kGhostGauge, color: color, renderCtx: ctx, gaugeSize: 80);
    }
    if (configType == FillGaugeConfig) {
      return FillGaugeRenderer(
        config: _kGhostFillGauge,
        color: color,
        renderCtx: ctx,
        tankWidth: 26,
        tankHeight: 54,
      );
    }
    if (configType == SegmentedBarConfig) {
      return SegmentedBarRenderer(
        config: _kGhostSegBar,
        color: color,
        renderCtx: ctx,
        barHeight: 10,
      );
    }
    return const SizedBox.shrink();
  }
}

// ── Deterministic ghost data — same shape every time, per chart type ─────────

final _kNow = DateTime(2026);

final _kGhostLine = LineChartConfig(
  points: [
    ChartPoint(date: _kNow.subtract(const Duration(days: 6)), value: 60),
    ChartPoint(date: _kNow.subtract(const Duration(days: 5)), value: 68),
    ChartPoint(date: _kNow.subtract(const Duration(days: 4)), value: 55),
    ChartPoint(date: _kNow.subtract(const Duration(days: 3)), value: 72),
    ChartPoint(date: _kNow.subtract(const Duration(days: 2)), value: 65),
    ChartPoint(date: _kNow.subtract(const Duration(days: 1)), value: 70),
    ChartPoint(date: _kNow, value: 67),
  ],
);

const _kGhostBar = BarChartConfig(
  bars: [
    BarPoint(label: 'M', value: 7000, isToday: false),
    BarPoint(label: 'T', value: 5500, isToday: false),
    BarPoint(label: 'W', value: 8200, isToday: false),
    BarPoint(label: 'T', value: 6100, isToday: false),
    BarPoint(label: 'F', value: 9000, isToday: false),
    BarPoint(label: 'S', value: 4800, isToday: false),
    BarPoint(label: 'S', value: 7500, isToday: false),
  ],
);

final _kGhostArea = AreaChartConfig(
  points: [
    ChartPoint(date: _kNow.subtract(const Duration(days: 6)), value: 7.0),
    ChartPoint(date: _kNow.subtract(const Duration(days: 5)), value: 6.5),
    ChartPoint(date: _kNow.subtract(const Duration(days: 4)), value: 7.8),
    ChartPoint(date: _kNow.subtract(const Duration(days: 3)), value: 7.2),
    ChartPoint(date: _kNow.subtract(const Duration(days: 2)), value: 6.8),
    ChartPoint(date: _kNow.subtract(const Duration(days: 1)), value: 7.5),
    ChartPoint(date: _kNow, value: 7.1),
  ],
  fillOpacity: 0.15,
);

const _kGhostRing = RingConfig(value: 5500, maxValue: 10000, unit: '');

const _kGhostGauge = GaugeConfig(
  value: 70,
  minValue: 40,
  maxValue: 120,
  zones: [
    GaugeZone(
        min: 40, max: 80, label: '', color: Color(0xFF30D158)),
    GaugeZone(
        min: 80, max: 120, label: '', color: Color(0xFFFF375F)),
  ],
);

const _kGhostFillGauge =
    FillGaugeConfig(value: 1.5, maxValue: 3.0, unit: '');

const _kGhostSegBar = SegmentedBarConfig(
  totalLabel: '',
  segments: [
    Segment(label: '', value: 100, color: Color(0xFF3634A3)),
    Segment(label: '', value: 200, color: Color(0xFF5E5CE6)),
    Segment(label: '', value: 80, color: Color(0xFF8E8CE8)),
  ],
);

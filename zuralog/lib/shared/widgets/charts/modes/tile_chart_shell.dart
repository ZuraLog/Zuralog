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

/// Wraps chart renderers with mode-specific supplementary layout (stats rows,
/// value text beside rings, zone legends, etc.) for tile modes only.
///
/// This widget handles the three tile sizes — [ChartMode.square],
/// [ChartMode.wide], and [ChartMode.tall]. Other modes (full, sparkline, etc.)
/// are handled by separate shells.
class TileChartShell extends StatelessWidget {
  const TileChartShell({
    super.key,
    required this.config,
    required this.color,
    required this.mode,
    required this.renderCtx,
  }) : assert(
          mode == ChartMode.square ||
              mode == ChartMode.wide ||
              mode == ChartMode.tall,
          'TileChartShell only supports square, wide, and tall modes',
        );

  final TileVisualizationConfig config;
  final Color color;
  final ChartMode mode;
  final ChartRenderContext renderCtx;

  @override
  Widget build(BuildContext context) {
    return switch (config) {
      final LineChartConfig c => _buildLine(context, c),
      final BarChartConfig c => _buildBar(c),
      final AreaChartConfig c => _buildArea(c),
      final RingConfig c => _buildRing(context, c),
      final GaugeConfig c => _buildGauge(context, c),
      final FillGaugeConfig c => _buildFillGauge(context, c),
      final SegmentedBarConfig c => _buildSegmentedBar(context, c),
      _ => const SizedBox.shrink(),
    };
  }

  // ── Line ──────────────────────────────────────────────────────────────────

  Widget _buildLine(BuildContext context, LineChartConfig c) {
    final renderer = LineRenderer(config: c, color: color, renderCtx: renderCtx);
    return switch (mode) {
      ChartMode.square || ChartMode.wide => SizedBox.expand(child: renderer),
      ChartMode.tall => Column(
          children: [
            Expanded(child: renderer),
            _StatsRow(points: c.points, color: color),
          ],
        ),
      _ => SizedBox.expand(child: renderer),
    };
  }

  // ── Bar ───────────────────────────────────────────────────────────────────

  Widget _buildBar(BarChartConfig c) {
    return SizedBox.expand(
      child: BarRenderer(config: c, color: color, renderCtx: renderCtx),
    );
  }

  // ── Area ──────────────────────────────────────────────────────────────────

  Widget _buildArea(AreaChartConfig c) {
    return SizedBox.expand(
      child: AreaRenderer(config: c, color: color, renderCtx: renderCtx),
    );
  }

  // ── Ring ──────────────────────────────────────────────────────────────────

  Widget _buildRing(BuildContext context, RingConfig c) {
    final colors = AppColorsOf(context);

    return switch (mode) {
      ChartMode.square => Center(
          child: RingRenderer(
            config: c,
            color: color,
            renderCtx: renderCtx,
            diameter: 80,
          ),
        ),
      ChartMode.wide => Row(
          children: [
            RingRenderer(
              config: c,
              color: color,
              renderCtx: renderCtx,
              diameter: 90,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${c.value.round()}',
                    style: AppTextStyles.titleMedium
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '/ ${c.maxValue.round()} ${c.unit}',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: colors.textSecondary),
                  ),
                  Text(
                    c.value > c.maxValue
                        ? 'Goal exceeded!'
                        : '${(c.maxValue - c.value).clamp(0, c.maxValue).round()} ${c.unit} remaining',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ChartMode.tall => Column(
          children: [
            RingRenderer(
              config: c,
              color: color,
              renderCtx: renderCtx,
              diameter: 110,
            ),
            if (c.weeklyBars != null) ...[
              const SizedBox(height: 8),
              RingBarRow(bars: c.weeklyBars!, color: color),
            ],
          ],
        ),
      _ => Center(
          child: RingRenderer(
            config: c,
            color: color,
            renderCtx: renderCtx,
            diameter: 80,
          ),
        ),
    };
  }

  // ── Gauge ─────────────────────────────────────────────────────────────────

  Widget _buildGauge(BuildContext context, GaugeConfig c) {
    final colors = AppColorsOf(context);
    final zoneLabel = _currentZoneLabel(c);

    return switch (mode) {
      ChartMode.square => LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Center(
                  child: GaugeRenderer(
                    config: c,
                    color: color,
                    renderCtx: renderCtx,
                    gaugeSize: constraints.maxWidth,
                  ),
                ),
              ),
              Text(
                '${c.value}',
                style: AppTextStyles.titleMedium
                    .copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              Text(
                zoneLabel,
                style: AppTextStyles.labelSmall
                    .copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ChartMode.wide => LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Center(
                  child: GaugeRenderer(
                    config: c,
                    color: color,
                    renderCtx: renderCtx,
                    gaugeSize: constraints.maxWidth * 0.65,
                  ),
                ),
              ),
              Text(
                '${c.value}',
                style: AppTextStyles.titleMedium
                    .copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              Text(
                zoneLabel,
                style: AppTextStyles.labelSmall
                    .copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ChartMode.tall => LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Center(
                  child: GaugeRenderer(
                    config: c,
                    color: color,
                    renderCtx: renderCtx,
                    gaugeSize: constraints.maxWidth * 0.8,
                  ),
                ),
              ),
              Text(
                '${c.value}',
                style: AppTextStyles.titleMedium
                    .copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              Text(
                zoneLabel,
                style: AppTextStyles.labelSmall
                    .copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
              ...c.zones.map(
                (z) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: z.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${z.label}: ${z.min}\u2013${z.max}',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  static String _currentZoneLabel(GaugeConfig c) {
    for (final zone in c.zones) {
      if (c.value >= zone.min && c.value <= zone.max) return zone.label;
    }
    return '';
  }

  // ── Fill Gauge ────────────────────────────────────────────────────────────

  Widget _buildFillGauge(BuildContext context, FillGaugeConfig c) {
    final colors = AppColorsOf(context);
    final valueLabel = '${c.value} ${c.unit}';

    return switch (mode) {
      ChartMode.square => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            FillGaugeRenderer(
              config: c,
              color: color,
              renderCtx: renderCtx,
              tankWidth: 26,
              tankHeight: 54,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valueLabel,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: color, fontWeight: FontWeight.bold),
                ),
                Text(
                  '/ ${c.maxValue} ${c.unit}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ChartMode.wide => Row(
          children: [
            FillGaugeRenderer(
              config: c,
              color: color,
              renderCtx: renderCtx,
              tankWidth: 26,
              tankHeight: 54,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    valueLabel,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                  if (c.unitIcon != null && c.unitSize != null) ...[
                    const SizedBox(height: 4),
                    _UnitIcons(config: c, color: color, iconSize: 14),
                  ],
                ],
              ),
            ),
          ],
        ),
      ChartMode.tall => Column(
          children: [
            FillGaugeRenderer(
              config: c,
              color: color,
              renderCtx: renderCtx,
              tankWidth: 34,
              tankHeight: 90,
            ),
            const SizedBox(height: 8),
            Text(
              valueLabel,
              style: AppTextStyles.titleMedium
                  .copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            if (c.unitIcon != null && c.unitSize != null) ...[
              const SizedBox(height: 4),
              _UnitIcons(
                config: c,
                color: color,
                iconSize: 16,
                alignment: WrapAlignment.center,
              ),
            ],
          ],
        ),
      _ => const SizedBox.shrink(),
    };
  }

  // ── Segmented Bar ─────────────────────────────────────────────────────────

  Widget _buildSegmentedBar(BuildContext context, SegmentedBarConfig c) {
    final colors = AppColorsOf(context);

    return switch (mode) {
      ChartMode.square => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              c.totalLabel,
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            SegmentedBarRenderer(
              config: c,
              color: color,
              renderCtx: renderCtx,
              barHeight: 10,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: c.segments
                  .take(3)
                  .map(
                    (seg) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: seg.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          seg.label,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ChartMode.wide => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              c.totalLabel,
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            SegmentedBarRenderer(
              config: c,
              color: color,
              renderCtx: renderCtx,
              barHeight: 16,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: c.segments
                  .map(
                    (seg) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: seg.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          seg.label,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: colors.textSecondary),
                        ),
                        Text(
                          _fmtMins(seg.value.round()),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ChartMode.tall => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              c.totalLabel,
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            SegmentedBarRenderer(
              config: c,
              color: color,
              renderCtx: renderCtx,
              barHeight: 16,
            ),
            const SizedBox(height: 8),
            ...c.segments.map(
              (seg) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: seg.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        seg.label,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: colors.textSecondary),
                      ),
                    ),
                    Text(
                      _fmtMins(seg.value.round()),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      _ => const SizedBox.shrink(),
    };
  }

  static String _fmtMins(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

// ── Private helper widgets ──────────────────────────────────────────────────

/// Stats row showing min / avg / max — used below line charts in tall mode.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.points, required this.color});

  final List<ChartPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final values = points.map((p) => p.value).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatCell(label: 'MIN', value: min.round().toString(), color: color),
          _StatCell(label: 'AVG', value: avg.round().toString(), color: color),
          _StatCell(label: 'MAX', value: max.round().toString(), color: color),
        ],
      ),
    );
  }
}

/// A single stat cell (value + label) used in [_StatsRow].
class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTextStyles.labelSmall
              .copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall
              .copyWith(color: AppColorsOf(context).textSecondary),
        ),
      ],
    );
  }
}

/// Renders emoji unit icons (e.g. water glasses) for [FillGaugeConfig].
class _UnitIcons extends StatelessWidget {
  const _UnitIcons({
    required this.config,
    required this.color,
    required this.iconSize,
    this.alignment = WrapAlignment.start,
  });

  final FillGaugeConfig config;
  final Color color;
  final double iconSize;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    if (config.unitIcon == null || config.unitSize == null || config.unitSize! <= 0) {
      return const SizedBox.shrink();
    }

    final iconCount = (config.value / config.unitSize!).floor();
    final totalIcons = (config.maxValue / config.unitSize!).ceil().clamp(0, 50);

    return Wrap(
      alignment: alignment,
      children: List.generate(
        totalIcons,
        (i) => Text(
          config.unitIcon!,
          style: TextStyle(
            fontSize: iconSize,
            color: i < iconCount ? color : color.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }
}

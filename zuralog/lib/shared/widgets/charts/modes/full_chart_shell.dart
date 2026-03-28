library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/interactions/chart_tooltip.dart';
import 'package:zuralog/shared/widgets/charts/interactions/scrub_controller.dart';
import 'package:zuralog/shared/widgets/charts/interactions/segment_tap_handler.dart';
import 'package:zuralog/shared/widgets/charts/renderers/area_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/bar_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/fill_gauge_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/gauge_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/line_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/ring_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/segmented_bar_renderer.dart';

/// Holds the data for a single bar tap event.
class _BarTapInfo {
  const _BarTapInfo({required this.value, this.label});
  final double value;
  final String? label;
}

/// Fixed hero chart height in fullscreen mode.
const _kFullChartHeight = 200.0;

/// Bar height used for [SegmentedBarRenderer] in full mode.
const _kSegmentedBarHeight = 32.0;

/// Assembles [ChartMode.full]: renderer + interaction overlays + stats row.
///
/// The time range selector (7D/30D/90D/Custom) is handled by
/// MetricDetailScreen — this widget renders the chart and its interactions only.
class FullChartShell extends StatefulWidget {
  const FullChartShell({
    super.key,
    required this.config,
    required this.color,
    required this.renderCtx,
    this.unit = '',
  });

  final TileVisualizationConfig config;
  final Color color;
  final ChartRenderContext renderCtx;

  /// Unit string for tooltip display (e.g. "steps", "bpm").
  final String unit;

  @override
  State<FullChartShell> createState() => _FullChartShellState();
}

class _FullChartShellState extends State<FullChartShell>
    with SingleTickerProviderStateMixin {
  // Scrub state (line/area)
  final _scrubController = ScrubController();

  // Fade animation for scrub tooltip
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // Segment tap state (ring/gauge/segmented bar)
  final _segmentNotifier = ValueNotifier<SegmentInfo?>(null);

  // Bar tap state
  final _barTapNotifier = ValueNotifier<_BarTapInfo?>(null);
  Timer? _barDismissTimer;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 0.0,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _scrubController.addListener(_onScrubChange);
  }

  @override
  void dispose() {
    _barDismissTimer?.cancel();
    _scrubController.removeListener(_onScrubChange);
    _scrubController.dispose();
    _fadeCtrl.dispose();
    _segmentNotifier.dispose();
    _barTapNotifier.dispose();
    super.dispose();
  }

  void _onScrubChange() {
    if (_scrubController.value != null) {
      _fadeCtrl.forward();
    } else {
      _fadeCtrl.reverse();
    }
  }

  void _onBarTap(int barIndex, double value, String label) {
    _barDismissTimer?.cancel();
    _barTapNotifier.value = _BarTapInfo(value: value, label: label);
    _barDismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _barTapNotifier.value = null;
    });
  }

  Widget _buildChart() {
    final config = widget.config;
    final ctx = widget.renderCtx;
    final color = widget.color;

    if (config is LineChartConfig) {
      return LineRenderer(
        config: config,
        color: color,
        renderCtx: ctx,
        scrubController: _scrubController,
        unit: widget.unit,
      );
    }
    if (config is AreaChartConfig) {
      return AreaRenderer(
        config: config,
        color: color,
        renderCtx: ctx,
        scrubController: _scrubController,
        unit: widget.unit,
      );
    }
    if (config is BarChartConfig) {
      return BarRenderer(
        config: config,
        color: color,
        renderCtx: ctx,
        onBarTap: _onBarTap,
      );
    }
    if (config is RingConfig) {
      return _RingWithTap(
        config: config,
        color: color,
        renderCtx: ctx,
        segmentNotifier: _segmentNotifier,
      );
    }
    if (config is GaugeConfig) {
      return _GaugeWithTap(
        config: config,
        color: color,
        renderCtx: ctx,
        segmentNotifier: _segmentNotifier,
      );
    }
    if (config is FillGaugeConfig) {
      return _FillGaugeExpanded(config: config, color: color, renderCtx: ctx);
    }
    if (config is SegmentedBarConfig) {
      return _SegmentedBarWithTap(
        config: config,
        color: color,
        renderCtx: ctx,
        segmentNotifier: _segmentNotifier,
        unit: widget.unit,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildStatsRow() {
    final config = widget.config;
    double? current;
    double? average;

    if (config is LineChartConfig && config.points.isNotEmpty) {
      current = config.points.last.value;
      final sum = config.points.fold(0.0, (a, b) => a + b.value);
      average = sum / config.points.length;
    } else if (config is AreaChartConfig && config.points.isNotEmpty) {
      current = config.points.last.value;
      final sum = config.points.fold(0.0, (a, b) => a + b.value);
      average = sum / config.points.length;
    } else if (config is BarChartConfig && config.bars.isNotEmpty) {
      current = config.bars.last.value;
      final sum = config.bars.fold(0.0, (a, b) => a + b.value);
      average = sum / config.bars.length;
    }

    if (current == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Row(
        children: [
          _StatCell(
            label: 'Current',
            value: _formatValue(current),
            unit: widget.unit,
            color: widget.color,
          ),
          if (average != null) ...[
            const SizedBox(width: 24),
            _StatCell(
              label: 'Average',
              value: _formatValue(average),
              unit: widget.unit,
            ),
          ],
        ],
      ),
    );
  }

  static String _formatValue(double v) {
    if (!v.isFinite) return '—';
    if (v >= 1000) return NumberFormat.compact().format(v);
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _kFullChartHeight,
          child: SegmentTapHandler(
            notifier: _segmentNotifier,
            child: Stack(
              children: [
                _buildChart(),
                // Scrub tooltip overlay (line/area only)
                AnimatedBuilder(
                  animation: _fadeAnim,
                  builder: (context, _) {
                    if (_fadeAnim.value == 0) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: _ScrubTooltipOverlay(
                          scrubState: _scrubController.value,
                          unit: widget.unit,
                        ),
                      ),
                    );
                  },
                ),
                // Bar tap tooltip
                ValueListenableBuilder<_BarTapInfo?>(
                  valueListenable: _barTapNotifier,
                  builder: (context, info, _) {
                    if (info == null) return const SizedBox.shrink();
                    return Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ZChartTooltip(
                          value: info.value,
                          unit: widget.unit,
                          label: info.label,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        _buildStatsRow(),
      ],
    );
  }
}

// ── Scrub tooltip overlay ──────────────────────────────────────────────────

class _ScrubTooltipOverlay extends StatelessWidget {
  const _ScrubTooltipOverlay({
    required this.scrubState,
    required this.unit,
  });

  final ScrubState? scrubState;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final state = scrubState;
    if (state == null) return const SizedBox.shrink();

    final mediaWidth = MediaQuery.sizeOf(context).width;
    final rawLeft = state.pixelX - 60;
    final left = rawLeft.clamp(8.0, math.max(8.0, mediaWidth - 128)).toDouble();

    return Stack(
      children: [
        Positioned(
          top: 4,
          left: left,
          child: ZChartTooltip(
            value: state.value,
            unit: unit,
            date: state.date,
            comparisonValue: state.comparisonValue,
          ),
        ),
      ],
    );
  }
}

// ── Ring with tap ──────────────────────────────────────────────────────────

class _RingWithTap extends StatelessWidget {
  const _RingWithTap({
    required this.config,
    required this.color,
    required this.renderCtx,
    required this.segmentNotifier,
  });

  final RingConfig config;
  final Color color;
  final ChartRenderContext renderCtx;
  final ValueNotifier<SegmentInfo?> segmentNotifier;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = math.min(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapUp: (details) {
            final pct = config.maxValue > 0
                ? (config.value / config.maxValue).clamp(0.0, 1.0)
                : 0.0;
            reportSegmentTap(
              segmentNotifier,
              SegmentInfo(
                label: config.unit,
                value: config.value,
                unit: config.unit,
                percentage: pct,
                tapOffset: details.localPosition,
              ),
            );
          },
          child: Center(
            child: RingRenderer(
              config: config,
              color: color,
              renderCtx: renderCtx,
              diameter: diameter,
            ),
          ),
        );
      },
    );
  }
}

// ── Gauge with tap ─────────────────────────────────────────────────────────

class _GaugeWithTap extends StatelessWidget {
  const _GaugeWithTap({
    required this.config,
    required this.color,
    required this.renderCtx,
    required this.segmentNotifier,
  });

  final GaugeConfig config;
  final Color color;
  final ChartRenderContext renderCtx;
  final ValueNotifier<SegmentInfo?> segmentNotifier;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gaugeSize = constraints.maxWidth;
        return GestureDetector(
          onTapUp: (details) {
            final zone = config.zones.firstWhere(
              (z) => config.value >= z.min && config.value <= z.max,
              orElse: () => config.zones.first,
            );
            reportSegmentTap(
              segmentNotifier,
              SegmentInfo(
                label: zone.label,
                value: config.value,
                unit: '',
                percentage: 0.0,
                tapOffset: details.localPosition,
              ),
            );
          },
          child: GaugeRenderer(
            config: config,
            color: color,
            renderCtx: renderCtx,
            gaugeSize: gaugeSize,
          ),
        );
      },
    );
  }
}

// ── FillGauge expanded ─────────────────────────────────────────────────────

class _FillGaugeExpanded extends StatelessWidget {
  const _FillGaugeExpanded({
    required this.config,
    required this.color,
    required this.renderCtx,
  });

  final FillGaugeConfig config;
  final Color color;
  final ChartRenderContext renderCtx;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: FillGaugeRenderer(
            config: config,
            color: color,
            renderCtx: renderCtx,
            tankWidth: constraints.maxWidth * 0.4,
            tankHeight: constraints.maxHeight,
          ),
        );
      },
    );
  }
}

// ── SegmentedBar with tap ──────────────────────────────────────────────────

class _SegmentedBarWithTap extends StatelessWidget {
  const _SegmentedBarWithTap({
    required this.config,
    required this.color,
    required this.renderCtx,
    required this.segmentNotifier,
    required this.unit,
  });

  final SegmentedBarConfig config;
  final Color color;
  final ChartRenderContext renderCtx;
  final ValueNotifier<SegmentInfo?> segmentNotifier;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (details) {
        if (config.segments.isEmpty) return;
        final totalWidth = context.size?.width ?? 1.0;
        final tapX = details.localPosition.dx;
        final total = config.segments.fold(0.0, (a, s) => a + s.value);

        double accumulated = 0;
        Segment? tapped;
        for (final seg in config.segments) {
          final segWidth = total > 0 ? (seg.value / total) * totalWidth : 0.0;
          if (tapX <= accumulated + segWidth) {
            tapped = seg;
            break;
          }
          accumulated += segWidth;
        }
        tapped ??= config.segments.last;

        reportSegmentTap(
          segmentNotifier,
          SegmentInfo(
            label: tapped.label,
            value: tapped.value,
            unit: unit,
            percentage: total > 0
                ? (tapped.value / total).clamp(0.0, 1.0)
                : 0.0,
            tapOffset: details.localPosition,
          ),
        );
      },
      child: Center(
        child: SegmentedBarRenderer(
          config: config,
          color: color,
          renderCtx: renderCtx,
          barHeight: _kSegmentedBarHeight,
        ),
      ),
    );
  }
}

// ── Stat cell ─────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.unit,
    this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: color != null
                ? color!.withValues(alpha: 0.7)
                : AppColors.warmWhite.withValues(alpha: 0.4),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: AppTextStyles.labelMedium.copyWith(
                  color: color ?? AppColors.warmWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.warmWhite.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

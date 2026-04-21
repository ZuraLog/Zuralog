/// Microscope bottom sheet — one metric, rich detail.
///
/// Opens via [showZMetricMicroscopeSheet]. Shows a Lora-serif hero
/// value, a 30-day line chart with the user's "your normal" baseline
/// drawn across it, a plain-English description, three context stat
/// tiles, and a Sage "Ask Coach about this" CTA.
///
/// This is the unified surface opened from every tap target on the
/// All Data screen: wheel spokes, chart shards, every-metric grid
/// tiles, and AI summary inline metric words.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart'
    show HealthCategory, MetricDataPoint;
import 'package:zuralog/features/data/domain/mandala_data.dart'
    show computeSpokeRatio;
import 'package:zuralog/features/data/domain/metric_descriptions.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// Opens the microscope bottom sheet for a single metric.
Future<void> showZMetricMicroscopeSheet(
  BuildContext context, {
  required String metricId,
  required HealthCategory category,
  required String displayName,
  required String unit,
  required double? todayValue,
  required double? baseline30d,
  required bool inverted,
  required List<MetricDataPoint> dataPoints,
  required DateTime? lastReadingTime,
  required VoidCallback onAskCoach,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    isScrollControlled: true,
    builder: (sheetCtx) => _MicroscopeSheet(
      metricId: metricId,
      category: category,
      displayName: displayName,
      unit: unit,
      todayValue: todayValue,
      baseline30d: baseline30d,
      inverted: inverted,
      dataPoints: dataPoints,
      lastReadingTime: lastReadingTime,
      onAskCoach: onAskCoach,
    ),
  );
}

enum _MicroscopeRange {
  d7(7, '7d'),
  d30(30, '30d'),
  d90(90, '90d');

  const _MicroscopeRange(this.days, this.label);
  final int days;
  final String label;
}

class _MicroscopeSheet extends StatefulWidget {
  const _MicroscopeSheet({
    required this.metricId,
    required this.category,
    required this.displayName,
    required this.unit,
    required this.todayValue,
    required this.baseline30d,
    required this.inverted,
    required this.dataPoints,
    required this.lastReadingTime,
    required this.onAskCoach,
  });

  final String metricId;
  final HealthCategory category;
  final String displayName;
  final String unit;
  final double? todayValue;
  final double? baseline30d;
  final bool inverted;
  final List<MetricDataPoint> dataPoints;
  final DateTime? lastReadingTime;
  final VoidCallback onAskCoach;

  @override
  State<_MicroscopeSheet> createState() => _MicroscopeSheetState();
}

class _MicroscopeSheetState extends State<_MicroscopeSheet> {
  _MicroscopeRange _range = _MicroscopeRange.d30;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceOverlay,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: colors.textPrimary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  // Generous bottom padding so the Coach pill clears the
                  // floating bottom-nav and the home-indicator safe area.
                  padding: EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    MediaQuery.of(context).padding.bottom + 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(
                        category: widget.category,
                        displayName: widget.displayName,
                        onClose: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 16),
                      _HeroCard(
                        todayValue: widget.todayValue,
                        baseline30d: widget.baseline30d,
                        inverted: widget.inverted,
                        unit: widget.unit,
                        category: widget.category,
                        lastReadingLabel:
                            _formatLastReading(widget.lastReadingTime),
                        dataPoints: widget.dataPoints,
                      ),
                      const SizedBox(height: 14),
                      _ChartCard(
                        range: _range,
                        onRangeChanged: (r) => setState(() => _range = r),
                        dataPoints: widget.dataPoints,
                        baseline30d: widget.baseline30d,
                        category: widget.category,
                      ),
                      const SizedBox(height: 12),
                      _HowTodayCompares(
                        todayValue: widget.todayValue,
                        baseline30d: widget.baseline30d,
                        inverted: widget.inverted,
                        category: widget.category,
                        dataPoints: widget.dataPoints,
                      ),
                      const SizedBox(height: 12),
                      _Stats(
                        todayValue: widget.todayValue,
                        baseline30d: widget.baseline30d,
                        dataPoints: widget.dataPoints,
                        category: widget.category,
                      ),
                      const SizedBox(height: 12),
                      _Explain(
                        metricId: widget.metricId,
                        category: widget.category,
                      ),
                      const SizedBox(height: 18),
                      _CoachCta(
                        category: widget.category,
                        onTap: widget.onAskCoach,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.category,
    required this.displayName,
    required this.onClose,
  });

  final HealthCategory category;
  final String displayName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: categoryColor(category),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: Text(
            displayName,
            style: AppTextStyles.titleMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: colors.elevatedSurface,
            borderRadius: BorderRadius.circular(AppDimens.shapePill),
          ),
          child: Text(
            category.displayName,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onClose,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.elevatedSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Hero card — category-tinted feature card with the topographic pattern,
/// the big Lora value, the delta pill, the last-reading caption, and a
/// "min ── you ── max" range bar at the bottom. The whole thing wears the
/// metric's category color so the user feels which body they're inside.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.todayValue,
    required this.baseline30d,
    required this.inverted,
    required this.unit,
    required this.category,
    required this.lastReadingLabel,
    required this.dataPoints,
  });

  final double? todayValue;
  final double? baseline30d;
  final bool inverted;
  final String unit;
  final HealthCategory category;
  final String lastReadingLabel;
  final List<MetricDataPoint> dataPoints;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final color = categoryColor(category);
    final valueText =
        todayValue == null ? '—' : _formatNumber(todayValue!);

    final values = dataPoints
        .map((p) => p.value)
        .where((v) => v.isFinite)
        .toList();
    final last30 =
        values.length > 30 ? values.sublist(values.length - 30) : values;
    final minV = last30.isEmpty ? null : last30.reduce((a, b) => a < b ? a : b);
    final maxV = last30.isEmpty ? null : last30.reduce((a, b) => a > b ? a : b);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.20),
              color.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Brand topographic contour pattern in the category's color
            // variant (Periwinkle for Sleep, Rose for Heart, Amber for
            // Food, etc). Always animated — drifts slowly per the brand
            // bible. This is what makes the hero feel branded, not flat.
            Positioned.fill(
              child: IgnorePointer(
                child: ZPatternOverlay(
                  variant: patternForCategory(color),
                  opacity: 0.18,
                  blendMode: BlendMode.screen,
                  animate: true,
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    valueText,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontWeight: FontWeight.w600,
                      fontSize: 56,
                      height: 1,
                      color: colors.textPrimary,
                      letterSpacing: -1.2,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Text(
                        unit,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _DeltaPill(
                todayValue: todayValue,
                baseline30d: baseline30d,
                inverted: inverted,
                category: category,
              ),
              const SizedBox(height: 6),
              Text(
                lastReadingLabel,
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
              ),
              if (minV != null && maxV != null && todayValue != null) ...[
                const SizedBox(height: 16),
                _RangeBar(
                  minValue: minV,
                  maxValue: maxV,
                  todayValue: todayValue!,
                  color: color,
                ),
              ],
            ],
          ),
        ],
      ),
      ),
    );
  }
}

/// Thin "min ── you ── max" bar visualizing where today falls inside the
/// 30-day range. The marker dot sits at today's position; tiny labels above
/// the dot read "Today" and below at the endpoints read the min/max numbers.
class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.minValue,
    required this.maxValue,
    required this.todayValue,
    required this.color,
  });
  final double minValue;
  final double maxValue;
  final double todayValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final span = maxValue - minValue;
    final t = span <= 0
        ? 0.5
        : ((todayValue - minValue) / span).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final dotX = (w * t).clamp(6.0, w - 6.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '30-day range',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 18,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Bar
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 7,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.18),
                            color.withValues(alpha: 0.55),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Today marker
                  Positioned(
                    left: dotX - 5,
                    top: 4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _formatNumber(minValue),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textTertiary,
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatNumber(maxValue),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({
    required this.todayValue,
    required this.baseline30d,
    required this.inverted,
    required this.category,
  });

  final double? todayValue;
  final double? baseline30d;
  final bool inverted;
  final HealthCategory category;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final ratio = computeSpokeRatio(
      todayValue: todayValue,
      baseline: baseline30d,
      inverted: inverted,
    );
    if (ratio == null) return const SizedBox.shrink();
    final pct = ((ratio - 1.0) * 100).round();
    if (pct == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.elevatedSurface,
          borderRadius: BorderRadius.circular(AppDimens.shapePill),
        ),
        child: Text(
          'On your normal',
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final isGood = pct > 0; // ratio > 1 always means "good" per our math.
    final color = isGood ? colors.success : categoryColor(category);
    final arrow = pct > 0 ? '↑' : '↓';
    final suffix =
        pct > 0 ? 'above your normal' : '${pct.abs()}% low for you';
    final label = pct > 0 ? '$arrow ${pct.abs()}% $suffix' : '↓ $suffix';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimens.shapePill),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.range,
    required this.onRangeChanged,
    required this.dataPoints,
    required this.baseline30d,
    required this.category,
  });

  final _MicroscopeRange range;
  final ValueChanged<_MicroscopeRange> onRangeChanged;
  final List<MetricDataPoint> dataPoints;
  final double? baseline30d;
  final HealthCategory category;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final color = categoryColor(category);

    // Last N values, oldest-first.
    final values = dataPoints
        .map((p) => p.value)
        .where((v) => v.isFinite)
        .toList();
    final windowed = values.length > range.days
        ? values.sublist(values.length - range.days)
        : values;

    return ZuralogCard(
      variant: ZCardVariant.data,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LAST ${range.days} DAYS',
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              for (final r in _MicroscopeRange.values) ...[
                _RangePill(
                  label: r.label,
                  active: r == range,
                  onTap: () => onRangeChanged(r),
                ),
                if (r != _MicroscopeRange.d90) const SizedBox(width: 2),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: windowed.length < 2
                ? Center(
                    child: Text(
                      'Not enough data yet',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: _axisMin(windowed, baseline30d),
                      maxY: _axisMax(windowed, baseline30d),
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      extraLinesData: baseline30d != null
                          ? ExtraLinesData(horizontalLines: [
                              HorizontalLine(
                                y: baseline30d!,
                                color: colors.textSecondary
                                    .withValues(alpha: 0.45),
                                strokeWidth: 0.7,
                                dashArray: [3, 4],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.topRight,
                                  padding: const EdgeInsets.only(
                                    right: 4,
                                    bottom: 2,
                                  ),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 8,
                                  ),
                                  labelResolver: (_) =>
                                      'your normal · ${_formatNumber(baseline30d!)}',
                                ),
                              ),
                            ])
                          : const ExtraLinesData(),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < windowed.length; i++)
                              FlSpot(i.toDouble(), windowed[i]),
                          ],
                          color: color,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, bar) =>
                                spot.x == (windowed.length - 1).toDouble(),
                            getDotPainter: (spot, _, _, _) =>
                                FlDotCirclePainter(
                              radius: 3.5,
                              color: color,
                              strokeWidth: 0,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withValues(alpha: 0.30),
                                color.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static double _axisMin(List<double> values, double? baseline) {
    final vs = <double>[...values, ?baseline];
    final m = vs.reduce((a, b) => a < b ? a : b);
    // leave 10% padding
    return m - (m.abs() * 0.1).clamp(0.5, double.infinity);
  }

  static double _axisMax(List<double> values, double? baseline) {
    final vs = <double>[...values, ?baseline];
    final m = vs.reduce((a, b) => a > b ? a : b);
    return m + (m.abs() * 0.1).clamp(0.5, double.infinity);
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? colors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.shapePill),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: active ? colors.textOnWarmWhite : colors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Explain extends StatelessWidget {
  const _Explain({required this.metricId, required this.category});
  final String metricId;
  final HealthCategory category;
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final color = categoryColor(category);
    return ZuralogCard(
      variant: ZCardVariant.data,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 9,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'WHAT THIS MEANS',
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            MetricDescriptions.lookup(metricId),
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// "How today compares" insight card — shows the percentile rank of today's
/// reading against the last 30 days and the current direction streak. Uses
/// the metric's category color for the icon tile + accent.
class _HowTodayCompares extends StatelessWidget {
  const _HowTodayCompares({
    required this.todayValue,
    required this.baseline30d,
    required this.inverted,
    required this.category,
    required this.dataPoints,
  });

  final double? todayValue;
  final double? baseline30d;
  final bool inverted;
  final HealthCategory category;
  final List<MetricDataPoint> dataPoints;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final color = categoryColor(category);
    final values = dataPoints
        .map((p) => p.value)
        .where((v) => v.isFinite)
        .toList();
    final last30 =
        values.length > 30 ? values.sublist(values.length - 30) : values;

    String percentileText = '—';
    String streakText = '—';
    if (todayValue != null && last30.length >= 3) {
      // Percentile: how many of the last 30 readings are BELOW today's?
      final belowCount =
          last30.where((v) => v < todayValue!).length;
      final pct = ((belowCount / last30.length) * 100).round();
      // Inverted metrics (RHR, stress): "low is good", so flip the language.
      final betterPct = inverted ? (100 - pct) : pct;
      if (betterPct >= 70) {
        percentileText = 'Better than $betterPct% of your last 30 days';
      } else if (betterPct <= 30) {
        percentileText = 'Lower than ${100 - betterPct}% of your last 30 days';
      } else {
        percentileText = 'Right around your typical range';
      }
    }

    // Streak: count consecutive recent readings below or above baseline.
    if (baseline30d != null && last30.isNotEmpty) {
      final ascending = !inverted;
      final goodSide = ascending
          ? last30.reversed.takeWhile((v) => v >= baseline30d!).length
          : last30.reversed.takeWhile((v) => v <= baseline30d!).length;
      final badSide = ascending
          ? last30.reversed.takeWhile((v) => v < baseline30d!).length
          : last30.reversed.takeWhile((v) => v > baseline30d!).length;
      if (goodSide >= 2) {
        streakText = '$goodSide-day streak above your normal';
      } else if (badSide >= 2) {
        streakText = '$badSide days below your normal';
      } else {
        streakText = 'Mixed week';
      }
    }

    return ZuralogCard(
      variant: ZCardVariant.data,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  size: 9,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'HOW TODAY COMPARES',
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CompareRow(
            label: percentileText,
            iconColor: color,
            colors: colors,
          ),
          const SizedBox(height: 6),
          _CompareRow(
            label: streakText,
            iconColor: color,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.iconColor,
    required this.colors,
  });
  final String label;
  final Color iconColor;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: iconColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.todayValue,
    required this.baseline30d,
    required this.dataPoints,
    required this.category,
  });
  final double? todayValue;
  final double? baseline30d;
  final List<MetricDataPoint> dataPoints;
  final HealthCategory category;

  @override
  Widget build(BuildContext context) {
    final values = dataPoints
        .map((p) => p.value)
        .where((v) => v.isFinite)
        .toList();
    final last30 =
        values.length > 30 ? values.sublist(values.length - 30) : values;
    final best30 =
        last30.isEmpty ? null : last30.reduce((a, b) => a > b ? a : b);
    final color = categoryColor(category);
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'TODAY',
            value: todayValue,
            highlightColor: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(label: 'YOUR NORMAL', value: baseline30d)),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(label: 'BEST IN 30D', value: best30)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.highlightColor,
  });
  final String label;
  final double? value;
  final Color? highlightColor;
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: highlightColor != null
            ? Border.all(
                color: highlightColor!.withValues(alpha: 0.35),
                width: 1,
              )
            : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value == null ? '—' : _formatNumber(value!),
            style: TextStyle(
              fontFamily: 'Lora',
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: highlightColor ?? colors.textPrimary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Coach call-to-action — solid category-color pill with the brand
/// topographic pattern in that color (Periwinkle for Sleep, Rose for Heart,
/// Amber for Food, etc.) at the same opacity used by the Sage primary
/// pill. The pattern is always animated. Foreground text picks black-or-
/// white based on the category color's luminance for AA contrast.
class _CoachCta extends StatelessWidget {
  const _CoachCta({required this.category, required this.onTap});
  final HealthCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    final fg = ThemeData.estimateBrightnessForColor(color) == Brightness.light
        ? const Color(0xFF161618)
        : Colors.white;
    const height = 56.0;
    return Semantics(
      button: true,
      label: 'Ask Coach about this',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: Material(
              color: color,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Brand topographic pattern in the category's color
                  // variant — the same pattern recipe the Sage primary
                  // pill uses, so this button feels native to the system.
                  IgnorePointer(
                    child: ZPatternOverlay(
                      variant: patternForCategory(color),
                      opacity: 0.22,
                      blendMode: BlendMode.multiply,
                      animate: true,
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 18, color: fg),
                        const SizedBox(width: 8),
                        Text(
                          'Ask Coach about this',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatNumber(double v) {
  if (v.abs() >= 1000) {
    final rounded = v.round();
    final s = rounded.toString();
    final buf = StringBuffer();
    var count = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count == 3 && i > 0) {
        buf.write(',');
        count = 0;
      }
    }
    return buf.toString().split('').reversed.join();
  }
  if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}

String _formatLastReading(DateTime? t) {
  if (t == null) return 'No recent reading';
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 60) return 'This morning';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${(diff.inDays / 7).floor()} weeks ago';
}

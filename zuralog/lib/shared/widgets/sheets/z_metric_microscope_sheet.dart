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
import 'package:zuralog/shared/widgets/buttons/z_pattern_pill_button.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

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
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(
                        category: widget.category,
                        displayName: widget.displayName,
                        onClose: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 14),
                      _Hero(
                        todayValue: widget.todayValue,
                        baseline30d: widget.baseline30d,
                        inverted: widget.inverted,
                        unit: widget.unit,
                        category: widget.category,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatLastReading(widget.lastReadingTime),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10,
                        ),
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
                      _Explain(metricId: widget.metricId),
                      const SizedBox(height: 14),
                      _Stats(
                        todayValue: widget.todayValue,
                        baseline30d: widget.baseline30d,
                        dataPoints: widget.dataPoints,
                      ),
                      const SizedBox(height: 14),
                      ZPatternPillButton(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Ask Coach about this',
                        onPressed: widget.onAskCoach,
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.todayValue,
    required this.baseline30d,
    required this.inverted,
    required this.unit,
    required this.category,
  });

  final double? todayValue;
  final double? baseline30d;
  final bool inverted;
  final String unit;
  final HealthCategory category;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final valueText =
        todayValue == null ? '—' : _formatNumber(todayValue!);
    final pill = _DeltaPill(
      todayValue: todayValue,
      baseline30d: baseline30d,
      inverted: inverted,
      category: category,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          valueText,
          style: TextStyle(
            fontFamily: 'Lora',
            fontWeight: FontWeight.w600,
            fontSize: 48,
            height: 1,
            color: colors.textPrimary,
            letterSpacing: -1,
          ),
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              unit,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
        const SizedBox(width: 10),
        Padding(padding: const EdgeInsets.only(bottom: 10), child: pill),
      ],
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
  const _Explain({required this.metricId});
  final String metricId;
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.data,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT THIS MEANS',
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            MetricDescriptions.lookup(metricId),
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.todayValue,
    required this.baseline30d,
    required this.dataPoints,
  });
  final double? todayValue;
  final double? baseline30d;
  final List<MetricDataPoint> dataPoints;

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
    return Row(
      children: [
        Expanded(child: _StatTile(label: 'TODAY', value: todayValue)),
        const SizedBox(width: 6),
        Expanded(
          child: _StatTile(label: 'YOUR NORMAL', value: baseline30d),
        ),
        const SizedBox(width: 6),
        Expanded(child: _StatTile(label: 'BEST IN 30D', value: best30)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final double? value;
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.data,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
              fontSize: 7.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value == null ? '—' : _formatNumber(value!),
            style: TextStyle(
              fontFamily: 'Lora',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: colors.textPrimary,
              height: 1,
            ),
          ),
        ],
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

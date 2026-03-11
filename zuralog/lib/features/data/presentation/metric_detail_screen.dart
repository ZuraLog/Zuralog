/// Metric Detail Screen — pushed from Category Detail.
///
/// Single metric deep-dive with a full fl_chart line chart, time-range
/// selector (7D / 30D / 90D), data source attribution ("from Fitbit",
/// "from Apple Health"), a toggleable raw data table, and an
/// "Ask Coach about this" action that opens a new coach chat with the
/// metric name pre-loaded as context.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/unit_converter.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/shared/widgets/time_range_selector.dart';

// ── Private constants ─────────────────────────────────────────────────────────

/// Maximum number of rows shown in the raw data table.
const int _kRawTableMaxRows = 30;

/// Maximum character length for the coach prefill string.
const int _kCoachPrefillMaxLength = 500;

// ── Source attribution label ──────────────────────────────────────────────────

String _sourceLabel(String? source) {
  if (source == null || source.isEmpty) return 'Unknown source';
  // LOW-02: clamp to prevent abnormally long source strings
  final s = source.length > 50 ? source.substring(0, 50) : source;
  switch (s.toLowerCase()) {
    case 'apple_health':
    case 'apple health':
      return 'from Apple Health';
    case 'fitbit':
      return 'from Fitbit';
    case 'strava':
      return 'from Strava';
    case 'garmin':
      return 'from Garmin';
    case 'google_fit':
    case 'google fit':
      return 'from Google Fit';
    default:
      return 'from ${s[0].toUpperCase()}${s.substring(1)}';
  }
}

// ── MetricDetailScreen ────────────────────────────────────────────────────────

/// Metric detail screen parameterised by [metricId].
class MetricDetailScreen extends ConsumerStatefulWidget {
  /// Creates a [MetricDetailScreen] for the given [metricId].
  const MetricDetailScreen({super.key, required this.metricId});

  /// The metric identifier slug (e.g. "steps", "heart_rate_resting").
  final String metricId;

  @override
  ConsumerState<MetricDetailScreen> createState() =>
      _MetricDetailScreenState();
}

class _MetricDetailScreenState extends ConsumerState<MetricDetailScreen> {
  TimeRange _selectedRange = TimeRange.days7;
  DateTimeRange? _customRange;
  bool _showRawTable = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final timeRangeKey =
        _selectedRange == TimeRange.custom && _customRange != null
            ? 'custom:${_customRange!.start.toIso8601String()}|${_customRange!.end.toIso8601String()}'
            : _selectedRange.label;
    final params = MetricDetailParams(
      metricId: widget.metricId,
      timeRange: timeRangeKey,
    );
    final detailAsync = ref.watch(metricDetailProvider(params));

    return ZuralogScaffold(
      appBar: AppBar(
        title: detailAsync.when(
          data: (d) => Text(d.series.displayName, style: AppTextStyles.displaySmall),
          loading: () => const SizedBox.shrink(),
          error: (err, stack) => Text(widget.metricId, style: AppTextStyles.displaySmall),
        ),
      ),
      body: detailAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 40, color: AppColors.textTertiary),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                'Could not load metric',
                style:
                    AppTextStyles.bodyLarge.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        data: (detail) => _MetricDetailBody(
          detail: detail,
          selectedRange: _selectedRange,
          customRange: _customRange,
          showRawTable: _showRawTable,
          onRangeChanged: (r) =>
              setState(() => _selectedRange = r),
          onCustomRangePicked: (range) => setState(() {
            _customRange = range;
            _selectedRange = TimeRange.custom;
          }),
          onToggleRawTable: () =>
              setState(() => _showRawTable = !_showRawTable),
        ),
      ),
    );
  }
}

// ── _MetricDetailBody ─────────────────────────────────────────────────────────

/// Body widget for the metric detail screen.
///
/// Must be a [ConsumerStatefulWidget] for two reasons:
/// 1. It owns an [AnimationController] via [SingleTickerProviderStateMixin] —
///    cannot be stateless.
/// 2. It reads [unitsSystemProvider] via `ref.watch` — requires a Riverpod
///    Consumer.
class _MetricDetailBody extends ConsumerStatefulWidget {
  const _MetricDetailBody({
    required this.detail,
    required this.selectedRange,
    required this.showRawTable,
    required this.onRangeChanged,
    required this.onToggleRawTable,
    this.customRange,
    this.onCustomRangePicked,
  });

  final MetricDetailData detail;
  final TimeRange selectedRange;
  final DateTimeRange? customRange;
  final bool showRawTable;
  final ValueChanged<TimeRange> onRangeChanged;
  final ValueChanged<DateTimeRange>? onCustomRangePicked;
  final VoidCallback onToggleRawTable;

  @override
  ConsumerState<_MetricDetailBody> createState() => _MetricDetailBodyState();
}

class _MetricDetailBodyState extends ConsumerState<_MetricDetailBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _chartOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _chartOpacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_MetricDetailBody old) {
    super.didUpdateWidget(old);
    // LOW-04: also replay animation when custom date range changes
    if (old.selectedRange != widget.selectedRange ||
        old.customRange != widget.customRange) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final series = widget.detail.series;
    final cat = widget.detail.category;
    final overrideInt = ref.watch(
      dashboardLayoutProvider
          .select((l) => l.categoryColorOverrides[cat.name]),
    );
    final color = (overrideInt != null && overrideInt != 0)
        ? Color(overrideInt)
        : categoryColor(cat);

    final unitsSystem = ref.watch(unitsSystemProvider);
    final unitLabel = displayUnit(series.unit, unitsSystem);

    final spots = [
      for (var i = 0; i < series.dataPoints.length; i++)
        FlSpot(i.toDouble(), series.dataPoints[i].value),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.bottomNavHeight + AppDimens.spaceMd,
      ),
      children: [
        // ── Time range selector ──────────────────────────────────────────────
        TimeRangeSelector(
          value: widget.selectedRange,
          onChanged: widget.onRangeChanged,
          customDateRange: widget.customRange,
          onCustomRangePicked: widget.onCustomRangePicked,
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // ── Stats row ────────────────────────────────────────────────────────
        _StatsRow(series: series, color: color, displayUnit: unitLabel),

        const SizedBox(height: AppDimens.spaceMd),

        // ── Chart ────────────────────────────────────────────────────────────
        if (spots.length >= 2) ...[
          _ChartCard(
            spots: spots,
            color: color,
            opacity: _chartOpacity,
            series: series,
            displayUnit: unitLabel,
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Pinch to zoom · drag to pan',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],

        if (spots.length == 1) ...[
          const SizedBox(height: AppDimens.spaceLg),
          Center(
            child: Text(
              'Only one data point available',
              style: AppTextStyles.bodyLarge.copyWith(
                  color: colors.textSecondary),
            ),
          ),
        ],

        if (spots.isEmpty) ...[
          const SizedBox(height: AppDimens.spaceLg),
          Center(
            child: Text(
              'No data for this period',
              style: AppTextStyles.bodyLarge.copyWith(
                  color: colors.textSecondary),
            ),
          ),
        ],

        const SizedBox(height: AppDimens.spaceMd),

        // ── Source attribution ───────────────────────────────────────────────
        _SourceAttribution(source: series.sourceIntegration),

        // ── AI Insight ───────────────────────────────────────────────────────
        if (widget.detail.aiInsight != null) ...[
          const SizedBox(height: AppDimens.spaceMd),
          _AiInsightCard(insight: widget.detail.aiInsight!),
        ],

        const SizedBox(height: AppDimens.spaceMd),

        // ── Raw data table toggle ────────────────────────────────────────────
        if (series.dataPoints.isNotEmpty) ...[
          _RawTableToggle(
            isExpanded: widget.showRawTable,
            onToggle: widget.onToggleRawTable,
            series: series,
            displayUnit: unitLabel,
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],

        // ── Ask Coach button ─────────────────────────────────────────────────
        _AskCoachButton(
          metricName: series.displayName,
          metricId: widget.detail.series.metricId,
          currentValue: series.currentValue,
          unit: unitLabel,
        ),
      ],
    );
  }
}

// ── _StatsRow ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.series,
    required this.color,
    required this.displayUnit,
  });
  final MetricSeries series;
  final Color color;
  final String displayUnit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _StatCell(
            label: 'Current',
            value: series.currentValue ?? '—',
            unit: displayUnit.isNotEmpty ? displayUnit : null,
            color: color,
          ),
          const _VerticalDivider(),
          _StatCell(
            label: 'Average',
            value: series.average?.toStringAsFixed(1) ?? '—',
            unit: displayUnit.isNotEmpty ? displayUnit : null,
          ),
          if (series.deltaPercent != null) ...[
            const _VerticalDivider(),
            _StatCell(
              label: 'vs last week',
              value:
                  '${series.deltaPercent! >= 0 ? '+' : ''}${series.deltaPercent!.toStringAsFixed(1)}%',
              color: series.deltaPercent! >= 0
                  ? AppColors.healthScoreGreen
                  : AppColors.healthScoreRed,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    this.unit,
    this.color,
  });
  final String label;
  final String value;
  final String? unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final textColor =
        color ?? Theme.of(context).colorScheme.onSurface;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            unit != null ? '$value $unit' : value,
            style: AppTextStyles.titleMedium.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      width: 1,
      height: 36,
      color: colors.border.withValues(alpha: 0.5),
    );
  }
}

// ── _ChartCard ────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.spots,
    required this.color,
    required this.opacity,
    required this.series,
    required this.displayUnit,
  });

  final List<FlSpot> spots;
  final Color color;
  final Animation<double> opacity;
  final MetricSeries series;
  final String displayUnit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final values = spots.map((s) => s.y).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) == 0 ? 1.0 : (maxY - minY) * 0.15;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
        AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: FadeTransition(
        opacity: opacity,
        child: InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 1.0,
          maxScale: 4.0,
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY - padding,
                maxY: maxY + padding,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ((maxY - minY) / 4).clamp(0.1, 1e9),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colors.border.withValues(alpha: 0.4),
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (val, meta) => Text(
                        val.toStringAsFixed(
                            val.abs() >= 100 ? 0 : 1),
                         style: AppTextStyles.labelSmall.copyWith(
                             color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => colors.surface,
                    getTooltipItems: (touchedSpots) => touchedSpots
                        .map((s) => LineTooltipItem(
                              '${s.y.toStringAsFixed(1)} $displayUnit',
                               AppTextStyles.bodySmall.copyWith(
                                 color: color,
                                 fontWeight: FontWeight.w600,
                               ),
                            ))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: color,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: spots.length <= 14,
                      getDotPainter: (spot, xPercentage, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: color,
                        strokeColor: colors.background,
                        strokeWidth: 1.5,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.15),
                          color.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
            ),
          ),
        ),
      ),
    );
  }
}

// ── _SourceAttribution ────────────────────────────────────────────────────────

class _SourceAttribution extends StatelessWidget {
  const _SourceAttribution({required this.source});
  final String? source;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.sensors_rounded,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: AppDimens.spaceXs),
        Flexible(
          child: Text(
            _sourceLabel(source),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── _AiInsightCard ────────────────────────────────────────────────────────────

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({required this.insight});
  final String insight;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 3px left accent bar.
            Container(width: 3, color: colors.primary),
            // Card body.
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                color: colors.cardBackground,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Expanded(
                       child: Text(
                         insight,
                         style: AppTextStyles.bodySmall.copyWith(
                           color: Theme.of(context).colorScheme.onSurface,
                         ),
                       ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _RawTableToggle ───────────────────────────────────────────────────────────

class _RawTableToggle extends StatelessWidget {
  const _RawTableToggle({
    required this.isExpanded,
    required this.onToggle,
    required this.series,
    required this.displayUnit,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final MetricSeries series;
  final String displayUnit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              children: [
                 Text(
                   'Raw Data',
                   style: AppTextStyles.titleMedium,
                 ),
                const Spacer(),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: AppDimens.spaceMd),
              // Table header
              Row(
                children: [
                  Expanded(
                    flex: 3,
                     child: Text(
                       'Date',
                       style: AppTextStyles.bodySmall.copyWith(
                         color: colors.textSecondary,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   ),
                   Expanded(
                     flex: 2,
                     child: Text(
                       'Value',
                       textAlign: TextAlign.right,
                       style: AppTextStyles.bodySmall.copyWith(
                         color: colors.textSecondary,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   ),
                ],
              ),
              const Divider(height: 16),
              // Table rows (latest first, max _kRawTableMaxRows)
              ...series.dataPoints.reversed
                  .take(_kRawTableMaxRows)
                  .map(
                    (dp) => Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              _formatDate(dp.timestamp),
                             style: AppTextStyles.bodySmall.copyWith(
                                 color: colors.textSecondary,
                               ),
                             ),
                           ),
                           Expanded(
                             flex: 2,
                             child: Text(
                               '${dp.value.toStringAsFixed(1)} $displayUnit',
                               textAlign: TextAlign.right,
                               style: AppTextStyles.bodySmall.copyWith(
                                 color: Theme.of(context)
                                     .colorScheme
                                     .onSurface,
                                 fontWeight: FontWeight.w600,
                               ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(String iso) {
    if (iso.isEmpty) return 'Unknown date';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return iso;
    }
  }
}

// ── _AskCoachButton ───────────────────────────────────────────────────────────

class _AskCoachButton extends ConsumerWidget {
  const _AskCoachButton({
    required this.metricName,
    required this.metricId,
    this.currentValue,
    this.unit = '',
  });

  final String metricName;
  final String metricId;
  final String? currentValue;
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryButtonText,
        minimumSize: const Size.fromHeight(AppDimens.touchTargetMin),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: () {
        final currentVal = currentValue ?? '';
        var prefill = 'Tell me about my $metricName'
            '${currentVal.isNotEmpty ? ': $currentVal${unit.isNotEmpty ? ' $unit' : ''}' : ''}';
        // HIGH-05: prevent abnormally large strings from reaching the coach input
        if (prefill.length > _kCoachPrefillMaxLength) {
          prefill = '${prefill.substring(0, _kCoachPrefillMaxLength - 1)}…';
        }
        ref.read(coachPrefillProvider.notifier).state = prefill;
        context.go(RouteNames.coachPath);
      },
      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
      label: Text(
        'Ask Coach about $metricName',
        style: AppTextStyles.bodyLarge.copyWith(
          color: AppColors.primaryButtonText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

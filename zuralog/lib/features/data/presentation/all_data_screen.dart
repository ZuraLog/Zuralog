/// All Data — Health Matrix.
///
/// A spreadsheet-style heatmap where every tracked metric is one row
/// and the last N days (7 / 30 / 90) are columns. Every cell is a
/// colored square whose tint intensity encodes the metric's value
/// relative to its own range across the selected window.
///
/// Anatomy:
///   1. Transparent [ZuralogAppBar] with back chevron.
///   2. Controls row — range pills on the left, legend on the right.
///   3. Grid — a fixed 140pt metric-name column on the left, a sticky
///      date header on top, and the heatmap body.
///   4. Footer — four micro-stats (metrics tracked / days of data /
///      cells / last synced).
///
/// Tapping any body cell opens a bottom popover with the exact value,
/// the date, a delta vs the metric's mean, and a plain-English
/// description.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Matrix constants ─────────────────────────────────────────────────────────

const double _kLabelColWidth = 140;
const double _kDayColWidth = 32;
const double _kCellHeight = 32;
const double _kCategoryRowHeight = 28;
const double _kDateHeaderHeight = 32;
const double _kControlsHeight = 48;
const double _kFooterHeight = 56;

/// The six health categories the matrix renders, in display order.
const List<HealthCategory> _kMatrixCategories = [
  HealthCategory.sleep,
  HealthCategory.activity,
  HealthCategory.heart,
  HealthCategory.nutrition,
  HealthCategory.body,
  HealthCategory.wellness,
];

/// Time-range options for the segmented control.
enum _MatrixRange {
  days7('7D', 7),
  days30('30D', 30),
  days90('90D', 90);

  const _MatrixRange(this.label, this.days);
  final String label;
  final int days;
}

/// Metric IDs whose intensity should be inverted (lower value = brighter cell).
const Set<String> _kInvertedMetrics = {
  'resting_heart_rate',
  'stress',
  'body_fat',
  'body_fat_percent',
  'respiratory_rate',
  'awake_time',
};

// ── AllDataScreen ────────────────────────────────────────────────────────────

/// Health Matrix — dense all-data heatmap grid.
class AllDataScreen extends ConsumerStatefulWidget {
  /// Creates the [AllDataScreen].
  const AllDataScreen({super.key});

  @override
  ConsumerState<AllDataScreen> createState() => _AllDataScreenState();
}

class _AllDataScreenState extends ConsumerState<AllDataScreen> {
  _MatrixRange _range = _MatrixRange.days30;

  // Scroll controllers — kept separate and mirrored via listeners. Flutter
  // forbids attaching the same controller to two scroll views simultaneously,
  // so we mirror offsets both ways with a guard flag to avoid ping-ponging.
  final ScrollController _headerHScroll = ScrollController();
  final ScrollController _bodyHScroll = ScrollController();
  final ScrollController _labelsVScroll = ScrollController();
  final ScrollController _bodyVScroll = ScrollController();

  bool _syncingH = false;
  bool _syncingV = false;
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    _headerHScroll.addListener(_onHeaderHScroll);
    _bodyHScroll.addListener(_onBodyHScroll);
    _labelsVScroll.addListener(_onLabelsVScroll);
    _bodyVScroll.addListener(_onBodyVScroll);
  }

  @override
  void dispose() {
    _headerHScroll
      ..removeListener(_onHeaderHScroll)
      ..dispose();
    _bodyHScroll
      ..removeListener(_onBodyHScroll)
      ..dispose();
    _labelsVScroll
      ..removeListener(_onLabelsVScroll)
      ..dispose();
    _bodyVScroll
      ..removeListener(_onBodyVScroll)
      ..dispose();
    super.dispose();
  }

  void _onHeaderHScroll() {
    if (_syncingH || !_bodyHScroll.hasClients) return;
    _syncingH = true;
    _bodyHScroll.jumpTo(_headerHScroll.offset);
    _syncingH = false;
  }

  void _onBodyHScroll() {
    if (_syncingH || !_headerHScroll.hasClients) return;
    _syncingH = true;
    _headerHScroll.jumpTo(_bodyHScroll.offset);
    _syncingH = false;
  }

  void _onLabelsVScroll() {
    if (_syncingV || !_bodyVScroll.hasClients) return;
    _syncingV = true;
    _bodyVScroll.jumpTo(_labelsVScroll.offset);
    _syncingV = false;
  }

  void _onBodyVScroll() {
    if (_syncingV || !_labelsVScroll.hasClients) return;
    _syncingV = true;
    _labelsVScroll.jumpTo(_bodyVScroll.offset);
    _syncingV = false;
  }

  void _scrollToToday() {
    if (_initialScrollDone) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_bodyHScroll.hasClients &&
          _bodyHScroll.position.maxScrollExtent > 0) {
        _bodyHScroll.jumpTo(_bodyHScroll.position.maxScrollExtent);
        _initialScrollDone = true;
      }
    });
  }

  void _setRange(_MatrixRange r) {
    if (r == _range) return;
    setState(() {
      _range = r;
      _initialScrollDone = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    // Watch one provider per category for the selected range.
    final List<AsyncValue<CategoryDetailData>> categoryAsyncs = _kMatrixCategories
        .map(
          (cat) => ref.watch(
            categoryDetailProvider(
              CategoryDetailParams(
                categoryId: cat.name,
                timeRange: _range.label,
              ),
            ),
          ),
        )
        .toList(growable: false);

    // Watch dashboard for the last-synced footer stat.
    final dashAsync = ref.watch(dashboardProvider);

    // Flatten — each entry is (category, metrics). Skeleton empty lists until
    // the fetch resolves so the grid shape is visible even while loading.
    final List<_CategoryBlock> blocks = [];
    for (var i = 0; i < _kMatrixCategories.length; i++) {
      final cat = _kMatrixCategories[i];
      final metrics = categoryAsyncs[i].maybeWhen(
        data: (d) => d.metrics,
        orElse: () => const <MetricSeries>[],
      );
      blocks.add(_CategoryBlock(category: cat, metrics: metrics));
    }

    // Build the day columns — anchored at today's local midnight, walking
    // backwards `range.days - 1` days. Oldest-first left to right.
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final List<DateTime> dayColumns = List<DateTime>.generate(
      _range.days,
      (i) => todayMidnight.subtract(Duration(days: _range.days - 1 - i)),
      growable: false,
    );

    // Once layout is done after a range change, pin today's column on screen.
    _scrollToToday();

    // Aggregate last-synced across all dashboard category summaries. We pick
    // the most recent ISO-8601 timestamp we can parse; anything unparseable
    // is ignored.
    final DateTime? lastSynced = dashAsync.maybeWhen(
      data: (d) => _mostRecentLastUpdated(d.categories),
      orElse: () => null,
    );

    // Count non-empty rows and total filled cells for the footer.
    int metricsTracked = 0;
    int totalFilledCells = 0;
    for (final b in blocks) {
      for (final m in b.metrics) {
        if (m.dataPoints.isEmpty) continue;
        metricsTracked++;
        final byDay = _bucketByDay(m.dataPoints);
        for (final col in dayColumns) {
          if (byDay.containsKey(_dayKey(col))) totalFilledCells++;
        }
      }
    }

    return ZuralogScaffold(
      appBar: const ZuralogAppBar(
        title: 'All Data',
        showProfileAvatar: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Controls row — range pills + legend.
          _ControlsRow(
            range: _range,
            onRangeChanged: _setRange,
          ),

          // The matrix grid itself — expands to fill remaining vertical space.
          Expanded(
            child: _MatrixGrid(
              blocks: blocks,
              days: dayColumns,
              headerHScroll: _headerHScroll,
              bodyHScroll: _bodyHScroll,
              labelsVScroll: _labelsVScroll,
              bodyVScroll: _bodyVScroll,
              onCellTap: _openCellPopover,
            ),
          ),

          // Footer — four micro-stats separated by hairline dividers.
          _FooterStrip(
            metricsTracked: metricsTracked,
            days: _range.days,
            cells: totalFilledCells,
            lastSynced: lastSynced,
            dividerColor: colors.border.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }

  Future<void> _openCellPopover({
    required MetricSeries series,
    required HealthCategory category,
    required DateTime day,
    required MetricDataPoint? point,
  }) async {
    // Compute metric mean across the range (ignoring non-finite values).
    double? mean;
    final vals = series.dataPoints
        .map((p) => p.value)
        .where((v) => v.isFinite)
        .toList(growable: false);
    if (vals.isNotEmpty) {
      mean = vals.reduce((a, b) => a + b) / vals.length;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: false,
      builder: (sheetCtx) {
        return _CellPopover(
          series: series,
          category: category,
          day: day,
          point: point,
          metricMean: mean,
        );
      },
    );
  }
}

// ── _ControlsRow ─────────────────────────────────────────────────────────────

class _ControlsRow extends StatelessWidget {
  const _ControlsRow({
    required this.range,
    required this.onRangeChanged,
  });

  final _MatrixRange range;
  final ValueChanged<_MatrixRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return SizedBox(
      height: _kControlsHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        child: Row(
          children: [
            // Range pills — sage-tinted segmented control.
            _RangePills(
              selected: range,
              onChanged: onRangeChanged,
            ),
            const Spacer(),
            // Legend — "Low → High" gradient strip.
            _LegendStrip(color: colors.primary),
          ],
        ),
      ),
    );
  }
}

class _RangePills extends StatelessWidget {
  const _RangePills({required this.selected, required this.onChanged});

  final _MatrixRange selected;
  final ValueChanged<_MatrixRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final opts = _MatrixRange.values;
    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in opts)
            _RangePill(
              label: o.label,
              active: o == selected,
              onTap: () => onChanged(o),
              activeColor: colors.primary,
              activeTextColor: colors.textOnWarmWhite,
              inactiveTextColor: colors.textSecondary,
            ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,
    required this.active,
    required this.onTap,
    required this.activeColor,
    required this.activeTextColor,
    required this.inactiveTextColor,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;
  final Color activeTextColor;
  final Color inactiveTextColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusChip - 3),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: active ? activeTextColor : inactiveTextColor,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _LegendStrip extends StatelessWidget {
  const _LegendStrip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Low',
          style: AppTextStyles.labelSmall.copyWith(color: colors.textTertiary),
        ),
        const SizedBox(width: 6),
        Container(
          width: 80,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.14),
                color.withValues(alpha: 0.90),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'High',
          style: AppTextStyles.labelSmall.copyWith(color: colors.textTertiary),
        ),
      ],
    );
  }
}

// ── _MatrixGrid ──────────────────────────────────────────────────────────────

class _MatrixGrid extends StatelessWidget {
  const _MatrixGrid({
    required this.blocks,
    required this.days,
    required this.headerHScroll,
    required this.bodyHScroll,
    required this.labelsVScroll,
    required this.bodyVScroll,
    required this.onCellTap,
  });

  final List<_CategoryBlock> blocks;
  final List<DateTime> days;
  final ScrollController headerHScroll;
  final ScrollController bodyHScroll;
  final ScrollController labelsVScroll;
  final ScrollController bodyVScroll;
  final _CellTapCallback onCellTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final totalDayWidth = days.length * _kDayColWidth;
    final now = DateTime.now();
    final todayKey = _dayKey(DateTime(now.year, now.month, now.day));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row 1 — sticky date header + corner cell.
        SizedBox(
          height: _kDateHeaderHeight,
          child: Row(
            children: [
              // Empty corner cell above the fixed label column.
              Container(
                width: _kLabelColWidth,
                height: _kDateHeaderHeight,
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(
                    right: BorderSide(
                      color: colors.border.withValues(alpha: 0.25),
                      width: 1,
                    ),
                    bottom: BorderSide(
                      color: colors.border.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                ),
              ),
              // Horizontally scrolling date header.
              Expanded(
                child: ScrollConfiguration(
                  // Hide overscroll glow — it would leak above the grid.
                  behavior: const _NoGlowBehavior(),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: headerHScroll,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: totalDayWidth,
                      height: _kDateHeaderHeight,
                      child: Row(
                        children: [
                          for (var i = 0; i < days.length; i++)
                            _DateHeaderCell(
                              date: days[i],
                              isWeekStart: i % 7 == 0 && i != 0,
                              isToday: _dayKey(days[i]) == todayKey,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Row 2 — fixed label column + horizontally scrolling body, both
        // vertically scrollable and mirrored.
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left — fixed label column (vertical scroll only).
              SizedBox(
                width: _kLabelColWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      right: BorderSide(
                        color: colors.border.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                  ),
                  child: ScrollConfiguration(
                    behavior: const _NoGlowBehavior(),
                    child: SingleChildScrollView(
                      controller: labelsVScroll,
                      physics: const ClampingScrollPhysics(),
                      child: _LabelColumn(blocks: blocks),
                    ),
                  ),
                ),
              ),
              // Right — horizontally scrollable body, nested vertical scroll.
              Expanded(
                child: ScrollConfiguration(
                  behavior: const _NoGlowBehavior(),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: bodyHScroll,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: totalDayWidth,
                      child: ScrollConfiguration(
                        behavior: const _NoGlowBehavior(),
                        child: SingleChildScrollView(
                          controller: bodyVScroll,
                          physics: const ClampingScrollPhysics(),
                          child: _HeatmapBody(
                            blocks: blocks,
                            days: days,
                            todayKey: todayKey,
                            onCellTap: onCellTap,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateHeaderCell extends StatelessWidget {
  const _DateHeaderCell({
    required this.date,
    required this.isWeekStart,
    required this.isToday,
  });

  final DateTime date;
  final bool isWeekStart;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      width: _kDayColWidth,
      height: _kDateHeaderHeight,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.25),
            width: 1,
          ),
          left: isWeekStart
              ? BorderSide(
                  color: colors.border.withValues(alpha: 0.18),
                  width: 1,
                )
              : BorderSide.none,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Today indicator dot — sage, 4pt, sitting just above the number.
          if (isToday)
            Positioned(
              top: 4,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Text(
            '${date.day}',
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _LabelColumn ─────────────────────────────────────────────────────────────

class _LabelColumn extends StatelessWidget {
  const _LabelColumn({required this.blocks});

  final List<_CategoryBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final children = <Widget>[];
    for (final b in blocks) {
      final catColor = categoryColor(b.category);
      // Category section header row.
      children.add(
        Container(
          height: _kCategoryRowHeight,
          padding: const EdgeInsets.only(left: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: 0.14),
            border: Border(
              bottom: BorderSide(
                color: colors.border.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
          ),
          child: Text(
            b.category.displayName.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
      // Metric name rows.
      for (final m in b.metrics) {
        children.add(
          Container(
            height: _kCellHeight,
            padding: const EdgeInsets.only(left: 12, right: 6),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.border.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: Text(
              m.displayName,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

// ── _HeatmapBody ─────────────────────────────────────────────────────────────

typedef _CellTapCallback = void Function({
  required MetricSeries series,
  required HealthCategory category,
  required DateTime day,
  required MetricDataPoint? point,
});

class _HeatmapBody extends StatelessWidget {
  const _HeatmapBody({
    required this.blocks,
    required this.days,
    required this.todayKey,
    required this.onCellTap,
  });

  final List<_CategoryBlock> blocks;
  final List<DateTime> days;
  final String todayKey;
  final _CellTapCallback onCellTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final rows = <Widget>[];
    for (final b in blocks) {
      final catColor = categoryColor(b.category);
      // Category band — spans the full day width.
      rows.add(
        Container(
          height: _kCategoryRowHeight,
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: 0.08),
            border: Border(
              bottom: BorderSide(
                color: colors.border.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
          ),
        ),
      );
      // One row per metric.
      for (final m in b.metrics) {
        rows.add(
          _MetricRow(
            series: m,
            category: b.category,
            days: days,
            todayKey: todayKey,
            catColor: catColor,
            onCellTap: onCellTap,
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.series,
    required this.category,
    required this.days,
    required this.todayKey,
    required this.catColor,
    required this.onCellTap,
  });

  final MetricSeries series;
  final HealthCategory category;
  final List<DateTime> days;
  final String todayKey;
  final Color catColor;
  final _CellTapCallback onCellTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    // Index points by local day for O(1) lookup per cell.
    final byDay = _bucketByDay(series.dataPoints);

    // Min / max across the range (values falling inside the day columns only).
    final invert = _kInvertedMetrics.contains(series.metricId);
    double? minV;
    double? maxV;
    for (final d in days) {
      final p = byDay[_dayKey(d)];
      if (p == null) continue;
      final v = p.value;
      if (!v.isFinite) continue;
      minV = (minV == null) ? v : math.min(minV, v);
      maxV = (maxV == null) ? v : math.max(maxV, v);
    }

    return SizedBox(
      height: _kCellHeight,
      child: Row(
        children: [
          for (final d in days)
            _HeatCell(
              point: byDay[_dayKey(d)],
              day: d,
              isToday: _dayKey(d) == todayKey,
              isWeekStart: _isWeekStart(d, days),
              catColor: catColor,
              minV: minV,
              maxV: maxV,
              invert: invert,
              missingColor: colors.elevatedSurface.withValues(alpha: 0.3),
              todayBorderColor: colors.textPrimary,
              gridLineColor: colors.border.withValues(alpha: 0.08),
              weekBorderColor: colors.border.withValues(alpha: 0.18),
              onTap: () => onCellTap(
                series: series,
                category: category,
                day: d,
                point: byDay[_dayKey(d)],
              ),
            ),
        ],
      ),
    );
  }

  bool _isWeekStart(DateTime d, List<DateTime> all) {
    final idx = all.indexOf(d);
    return idx > 0 && idx % 7 == 0;
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.point,
    required this.day,
    required this.isToday,
    required this.isWeekStart,
    required this.catColor,
    required this.minV,
    required this.maxV,
    required this.invert,
    required this.missingColor,
    required this.todayBorderColor,
    required this.gridLineColor,
    required this.weekBorderColor,
    required this.onTap,
  });

  final MetricDataPoint? point;
  final DateTime day;
  final bool isToday;
  final bool isWeekStart;
  final Color catColor;
  final double? minV;
  final double? maxV;
  final bool invert;
  final Color missingColor;
  final Color todayBorderColor;
  final Color gridLineColor;
  final Color weekBorderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    if (point == null || !point!.value.isFinite) {
      fill = missingColor;
    } else if (minV == null || maxV == null) {
      fill = catColor.withValues(alpha: 0.14 + 0.5 * 0.76);
    } else if (maxV == minV) {
      fill = catColor.withValues(alpha: 0.14 + 0.5 * 0.76);
    } else {
      double intensity = (point!.value - minV!) / (maxV! - minV!);
      if (!intensity.isFinite) intensity = 0.5;
      intensity = intensity.clamp(0.0, 1.0);
      if (invert) intensity = 1.0 - intensity;
      final alpha = 0.14 + intensity * 0.76;
      fill = catColor.withValues(alpha: alpha);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _kDayColWidth,
        height: _kCellHeight,
        decoration: BoxDecoration(
          color: fill,
          border: Border(
            right: isToday
                ? BorderSide(color: todayBorderColor, width: 1)
                : BorderSide(color: gridLineColor, width: 0.5),
            left: isWeekStart
                ? BorderSide(color: weekBorderColor, width: 1)
                : BorderSide.none,
            bottom: BorderSide(color: gridLineColor, width: 0.5),
          ),
        ),
      ),
    );
  }
}

// ── _FooterStrip ─────────────────────────────────────────────────────────────

class _FooterStrip extends StatelessWidget {
  const _FooterStrip({
    required this.metricsTracked,
    required this.days,
    required this.cells,
    required this.lastSynced,
    required this.dividerColor,
  });

  final int metricsTracked;
  final int days;
  final int cells;
  final DateTime? lastSynced;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      height: _kFooterHeight,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.border.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Row(
        children: [
          Expanded(
            child: _FooterStat(
              label: 'Metrics tracked',
              value: _formatThousands(metricsTracked),
            ),
          ),
          _FooterDivider(color: dividerColor),
          Expanded(
            child: _FooterStat(
              label: 'Days of data',
              value: '$days',
            ),
          ),
          _FooterDivider(color: dividerColor),
          Expanded(
            child: _FooterStat(
              label: 'Cells',
              value: _formatThousands(cells),
            ),
          ),
          _FooterDivider(color: dividerColor),
          Expanded(
            child: _FooterStat(
              label: 'Last synced',
              value: _formatLastSynced(lastSynced),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterDivider extends StatelessWidget {
  const _FooterDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: color,
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: colors.textTertiary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── _CellPopover ─────────────────────────────────────────────────────────────

class _CellPopover extends StatelessWidget {
  const _CellPopover({
    required this.series,
    required this.category,
    required this.day,
    required this.point,
    required this.metricMean,
  });

  final MetricSeries series;
  final HealthCategory category;
  final DateTime day;
  final MetricDataPoint? point;
  final double? metricMean;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final catColor = categoryColor(category);
    final hasValue = point != null && point!.value.isFinite;

    final String valueText = hasValue ? _formatNumber(point!.value) : '—';
    final String? deltaText = (hasValue && metricMean != null)
        ? _formatDelta(point!.value - metricMean!)
        : null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          0,
          AppDimens.spaceMd,
          AppDimens.spaceMd,
        ),
        child: SizedBox(
          height: 200,
          child: ZuralogCard(
            variant: ZCardVariant.feature,
            category: catColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metric name.
                Text(
                  series.displayName,
                  style: AppTextStyles.titleMedium
                      .copyWith(color: colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimens.spaceXs),
                // Date line.
                Text(
                  _formatDayLabel(day),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: colors.textTertiary),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                // Big value (Lora serif) + unit.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      valueText,
                      style: GoogleFonts.lora(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    if (series.unit.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        series.unit,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ],
                ),
                if (deltaText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$deltaText vs metric avg',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: colors.textSecondary),
                  ),
                ],
                const Spacer(),
                // Plain-English description.
                Text(
                  _metricDescription(series.metricId),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: colors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers: data & formatting ───────────────────────────────────────────────

/// One category's metrics resolved from the provider.
class _CategoryBlock {
  const _CategoryBlock({required this.category, required this.metrics});
  final HealthCategory category;
  final List<MetricSeries> metrics;
}

/// Normalises a [DateTime] to a local YYYY-MM-DD key usable as a map lookup.
String _dayKey(DateTime d) {
  final local = d.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

/// Buckets the last data point per local day. If two points share a day we
/// keep the latest — sufficient for the heatmap since each cell is one day.
Map<String, MetricDataPoint> _bucketByDay(List<MetricDataPoint> points) {
  final out = <String, MetricDataPoint>{};
  for (final p in points) {
    final parsed = DateTime.tryParse(p.timestamp);
    if (parsed == null) continue;
    out[_dayKey(parsed)] = p;
  }
  return out;
}

/// Picks the most recent parseable `lastUpdated` across the dashboard
/// summaries. Returns null when nothing parseable is available.
DateTime? _mostRecentLastUpdated(List<CategorySummary> summaries) {
  DateTime? best;
  for (final s in summaries) {
    final raw = s.lastUpdated;
    if (raw == null) continue;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) continue;
    if (best == null || parsed.isAfter(best)) best = parsed;
  }
  return best;
}

String _formatThousands(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
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

String _formatLastSynced(DateTime? t) {
  if (t == null) return '—';
  final diff = DateTime.now().difference(t);
  if (diff.isNegative) return 'just now';
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}

String _formatNumber(double v) {
  if (!v.isFinite) return '—';
  if (v.abs() >= 1000) return _formatThousands(v.round());
  // Show one decimal when non-integer, clean when integer.
  if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}

String _formatDelta(double delta) {
  if (!delta.isFinite) return '0';
  final sign = delta > 0 ? '+' : (delta < 0 ? '−' : '');
  final abs = delta.abs();
  final str = abs >= 100
      ? abs.toStringAsFixed(0)
      : abs >= 10
          ? abs.toStringAsFixed(1)
          : abs.toStringAsFixed(2);
  return '$sign$str';
}

String _formatDayLabel(DateTime d) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${weekdays[d.weekday - 1]} · ${months[d.month - 1]} ${d.day}';
}

// ── _NoGlowBehavior ──────────────────────────────────────────────────────────

/// Suppresses the default Android overscroll glow inside the matrix — a
/// glow leaking between the fixed column and the body would look like a bug.
class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

// ── _metricDescription ───────────────────────────────────────────────────────

/// Plain-English one-line descriptions of every metric id we currently
/// expect from the backend. Unknown ids fall back to a generic caption.
///
/// Copied verbatim from the removed magazine layout so cell popovers keep
/// the same wording users have already seen.
String _metricDescription(String id) {
  switch (id) {
    // Sleep
    case 'sleep_duration':
      return 'How long you were actually asleep last night.';
    case 'deep_sleep':
      return 'Time your body spent in deep, restorative sleep.';
    case 'rem_sleep':
      return 'Dream sleep — when your brain consolidates memory.';
    case 'light_sleep':
      return 'Light sleep — the bulk of the night.';
    case 'awake_time':
      return 'Minutes you were awake during the night.';
    case 'sleep_efficiency':
      return 'Percent of time in bed you were actually asleep.';
    case 'bedtime':
      return 'When you fell asleep last night.';
    case 'wake_time':
      return 'When you woke up this morning.';
    case 'sleep_stages':
      return 'Breakdown of deep, REM, light and awake time.';
    // Activity
    case 'steps':
      return 'Total steps you took today.';
    case 'active_calories':
      return 'Calories burned from movement beyond resting metabolism.';
    case 'active_minutes':
    case 'exercise_minutes':
      return 'Minutes you spent in moderate-to-vigorous movement.';
    case 'distance':
      return 'How far you moved today.';
    case 'floors_climbed':
      return 'Floors climbed via stairs or elevation gain.';
    case 'workouts':
      return 'Workouts you logged today.';
    case 'walking_speed':
      return 'Your average walking pace.';
    case 'running_pace':
      return 'Your average running pace.';
    // Heart
    case 'resting_heart_rate':
      return 'Your heart rate at full rest — lower usually means better recovery.';
    case 'hrv':
      return 'Heart rate variability — a key signal for recovery and stress.';
    case 'max_heart_rate':
    case 'avg_heart_rate':
      return 'Your heart rate while you moved today.';
    case 'walking_heart_rate':
      return 'Your average heart rate during steady walking.';
    case 'respiratory_rate':
      return 'Your breathing rate at rest.';
    case 'spo2':
      return 'Blood oxygen saturation — normal is 95–100%.';
    // Nutrition
    case 'calories':
      return 'Total energy you consumed today.';
    case 'protein':
      return 'Grams of protein you ate today.';
    case 'carbs':
      return 'Grams of carbohydrates you ate today.';
    case 'fat':
      return 'Grams of fat you ate today.';
    case 'water':
      return 'Water you drank today.';
    case 'mindful_minutes':
    case 'mindfulness':
    case 'meditation_minutes':
      return 'Time you spent in meditation or focused breathing.';
    // Body
    case 'weight':
      return 'Your latest weight reading.';
    case 'body_fat':
    case 'body_fat_percent':
      return 'Estimated percentage of your weight that is body fat.';
    case 'bmi':
      return 'Body mass index — weight-to-height ratio.';
    case 'body_temperature':
    case 'wrist_temperature':
      return 'Your skin temperature deviation from your baseline.';
    case 'blood_glucose':
      return 'Blood sugar reading — normal fasting is 70–99 mg/dL.';
    case 'blood_pressure':
      return 'Systolic over diastolic blood pressure.';
    case 'vo2_max':
      return 'A fitness measure of how much oxygen your body uses at peak effort.';
    // Wellness
    case 'mood':
      return 'How you rated your mood today.';
    case 'energy':
      return 'How energetic you felt today.';
    case 'stress':
      return 'How stressful today felt — lower is better.';
    default:
      return 'Tracked measurement from your connected sources.';
  }
}

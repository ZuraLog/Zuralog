/// Zuralog Dashboard — Calendar Heatmap Widget.
///
/// Renders a mini calendar grid where each day cell is filled with a colour
/// whose opacity reflects the magnitude of the metric's value on that day.
///
/// Used for: Exercise Sessions (intensity / count per day),
/// Cervical Mucus (quality level per day).
///
/// The grid is built from Flutter's layout primitives ([GridView], [Wrap],
/// [Container]) — no `fl_chart` dependency.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/graph_utils.dart';

// ── Internal helpers ──────────────────────────────────────────────────────────

/// Builds a [DateTime] representing midnight on [day].
DateTime _midnight(DateTime day) =>
    DateTime(day.year, day.month, day.day);

/// Short day-of-week header labels (ISO: Mon = 1).
const List<String> _dowLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

// ── Widget ────────────────────────────────────────────────────────────────────

/// A calendar-grid heatmap that colours each day by data magnitude.
///
/// Cells transition from transparent (no data) through semi-opaque to fully
/// opaque [accentColor] as the value increases relative to the period maximum.
///
/// Example usage:
/// ```dart
/// CalendarHeatmap(
///   series: exerciseSeries,
///   timeRange: TimeRange.month,
///   accentColor: Colors.green,
/// )
/// ```
class CalendarHeatmap extends StatefulWidget {
  /// Creates a [CalendarHeatmap].
  ///
  /// [series] — the metric time-series to visualise.
  ///
  /// [timeRange] — the selected time window (controls how many weeks to show).
  ///
  /// [accentColor] — the hue used to colour calendar cells.
  ///
  /// [interactive] — when `true`, tap on a day shows a bottom info tooltip.
  ///
  /// [compact] — when `true`, renders a 4-week mini calendar (~8 px cells)
  /// with no labels at 48 px height.
  const CalendarHeatmap({
    super.key,
    required this.series,
    required this.timeRange,
    required this.accentColor,
    this.interactive = true,
    this.compact = false,
  });

  /// The metric time-series to visualise.
  final MetricSeries series;

  /// The selected time window.
  final TimeRange timeRange;

  /// The primary hue for heatmap cell colouring.
  final Color accentColor;

  /// Enables tap-to-tooltip interactions when `true`.
  final bool interactive;

  /// When `true`, renders a compact 4-week mini grid at 48 px height.
  final bool compact;

  @override
  State<CalendarHeatmap> createState() => _CalendarHeatmapState();
}

class _CalendarHeatmapState extends State<CalendarHeatmap> {
  DateTime? _selectedDay;

  // ── Data ─────────────────────────────────────────────────────────────────────

  /// Builds a map from midnight [DateTime] to the data point value.
  Map<DateTime, double> _buildDayMap() {
    final map = <DateTime, double>{};
    for (final point in widget.series.dataPoints) {
      final key = _midnight(point.timestamp);
      // Keep max when multiple readings per day.
      final existing = map[key];
      if (existing == null || point.value > existing) {
        map[key] = point.value;
      }
    }
    return map;
  }

  /// Returns the list of [DateTime] days to display.
  ///
  /// Always starts on a Monday and covers full weeks.
  List<DateTime> _buildDayList(DateTime start, DateTime end) {
    // Rewind to Monday.
    var cursor = start.subtract(
      Duration(days: (start.weekday - 1) % 7),
    );
    final days = <DateTime>[];
    while (!cursor.isAfter(end)) {
      days.add(_midnight(cursor));
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }

  /// Computes the date range to render based on [TimeRange].
  (DateTime start, DateTime end) _dateRange() {
    final now = DateTime.now();
    final end = _midnight(now);
    final start = _midnight(now.subtract(Duration(days: widget.timeRange.days - 1)));
    return (start, end);
  }

  // ── Cell colour ──────────────────────────────────────────────────────────────

  /// Returns the fill colour for a day cell given its [value] and the
  /// period [maxValue].
  Color _cellColor(double? value, double maxValue) {
    if (value == null || value == 0) {
      return AppColors.textSecondary.withValues(alpha: 0.08);
    }
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    if (ratio < 0.35) return widget.accentColor.withValues(alpha: 0.3);
    if (ratio < 0.70) return widget.accentColor.withValues(alpha: 0.6);
    return widget.accentColor;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.series.dataPoints.isEmpty) {
      return GraphEmptyState(compact: widget.compact);
    }

    final dayMap = _buildDayMap();
    final maxValue = dayMap.values.fold(0.0, (a, b) => a > b ? a : b);

    if (widget.compact) {
      return _CompactGrid(
        dayMap: dayMap,
        maxValue: maxValue,
        accentColor: widget.accentColor,
        cellColor: _cellColor,
      );
    }

    final (start, end) = _dateRange();
    final days = _buildDayList(start, end);

    return _FullCalendar(
      days: days,
      dayMap: dayMap,
      maxValue: maxValue,
      selectedDay: _selectedDay,
      interactive: widget.interactive,
      cellColor: _cellColor,
      onDayTap: (day) {
        if (!widget.interactive) return;
        setState(() {
          _selectedDay = _selectedDay == day ? null : day;
        });
      },
    );
  }
}

// ── Compact grid ──────────────────────────────────────────────────────────────

/// A 4-week, 7-column mini heatmap at 48 px height with no labels.
class _CompactGrid extends StatelessWidget {
  const _CompactGrid({
    required this.dayMap,
    required this.maxValue,
    required this.accentColor,
    required this.cellColor,
  });

  final Map<DateTime, double> dayMap;
  final double maxValue;
  final Color accentColor;
  final Color Function(double? value, double maxValue) cellColor;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(28, (i) {
      final d = now.subtract(Duration(days: 27 - i));
      return DateTime(d.year, d.month, d.day);
    });

    return SizedBox(
      height: 48,
      child: GridView.count(
        crossAxisCount: 7,
        padding: EdgeInsets.zero,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: days.map((day) {
          return Container(
            decoration: BoxDecoration(
              color: cellColor(dayMap[day], maxValue),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Full calendar ─────────────────────────────────────────────────────────────

/// Full calendar grid with month headers, DOW headers, and tap interactions.
class _FullCalendar extends StatelessWidget {
  const _FullCalendar({
    required this.days,
    required this.dayMap,
    required this.maxValue,
    required this.selectedDay,
    required this.interactive,
    required this.cellColor,
    required this.onDayTap,
  });

  final List<DateTime> days;
  final Map<DateTime, double> dayMap;
  final double maxValue;
  final DateTime? selectedDay;
  final bool interactive;
  final Color Function(double? value, double maxValue) cellColor;
  final void Function(DateTime) onDayTap;

  /// Groups days into weeks.
  List<List<DateTime>> _weeks() {
    final weeks = <List<DateTime>>[];
    for (var i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, (i + 7).clamp(0, days.length)));
    }
    return weeks;
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _weeks();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // DOW header.
        Row(
          children: _dowLabels
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        // Week rows.
        ...weeks.map((week) => _WeekRow(
              week: week,
              dayMap: dayMap,
              maxValue: maxValue,
              selectedDay: selectedDay,
              cellColor: cellColor,
              onTap: onDayTap,
            )),
        // Selected day info.
        if (selectedDay != null)
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.spaceSm),
            child: _DayInfo(day: selectedDay!, value: dayMap[selectedDay]),
          ),
      ],
    );
  }
}

/// One row of 7 day cells.
class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.week,
    required this.dayMap,
    required this.maxValue,
    required this.selectedDay,
    required this.cellColor,
    required this.onTap,
  });

  final List<DateTime> week;
  final Map<DateTime, double> dayMap;
  final double maxValue;
  final DateTime? selectedDay;
  final Color Function(double? value, double maxValue) cellColor;
  final void Function(DateTime) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: List.generate(7, (i) {
          if (i >= week.length) return const Expanded(child: SizedBox());
          final day = week[i];
          final isSelected = day == selectedDay;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(day),
              child: Container(
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: cellColor(dayMap[day], maxValue),
                  borderRadius: BorderRadius.circular(4),
                  border: isSelected
                      ? Border.all(color: AppColors.textSecondary, width: 1)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// A small info row shown below the grid when a day is tapped.
class _DayInfo extends StatelessWidget {
  const _DayInfo({required this.day, required this.value});

  final DateTime day;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr = '${months[day.month - 1]} ${day.day}, ${day.year}';
    final valStr = value != null ? value!.toStringAsFixed(1) : 'No data';
    return Text(
      '$dateStr — $valStr',
      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    );
  }
}



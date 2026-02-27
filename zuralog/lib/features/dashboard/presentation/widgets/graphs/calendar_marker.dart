/// Zuralog Dashboard — Calendar Marker Widget.
///
/// Renders a calendar grid where days are marked with coloured dots when an
/// event occurred, rather than colour-coding by data magnitude.
///
/// Used for: Menstruation Flow/Period, Ovulation Test, Intermenstrual
/// Bleeding, Sexual Activity, Contraceptive.
///
/// Dot colour is determined by [MetricSeries.metricId]:
///   - `menstruation_flow` / `menstruation_period` → red.
///   - `ovulation_test` → blue.
///   - `intermenstrual_bleeding` → orange.
///   - `sexual_activity` → pink.
///   - `contraceptive` → purple.
///   - Default → [accentColor].
///
/// Built with Flutter layout primitives — no `fl_chart` dependency.
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

/// Returns the marker dot colour for a given [metricId] and [accentColor].
Color _dotColor(String metricId, Color accentColor) {
  switch (metricId) {
    case 'menstruation_flow':
    case 'menstruation_period':
      return Colors.red.shade400;
    case 'ovulation_test':
      return Colors.blue.shade400;
    case 'intermenstrual_bleeding':
      return Colors.orange.shade400;
    case 'sexual_activity':
      return Colors.pink.shade300;
    case 'contraceptive':
      return Colors.purple.shade300;
    default:
      return accentColor;
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// A calendar-grid marker widget that places coloured dots on event days.
///
/// Unlike [CalendarHeatmap], this widget does not encode value magnitude —
/// it simply marks days where any event was recorded.
///
/// Example usage:
/// ```dart
/// CalendarMarker(
///   series: menstruationSeries,
///   timeRange: TimeRange.month,
///   accentColor: Colors.red,
/// )
/// ```
class CalendarMarker extends StatefulWidget {
  /// Creates a [CalendarMarker].
  ///
  /// [series] — the metric time-series whose data points indicate event days.
  ///
  /// [timeRange] — the selected time window (controls how many weeks to show).
  ///
  /// [accentColor] — the fallback dot colour when [MetricSeries.metricId]
  /// does not match a known marker type.
  ///
  /// [interactive] — when `true`, tapping a day shows a tooltip with the date
  /// and event value.
  ///
  /// [compact] — when `true`, renders a 4-week mini grid with 4 px dots at
  /// 48 px total height, with no labels.
  const CalendarMarker({
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

  /// The fallback accent colour for the dot markers.
  final Color accentColor;

  /// Enables tap interactions when `true`.
  final bool interactive;

  /// When `true`, renders a compact 4-week mini grid at 48 px height.
  final bool compact;

  @override
  State<CalendarMarker> createState() => _CalendarMarkerState();
}

class _CalendarMarkerState extends State<CalendarMarker> {
  DateTime? _selectedDay;

  // ── Data ─────────────────────────────────────────────────────────────────────

  /// Builds a map from midnight [DateTime] to the event value (first reading).
  Map<DateTime, double> _buildEventMap() {
    final map = <DateTime, double>{};
    for (final point in widget.series.dataPoints) {
      final key = _midnight(point.timestamp);
      map.putIfAbsent(key, () => point.value);
    }
    return map;
  }

  /// Returns the list of [DateTime] days to display, starting on Monday.
  List<DateTime> _buildDayList(DateTime start, DateTime end) {
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

  /// Computes the date range to render.
  (DateTime start, DateTime end) _dateRange() {
    final now = DateTime.now();
    final end = _midnight(now);
    final start = _midnight(
      now.subtract(Duration(days: widget.timeRange.days - 1)),
    );
    return (start, end);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.series.dataPoints.isEmpty) {
      return GraphEmptyState(compact: widget.compact);
    }

    final eventMap = _buildEventMap();
    final dot = _dotColor(widget.series.metricId, widget.accentColor);

    if (widget.compact) {
      return _CompactGrid(eventMap: eventMap, dotColor: dot);
    }

    final (start, end) = _dateRange();
    final days = _buildDayList(start, end);

    return _FullCalendar(
      days: days,
      eventMap: eventMap,
      dotColor: dot,
      selectedDay: _selectedDay,
      interactive: widget.interactive,
      metricId: widget.series.metricId,
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

/// A 4-week mini grid with tiny 4 px dots, 48 px tall.
class _CompactGrid extends StatelessWidget {
  const _CompactGrid({required this.eventMap, required this.dotColor});

  final Map<DateTime, double> eventMap;
  final Color dotColor;

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
          final hasEvent = eventMap.containsKey(day);
          return Container(
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(2),
            ),
            child: hasEvent
                ? Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          );
        }).toList(),
      ),
    );
  }
}

// ── Full calendar ─────────────────────────────────────────────────────────────

/// Full calendar with DOW header, week rows, and tap-to-info.
class _FullCalendar extends StatelessWidget {
  const _FullCalendar({
    required this.days,
    required this.eventMap,
    required this.dotColor,
    required this.selectedDay,
    required this.interactive,
    required this.metricId,
    required this.onDayTap,
  });

  final List<DateTime> days;
  final Map<DateTime, double> eventMap;
  final Color dotColor;
  final DateTime? selectedDay;
  final bool interactive;
  final String metricId;
  final void Function(DateTime) onDayTap;

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
        ...weeks.map((week) => _MarkerWeekRow(
              week: week,
              eventMap: eventMap,
              dotColor: dotColor,
              selectedDay: selectedDay,
              onTap: onDayTap,
            )),
        // Selected day info.
        if (selectedDay != null)
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.spaceSm),
            child: _DayInfo(
              day: selectedDay!,
              value: eventMap[selectedDay],
              metricId: metricId,
            ),
          ),
      ],
    );
  }
}

/// One row of 7 day cells, each with an optional 6 px dot.
class _MarkerWeekRow extends StatelessWidget {
  const _MarkerWeekRow({
    required this.week,
    required this.eventMap,
    required this.dotColor,
    required this.selectedDay,
    required this.onTap,
  });

  final List<DateTime> week;
  final Map<DateTime, double> eventMap;
  final Color dotColor;
  final DateTime? selectedDay;
  final void Function(DateTime) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: List.generate(7, (i) {
          if (i >= week.length) return const Expanded(child: SizedBox());
          final day = week[i];
          final hasEvent = eventMap.containsKey(day);
          final isSelected = day == selectedDay;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(day),
              child: Container(
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                  border: isSelected
                      ? Border.all(color: AppColors.textSecondary, width: 1)
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    if (hasEvent)
                      Positioned(
                        bottom: 3,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
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
  const _DayInfo({
    required this.day,
    required this.value,
    required this.metricId,
  });

  final DateTime day;
  final double? value;
  final String metricId;

  @override
  Widget build(BuildContext context) {
    const months = [
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



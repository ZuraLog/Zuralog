/// Zuralog Dashboard — Single Value Display Widget.
///
/// A non-chart display used for metrics that change very infrequently
/// (e.g., Height). Shows the most recent reading as a large centred number
/// with its unit and the timestamp of the last measurement.
///
/// This is a pure Flutter widget — no `fl_chart` dependency.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';

// ── Widget ────────────────────────────────────────────────────────────────────

/// Displays the most recent value of an infrequently-changing metric.
///
/// Renders a large [accentColor] numeral for the latest data point, the
/// metric unit below it in secondary caption style, and a "Last measured:
/// …" timestamp. Falls back to an em-dash when [MetricSeries.dataPoints]
/// is empty.
///
/// Example usage:
/// ```dart
/// SingleValueDisplay(
///   series: heightSeries,
///   timeRange: TimeRange.year,
///   accentColor: Colors.teal,
///   unit: 'cm',
/// )
/// ```
class SingleValueDisplay extends StatelessWidget {
  /// Creates a [SingleValueDisplay].
  ///
  /// [series] — the metric time-series. Only the most recent point is shown.
  ///
  /// [timeRange] — unused for rendering but kept for interface consistency
  /// with other graph widgets.
  ///
  /// [accentColor] — the colour applied to the large value numeral.
  ///
  /// [unit] — the measurement unit appended below the value (e.g. `'cm'`,
  /// `'kg'`). Defaults to an empty string.
  ///
  /// [interactive] — kept for interface consistency; has no effect here since
  /// there is no chart to interact with.
  ///
  /// [compact] — when `true`, renders only the value + unit at a smaller
  /// size without the timestamp.
  const SingleValueDisplay({
    super.key,
    required this.series,
    required this.timeRange,
    required this.accentColor,
    this.unit = '',
    this.interactive = true,
    this.compact = false,
  });

  /// The metric time-series (only the latest point is displayed).
  final MetricSeries series;

  /// The selected time window (interface consistency — not used for layout).
  final TimeRange timeRange;

  /// The accent colour applied to the large value numeral.
  final Color accentColor;

  /// The measurement unit label displayed below the numeral.
  final String unit;

  /// Unused — kept for consistency with the graph widget interface.
  final bool interactive;

  /// When `true`, omits the timestamp row and renders a smaller value + unit.
  final bool compact;

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Returns the most recent [MetricDataPoint], or `null` if there is none.
  _Latest? _latest() {
    if (series.dataPoints.isEmpty) return null;
    final point = series.dataPoints.last;
    return _Latest(value: point.value, timestamp: point.timestamp);
  }

  /// Formats a [DateTime] as "MMM d, yyyy" (e.g., "Feb 15, 2026").
  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final latest = _latest();

    if (compact) {
      return _CompactDisplay(
        value: latest?.value,
        unit: unit,
        accentColor: accentColor,
      );
    }

    return _FullDisplay(
      value: latest?.value,
      timestamp: latest?.timestamp,
      unit: unit,
      accentColor: accentColor,
      formatDate: _formatDate,
    );
  }
}

// ── Data carrier ─────────────────────────────────────────────────────────────

/// Internal carrier for the most recent point's value and timestamp.
class _Latest {
  const _Latest({required this.value, required this.timestamp});

  final double value;
  final DateTime timestamp;
}

// ── Display variants ──────────────────────────────────────────────────────────

/// Full display: large value + unit + "Last measured" timestamp.
class _FullDisplay extends StatelessWidget {
  const _FullDisplay({
    required this.value,
    required this.timestamp,
    required this.unit,
    required this.accentColor,
    required this.formatDate,
  });

  final double? value;
  final DateTime? timestamp;
  final String unit;
  final Color accentColor;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final valueStr = value != null
        ? (value! == value!.floorToDouble()
            ? value!.toInt().toString()
            : value!.toStringAsFixed(1))
        : '—';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Large value numeral.
        Text(
          valueStr,
          style: AppTextStyles.h1.copyWith(
            color: accentColor,
            fontSize: 56,
            fontWeight: FontWeight.w700,
          ),
        ),
        // Unit.
        if (unit.isNotEmpty)
          Text(
            unit,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        const SizedBox(height: AppDimens.spaceSm),
        // Timestamp.
        if (timestamp != null)
          Text(
            'Last measured: ${formatDate(timestamp!)}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        else
          Text(
            'No data recorded',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

/// Compact display: smaller value + unit only.
class _CompactDisplay extends StatelessWidget {
  const _CompactDisplay({
    required this.value,
    required this.unit,
    required this.accentColor,
  });

  final double? value;
  final String unit;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final valueStr = value != null
        ? (value! == value!.floorToDouble()
            ? value!.toInt().toString()
            : value!.toStringAsFixed(1))
        : '—';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          valueStr,
          style: AppTextStyles.h2.copyWith(color: accentColor),
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: AppDimens.spaceXs),
          Text(
            unit,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

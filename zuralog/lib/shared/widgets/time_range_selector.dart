/// Zuralog — TimeRangeSelector widget.
///
/// Segmented control for selecting a chart time range.
/// Options: 7D / 30D / 90D / Custom.
///
/// ## Design spec
/// - Background: `surface-500` equivalent (dark surface)
/// - Active segment: sage-green indicator with `primaryButtonText` label
/// - Inactive: `textSecondary` label
/// - Height: 36px; full-width within its container
/// - Border radius: 10
///
/// ## Usage
/// ```dart
/// TimeRangeSelector(
///   value: TimeRange.days7,
///   onChanged: (range) => setState(() => _range = range),
/// )
/// ```
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── TimeRange ─────────────────────────────────────────────────────────────────

/// Available time range options for charts and analytics.
enum TimeRange {
  /// Last 7 days.
  days7('7D'),

  /// Last 30 days.
  days30('30D'),

  /// Last 90 days.
  days90('90D'),

  /// Custom date range (opens date picker when selected).
  custom('Custom');

  const TimeRange(this.label);

  /// Short display label for the segment control.
  final String label;
}

// ── TimeRangeSelector ─────────────────────────────────────────────────────────

/// Segmented control for picking a chart time range.
class TimeRangeSelector extends StatelessWidget {
  /// Creates a [TimeRangeSelector].
  ///
  /// [value] — currently selected range.
  /// [onChanged] — called with the new [TimeRange] when the user taps a segment.
  /// [options] — subset of ranges to show. Defaults to all four.
  /// [customDateRange] — the active custom range, shown when [value] is custom.
  /// [onCustomRangePicked] — called with the picked [DateTimeRange] when the
  ///   user confirms a date range in the date picker.
  const TimeRangeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.options = TimeRange.values,
    this.customDateRange,
    this.onCustomRangePicked,
  });

  /// Currently selected time range.
  final TimeRange value;

  /// Callback invoked when the selection changes.
  final ValueChanged<TimeRange> onChanged;

  /// Ordered list of ranges to display. Defaults to all four.
  final List<TimeRange> options;

  /// The currently active custom date range. Used to pre-populate the picker.
  final DateTimeRange? customDateRange;

  /// Called when the user picks a custom date range. If null, the Custom
  /// segment simply fires [onChanged] without opening a picker.
  final ValueChanged<DateTimeRange>? onCustomRangePicked;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF2C2C2E) : AppColors.secondaryButtonLight;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final range in options)
            _Segment(
              range: range,
              isSelected: range == value,
              onTap: range == TimeRange.custom
                  ? () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: customDateRange,
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                              primary: colors.primary,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        onChanged(TimeRange.custom);
                        onCustomRangePicked?.call(picked);
                      }
                    }
                  : () => onChanged(range),
              isFirst: range == options.first,
              isLast: range == options.last,
            ),
        ],
      ),
    );
  }
}

// ── _Segment ──────────────────────────────────────────────────────────────────

class _Segment extends StatelessWidget {
  const _Segment({
    required this.range,
    required this.isSelected,
    required this.onTap,
    required this.isFirst,
    required this.isLast,
  });

  final TimeRange range;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final textColor = isSelected
        ? colors.textOnSage
        : Theme.of(context).colorScheme.onSurfaceVariant;

    final radius = BorderRadius.horizontal(
      left: isFirst ? const Radius.circular(10) : Radius.zero,
      right: isLast ? const Radius.circular(10) : Radius.zero,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: radius,
        ),
        child: Text(
          range.label,
          style: AppTextStyles.caption.copyWith(
            color: textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

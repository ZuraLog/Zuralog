/// Zuralog — Global Time Range Selector widget.
///
/// A horizontally scrollable segmented control for the data dashboard.
/// Chips: Today | 7D | 30D | 90D | Custom
///
/// - Tapping a non-custom option writes [dashboardTimeRangeProvider] directly.
/// - Tapping "Custom" shows a [showDateRangePicker]; on confirm, sets
///   [dashboardTimeRangeProvider] to [TimeRange.custom] and saves the chosen
///   range to [customDateRangeProvider].
/// - When the active range is [TimeRange.custom] and [customDateRangeProvider]
///   is non-null, the Custom chip label shows the range as "Mar 1–15".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/time_range.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';

// ── GlobalTimeRangeSelector ───────────────────────────────────────────────────

/// Horizontally scrollable segmented control for the dashboard time range.
class GlobalTimeRangeSelector extends ConsumerWidget {
  const GlobalTimeRangeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(dashboardTimeRangeProvider);
    final customRange = ref.watch(customDateRangeProvider);
    final colors = AppColorsOf(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Row(
        children: TimeRange.values.expand((range) {
          final isActive = selected == range;
          final label = _labelFor(range, customRange, selected);

          return [
            _RangeChip(
              label: label,
              isActive: isActive,
              colors: colors,
              onTap: () => _onTap(context, ref, range),
            ),
            const SizedBox(width: AppDimens.spaceSm),
          ];
        }).toList(),
      ),
    );
  }

  /// Returns the display label for [range].
  ///
  /// For [TimeRange.custom] when it is active and [customRange] is set,
  /// returns a compact "MMM d–d" string (e.g. "Mar 1–15").
  String _labelFor(
    TimeRange range,
    DateTimeRange? customRange,
    TimeRange selected,
  ) {
    if (range == TimeRange.custom &&
        selected == TimeRange.custom &&
        customRange != null) {
      return _formatCustomRange(customRange);
    }
    return range.label;
  }

  /// Formats a [DateTimeRange] as "Mar 1–15" or "Mar 1 – Apr 5".
  String _formatCustomRange(DateTimeRange range) {
    final start = range.start;
    final end = range.end;
    final startMonth = _monthAbbr(start.month);
    final endMonth = _monthAbbr(end.month);

    if (start.month == end.month && start.year == end.year) {
      return '$startMonth ${start.day}–${end.day}';
    }
    return '$startMonth ${start.day} – $endMonth ${end.day}';
  }

  String _monthAbbr(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    TimeRange range,
  ) async {
    if (range != TimeRange.custom) {
      ref.read(dashboardTimeRangeProvider.notifier).state = range;
      return;
    }

    // Show Flutter's built-in date range picker.
    final existing = ref.read(customDateRangeProvider);
    final now = DateTime.now();

    // ignore: use_build_context_synchronously
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: existing ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked != null) {
      ref.read(customDateRangeProvider.notifier).state = picked;
      ref.read(dashboardTimeRangeProvider.notifier).state = TimeRange.custom;
    }
  }
}

// ── _RangeChip ────────────────────────────────────────────────────────────────

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.isActive,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final AppColorsOf colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive ? colors.primary : Colors.transparent;
    final borderColor = isActive ? colors.primary : colors.border;
    final textColor = isActive ? Colors.white : colors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
          border: Border.all(color: borderColor, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: textColor,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

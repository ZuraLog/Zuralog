/// Zuralog Dashboard — Time Range Selector Widget.
///
/// A horizontal pill-shaped toggle bar that lets the user switch between the
/// five time windows defined in [TimeRange]. The selected pill is filled with
/// [AppColors.primary] (Sage Green); inactive pills are transparent with
/// [AppColors.textSecondary] text.
///
/// Also exports [selectedTimeRangeProvider], a Riverpod [StateProvider] that
/// holds the currently selected [TimeRange] across the dashboard screens.
/// Other files (data layer, detail screens) import this provider directly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// Global [StateProvider] that holds the currently active [TimeRange].
///
/// Defaults to [TimeRange.week]. Any widget in the app can read or write
/// this provider to observe or change the selected time window.
///
/// Example:
/// ```dart
/// final range = ref.watch(selectedTimeRangeProvider);
/// ref.read(selectedTimeRangeProvider.notifier).state = TimeRange.month;
/// ```
final StateProvider<TimeRange> selectedTimeRangeProvider =
    StateProvider<TimeRange>((ref) => TimeRange.week);

// ── Widget ────────────────────────────────────────────────────────────────────

/// A horizontal row of pill-shaped toggle buttons for selecting a [TimeRange].
///
/// Renders one pill per [TimeRange] value (D / W / M / 6M / Y). The active
/// pill is filled with [AppColors.primary]; inactive pills are transparent.
///
/// Reads and writes [selectedTimeRangeProvider] via Riverpod.
///
/// Example:
/// ```dart
/// const TimeRangeSelector()
/// ```
class TimeRangeSelector extends ConsumerWidget {
  /// Creates a [TimeRangeSelector].
  const TimeRangeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTimeRangeProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: TimeRange.values.map((range) {
        return _TimeRangePill(
          range: range,
          isSelected: range == selected,
          onTap: () =>
              ref.read(selectedTimeRangeProvider.notifier).state = range,
        );
      }).toList(),
    );
  }
}

// ── Private pill widget ───────────────────────────────────────────────────────

/// A single pill button representing one [TimeRange] value.
///
/// [isSelected] controls whether the pill is filled or transparent.
/// [onTap] is called when the user taps the pill.
class _TimeRangePill extends StatelessWidget {
  const _TimeRangePill({
    required this.range,
    required this.isSelected,
    required this.onTap,
  });

  /// The time range this pill represents.
  final TimeRange range;

  /// Whether this pill is the currently active selection.
  final bool isSelected;

  /// Callback invoked when the pill is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(minWidth: AppDimens.touchTargetMin),
        height: AppDimens.touchTargetMin,
        margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceXs / 2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusButton),
        ),
        child: Center(
          child: Text(
            range.label,
            style: AppTextStyles.caption.copyWith(
              color: isSelected
                  ? AppColors.primaryButtonText
                  : AppColors.textSecondary,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

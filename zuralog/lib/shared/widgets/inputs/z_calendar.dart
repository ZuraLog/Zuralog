/// Zuralog Design System — Calendar Date Picker Component.
///
/// A self-contained month calendar for picking a single date.
/// Shows a grid of days for the displayed month with left/right arrows
/// to navigate between months. Follows the Brand Bible color spec.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// Month calendar date picker.
///
/// Displays a single month grid with navigation arrows. Tap a day to
/// select it. Days outside the `firstDate`–`lastDate` range are disabled.
///
/// ```dart
/// ZCalendar(
///   selectedDate: _picked,
///   onDateSelected: (date) => setState(() => _picked = date),
/// )
/// ```
class ZCalendar extends StatefulWidget {
  const ZCalendar({
    super.key,
    this.selectedDate,
    this.onDateSelected,
    this.initialMonth,
    this.firstDate,
    this.lastDate,
  });

  /// The currently selected date (highlighted with Sage fill).
  final DateTime? selectedDate;

  /// Called when the user taps a selectable day.
  final ValueChanged<DateTime>? onDateSelected;

  /// Which month to show initially. Defaults to [selectedDate] or today.
  final DateTime? initialMonth;

  /// Earliest selectable date. Days before this are disabled.
  final DateTime? firstDate;

  /// Latest selectable date. Days after this are disabled.
  final DateTime? lastDate;

  @override
  State<ZCalendar> createState() => _ZCalendarState();
}

class _ZCalendarState extends State<ZCalendar> {
  late DateTime _displayedMonth;

  // ── Day-of-week headers starting Monday ──────────────────────────────────
  static const List<String> _weekLabels = [
    'Mo',
    'Tu',
    'We',
    'Th',
    'Fr',
    'Sa',
    'Su',
  ];

  // ── Sizing ───────────────────────────────────────────────────────────────
  static const double _daySize = 36;
  static const double _touchTarget = 44;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialMonth ?? widget.selectedDate ?? DateTime.now();
    _displayedMonth = DateTime(seed.year, seed.month);
  }

  @override
  void didUpdateWidget(ZCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the caller changes initialMonth explicitly, jump to it.
    if (widget.initialMonth != null &&
        oldWidget.initialMonth != widget.initialMonth) {
      final m = widget.initialMonth!;
      setState(() => _displayedMonth = DateTime(m.year, m.month));
    }
  }

  // ── Month navigation ────────────────────────────────────────────────────

  bool get _canGoBack {
    if (widget.firstDate == null) return true;
    final first = widget.firstDate!;
    return _displayedMonth.year > first.year ||
        (_displayedMonth.year == first.year &&
            _displayedMonth.month > first.month);
  }

  bool get _canGoForward {
    if (widget.lastDate == null) return true;
    final last = widget.lastDate!;
    return _displayedMonth.year < last.year ||
        (_displayedMonth.year == last.year &&
            _displayedMonth.month < last.month);
  }

  void _previousMonth() {
    if (!_canGoBack) return;
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
      );
    });
  }

  void _nextMonth() {
    if (!_canGoForward) return;
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
      );
    });
  }

  // ── Date helpers ─────────────────────────────────────────────────────────

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime date) => _isSameDay(date, DateTime.now());

  bool _isSelected(DateTime date) =>
      widget.selectedDate != null && _isSameDay(date, widget.selectedDate!);

  bool _isInDisplayedMonth(DateTime date) =>
      date.year == _displayedMonth.year &&
      date.month == _displayedMonth.month;

  bool _isEnabled(DateTime date) {
    if (widget.firstDate != null) {
      final first = widget.firstDate!;
      final firstDay = DateTime(first.year, first.month, first.day);
      if (date.isBefore(firstDay)) return false;
    }
    if (widget.lastDate != null) {
      final last = widget.lastDate!;
      final lastDay = DateTime(last.year, last.month, last.day);
      if (date.isAfter(lastDay)) return false;
    }
    return true;
  }

  // ── Build the 6-row × 7-col grid of dates ──────────────────────────────

  List<DateTime> _buildDayGrid() {
    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month);
    // Monday = 1, Sunday = 7. We want Monday in column 0.
    final leadingBlanks = (firstOfMonth.weekday - DateTime.monday) % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: leadingBlanks));

    // Always show 6 rows (42 cells) so the widget height is stable.
    return List.generate(42, (i) => gridStart.add(Duration(days: i)));
  }

  // ── Month name ──────────────────────────────────────────────────────────

  String get _monthYearLabel {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[_displayedMonth.month - 1]} ${_displayedMonth.year}';
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final days = _buildDayGrid();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeLg),
      ),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: AnimatedSwitcher(
        duration: AppMotion.durationMedium,
        switchInCurve: AppMotion.curveEntrance,
        switchOutCurve: AppMotion.curveExit,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: Column(
          key: ValueKey<DateTime>(_displayedMonth),
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(colors),
            const SizedBox(height: AppDimens.spaceSm),
            _buildWeekdayRow(colors),
            const SizedBox(height: AppDimens.spaceXs),
            _buildDayGrid42(days, colors),
          ],
        ),
      ),
    );
  }

  // ── Header row: ← March 2026 → ─────────────────────────────────────────

  Widget _buildHeader(AppColorsOf colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _NavArrow(
          icon: Icons.chevron_left_rounded,
          enabled: _canGoBack,
          onTap: _previousMonth,
          semanticLabel: 'Previous month',
          colors: colors,
        ),
        Text(
          _monthYearLabel,
          style: AppTextStyles.titleMedium.copyWith(
            color: colors.textPrimary,
          ),
        ),
        _NavArrow(
          icon: Icons.chevron_right_rounded,
          enabled: _canGoForward,
          onTap: _nextMonth,
          semanticLabel: 'Next month',
          colors: colors,
        ),
      ],
    );
  }

  // ── Weekday labels row ──────────────────────────────────────────────────

  Widget _buildWeekdayRow(AppColorsOf colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: _weekLabels.map((label) {
        return SizedBox(
          width: _touchTarget,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── 6×7 day grid ───────────────────────────────────────────────────────

  Widget _buildDayGrid42(List<DateTime> days, AppColorsOf colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (col) {
            final date = days[row * 7 + col];
            return _buildDayCell(date, colors);
          }),
        );
      }),
    );
  }

  // ── Individual day cell ─────────────────────────────────────────────────

  Widget _buildDayCell(DateTime date, AppColorsOf colors) {
    final inMonth = _isInDisplayedMonth(date);
    final enabled = _isEnabled(date);
    final selected = _isSelected(date);
    final today = _isToday(date);

    // Determine visual style.
    Color? fillColor;
    Color textColor;
    Border? border;

    if (selected) {
      fillColor = AppColors.primary;
      textColor = AppColors.textOnSage;
    } else if (today && inMonth) {
      border = Border.all(color: AppColors.primary, width: 2);
      textColor = colors.textPrimary;
    } else if (!inMonth) {
      textColor = colors.textPrimary.withValues(alpha: 0.3);
    } else if (!enabled) {
      textColor = colors.textPrimary.withValues(alpha: 0.4);
    } else {
      textColor = colors.textPrimary;
    }

    final bool tappable = inMonth && enabled;

    // Semantic label like "March 15" or "March 15, selected".
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final semanticDate = '${monthNames[date.month - 1]} ${date.day}';
    final semanticSuffix = selected ? ', selected' : '';

    return Semantics(
      label: '$semanticDate$semanticSuffix',
      button: tappable,
      selected: selected,
      child: GestureDetector(
        onTap: tappable
            ? () => widget.onDateSelected?.call(
                  DateTime(date.year, date.month, date.day),
                )
            : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _touchTarget,
          height: _touchTarget,
          child: Center(
            child: Container(
              width: _daySize,
              height: _daySize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fillColor,
                border: border,
              ),
              alignment: Alignment.center,
              child: Text(
                '${date.day}',
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Navigation arrow button ───────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.semanticLabel,
    required this.colors,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String semanticLabel;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? AppColors.primary
        : colors.textPrimary.withValues(alpha: 0.3);

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: AppDimens.touchTargetMin,
          height: AppDimens.touchTargetMin,
          child: Icon(icon, color: color, size: AppDimens.iconMd),
        ),
      ),
    );
  }
}

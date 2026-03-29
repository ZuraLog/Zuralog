library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zuralog/core/theme/theme.dart';

/// Tooltip card shown during chart scrubbing and bar/segment taps.
///
/// Displays [date] + [value] (formatted) on a Surface Raised background.
/// When [comparisonValue] is provided, adds a second row for the previous period.
class ZChartTooltip extends StatelessWidget {
  const ZChartTooltip({
    super.key,
    required this.value,
    required this.unit,
    this.date,
    this.comparisonValue,
    this.label,
  });

  /// Primary data value (current period).
  final double value;

  /// Unit string appended to value (e.g. "steps", "bpm").
  final String unit;

  /// Point date — shown as "Mon, Mar 24". Null for bar/segment taps.
  final DateTime? date;

  /// Previous-period value for comparison mode. Null when not comparing.
  final double? comparisonValue;

  /// Override label for segment/zone tap (replaces value formatting).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Semantics(
      label: _buildSemanticLabel(),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (date != null)
              Text(
                DateFormat('EEE, MMM d').format(date!),
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textPrimary.withValues(alpha: 0.6),
                ),
              ),
            if (date != null) const SizedBox(height: 2),
            if (label != null)
              Text(
                label!,
                style: AppTextStyles.labelMedium.copyWith(
                  color: colors.textPrimary,
                ),
              )
            else
              Text(
                '${_formatValue(value)} $unit',
                style: AppTextStyles.labelMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            if (comparisonValue != null) ...[
              const SizedBox(height: 4),
              Text(
                '${_formatValue(comparisonValue!)} $unit  (prev)',
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textPrimary.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildSemanticLabel() {
    final datePart = date != null ? DateFormat('EEEE, MMMM d').format(date!) : '';
    final valuePart = label ?? '${_formatValue(value)} $unit';
    final parts = [if (datePart.isNotEmpty) datePart, valuePart];
    if (comparisonValue != null) parts.add('Previous: ${_formatValue(comparisonValue!)} $unit');
    return parts.join(': ');
  }

  static String _formatValue(double v) {
    if (!v.isFinite) return '—';
    if (v >= 1000) {
      return NumberFormat('#,###').format(v.round());
    }
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(1);
  }
}

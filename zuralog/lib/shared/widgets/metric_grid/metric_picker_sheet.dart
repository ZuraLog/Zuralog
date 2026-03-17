/// Zuralog — Metric Picker Sheet.
///
/// A scrollable bottom sheet listing all metrics Zuralog can track, grouped
/// by health category. Used to add metrics to the Today tab's pinned grid.
///
/// Metrics that are already pinned are shown with a checkmark and are not
/// selectable. Tapping a new metric calls [onSelect] with its type string.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── Metric catalogue ──────────────────────────────────────────────────────────

/// All metrics available for pinning, grouped by category.
const _kMetricCatalogue = <_MetricCategory>[
  _MetricCategory(
    name: 'Wellness',
    color: AppColors.categoryWellness,
    metrics: [
      _MetricEntry(type: 'mood',   label: 'Mood',   emoji: '😊'),
      _MetricEntry(type: 'energy', label: 'Energy', emoji: '⚡'),
      _MetricEntry(type: 'stress', label: 'Stress', emoji: '😤'),
    ],
  ),
  _MetricCategory(
    name: 'Body',
    color: AppColors.categoryBody,
    metrics: [
      _MetricEntry(type: 'weight', label: 'Weight', emoji: '⚖️'),
      _MetricEntry(type: 'water',  label: 'Water',  emoji: '💧'),
    ],
  ),
  _MetricCategory(
    name: 'Activity',
    color: AppColors.categoryActivity,
    metrics: [
      _MetricEntry(type: 'steps', label: 'Steps', emoji: '👣'),
      _MetricEntry(type: 'run',   label: 'Run',   emoji: '🏃'),
    ],
  ),
  _MetricCategory(
    name: 'Sleep',
    color: AppColors.categorySleep,
    metrics: [
      _MetricEntry(type: 'sleep', label: 'Sleep', emoji: '😴'),
    ],
  ),
  _MetricCategory(
    name: 'Nutrition',
    color: AppColors.categoryNutrition,
    metrics: [
      _MetricEntry(type: 'meal', label: 'Calories', emoji: '🍽️'),
    ],
  ),
  _MetricCategory(
    name: 'Heart',
    color: AppColors.categoryHeart,
    metrics: [
      _MetricEntry(type: 'heart_rate', label: 'Heart Rate', emoji: '❤️'),
    ],
  ),
  _MetricCategory(
    name: 'Health',
    color: AppColors.categoryVitals,
    metrics: [
      _MetricEntry(type: 'supplement', label: 'Supplements', emoji: '💊'),
      _MetricEntry(type: 'symptom',    label: 'Symptom',     emoji: '🩹'),
    ],
  ),
];

// ── MetricPickerSheet ─────────────────────────────────────────────────────────

/// Shows all available metrics grouped by category for the user to pick from.
///
/// [pinnedTypes] — the set of metric type strings already pinned.
/// [onSelect]    — called with the [metricType] string when a new metric is tapped.
class MetricPickerSheet extends StatelessWidget {
  const MetricPickerSheet({
    super.key,
    required this.pinnedTypes,
    required this.onSelect,
  });

  final Set<String> pinnedTypes;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd, AppDimens.spaceLg,
        AppDimens.spaceMd, AppDimens.spaceXxl,
      ),
      children: [
        // Sheet handle
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppDimens.spaceLg),
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text(
          'Add a metric',
          style: AppTextStyles.titleLarge.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppDimens.spaceLg),

        for (final category in _kMetricCatalogue) ...[
          // Category header with colour accent
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: category.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Text(
                  category.name,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          // Metric rows
          for (final metric in category.metrics)
            _MetricRow(
              metric: metric,
              isPinned: pinnedTypes.contains(metric.type),
              categoryColor: category.color,
              onTap: pinnedTypes.contains(metric.type)
                  ? null
                  : () => onSelect(metric.type),
            ),

          const SizedBox(height: AppDimens.spaceLg),
        ],
      ],
    );
  }
}

// ── _MetricRow ────────────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.metric,
    required this.isPinned,
    required this.categoryColor,
    required this.onTap,
  });

  final _MetricEntry metric;
  final bool isPinned;
  final Color categoryColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isPinned ? 0.45 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppDimens.spaceXs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimens.shapeSm),
          ),
          child: Row(
            children: [
              Text(metric.emoji, style: TextStyle(fontSize: AppDimens.emojiSm)),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Text(
                  metric.label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (isPinned)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: AppDimens.iconSm,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Internal data types ───────────────────────────────────────────────────────

class _MetricCategory {
  const _MetricCategory({
    required this.name,
    required this.color,
    required this.metrics,
  });
  final String name;
  final Color color;
  final List<_MetricEntry> metrics;
}

class _MetricEntry {
  const _MetricEntry({
    required this.type,
    required this.label,
    required this.emoji,
  });
  final String type;
  final String label;
  final String emoji;
}

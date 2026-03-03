/// Zuralog — CategoryCard widget.
///
/// Health category summary card displayed on the Health Dashboard.
/// Shows the category name, primary metric value, 7-day sparkline trend,
/// and a delta indicator (week-over-week change).
///
/// In **edit mode** (drag-and-drop reorder) the card shows a drag handle and
/// a visibility toggle (eye icon) instead of the sparkline.
///
/// ## Design spec
/// - Category color accent: left border stripe (4px) in `AppColors.category*`
/// - `borderRadius: 20`, no border, no shadow — contrast via background
/// - Delta: green arrow up / red arrow down / grey dash for flat
/// - Compact height: ~88px
///
/// ## Usage
/// ```dart
/// CategoryCard(
///   category: HealthCategory.sleep,
///   title: 'Sleep',
///   primaryValue: '7h 22m',
///   deltaPercent: 8.5,
///   trend: [6.5, 7.0, 7.2, 6.8, 7.5, 7.1, 7.4],
///   onTap: () => context.push('/data/category/sleep'),
/// )
/// ```
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── CategoryCard ──────────────────────────────────────────────────────────────

/// A health category summary card with sparkline and delta indicator.
class CategoryCard extends StatelessWidget {
  /// Creates a [CategoryCard].
  const CategoryCard({
    super.key,
    required this.title,
    required this.categoryColor,
    this.primaryValue,
    this.unit,
    this.deltaPercent,
    this.trend,
    this.isVisible = true,
    this.isEditMode = false,
    this.onTap,
    this.onVisibilityToggle,
  });

  /// Category display name (e.g. "Sleep", "Activity").
  final String title;

  /// Category accent color from `AppColors.category*`.
  final Color categoryColor;

  /// Primary metric value string (e.g. "7h 22m", "8,432").
  final String? primaryValue;

  /// Unit label shown after [primaryValue] (e.g. "steps", "bpm").
  final String? unit;

  /// Week-over-week delta as a percentage. Positive = up, negative = down.
  final double? deltaPercent;

  /// 7-day trend values for the sparkline (oldest first).
  final List<double>? trend;

  /// Whether this category is shown on the dashboard (used in edit mode).
  final bool isVisible;

  /// When `true` shows drag handle + visibility toggle instead of sparkline.
  final bool isEditMode;

  /// Tap callback — navigates to Category Detail.
  final VoidCallback? onTap;

  /// Visibility toggle callback — shown only in edit mode.
  final VoidCallback? onVisibilityToggle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    Widget card = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category color accent stripe
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm + 2,
              ),
              child: Row(
                children: [
                  // Text info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.caption.copyWith(
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (primaryValue != null)
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: primaryValue!,
                                  style: AppTextStyles.h3.copyWith(
                                    color: textPrimary,
                                  ),
                                ),
                                if (unit != null)
                                  TextSpan(
                                    text: ' $unit',
                                    style: AppTextStyles.caption.copyWith(
                                      color: textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (deltaPercent != null) ...[
                          const SizedBox(height: 2),
                          _DeltaIndicator(deltaPercent: deltaPercent!),
                        ],
                      ],
                    ),
                  ),

                  // Edit mode controls OR sparkline
                  if (isEditMode)
                    _EditModeControls(
                      isVisible: isVisible,
                      categoryColor: categoryColor,
                      onVisibilityToggle: onVisibilityToggle,
                    )
                  else if (trend != null && trend!.length >= 2)
                    _MiniSparkline(
                      values: trend!,
                      color: categoryColor,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!isEditMode && onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }

    return card;
  }
}

// ── _DeltaIndicator ───────────────────────────────────────────────────────────

class _DeltaIndicator extends StatelessWidget {
  const _DeltaIndicator({required this.deltaPercent});
  final double deltaPercent;

  @override
  Widget build(BuildContext context) {
    final isUp = deltaPercent > 0;
    final isFlat = deltaPercent == 0;
    final color = isFlat
        ? AppColors.textTertiary
        : isUp
            ? AppColors.healthScoreGreen
            : AppColors.healthScoreRed;
    final icon = isFlat
        ? Icons.remove_rounded
        : isUp
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;
    final label = isFlat
        ? '0%'
        : '${isUp ? '+' : ''}${deltaPercent.toStringAsFixed(1)}%';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ── _EditModeControls ─────────────────────────────────────────────────────────

class _EditModeControls extends StatelessWidget {
  const _EditModeControls({
    required this.isVisible,
    required this.categoryColor,
    this.onVisibilityToggle,
  });

  final bool isVisible;
  final Color categoryColor;
  final VoidCallback? onVisibilityToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onVisibilityToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              size: AppDimens.iconSm,
              color: isVisible ? categoryColor : AppColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Drag handle
        Icon(
          Icons.drag_handle_rounded,
          size: AppDimens.iconSm,
          color: AppColors.textTertiary,
        ),
      ],
    );
  }
}

// ── _MiniSparkline ────────────────────────────────────────────────────────────

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final minY = values.reduce(math.min) - 1;
    final maxY = values.reduce(math.max) + 1;

    return SizedBox(
      width: 56,
      height: 36,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

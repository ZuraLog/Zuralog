/// Zuralog — Time Period Card.
///
/// A compact card showing a weekly health summary: date range, overall health
/// score ring, and up to 3 metric highlights with delta indicators.
/// Used inside the Time Machine horizontal scroll strip on the Trends tab.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/trends/domain/trends_models.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// A fixed-width card displaying a single week's health summary.
class TimePeriodCard extends StatelessWidget {
  const TimePeriodCard({super.key, required this.summary});

  /// The period data to display.
  final TimePeriodSummary summary;

  /// Card width in logical pixels.
  static const double _cardWidth = 160.0;

  /// Inner padding of the card.
  static const double _cardPadding = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final scoreFraction = summary.overallScore / 100;

    return Container(
      width: _cardWidth,
      padding: const EdgeInsets.all(_cardPadding),
      decoration: BoxDecoration(
        color: colors.trendsSurface,
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
        border: Border.all(color: colors.trendsBorderDefault),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Week label
          Text(
            summary.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.trendsTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimens.spaceSm),

          // Health score ring with overlaid number
          Semantics(
            label: 'Health score ${summary.overallScore} out of 100',
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ZCircularProgress(
                    value: scoreFraction,
                    size: 56,
                    strokeWidth: 4,
                    color: _scoreColor(summary.overallScore),
                  ),
                  Text(
                    '${summary.overallScore}',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.trendsTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),

          // Metric highlights (up to 3)
          for (final metric in summary.highlights.take(3))
            _MetricRow(metric: metric),
        ],
      ),
    );
  }

  /// Pick a ring color based on the score value.
  static Color _scoreColor(int score) {
    if (score >= 70) return AppColors.categoryActivity;
    if (score >= 40) return AppColors.categoryNutrition;
    return AppColors.error;
  }
}

// ── _MetricRow ────────────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric});

  final MetricHighlight metric;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final delta = metric.deltaPercent;
    final isZero = delta == 0;
    final isPositive = delta > 0;

    final Color deltaColor;
    final String deltaText;
    if (isZero) {
      deltaColor = colors.trendsTextMuted;
      deltaText = '0%';
    } else {
      deltaColor = isPositive ? AppColors.categoryActivity : AppColors.error;
      final sign = isPositive ? '+' : '';
      deltaText = '$sign${delta.toStringAsFixed(0)}%';
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.spaceXs),
      child: Semantics(
        label: '${metric.label}: ${metric.value} ${metric.unit}, $deltaText',
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.trendsTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${metric.value} ${metric.unit}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.trendsTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spaceXs),
            Text(
              deltaText,
              style: AppTextStyles.labelSmall.copyWith(
                color: deltaColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

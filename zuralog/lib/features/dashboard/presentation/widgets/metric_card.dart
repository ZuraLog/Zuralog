/// Zuralog Dashboard — Metric Card Widget.
///
/// A bento-grid card for individual health metrics.  Renders an icon,
/// a large value + unit, a title, a trend direction indicator, and a
/// [TrendSparkline] chart at the bottom.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/trend_sparkline.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Widget ────────────────────────────────────────────────────────────────────

/// A bento-grid card displaying a single health metric.
///
/// Shows an accent-coloured icon badge, the metric [value] and [unit] in a
/// large font, the metric [title] in a muted caption, a trend direction arrow,
/// and a [TrendSparkline] chart built from [trendData].
///
/// Example:
/// ```dart
/// MetricCard(
///   title: 'Sleep',
///   value: '7.5',
///   unit: 'hrs',
///   icon: Icons.bedtime_rounded,
///   accentColor: AppColors.secondaryLight,
///   trendData: [6.5, 7.0, 8.0, 7.5, 6.8, 7.2, 7.5],
/// )
/// ```
class MetricCard extends StatelessWidget {
  /// Creates a [MetricCard].
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accentColor,
    required this.trendData,
    this.onTap,
  });

  /// Metric title displayed below the value (e.g., "Sleep").
  final String title;

  /// Formatted metric value string (e.g., "7.5", "8,432").
  final String value;

  /// Unit abbreviation (e.g., "hrs", "steps", "kcal").
  final String unit;

  /// Material icon representing this metric.
  final IconData icon;

  /// Accent colour applied to the icon badge, trend arrow, and sparkline.
  final Color accentColor;

  /// Seven-day trend data passed to [TrendSparkline].
  ///
  /// A minimum of 2 entries is required to render the sparkline.
  final List<double> trendData;

  /// Optional tap callback.
  final VoidCallback? onTap;

  // ── Trend thresholds ─────────────────────────────────────────────────────

  /// Relative change required to consider a trend "up" or "down".
  ///
  /// Changes within ±[_trendThreshold] of the initial value are treated as flat.
  static const double _trendThreshold = 0.02;

  // ── Trend icon helpers ────────────────────────────────────────────────────

  /// Returns the trend [IconData] based on the first and last values in [data].
  ///
  /// Returns null when [data] has fewer than 2 points.
  static IconData? _trendIcon(List<double> data) {
    if (data.length < 2) return null;
    final first = data.first;
    final last = data.last;
    if (first == 0) return Icons.trending_flat;
    final change = (last - first) / first;
    if (change > _trendThreshold) return Icons.trending_up;
    if (change < -_trendThreshold) return Icons.trending_down;
    return Icons.trending_flat;
  }

  /// Returns the colour for the trend arrow icon.
  static Color _trendColor(IconData? icon) {
    if (icon == Icons.trending_up) return const Color(0xFF34C759); // iOS green
    if (icon == Icons.trending_down) return const Color(0xFFFF3B30); // iOS red
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trend = _trendIcon(trendData);

    return ZuralogCard(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Icon row + trend arrow ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Tinted icon badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Icon(icon, color: accentColor, size: AppDimens.iconSm),
              ),
              const Spacer(),
              // Trend direction indicator
              if (trend != null)
                Icon(trend, color: _trendColor(trend), size: AppDimens.iconSm),
            ],
          ),

          const SizedBox(height: AppDimens.spaceSm),

          // ── Value ─────────────────────────────────────────────────────
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),

          // ── Unit ──────────────────────────────────────────────────────
          Text(
            unit,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimens.spaceXs),

          // ── Title ─────────────────────────────────────────────────────
          Text(
            title,
            style: AppTextStyles.h3.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),

          const SizedBox(height: AppDimens.spaceSm),

          // ── Sparkline ─────────────────────────────────────────────────
          TrendSparkline(
            dataPoints: trendData,
            color: accentColor,
            height: 36,
          ),
        ],
      ),
    );
  }
}

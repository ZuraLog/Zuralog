/// Zuralog Design System — Chart Container & Tooltip.
///
/// [ZChartContainer] provides consistent theming for any chart widget.
/// It wraps the child in a branded surface with optional title and subtitle.
///
/// [ZChartTooltip] is a standalone tooltip widget for use inside chart
/// overlays (e.g. fl_chart touch callbacks).
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

// ─── Chart Color Palette ─────────────────────────────────────────────────────

/// Standard chart color palette matching health categories.
///
/// Keys are lowercase category names. Values come from [AppColors.category*]
/// tokens. Use these when assigning series colors so every chart stays
/// visually consistent across the app.
const Map<String, Color> kChartColors = {
  'activity': AppColors.categoryActivity,
  'sleep': AppColors.categorySleep,
  'heart': AppColors.categoryHeart,
  'nutrition': AppColors.categoryNutrition,
  'body': AppColors.categoryBody,
  'vitals': AppColors.categoryVitals,
  'wellness': AppColors.categoryWellness,
  'cycle': AppColors.categoryCycle,
  'mobility': AppColors.categoryMobility,
  'environment': AppColors.categoryEnvironment,
  'primary': AppColors.primary,
};

// ─── ZChartContainer ─────────────────────────────────────────────────────────

/// A themed wrapper that gives any chart a consistent surface, padding,
/// optional title/subtitle, and a fixed aspect ratio.
///
/// Pass your chart widget (fl_chart, custom painter, etc.) as [child].
///
/// ```dart
/// ZChartContainer(
///   title: 'Steps This Week',
///   subtitle: 'Daily average: 8,421',
///   child: LineChart(data),
/// )
/// ```
class ZChartContainer extends StatelessWidget {
  const ZChartContainer({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.aspectRatio = 16 / 9,
    this.padding,
  });

  /// The chart widget to display inside the container.
  final Widget child;

  /// Optional heading shown above the chart area.
  final String? title;

  /// Optional secondary line shown below the title.
  final String? subtitle;

  /// Width-to-height ratio constraint for the chart area.
  ///
  /// Defaults to 16:9. Pass `null` to let the child size itself freely.
  final double? aspectRatio;

  /// Inner padding. Defaults to 16px on all sides ([AppDimens.spaceMd]).
  final EdgeInsetsGeometry? padding;

  /// Convenience accessor for the standard chart color palette.
  static const Map<String, Color> chartColors = kChartColors;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final effectivePadding =
        padding ?? const EdgeInsets.all(AppDimens.spaceMd);

    // Build the chart area — optionally constrained by aspect ratio.
    Widget chartArea = child;
    if (aspectRatio != null) {
      chartArea = AspectRatio(
        aspectRatio: aspectRatio!,
        child: child,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeLg),
      ),
      child: Padding(
        padding: effectivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spaceXs),
                  child: Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: AppDimens.spaceSm),
            ],
            chartArea,
          ],
        ),
      ),
    );
  }
}

// ─── ZChartTooltip ───────────────────────────────────────────────────────────

/// A single row inside a [ZChartTooltip].
class ZChartTooltipEntry {
  /// Creates a tooltip entry with a colored dot, label, and value.
  const ZChartTooltipEntry({
    required this.color,
    required this.name,
    required this.value,
  });

  /// Dot color shown at the leading edge of this row.
  final Color color;

  /// Series or category name (e.g. "Steps").
  final String name;

  /// Formatted value string (e.g. "8,421").
  final String value;
}

/// A branded tooltip widget for use inside chart touch overlays.
///
/// Shows an optional top label and one or more [ZChartTooltipEntry] rows,
/// each with a colored indicator dot, a name, and a right-aligned value.
///
/// ```dart
/// ZChartTooltip(
///   label: 'Mon 24 Mar',
///   entries: [
///     ZChartTooltipEntry(color: kChartColors['activity']!, name: 'Steps', value: '8,421'),
///   ],
/// )
/// ```
class ZChartTooltip extends StatelessWidget {
  const ZChartTooltip({
    super.key,
    required this.entries,
    this.label,
  });

  /// Optional header label (e.g. a date or time).
  final String? label;

  /// One row per data series shown in the tooltip.
  final List<ZChartTooltipEntry> entries;

  static const double _dotSize = 8;
  static const double _minValueWidth = 48;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final labelStyle = AppTextStyles.labelSmall.copyWith(
      color: colors.textSecondary,
    );
    final nameStyle = AppTextStyles.labelSmall.copyWith(
      color: colors.textSecondary,
    );
    final valueStyle = AppTextStyles.labelSmall.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w600,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDimens.shapeXs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null) ...[
                Text(label!, style: labelStyle),
                const SizedBox(height: AppDimens.spaceXs),
              ],
              for (int i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: AppDimens.spaceXxs),
                _buildEntryRow(entries[i], nameStyle, valueStyle),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryRow(
    ZChartTooltipEntry entry,
    TextStyle nameStyle,
    TextStyle valueStyle,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Colored indicator dot.
        Container(
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(
            color: entry.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        // Series name.
        Flexible(child: Text(entry.name, style: nameStyle)),
        const SizedBox(width: AppDimens.spaceMd),
        // Right-aligned value.
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: _minValueWidth),
          child: Text(
            entry.value,
            style: valueStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// Zuralog Dashboard — Category Card Widget.
///
/// A dashboard hub card representing a single [HealthCategory]. Displays a
/// coloured icon badge, the category display name, up to four inline metric
/// preview rows, and an optional miniature graph at the bottom.
///
/// Light mode: white surface with a soft diffusion shadow (via [ZuralogCard]).
/// Dark mode: dark surface with a 1px border stroke (via [ZuralogCard]).
///
/// Also defines [MetricPreview], a lightweight value class for the inline
/// metric preview rows.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/dashboard/domain/health_category.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── MetricPreview value class ─────────────────────────────────────────────────

/// A lightweight snapshot of a single metric value for inline display.
///
/// Used inside [CategoryCard] to render a compact row of the form:
/// "{label}: {value} {unit}".
///
/// Example:
/// ```dart
/// const MetricPreview(label: 'Steps', value: '8,432', unit: 'steps')
/// ```
class MetricPreview {
  /// Creates a [MetricPreview].
  ///
  /// All fields are required and must be non-null strings.
  const MetricPreview({
    required this.label,
    required this.value,
    required this.unit,
  });

  /// Human-readable metric label (e.g. `'Steps'`, `'Heart Rate'`).
  final String label;

  /// Formatted current value string (e.g. `'8,432'`, `'72'`).
  final String value;

  /// Unit abbreviation (e.g. `'steps'`, `'bpm'`).
  final String unit;
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// A dashboard hub card for a single [HealthCategory].
///
/// Renders:
/// - Top-left: a coloured icon badge (category icon on a semi-opaque
///   [accentColor] background).
/// - Category [displayName] as an H3 heading.
/// - 2–4 inline metric preview rows (label: value unit).
/// - Optional [miniGraph] widget at the bottom inside a 60px [SizedBox].
///
/// Tapping the card calls [onTap]; the parent screen handles navigation.
///
/// Corner radius is [AppDimens.radiusCard] (24px) via [ZuralogCard].
///
/// Example:
/// ```dart
/// CategoryCard(
///   category: HealthCategory.heart,
///   previews: [
///     MetricPreview(label: 'Heart Rate', value: '72', unit: 'bpm'),
///     MetricPreview(label: 'Resting HR', value: '58', unit: 'bpm'),
///   ],
///   miniGraph: mySparklineWidget,
///   onTap: () => navigateToHeartDetail(),
/// )
/// ```
class CategoryCard extends StatelessWidget {
  /// Creates a [CategoryCard].
  ///
  /// [category] — the [HealthCategory] this card represents.
  ///
  /// [previews] — 2–4 [MetricPreview] values shown as inline rows.
  ///   Passing more than 4 is allowed but only the first 4 are rendered.
  ///
  /// [miniGraph] — optional sparkline or mini-chart at the bottom of the card
  ///   (rendered inside a 60px [SizedBox]). Pass `null` to omit.
  ///
  /// [onTap] — called when the card is tapped; the parent screen navigates.
  const CategoryCard({
    super.key,
    required this.category,
    required this.previews,
    this.miniGraph,
    required this.onTap,
  });

  /// The health category this card represents.
  final HealthCategory category;

  /// Inline metric snapshot rows (2–4 recommended).
  final List<MetricPreview> previews;

  /// Optional miniature graph rendered at the bottom of the card.
  final Widget? miniGraph;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Limit previews to 4 to respect the 2-4 spec.
    final displayedPreviews =
        previews.length > 4 ? previews.sublist(0, 4) : previews;

    return ZuralogCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Icon badge + category name ─────────────────────────────────
          _CategoryHeader(category: category),
          const SizedBox(height: AppDimens.spaceMd),

          // ── Metric preview rows ────────────────────────────────────────
          ...displayedPreviews.map(
            (preview) => _MetricPreviewRow(
              preview: preview,
              accentColor: category.accentColor,
            ),
          ),

          // ── Optional mini graph ────────────────────────────────────────
          if (miniGraph != null) ...[
            const SizedBox(height: AppDimens.spaceSm),
            SizedBox(height: 60, child: miniGraph),
          ],
        ],
      ),
    );
  }
}

// ── Private sub-widgets ───────────────────────────────────────────────────────

/// Renders the category icon badge and display name in a horizontal row.
///
/// Icon badge: [HealthCategory.icon] centred inside a rounded square with
/// [HealthCategory.accentColor] at 20% opacity background. The icon glyph
/// uses [HealthCategory.accentColor] for a monochromatic treatment on the
/// tinted background.
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  /// The health category whose icon and name are displayed.
  final HealthCategory category;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Row(
      children: [
        _CategoryIconBadge(category: category),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: Text(
            category.displayName,
            style: AppTextStyles.h3.copyWith(color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A rounded-square icon badge for a [HealthCategory].
///
/// Background: [HealthCategory.accentColor] at 20% opacity.
/// Icon glyph: [HealthCategory.accentColor] at full opacity for a
/// monochromatic treatment on the tinted background.
class _CategoryIconBadge extends StatelessWidget {
  const _CategoryIconBadge({required this.category});

  /// The category providing [icon] and [accentColor].
  final HealthCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimens.iconMd + AppDimens.spaceMd,
      height: AppDimens.iconMd + AppDimens.spaceMd,
      decoration: BoxDecoration(
        color: category.accentColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Icon(
        category.icon,
        color: category.accentColor,
        size: AppDimens.iconMd,
      ),
    );
  }
}

/// A single inline row showing "{label}: {value} {unit}".
///
/// The label is rendered in [AppColors.textSecondary]; the value and unit
/// are rendered in the primary text colour. The value text is emphasised
/// with [FontWeight.w600].
class _MetricPreviewRow extends StatelessWidget {
  const _MetricPreviewRow({
    required this.preview,
    required this.accentColor,
  });

  /// The metric snapshot to render.
  final MetricPreview preview;

  /// Category accent colour (reserved for future use, e.g. value dots).
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
      child: Row(
        children: [
          Text(
            '${preview.label}: ',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            preview.value,
            style: AppTextStyles.caption.copyWith(
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            preview.unit,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

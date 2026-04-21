/// Shared hero metric card used at the top of every category-specific
/// insight body. A big serif Lora number, a delta badge vs last week,
/// and a quality pill on a category-tinted gradient surface.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class InsightHeroCard extends StatelessWidget {
  const InsightHeroCard({
    super.key,
    required this.eyebrow,
    required this.value,
    required this.categoryColor,
    required this.categoryIcon,
    this.deltaLabel,
    this.deltaIsPositive,
    this.qualityLabel,
  });

  /// Small tag above the number, e.g. "Last night".
  final String eyebrow;

  /// Formatted value to show big, e.g. "7h 24m" or "8,420 steps".
  final String value;

  /// Category color used for the eyebrow icon and gradient accent.
  final Color categoryColor;

  /// Icon shown next to the eyebrow.
  final IconData categoryIcon;

  /// Optional delta label, e.g. "+18m vs last week".
  final String? deltaLabel;

  /// Whether the delta should be rendered with the success tint (up) or
  /// the warning tint (down). Null means no delta badge.
  final bool? deltaIsPositive;

  /// Optional quality pill label, e.g. "Good", "Below goal".
  final String? qualityLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZFadeSlideIn(
      delay: const Duration(milliseconds: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.cardBackground,
                  categoryColor.withValues(alpha: 0.10),
                ],
              ),
              border: Border.all(
                color: categoryColor.withValues(alpha: 0.22),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            ),
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(categoryIcon, size: 18, color: categoryColor),
                    const SizedBox(width: AppDimens.spaceXs),
                    Text(
                      eyebrow,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  value,
                  style: GoogleFonts.lora(
                    textStyle: AppTextStyles.displayLarge.copyWith(
                      color: colors.textPrimary,
                      fontSize: 44,
                      height: 1.05,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (deltaLabel != null || qualityLabel != null) ...[
                  const SizedBox(height: AppDimens.spaceSm),
                  Row(
                    children: [
                      if (deltaLabel != null && deltaIsPositive != null)
                        _DeltaBadge(
                          label: deltaLabel!,
                          isPositive: deltaIsPositive!,
                        ),
                      if (deltaLabel != null && qualityLabel != null)
                        const SizedBox(width: AppDimens.spaceSm),
                      if (qualityLabel != null)
                        _QualityPill(
                          label: qualityLabel!,
                          color: colors.primary,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.label, required this.isPositive});
  final String label;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityPill extends StatelessWidget {
  const _QualityPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

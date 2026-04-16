/// Zuralog Design System — Pillar Card Component.
///
/// Shared base layout for the four health pillar cards on the Today tab.
/// Renders a category-tinted icon container, label, headline stat, and
/// secondary stats in a single compact row inside a feature-variant card.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

/// A single secondary stat displayed on the right side of a [ZPillarCard].
class PillarStat {
  const PillarStat({required this.label, required this.value});
  final String label;
  final String value;
}

/// Compact pillar card used on the Today tab to summarise a health domain.
///
/// Wraps its content in [ZuralogCard] with [ZCardVariant.feature] and the
/// matching [category] color so the card gets the correct brand pattern.
///
/// [bottomChild] is an optional widget rendered below the main row — used
/// by the Nutrition card to show a meal-chips row.
class ZPillarCard extends StatelessWidget {
  const ZPillarCard({
    super.key,
    required this.icon,
    required this.categoryColor,
    required this.label,
    required this.headline,
    this.headlineUnit,
    this.contextStat,
    this.secondaryStats = const [],
    this.bottomChild,
    this.onTap,
  });

  final IconData icon;
  final Color categoryColor;
  final String label;
  final String headline;
  final String? headlineUnit;
  final String? contextStat;
  final List<PillarStat> secondaryStats;
  final Widget? bottomChild;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: categoryColor,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: AppDimens.iconContainerMd,
                height: AppDimens.iconContainerMd,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: AppDimens.iconMd,
                    color: categoryColor,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          label.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: categoryColor,
                          ),
                        ),
                        if (contextStat != null) ...[
                          const SizedBox(width: AppDimens.spaceSm),
                          Text(
                            contextStat!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppDimens.spaceXxs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          headline,
                          style: AppTextStyles.displaySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (headlineUnit != null) ...[
                          const SizedBox(width: AppDimens.spaceXs),
                          Text(
                            headlineUnit!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (secondaryStats.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < secondaryStats.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppDimens.spaceXxs),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${secondaryStats[i].label} ',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            TextSpan(
                              text: secondaryStats[i].value,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          if (bottomChild != null) ...[
            const SizedBox(height: AppDimens.spaceSm),
            bottomChild!,
          ],
        ],
      ),
    );
  }
}

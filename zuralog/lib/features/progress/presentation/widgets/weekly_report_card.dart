/// Weekly Report — Feature card teaser for the AI-generated weekly story.
///
/// Locked behind PRO for free users. Uses the bible-spec'd ZFeatureCard
/// surface with the Sage ZCategoryIconTile and the restyled ZProBadge.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/presentation/widgets/pressable_card.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';
import 'package:zuralog/shared/widgets/indicators/z_category_icon_tile.dart';
import 'package:zuralog/shared/widgets/indicators/z_pro_badge.dart';

class WeeklyReportCard extends StatelessWidget {
  const WeeklyReportCard({
    super.key,
    required this.onTap,
    required this.isPremium,
  });

  final VoidCallback onTap;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return PressableCard(
      onTap: onTap,
      borderRadius: AppDimens.shapeLg,
      child: ZFeatureCard(
        child: Row(
          children: [
            const ZCategoryIconTile(
              color: AppColors.primary, // Sage
              icon: Icons.calendar_month_rounded,
              size: AppDimens.iconContainerMd, // 44
              iconColor: AppColors.textOnSage,
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your week at a glance',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.progressTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AI-generated story of your week',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.progressTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            if (!isPremium)
              const ZProBadge()
            else
              Icon(
                Icons.chevron_right_rounded,
                color: colors.progressTextMuted,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

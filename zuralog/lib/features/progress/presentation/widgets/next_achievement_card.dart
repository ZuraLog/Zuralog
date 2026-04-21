library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/achievement_category.dart';
import 'package:zuralog/features/progress/presentation/widgets/pressable_card.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';
import 'package:zuralog/shared/widgets/feedback/z_progress_bar.dart';
import 'package:zuralog/shared/widgets/indicators/z_category_icon_tile.dart';

class NextAchievementCard extends StatelessWidget {
  const NextAchievementCard({
    super.key,
    required this.achievement,
    required this.onTap,
  });

  final Achievement achievement;
  final VoidCallback onTap;

  static const Map<String, IconData> _iconMap = {
    'flame': Icons.local_fire_department_rounded,
    'zap': Icons.bolt_rounded,
    'gem': Icons.diamond_rounded,
    'crown': Icons.workspace_premium_rounded,
    'trophy': Icons.emoji_events_rounded,
    'link': Icons.link_rounded,
    'flag': Icons.flag_rounded,
    'star': Icons.star_rounded,
    'bar_chart': Icons.bar_chart_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final current = achievement.progressCurrent ?? 0;
    final total = achievement.progressTotal ?? 1;
    final fraction = (total > 0) ? (current / total).clamp(0.0, 1.0) : 0.0;
    final category = achievementCategoryFor(achievement.iconName);
    final iconData =
        _iconMap[achievement.iconName] ?? Icons.emoji_events_rounded;

    return PressableCard(
      onTap: onTap,
      borderRadius: AppDimens.radiusCard,
      child: ZFeatureCard(
        variant: category.variant,
        borderRadius: AppDimens.radiusCard,
        child: Row(
          children: [
            ZCategoryIconTile(
              color: category.color,
              icon: iconData,
              size: AppDimens.iconContainerMd,
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.progressTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.progressTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Row(
                    children: [
                      Expanded(
                        child: ZProgressBar(value: fraction.toDouble()),
                      ),
                      const SizedBox(width: AppDimens.spaceSm),
                      Text(
                        achievement.progressLabel ?? '$current/$total',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: colors.progressTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

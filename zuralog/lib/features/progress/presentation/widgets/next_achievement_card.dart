library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/pattern_fill.dart';
import 'package:zuralog/features/progress/presentation/widgets/pattern_progress_bar.dart';
import 'package:zuralog/features/progress/presentation/widgets/pressable_card.dart';

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

    return PressableCard(
      onTap: onTap,
      borderRadius: AppDimens.radiusCard,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: BoxDecoration(
              color: colors.progressSurface,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              border: Border.all(color: colors.progressBorderDefault),
            ),
            child: Row(
              children: [
                Container(
                  width: AppDimens.iconContainerMd,
                  height: AppDimens.iconContainerMd,
                  decoration: BoxDecoration(
                    color: colors.progressSurfaceRaised,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Center(
                    child: Icon(
                      _iconMap[achievement.iconName] ?? Icons.emoji_events_rounded,
                      size: 22,
                      color: colors.progressTextSecondary,
                    ),
                  ),
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
                            child: PatternProgressBar(fraction: fraction),
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
          // Top 3px pattern-fill accent bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDimens.radiusCard),
                topRight: Radius.circular(AppDimens.radiusCard),
              ),
              child: PatternFill(
                child: Container(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Achievements section card for the Progress Home screen.
///
/// Shows the next closest-to-completion locked achievement with a progress
/// bar, plus a badge row of up to 4 recently unlocked (or locked-dimmed)
/// achievements.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/achievement_category.dart';
import 'package:zuralog/features/progress/presentation/widgets/next_achievement_card.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';
import 'package:zuralog/shared/widgets/indicators/z_category_icon_tile.dart';

class AchievementsSectionCard extends StatelessWidget {
  const AchievementsSectionCard({
    super.key,
    required this.nextAchievement,
    required this.recentAchievements,
    required this.onGalleryTap,
    required this.onAchievementTap,
  });

  /// The locked achievement closest to completion. May be null when all are unlocked.
  final Achievement? nextAchievement;

  /// Recently unlocked achievements (newest first, last 30 days).
  final List<Achievement> recentAchievements;

  /// Called when the user taps "Gallery" to view all achievements.
  final VoidCallback onGalleryTap;

  /// Called when the user taps the next achievement card.
  final VoidCallback onAchievementTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    // Badge row: show recents first, pad with placeholder slots up to 4
    final badgeSlots = recentAchievements.take(4).toList();
    final hasContent = nextAchievement != null || recentAchievements.isNotEmpty;

    if (!hasContent) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
          child: Row(
            children: [
              Text(
                'Achievements',
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.progressTextPrimary,
                ),
              ),
              const Spacer(),
              Semantics(
                label: 'View all achievements',
                button: true,
                child: GestureDetector(
                  onTap: onGalleryTap,
                  child: Text(
                    'Gallery',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.progressTextSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Next achievement card
        if (nextAchievement != null)
          NextAchievementCard(
            achievement: nextAchievement!,
            onTap: onAchievementTap,
          ),

        // Recent badges row
        if (badgeSlots.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceSm),
          _RecentBadgesRow(achievements: badgeSlots),
        ],
      ],
    );
  }
}

// ── _RecentBadgesRow ──────────────────────────────────────────────────────────

class _RecentBadgesRow extends StatelessWidget {
  const _RecentBadgesRow({required this.achievements});
  final List<Achievement> achievements;

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
    return ZFeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECENTLY UNLOCKED',
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.progressTextMuted,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            children: achievements.map((a) => _BadgeTile(achievement: a, iconMap: _iconMap)).toList(),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.achievement, required this.iconMap});
  final Achievement achievement;
  final Map<String, IconData> iconMap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final cat = achievementCategoryFor(achievement.iconName);
    return Expanded(
      child: Column(
        children: [
          ZCategoryIconTile(
            color: cat.color,
            icon: iconMap[achievement.iconName] ?? Icons.emoji_events_rounded,
            size: AppDimens.iconContainerMd,
            iconSize: 22,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            achievement.title,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.progressTextMuted,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

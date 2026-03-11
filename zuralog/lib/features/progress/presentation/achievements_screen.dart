/// Achievements Screen — badge gallery grouped by category.
///
/// Shows all achievements (locked + unlocked) grouped by [AchievementCategory].
/// Newly unlocked badges (within last 7 days) animate with a scale + glow pulse
/// and trigger haptic feedback on tap.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── AchievementsScreen ────────────────────────────────────────────────────────

/// Badge gallery screen for all user achievements.
class AchievementsScreen extends ConsumerStatefulWidget {
  /// Creates the [AchievementsScreen].
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(achievementsProvider);
    // Wait for the new future to settle before completing the refresh indicator
    await ref
        .read(achievementsProvider.future)
        .catchError((_) => const AchievementList(achievements: []));
  }

  @override
  Widget build(BuildContext context) {
    final achievementsAsync = ref.watch(achievementsProvider);

    return ZuralogScaffold(
      appBar: const ZuralogAppBar(title: 'Achievements'),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.cardBackgroundDark,
        onRefresh: _refresh,
        child: achievementsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, _) => ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      Text(
                        'Failed to load achievements',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          data: (achievementList) {
            final achievements = achievementList.achievements;
            if (achievements.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            size: 64,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: AppDimens.spaceMd),
                          Text(
                            'No achievements yet',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.textPrimaryDark,
                            ),
                          ),
                          const SizedBox(height: AppDimens.spaceSm),
                          Text(
                            'Keep logging your health data to earn badges.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            // Group achievements by category
            final grouped = <AchievementCategory, List<Achievement>>{};
            for (final cat in AchievementCategory.values) {
              final items =
                  achievements.where((a) => a.category == cat).toList();
              if (items.isNotEmpty) grouped[cat] = items;
            }

            return ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceMd,
              ),
              children: [
                for (final entry in grouped.entries) ...[
                  _CategoryHeader(
                    category: entry.key,
                    achievements: entry.value,
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  _AchievementGrid(achievements: entry.value),
                  const SizedBox(height: AppDimens.spaceLg),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── _CategoryHeader ───────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.category,
    required this.achievements,
  });

  final AchievementCategory category;
  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final total = achievements.length;

    return Row(
      children: [
        Text(
          category.displayName,
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimaryDark),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceSm,
            vertical: AppDimens.spaceXs,
          ),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurfaceDark,
            borderRadius: BorderRadius.circular(AppDimens.radiusChip),
          ),
          child: Text(
            '$unlockedCount / $total',
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ── _AchievementGrid ──────────────────────────────────────────────────────────

class _AchievementGrid extends StatelessWidget {
  const _AchievementGrid({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: achievements.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppDimens.spaceSm,
        mainAxisSpacing: AppDimens.spaceSm,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (context, index) {
        return _AchievementBadgeCard(achievement: achievements[index]);
      },
    );
  }
}

// ── _AchievementBadgeCard ─────────────────────────────────────────────────────

class _AchievementBadgeCard extends ConsumerStatefulWidget {
  const _AchievementBadgeCard({required this.achievement});

  final Achievement achievement;

  @override
  ConsumerState<_AchievementBadgeCard> createState() =>
      _AchievementBadgeCardState();
}

class _AchievementBadgeCardState extends ConsumerState<_AchievementBadgeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  bool get _isNew {
    final unlocked = widget.achievement.unlockedAt;
    if (unlocked == null) return false;
    return DateTime.now().difference(unlocked).inDays < 7;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (_isNew) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_isNew) {
      await ref.read(hapticServiceProvider).medium();
    }
    final achievement = widget.achievement;
    ref.read(analyticsServiceProvider).capture(
      event: AnalyticsEvents.achievementViewed,
      properties: {
        'achievement_key': achievement.key,
        'is_unlocked': achievement.isUnlocked,
        'is_new': _isNew,
      },
    );
  }

  Color _categoryColor(AchievementCategory cat) {
    switch (cat) {
      case AchievementCategory.gettingStarted:
        return AppColors.primary;
      case AchievementCategory.consistency:
        return AppColors.categoryActivity;
      case AchievementCategory.goals:
        return AppColors.categoryBody;
      case AchievementCategory.data:
        return AppColors.categoryVitals;
      case AchievementCategory.coach:
        return AppColors.categoryWellness;
      case AchievementCategory.health:
        return AppColors.categoryHeart;
    }
  }

  IconData _iconForName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('trophy') || lower.contains('award')) {
      return Icons.emoji_events_rounded;
    }
    if (lower.contains('flame') ||
        lower.contains('fire') ||
        lower.contains('streak')) {
      return Icons.local_fire_department_rounded;
    }
    if (lower.contains('star')) return Icons.star_rounded;
    if (lower.contains('check') || lower.contains('done')) {
      return Icons.check_circle_rounded;
    }
    if (lower.contains('data') || lower.contains('sync')) {
      return Icons.sync_rounded;
    }
    if (lower.contains('heart')) return Icons.favorite_rounded;
    if (lower.contains('run') || lower.contains('steps')) {
      return Icons.directions_run_rounded;
    }
    return Icons.military_tech_rounded;
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  /// Builds a thin progress bar + label for locked achievements that have
  /// partial progress data.
  Widget _buildLockedProgress(Achievement achievement) {
    final current = achievement.progressCurrent!;
    final total = achievement.progressTotal!;
    final label =
        achievement.progressLabel ?? '$current of $total';
    final fraction = (current / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            return Stack(
              children: [
                // Track
                Container(
                  height: 3,
                  width: maxWidth,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Fill
                Container(
                  height: 3,
                  width: maxWidth * fraction,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final achievement = widget.achievement;
    final isUnlocked = achievement.isUnlocked;
    final categoryColor = _categoryColor(achievement.category);
    final icon = _iconForName(achievement.iconName);

    if (!_isNew) {
      return _buildCard(
        isUnlocked: isUnlocked,
        categoryColor: categoryColor,
        icon: icon,
        scale: 1.0,
        glowOpacity: isUnlocked ? 0.35 : 0.0,
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: _buildCard(
            isUnlocked: isUnlocked,
            categoryColor: categoryColor,
            icon: icon,
            scale: _scaleAnimation.value,
            glowOpacity: _glowAnimation.value * 0.6,
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required bool isUnlocked,
    required Color categoryColor,
    required IconData icon,
    required double scale,
    required double glowOpacity,
  }) {
    final achievement = widget.achievement;

    return GestureDetector(
      onTap: _onTap,
      child: Opacity(
        opacity: isUnlocked ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: isUnlocked
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundDark,
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            boxShadow: isUnlocked && glowOpacity > 0
                ? [
                    BoxShadow(
                      color: categoryColor.withValues(alpha: glowOpacity),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              ZIconBadge(
                icon: icon,
                color: isUnlocked ? categoryColor : AppColors.textTertiary,
                size: 44,
                iconSize: 24,
                borderRadius: AppDimens.radiusSm + 2,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              // Title
              Text(
                achievement.title,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isUnlocked
                      ? AppColors.textPrimaryDark
                      : AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppDimens.spaceXs),
              // Description
              Text(
                achievement.description,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Status label / progress indicator
              if (isUnlocked && achievement.unlockedAt != null)
                Text(
                  'Earned ${_formatDate(achievement.unlockedAt!)}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: categoryColor,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (!isUnlocked &&
                  achievement.progressCurrent != null &&
                  achievement.progressTotal != null &&
                  achievement.progressTotal! > 0)
                _buildLockedProgress(achievement)
              else
                Text(
                  'Locked',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

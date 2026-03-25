/// Progress Home Screen — Tab 3 (Progress) root screen.
///
/// Redesigned with the Flame Hero layout:
/// - Streak Flame Hero card with 7-day calendar row
/// - 4-tile streak row (engagement, steps, workouts, check-in)
/// - 14-day heatmap card with freeze CTA
/// - Next Achievement card with pattern progress bar
/// - Goal Trajectory cards (vertical list)
/// - Journal Prompt CTA
///
/// Pull-to-refresh invalidates [progressHomeProvider] and [achievementsProvider].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/goal_create_edit_sheet.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_trajectory_card.dart';
import 'package:zuralog/features/progress/presentation/widgets/journal_prompt_cta.dart';
import 'package:zuralog/features/progress/presentation/widgets/next_achievement_card.dart';
import 'package:zuralog/features/progress/presentation/widgets/progress_skeleton_loader.dart';
import 'package:zuralog/features/progress/presentation/widgets/streak_flame_hero.dart';
import 'package:zuralog/features/progress/presentation/widgets/streak_freeze_dialog.dart';
import 'package:zuralog/features/progress/presentation/widgets/streak_heatmap_card.dart';
import 'package:zuralog/features/progress/presentation/widgets/streak_type_tile.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── ProgressHomeScreen ────────────────────────────────────────────────────────

/// Progress Home screen — Tab 3 root.
class ProgressHomeScreen extends ConsumerStatefulWidget {
  const ProgressHomeScreen({super.key});

  @override
  ConsumerState<ProgressHomeScreen> createState() => _ProgressHomeScreenState();
}

class _ProgressHomeScreenState extends ConsumerState<ProgressHomeScreen> {

  Future<void> _onRefresh() async {
    ref.read(hapticServiceProvider).medium();
    ref.read(progressRepositoryProvider).invalidateAll();
    ref.invalidate(progressHomeProvider);
    ref.invalidate(achievementsProvider);
    try {
      await ref.read(progressHomeProvider.future);
    } catch (_) {
      // Error is displayed via asyncData.when(error: ...).
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final asyncData = ref.watch(progressHomeProvider);

    return ZuralogScaffold(
      addBottomNavPadding: true,
      appBar: ZuralogAppBar(
        title: 'Progress',
        tooltipConfig: const ZuralogAppBarTooltipConfig(
          screenKey: 'progress_home',
          tooltipKey: 'welcome',
          message: 'Set goals and I\'ll track your streaks automatically. '
              'Consistency is what matters most.',
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: colors.cardBackground,
        onRefresh: _onRefresh,
        child: asyncData.when(
          loading: () => CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ProgressSkeletonLoader(),
              ),
            ],
          ),
          error: (error, _) => CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ZErrorState(
                  message: 'Something went wrong. Please try again.',
                  onRetry: () => ref.invalidate(progressHomeProvider),
                ),
              ),
            ],
          ),
          data: (data) {
            final isEmpty = data.goals.isEmpty && data.streaks.isEmpty;

            if (isEmpty) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ZEmptyState(
                      icon: Icons.flag_rounded,
                      title: 'Start your journey',
                      message: "Set a goal and I'll track your streaks and progress.",
                      actionLabel: 'Set First Goal',
                      onAction: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const GoalCreateEditSheet(),
                        );
                      },
                    ),
                  ),
                ],
              );
            }

            return _ContentView(data: data);
          },
        ),
      ),
    );
  }
}

// ── _ContentView ──────────────────────────────────────────────────────────────

class _ContentView extends ConsumerWidget {
  const _ContentView({required this.data});

  final ProgressHomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    Widget wrap(Widget child, int index) {
      if (reducedMotion) return child;
      return ZFadeSlideIn(
        delay: Duration(milliseconds: 60 * index),
        offset: 16.0,
        child: child,
      );
    }

    final engagementStreak = data.streaks.firstWhere(
      (s) => s.type == StreakType.engagement,
      orElse: () => const UserStreak(
        type: StreakType.engagement,
        currentCount: 0,
        longestCount: 0,
        lastActivityDate: '',
        isFrozen: false,
        freezeCount: 0,
      ),
    );

    final todayIndex = DateTime.now().weekday - 1; // 0=Monday
    final weekHits = data.weekHits['engagement'] ?? List.filled(7, false);
    final heatmapHistory =
        data.streakHistory['engagement'] ?? List.filled(14, false);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.bottomClearance(context),
      ),
      children: [
        if (data.milestoneStreakCount != null)
          wrap(_MilestoneCelebrationCard(days: data.milestoneStreakCount!), 0),

        wrap(
          StreakFlameHero(
            currentCount: engagementStreak.currentCount,
            longestCount: engagementStreak.longestCount,
            weekHits: weekHits,
            todayIndex: todayIndex,
            isFrozen: engagementStreak.isFrozen,
          ),
          1,
        ),
        const SizedBox(height: AppDimens.spaceLg),

        wrap(_AllStreaksRow(streaks: data.streaks), 2),
        const SizedBox(height: AppDimens.spaceLg),

        wrap(
          Consumer(
            builder: (context, innerRef, _) => StreakHeatmapCard(
              streakName: '🔥 Engagement — last 14 days',
              freezeCount: engagementStreak.freezeCount,
              history: heatmapHistory,
              onFreezeTap: () => showStreakFreezeDialog(
                context,
                innerRef,
                engagementStreak,
              ),
            ),
          ),
          3,
        ),
        const SizedBox(height: AppDimens.spaceLg),

        if (data.nextAchievement != null)
          wrap(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Next Achievement',
                  trailingLabel: 'Gallery',
                  onTrailingTap: () {
                    ref.read(hapticServiceProvider).light();
                    context.push(RouteNames.achievementsPath);
                  },
                ),
                NextAchievementCard(
                  achievement: data.nextAchievement!,
                  onTap: () => context.push(RouteNames.achievementsPath),
                ),
              ],
            ),
            4,
          ),
        if (data.nextAchievement != null) const SizedBox(height: AppDimens.spaceLg),

        if (data.goals.isNotEmpty)
          wrap(_GoalsSection(goals: data.goals), 5),
        if (data.goals.isNotEmpty) const SizedBox(height: AppDimens.spaceLg),

        wrap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'Journal',
                trailingLabel: 'History',
                onTrailingTap: () {
                  ref.read(hapticServiceProvider).light();
                  context.push(RouteNames.journalPath);
                },
              ),
              JournalPromptCta(
                onTap: () => context.push(RouteNames.journalPath),
              ),
            ],
          ),
          6,
        ),
      ],
    );
  }
}

// ── _SectionHeader ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailingLabel,
    this.onTrailingTap,
  });

  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppDimens.spaceSm,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.progressTextPrimary,
            ),
          ),
          const Spacer(),
          if (trailingLabel != null && onTrailingTap != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailingLabel!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.progressTextSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── _GoalsSection ─────────────────────────────────────────────────────────────

class _GoalsSection extends ConsumerWidget {
  const _GoalsSection({required this.goals});
  final List<Goal> goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Goals',
          trailingLabel: 'Manage',
          onTrailingTap: () {
            ref.read(hapticServiceProvider).light();
            context.push(RouteNames.goalsPath);
          },
        ),
        ...goals.asMap().entries.map((entry) => Padding(
          padding: EdgeInsets.only(
            bottom: entry.key < goals.length - 1 ? AppDimens.spaceSm : 0,
          ),
          child: GoalTrajectoryCard(
            goal: entry.value,
            onTap: () {
              ref.read(selectedGoalIdProvider.notifier).state = entry.value.id;
              context.push(RouteNames.goalDetailPath);
            },
          ),
        )),
      ],
    );
  }
}

// ── _AllStreaksRow ─────────────────────────────────────────────────────────────

class _AllStreaksRow extends StatelessWidget {
  const _AllStreaksRow({required this.streaks});
  final List<UserStreak> streaks;

  static const _streakConfig = [
    (StreakType.engagement, '🔥', 'Engage'),
    (StreakType.steps, '👟', 'Steps'),
    (StreakType.workouts, '🏋️', 'Workout'),
    (StreakType.checkin, '📋', 'Check-in'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < _streakConfig.length; i++) {
      final (type, emoji, label) = _streakConfig[i];
      final streak = streaks.firstWhere(
        (s) => s.type == type,
        orElse: () => UserStreak(
          type: type,
          currentCount: 0,
          longestCount: 0,
          lastActivityDate: '',
          isFrozen: false,
          freezeCount: 0,
        ),
      );
      items.add(
        Expanded(
          child: Semantics(
            label: '$label streak: ${streak.currentCount} days',
            excludeSemantics: true,
            child: StreakTypeTile(
              emoji: emoji,
              count: streak.currentCount,
              label: label,
              isHot: streak.currentCount > 0,
            ),
          ),
        ),
      );
      if (i < _streakConfig.length - 1) {
        items.add(const SizedBox(width: AppDimens.spaceSm));
      }
    }
    return Row(children: items);
  }
}

// ── _MilestoneCelebrationCard ─────────────────────────────────────────────────

/// Full-width inline card shown when the user hits a major streak milestone.
class _MilestoneCelebrationCard extends ConsumerStatefulWidget {
  const _MilestoneCelebrationCard({required this.days});

  final int days;

  @override
  ConsumerState<_MilestoneCelebrationCard> createState() =>
      _MilestoneCelebrationCardState();
}

class _MilestoneCelebrationCardState
    extends ConsumerState<_MilestoneCelebrationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim;
  bool _hapticFired = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.015).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    SharedPreferences.getInstance().then((prefs) {
      if (prefs.getBool('last_seen_milestone_${widget.days}') == true) {
        if (mounted) setState(() => _dismissed = true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!_hapticFired) {
        _hapticFired = true;
        ref.read(hapticServiceProvider).success();
      }

      ref.read(analyticsServiceProvider).capture(
        event: AnalyticsEvents.streakMilestoneViewed,
        properties: {'days': widget.days},
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _pulseCtrl.stop();
    } else if (!_pulseCtrl.isAnimating && !_dismissed) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('last_seen_milestone_${widget.days}', true);
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            color: AppColors.progressSurface,
            border: Border.all(color: AppColors.progressBorderDefault),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.progressStreakWarm.withValues(alpha: 0.08),
                          AppColors.progressStreakWarm.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Text('🔥', style: TextStyle(fontSize: 28)),
                          SizedBox(width: AppDimens.spaceXs),
                          Text('🏆', style: TextStyle(fontSize: 28)),
                        ],
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      Text(
                        '${widget.days}-Day Streak!',
                        style: AppTextStyles.displaySmall.copyWith(
                          color: AppColors.progressStreakWarm,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceXs),
                      Text(
                        'Amazing consistency! You\'ve logged every day '
                        'for ${widget.days} days.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.progressTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.progressTextMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

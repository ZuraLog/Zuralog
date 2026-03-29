/// Progress Home Screen — Tab 3 (Progress) root screen.
///
/// Redesigned with the Flame Hero layout (v2):
/// - Streak Flame Hero card with 7-day calendar row + freeze pill
/// - "This Week" snapshot card (goals on track, day streak, top WoW metric)
/// - Achievements section (next achievement + recently unlocked badges)
/// - Goals section (trajectory cards, or empty-state CTA when no goals)
/// - Journal CTA (hidden when already logged today, contextual otherwise)
///
/// Pull-to-refresh invalidates [progressHomeProvider], [achievementsProvider],
/// and [journalProvider].
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
import 'package:zuralog/features/progress/presentation/widgets/achievements_section_card.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_trajectory_card.dart';
import 'package:zuralog/features/progress/presentation/widgets/goals_empty_card.dart';
import 'package:zuralog/features/progress/presentation/journal_entry_router.dart';
import 'package:zuralog/features/progress/presentation/widgets/journal_prompt_cta.dart';
import 'package:zuralog/features/progress/presentation/widgets/progress_skeleton_loader.dart';
import 'package:zuralog/features/progress/presentation/widgets/streak_flame_hero.dart';
import 'package:zuralog/features/progress/presentation/widgets/streak_freeze_dialog.dart';
import 'package:zuralog/features/progress/presentation/widgets/this_week_snapshot_card.dart';
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
    ref.invalidate(journalProvider);
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
          data: (data) => _ContentView(data: data),
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
    final journalAsync = ref.watch(journalProvider);

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

    final goalsOnTrack = data.goals
        .where((g) =>
            g.trendDirection == 'on_track' || g.trendDirection == 'completed')
        .length;

    final nudgeMessage = engagementStreak.currentCount == 0
        ? 'Open the app daily to start building your streak.'
        : null;

    // Derive journal state from journalProvider
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    String? lastEntryDateStr;
    bool journalledToday = false;
    journalAsync.whenData((page) {
      if (page.entries.isNotEmpty) {
        lastEntryDateStr = page.entries.first.date;
        journalledToday = page.entries.first.date == todayStr;
      }
    });

    final hasAchievements =
        data.nextAchievement != null || data.recentAchievements.isNotEmpty;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.bottomClearance(context),
      ),
      children: [
        // Milestone celebration banner
        if (data.milestoneStreakCount != null)
          wrap(_MilestoneCelebrationCard(days: data.milestoneStreakCount!), 0),

        // Streak Flame Hero with freeze pill
        wrap(
          Consumer(
            builder: (context, innerRef, _) => StreakFlameHero(
              currentCount: engagementStreak.currentCount,
              longestCount: engagementStreak.longestCount,
              weekHits: weekHits,
              todayIndex: todayIndex,
              isFrozen: engagementStreak.isFrozen,
              freezeCount: engagementStreak.freezeCount,
              nudgeMessage: nudgeMessage,
              onFreezeTap: () => showStreakFreezeDialog(
                context,
                innerRef,
                engagementStreak,
              ),
            ),
          ),
          1,
        ),
        const SizedBox(height: AppDimens.spaceLg),

        // This Week snapshot (shown when there is any meaningful data)
        if (data.streaks.isNotEmpty || data.goals.isNotEmpty) ...[
          wrap(
            ThisWeekSnapshotCard(
              wow: data.wow,
              streakCount: engagementStreak.currentCount,
              goalsOnTrack: goalsOnTrack,
              totalGoals: data.goals.length,
            ),
            2,
          ),
          const SizedBox(height: AppDimens.spaceLg),
        ],

        // Achievements section
        if (hasAchievements) ...[
          wrap(
            AchievementsSectionCard(
              nextAchievement: data.nextAchievement,
              recentAchievements: data.recentAchievements,
              onGalleryTap: () {
                ref.read(hapticServiceProvider).light();
                context.push(RouteNames.achievementsPath);
              },
              onAchievementTap: () =>
                  context.push(RouteNames.achievementsPath),
            ),
            3,
          ),
          const SizedBox(height: AppDimens.spaceLg),
        ],

        // Goals section (with empty state CTA when no goals)
        wrap(_GoalsSection(goals: data.goals), 4),
        const SizedBox(height: AppDimens.spaceLg),

        // Journal CTA (hidden automatically when user already journalled today)
        wrap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!journalledToday)
                _SectionHeader(
                  title: 'Journal',
                  trailingLabel: 'History',
                  onTrailingTap: () {
                    ref.read(hapticServiceProvider).light();
                    context.push(RouteNames.journalPath);
                  },
                ),
              JournalPromptCta(
                onTap: () => showDialog(
                  context: context,
                  barrierColor: Colors.transparent,
                  builder: (_) => const JournalEntryRouter(),
                ),
                lastEntryDate: lastEntryDateStr,
                journalledToday: journalledToday,
              ),
            ],
          ),
          5,
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
        if (goals.isEmpty)
          GoalsEmptyCard(
            onTap: () {
              ref.read(hapticServiceProvider).light();
              context.push(RouteNames.goalsPath);
            },
          )
        else
          ...goals.asMap().entries.map((entry) => Padding(
                padding: EdgeInsets.only(
                  bottom:
                      entry.key < goals.length - 1 ? AppDimens.spaceSm : 0,
                ),
                child: GoalTrajectoryCard(
                  goal: entry.value,
                  onTap: () {
                    ref.read(selectedGoalIdProvider.notifier).state =
                        entry.value.id;
                    context.push(RouteNames.goalDetailPath);
                  },
                ),
              )),
      ],
    );
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
                          Icon(Icons.local_fire_department_rounded, size: 28, color: Color(0xFFFF9500)),
                          SizedBox(width: AppDimens.spaceXs),
                          Icon(Icons.emoji_events_rounded, size: 28, color: Color(0xFFFFD60A)),
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

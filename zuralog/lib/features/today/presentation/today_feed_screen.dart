/// Today Feed — Tab 0 root screen.
///
/// Curated daily briefing: Health Score hero paired with the Streak Hero Card,
/// four health pillar cards (Sleep, Nutrition, Workouts, Heart), daily goals,
/// journal prompt, and AI insight cards.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/constants/app_constants.dart';
import 'package:zuralog/core/haptics/haptic_providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/state/log_sheet_provider.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/features/heart/domain/heart_models.dart';
import 'package:zuralog/features/heart/providers/heart_providers.dart';
import 'package:zuralog/features/today/presentation/widgets/heart_pillar_card.dart';
import 'package:zuralog/features/today/presentation/widgets/journal_prompt_card.dart';
import 'package:zuralog/features/today/presentation/widgets/nutrition_pillar_card.dart';
import 'package:zuralog/features/today/presentation/widgets/sleep_pillar_card.dart';
import 'package:zuralog/features/today/presentation/widgets/workouts_pillar_card.dart';
import 'package:zuralog/shared/widgets/health_score_widget.dart';
import 'package:zuralog/shared/widgets/onboarding_tooltip.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── TodayFeedScreen ───────────────────────────────────────────────────────────

/// Today Feed screen — the curated daily briefing.
///
/// Displays the Health Score hero paired with the Streak Hero Card, four health
/// pillar cards (Sleep, Nutrition, Workouts, Heart), daily goals, journal
/// prompt, and AI insight cards.
class TodayFeedScreen extends ConsumerStatefulWidget {
  /// Creates the [TodayFeedScreen].
  const TodayFeedScreen({super.key});

  @override
  ConsumerState<TodayFeedScreen> createState() => _TodayFeedScreenState();
}

class _TodayFeedScreenState extends ConsumerState<TodayFeedScreen> {
  @override
  Widget build(BuildContext context) {
    final openSheet = ref.watch(logSheetCallbackProvider) ?? () {};
    final colors = AppColorsOf(context);
    final scoreAsync = ref.watch(healthScoreProvider);
    final feedAsync = ref.watch(todayFeedProvider);
    final dataDays = scoreAsync.valueOrNull?.dataDays ?? 0;
    final heartSummaryAsync = ref.watch(heartDaySummaryProvider);
    final heartSummary = heartSummaryAsync.valueOrNull ?? HeartDaySummary.empty;

    // When the user creates, edits, or deletes a goal on the Progress tab,
    // goalsProvider gets invalidated. Listen for that and refresh the daily
    // goals card so it reflects the change immediately.
    ref.listen(goalsProvider, (previous, next) {
      if (next is AsyncData) {
        ref.invalidate(dailyGoalsProvider);
      }
    });

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: 'Today',
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ref.read(hapticServiceProvider).light();
              ref.read(analyticsServiceProvider).capture(
                event: AnalyticsEvents.notificationHistoryViewed,
              );
              context.pushNamed(RouteNames.notificationHistory);
            },
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primary,
        backgroundColor: colors.canvas,
        onRefresh: () async {
          ref.read(todayRepositoryProvider).invalidateFeedCache();
          ref.invalidate(healthScoreProvider);
          ref.invalidate(todayFeedProvider);
          ref.invalidate(todayLogSummaryProvider);
          ref.invalidate(pinnedMetricsProvider);
          ref.invalidate(dailyGoalsProvider);
          ref.invalidate(heartDaySummaryProvider);
          await Future.wait([
            ref
                .read(healthScoreProvider.future)
                .catchError(
                  (Object e, StackTrace _) =>
                      const HealthScoreData(score: 0, trend: [], dataDays: 0),
                ),
            ref
                .read(todayFeedProvider.future)
                .catchError(
                  (Object e, StackTrace _) =>
                      TodayFeedData(insights: [], streak: null),
                ),
            ref
                .read(todayLogSummaryProvider.future)
                .catchError(
                  (Object e, StackTrace _) => TodayLogSummary.empty,
                ),
            ref.read(dailyGoalsProvider.future).catchError(
              (Object e, StackTrace _) => <DailyGoal>[],
            ),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ── Health Score + Streak Hero Card (side by side) ──────────────
            ZFadeSlideIn(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceLg,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Health Score hero — left half.
                      Expanded(
                        child: OnboardingTooltip(
                          screenKey: 'today_feed',
                          tooltipKey: 'health_score',
                          message: 'This is your daily health score — a composite of '
                              'all your health data from the last 24 hours.',
                          child: _HealthScoreHero(scoreAsync: scoreAsync),
                        ),
                      ),
                      const SizedBox(width: AppDimens.spaceSm),
                      // Streak Hero Card — right half.
                      Expanded(
                        child: feedAsync.when(
                          loading: () => const StreakHeroCard(streakDays: 0),
                          error: (e, _) => const StreakHeroCard(streakDays: 0),
                          data: (feed) => StreakHeroCard(
                            streakDays: feed.streak?.currentStreak ?? 0,
                            isPersonalBest: feed.streak != null &&
                                feed.streak!.currentStreak > 0 &&
                                feed.streak!.currentStreak >=
                                    (feed.streak!.longestStreak ?? 0),
                            isFrozen: feed.streak?.isFrozen ?? false,
                            onTap: () => context.go(RouteNames.progressPath),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Health Pillar Cards ───────────────────────────────────────
            ZFadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: SleepPillarCard(
                  onTap: () => context.pushNamed(RouteNames.sleep),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            ZFadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: NutritionPillarCard(
                  onTap: () => context.pushNamed(RouteNames.nutrition),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            ZFadeSlideIn(
              delay: const Duration(milliseconds: 180),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: WorkoutsPillarCard(
                  onTap: () => context.push(RouteNames.workoutLogPath),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            ZFadeSlideIn(
              delay: const Duration(milliseconds: 240),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: HeartPillarCard(
                  summary: heartSummary,
                  onTap: () => context.pushNamed(RouteNames.heart),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // ── Daily Goals ──────────────────────────────────────────────────
            ZFadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: _DailyGoalsSection(),
              ),
            ),

            const SizedBox(height: AppDimens.spaceMd),
            ZFadeSlideIn(
              delay: const Duration(milliseconds: 360),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: JournalPromptCard(
                  onTap: () => context.pushNamed(RouteNames.journalDiary),
                ),
              ),
            ),

            const SizedBox(height: AppDimens.spaceLg),

            // ── Section: Your Briefing ────────────────────────────────────────
            ZFadeSlideIn(
              delay: const Duration(milliseconds: 420),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  0,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: SectionHeader(title: 'Your Briefing'),
              ),
            ),

            // Provider never errors — only loading and data branches needed.
            ...feedAsync.when(
              error: (err, stack) => [
                ZFadeSlideIn(
                  delay: const Duration(milliseconds: 480),
                  child: ZEmptyInsightsCard(
                    onLogTap: openSheet,
                    onConnectTap: () =>
                        context.pushNamed(RouteNames.settingsIntegrations),
                  ),
                ),
              ],
              loading: () => [
                ZFadeSlideIn(
                  delay: const Duration(milliseconds: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                    ),
                    child: ZLoadingSkeleton(
                      width: double.infinity,
                      height: 120,
                      borderRadius: AppDimens.shapeLg,
                    ),
                  ),
                ),
              ],
              data: (feed) {
                if (feed.insights.isEmpty) {
                  return [
                    ZFadeSlideIn(
                      delay: const Duration(milliseconds: 480),
                      child: ZEmptyInsightsCard(
                        onLogTap: openSheet,
                        onConnectTap: () =>
                            context.pushNamed(RouteNames.settingsIntegrations),
                      ),
                    ),
                  ];
                }

                // Building Up (Days 1–6): show first insight + "Day 7" teaser.
                final isBuilding = dataDays > 0 &&
                    dataDays < kMinDataDaysForMaturity;

                Widget buildInsightCard(InsightCard insight, int index) =>
                    ZFadeSlideIn(
                      delay: Duration(milliseconds: 480 + (index * 60)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceMd,
                          vertical: AppDimens.spaceXs,
                        ),
                        child: ZInsightCard(
                          insight: insight,
                          onTap: () {
                            ref.read(hapticServiceProvider).light();
                            ref.read(analyticsServiceProvider).capture(
                              event: AnalyticsEvents.insightCardTapped,
                              properties: {
                                'insight_id': insight.id,
                                'insight_type': insight.type.name,
                                'category': insight.category,
                                'is_unread': !insight.isRead,
                              },
                            );
                            context.pushNamed(
                              RouteNames.insightDetail,
                              pathParameters: {'id': insight.id},
                            );
                          },
                        ),
                      ),
                    );

                if (isBuilding) {
                  return [
                    buildInsightCard(feed.insights.first, 0),
                    const _BuildingInsightsNote(),
                  ];
                }

                return feed.insights
                    .asMap()
                    .entries
                    .map((e) => buildInsightCard(e.value, e.key))
                    .toList();
              },
            ),

            // Bottom padding so last card clears the FAB.
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ── _HealthScoreHero ───────────────────────────────────────────────────────────

class _HealthScoreHero extends ConsumerWidget {
  const _HealthScoreHero({required this.scoreAsync});

  final AsyncValue<HealthScoreData> scoreAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.hero,
      padding: const EdgeInsets.symmetric(
        vertical: AppDimens.spaceLg,
        horizontal: AppDimens.spaceMd,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient sage-green radial glow — top-right corner (decorative,
          // Positioned.fill so it doesn't affect the Stack's intrinsic height).
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.85, -0.85),
                    radius: 0.9,
                    colors: [
                      colors.primary.withValues(alpha: 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Center fills the Stack and vertically centers the content.
          // Non-positioned so IntrinsicHeight can measure it correctly.
          Center(
            child: scoreAsync.when(
            // Provider never errors — this branch is a safety net only.
            error: (err, stack) => const HealthScoreZeroState(),
            loading: () => const ZLoadingSkeleton(
              width: double.infinity,
              height: 120,
              borderRadius: AppDimens.shapeLg,
            ),
            data: (data) {
              // Three states based on data maturity:
              // 1. No data at all → sad-face zero state.
              if (data.dataDays == 0) {
                return const HealthScoreZeroState();
              }
              // 2. Building up (Days 1–6) → partial sage-green ring
              //    showing progress towards the 7-day threshold.
              if (data.dataDays < kMinDataDaysForMaturity) {
                return HealthScoreBuildingState(
                  dataDays: data.dataDays,
                  targetDays: kMinDataDaysForMaturity,
                );
              }
              // 3. Full (Day 7+) → real score ring with sparkline.
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HealthScoreWidget.hero(
                    score: data.score,
                    trend: data.trend.isNotEmpty ? data.trend : null,
                    commentary: data.commentary,
                    onTap: () {
                      ref.read(hapticServiceProvider).light();
                      ref.read(analyticsServiceProvider).capture(
                        event: AnalyticsEvents.healthScoreTapped,
                      );
                      context.go(RouteNames.dataPath);
                    },
                  ),
                  // AI delta chip — week-over-week score change.
                  if (data.weekChange != null &&
                      data.weekChange != 0 &&
                      data.dataDays > kMinDataDaysForMaturity)
                    _HealthScoreDeltaChip(weekChange: data.weekChange!),
                ],
              );
            },
          ),
          ),
        ],
      ),
    );
  }
}

// ── _DailyGoalsSection ────────────────────────────────────────────────────────

/// Watches [dailyGoalsProvider] and renders [ZDailyGoalsCard] with real data.
///
/// Loading: shows a skeleton placeholder matching the card height.
/// Data: maps [DailyGoal] → [DailyGoalDisplay] and passes to the card.
class _DailyGoalsSection extends ConsumerWidget {
  const _DailyGoalsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(dailyGoalsProvider);

    return goalsAsync.when(
      loading: () => const _GoalsSkeleton(),
      error: (e, _) => ZDailyGoalsCard(
        goals: const [],
        onSetupTap: () => context.go(RouteNames.progressPath),
      ),
      data: (goals) => ZDailyGoalsCard(
        goals: goals
            .map((g) => DailyGoalDisplay(
                  label: g.label,
                  current: _formatGoalValue(g.current),
                  target: _formatGoalValue(g.target),
                  unit: g.unit,
                  fraction: g.fraction,
                ))
            .toList(),
        onSetupTap: () => context.go(RouteNames.progressPath),
      ),
    );
  }

  String _formatGoalValue(double value) {
    if (value == value.roundToDouble()) {
      final intVal = value.toInt();
      if (intVal >= 1000) return _formatWithCommas(intVal);
      return intVal.toString();
    }
    return value.toStringAsFixed(1);
  }

  /// Formats an integer with thousand separators (e.g. 10000 → "10,000").
  static String _formatWithCommas(int n) {
    final str = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}

class _GoalsSkeleton extends StatelessWidget {
  const _GoalsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ZLoadingSkeleton(
      width: double.infinity,
      height: 120,
      borderRadius: AppDimens.shapeMd,
    );
  }
}



// ── _BuildingInsightsNote ─────────────────────────────────────────────────────

/// Subtle inline hint shown during Days 1–6 below the first insight card.
class _BuildingInsightsNote extends StatelessWidget {
  const _BuildingInsightsNote();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: AppDimens.iconSm,
            color: colors.textTertiary,
          ),
          const SizedBox(width: AppDimens.spaceXs),
          Text(
            'More insights unlock at Day 7',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _HealthScoreDeltaChip ─────────────────────────────────────────────────────

/// Small pill chip showing week-over-week health score change.
///
/// Positive: green arrow up + "↑ X pts this week".
/// Negative: red arrow down + "↓ X pts this week".
class _HealthScoreDeltaChip extends StatelessWidget {
  const _HealthScoreDeltaChip({required this.weekChange});

  final int weekChange;

  @override
  Widget build(BuildContext context) {
    final isPositive = weekChange > 0;
    final chipColor = isPositive
        ? AppColors.categoryActivity // green
        : AppColors.healthScoreRed;  // error red per spec
    final arrow = isPositive ? '↑' : '↓';
    final absChange = weekChange.abs();

    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.spaceSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        ),
        child: Text(
          '$arrow $absChange pts this week',
          style: AppTextStyles.labelSmall.copyWith(
            color: chipColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}


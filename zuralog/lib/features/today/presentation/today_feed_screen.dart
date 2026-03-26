/// Today Feed — Tab 0 root screen.
///
/// Curated daily briefing: Health Score hero paired with the Streak Hero Card,
/// AI insight cards, metric grid, daily goals, and streak badge.
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
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/metric_format_utils.dart';
import 'package:zuralog/features/today/domain/metric_grid_models.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/data_maturity_banner.dart';
import 'package:zuralog/shared/widgets/health_score_widget.dart';
import 'package:zuralog/shared/widgets/onboarding_tooltip.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── TodayFeedScreen ───────────────────────────────────────────────────────────

/// Today Feed screen — the curated daily briefing.
///
/// Displays the Health Score hero paired with the Streak Hero Card, data maturity
/// banner, snapshot row, daily goals, AI insight cards, and streak badge.
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
    final bannerDismissed = ref.watch(dataMaturityBannerDismissedProvider);

    // Data maturity banner state computation.
    final dataDays = scoreAsync.valueOrNull?.dataDays ?? 0;
    final profile = ref.watch(userProfileProvider);
    final accountAge = profile?.createdAt != null
        ? DateTime.now().difference(profile!.createdAt!).inDays
        : 0;
    final accountMature = accountAge >= kMinDataDaysForMaturity;
    final bannerMode = accountMature
        ? DataMaturityMode.stillBuilding
        : DataMaturityMode.progress;
    final sessionDismissed = ref.watch(todayBannerSessionDismissed);
    final prefsAsync = ref.watch(userPreferencesProvider);
    final showBanner = dataDays < kMinDataDaysForMaturity &&
        !bannerDismissed &&
        !prefsAsync.isLoading && // Don't show banner while prefs loading — avoids silent dismiss drop
        (bannerMode == DataMaturityMode.progress || !sessionDismissed);

    void persistBannerDismissed() => ref
        .read(userPreferencesProvider.notifier)
        .mutate((p) => p.copyWith(dataMaturityBannerDismissed: true));

    // When the user creates, edits, or deletes a goal on the Progress tab,
    // goalsProvider gets invalidated. Listen for that and refresh the daily
    // goals card so it reflects the change immediately.
    ref.listen(goalsProvider, (previous, next) {
      if (next is AsyncData) {
        ref.invalidate(dailyGoalsProvider);
      }
    });

    return ZuralogScaffold(
      floatingActionButton: ZLogFab(onPressed: openSheet),
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
        backgroundColor: colors.cardBackground,
        onRefresh: () async {
          ref.read(todayRepositoryProvider).invalidateFeedCache();
          ref.invalidate(healthScoreProvider);
          ref.invalidate(todayFeedProvider);
          ref.invalidate(todayLogSummaryProvider);
          ref.invalidate(pinnedMetricsProvider);
          ref.invalidate(dailyGoalsProvider);
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
            Padding(
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
                    Flexible(
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
                    Flexible(
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Data Maturity banner ─────────────────────────────────────────
            if (showBanner)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: DataMaturityBanner(
                  daysWithData: dataDays,
                  targetDays: kMinDataDaysForMaturity,
                  mode: bannerMode,
                  onDismiss: bannerMode == DataMaturityMode.progress
                      ? persistBannerDismissed
                      : () =>
                          ref.read(todayBannerSessionDismissed.notifier).state =
                              true,
                  onPermanentDismiss:
                      bannerMode == DataMaturityMode.stillBuilding
                          ? persistBannerDismissed
                          : null,
                ),
              ),

            // ── Greeting ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: () {
                final subtitle = _greetingSubtitle(
                  dataDays,
                  ref.watch(todayLogSummaryProvider).valueOrNull ??
                      TodayLogSummary.empty,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: _timeOfDayGreeting(profile?.aiName),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppDimens.spaceXs),
                        child: Text(
                          subtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                );
              }(),
            ),

            // ── My Metrics Grid ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: _MetricGridSection(),
            ),

            const SizedBox(height: AppDimens.spaceMd),

            // ── Daily Goals ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
              ),
              child: _DailyGoalsSection(),
            ),

            const SizedBox(height: AppDimens.spaceLg),

            // ── Section: Your Briefing ────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: SectionHeader(title: 'Your Briefing'),
            ),

            // Provider never errors — only loading and data branches needed.
            ...feedAsync.when(
              error: (err, stack) => [
                ZEmptyInsightsCard(
                  onLogTap: openSheet,
                  onConnectTap: () =>
                      context.pushNamed(RouteNames.settingsIntegrations),
                ),
              ],
              loading: () => [
                SizedBox(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  ),
                ),
              ],
              data: (feed) {
                if (feed.insights.isEmpty) {
                  return [
                    ZEmptyInsightsCard(
                      onLogTap: openSheet,
                      onConnectTap: () =>
                          context.pushNamed(RouteNames.settingsIntegrations),
                    ),
                  ];
                }

                // Building Up (Days 1–6): show first insight + "Day 7" teaser.
                final isBuilding = dataDays > 0 &&
                    dataDays < kMinDataDaysForMaturity;

                Widget buildInsightCard(InsightCard insight) => Padding(
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
                );

                if (isBuilding) {
                  return [
                    buildInsightCard(feed.insights.first),
                    const _BuildingInsightsNote(),
                  ];
                }

                return feed.insights
                    .map((insight) => buildInsightCard(insight))
                    .toList();
              },
            ),

            // Bottom padding so last card clears the FAB (added in Part 2).
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Stack(
        children: [
          // Ambient sage-green radial glow — top-right corner.
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.85, -0.85),
                    radius: 0.9,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Card body.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppDimens.spaceLg,
              horizontal: AppDimens.spaceMd,
            ),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              border: Border.all(color: colors.border),
            ),
            child: scoreAsync.when(
              // Provider never errors — this branch is a safety net only.
              error: (err, stack) => const HealthScoreZeroState(),
              loading: () => SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(color: colors.primary),
                ),
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

// ── _MetricGridSection ────────────────────────────────────────────────────────

/// Builds the Today tab metric grid, wiring pinned metrics to today's log data.
class _MetricGridSection extends ConsumerWidget {
  const _MetricGridSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedAsync = ref.watch(pinnedMetricsProvider);
    final summaryAsync = ref.watch(todayLogSummaryProvider);

    return pinnedAsync.when(
      loading: () => const _MetricGridSkeleton(),
      error: (e, _) => _MetricGridError(
        onRetry: () => ref.invalidate(pinnedMetricsProvider),
      ),
      data: (pinned) {
        final summary = summaryAsync.valueOrNull ?? TodayLogSummary.empty;

        // Fetch last-ever logged values for all pinned metrics so unlit tiles
        // can show "87kg · 4d ago" instead of a plain dash.
        final latestAsync = ref.watch(
          latestLogValuesProvider(latestLogValuesKey(pinned.toSet())),
        );
        final latest = latestAsync.valueOrNull ?? const {};

        final tiles = pinned
            .map((type) => _buildTile(type, summary, latest))
            .toList();

        return MetricGrid(
          tiles: tiles,
          onAddTap: () => context.pushNamed(
            RouteNames.metricPicker,
            extra: pinned.toSet(),
          ),
          onRemove: (tile) {
            ref
                .read(pinnedMetricsProvider.notifier)
                .removeMetric(tile.metricType);
          },
          onTileTap: (tile) => _openLogForMetric(context, tile.metricType),
        );
      },
    );
  }

  /// Opens the appropriate logging experience for [metricType].
  ///
  /// Inline metrics (mood/energy/stress/water/weight/steps) open
  /// [ZLogGridSheet] pre-navigated to the correct panel.
  /// Full-screen metrics (sleep/run/meal/supplement/symptom) push the
  /// corresponding named route directly over the shell.
  /// Read-only synced metrics (heart_rate, etc.) are silently ignored.
  void _openLogForMetric(BuildContext context, String metricType) {
    // Map energy/stress → mood since they share the wellness inline panel.
    final sheetKey = switch (metricType) {
      'energy' || 'stress' => 'mood',
      _                    => metricType,
    };

    // Full-screen routes — push directly, no sheet needed.
    final fullScreenRoute = switch (metricType) {
      'sleep'      => RouteNames.sleepLog,
      'run'        => RouteNames.runLog,
      'meal'       => RouteNames.mealLog,
      'supplement' => RouteNames.supplementsLog,
      'symptom'    => RouteNames.symptomLog,
      _            => null,
    };

    if (fullScreenRoute != null) {
      context.pushNamed(fullScreenRoute);
      return;
    }

    // Inline metrics — open the sheet pre-navigated to the right panel.
    const inlineKeys = {'mood', 'water', 'weight', 'steps'};
    if (inlineKeys.contains(sheetKey)) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useRootNavigator: true,
        builder: (_) => ZLogGridSheet(
          initialTileKey: sheetKey,
          parentMessenger: ScaffoldMessenger.of(context),
          onFullScreenRoute: (routeName) {
            Navigator.of(context, rootNavigator: true).pop();
            context.pushNamed(routeName);
          },
        ),
      );
      return;
    }

    // heart_rate and any unrecognised types are read-only — no action.
  }
}

// ── _buildTile ────────────────────────────────────────────────────────────────

/// Maps a metric type string and today's log summary to a [MetricTileData].
///
/// [latest] is the result of `latestLogValuesProvider` — the most recent ever-
/// logged value per metric type (across all time, not just today). Used to
/// populate [MetricTileData.lastValue] and [MetricTileData.lastLoggedAt] so
/// unlit tiles can display "87kg · 4d ago" instead of a plain dash.
MetricTileData _buildTile(
  String type,
  TodayLogSummary summary,
  Map<String, dynamic> latest,
) {
  final isLit = summary.loggedTypes.contains(type);
  final raw = summary.latestValues[type];

  // Extract last-ever logged value and timestamp from the /latest endpoint.
  final (lastValue, lastLoggedAt) = _extractLastLogged(type, latest);

  return switch (type) {
    'mood' => MetricTileData(
        metricType: type,
        label: 'Mood',
        emoji: '😊',
        categoryColor: AppColors.categoryWellness.toARGB32(),
        value:
            isLit ? '${(raw as num?)?.toStringAsFixed(1) ?? '—'}/10' : null,
        lastValue: lastValue,
        lastLoggedAt: lastLoggedAt,
      ),
    'energy' => MetricTileData(
        metricType: type,
        label: 'Energy',
        emoji: '⚡',
        categoryColor: AppColors.categoryWellness.toARGB32(),
        value:
            isLit ? '${(raw as num?)?.toStringAsFixed(1) ?? '—'}/10' : null,
        lastValue: lastValue,
        lastLoggedAt: lastLoggedAt,
      ),
    'stress' => MetricTileData(
        metricType: type,
        label: 'Stress',
        emoji: '😤',
        categoryColor: AppColors.categoryWellness.toARGB32(),
        value:
            isLit ? '${(raw as num?)?.toStringAsFixed(1) ?? '—'}/10' : null,
        lastValue: lastValue,
        lastLoggedAt: lastLoggedAt,
      ),
    'water' => MetricTileData(
        metricType: type,
        label: 'Water',
        emoji: '💧',
        categoryColor: AppColors.categoryBody.toARGB32(),
        value:
            isLit ? '${(raw as num?)?.toStringAsFixed(0) ?? '—'}ml' : null,
        lastValue: lastValue,
        lastLoggedAt: lastLoggedAt,
      ),
    'sleep' => MetricTileData(
        metricType: type,
        label: 'Sleep',
        emoji: '😴',
        categoryColor: AppColors.categorySleep.toARGB32(),
        value: isLit && raw != null
            ? formatSleepMinutes((raw as num).toDouble())
            : null,
        lastValue: lastValue,
        lastLoggedAt: lastLoggedAt,
      ),
    'weight' => MetricTileData(
        metricType: type,
        label: 'Weight',
        emoji: '⚖️',
        categoryColor: AppColors.categoryBody.toARGB32(),
        value:
            isLit ? '${(raw as num?)?.toStringAsFixed(1) ?? '—'}kg' : null,
        lastValue: lastValue,
        lastLoggedAt: lastLoggedAt,
      ),
    'steps' => MetricTileData(
        metricType: type,
        label: 'Steps',
        emoji: '👣',
        categoryColor: AppColors.categoryActivity.toARGB32(),
        value: isLit && raw != null
            ? formatSteps((raw as num).toInt())
            : null,
        lastValue: lastValue,
        lastLoggedAt: lastLoggedAt,
      ),
    'run' => MetricTileData(
        metricType: type,
        label: 'Run',
        emoji: '🏃',
        categoryColor: AppColors.categoryActivity.toARGB32(),
        value:
            isLit ? '${(raw as num?)?.toStringAsFixed(1) ?? '—'}km' : null,
        lastValue: lastValue,
        lastLoggedAt: lastLoggedAt,
      ),
    'meal' => MetricTileData(
        metricType: type,
        label: 'Calories',
        emoji: '🍽️',
        categoryColor: AppColors.categoryNutrition.toARGB32(),
        value: isLit
            ? '${(raw as num?)?.toStringAsFixed(0) ?? '—'} kcal'
            : null,
        lastValue: lastValue,
        lastLoggedAt: lastLoggedAt,
      ),
    'supplement' => MetricTileData(
        metricType: type,
        label: 'Supplements',
        emoji: '💊',
        categoryColor: AppColors.categoryVitals.toARGB32(),
        value: isLit && raw != null
            ? '${(raw as num).toInt()} taken'
            : null,
        lastValue: lastValue,
        lastLoggedAt: lastLoggedAt,
      ),
    'symptom' => MetricTileData(
        metricType: type,
        label: 'Symptom',
        emoji: '🩹',
        categoryColor: AppColors.categoryVitals.toARGB32(),
        // 'symptom_severity' holds the formatted severity string; 'symptom' is the log type key.
        value: isLit ? (summary.latestValues['symptom_severity'] as String?) : null,
        lastValue: lastValue,
        lastLoggedAt: lastLoggedAt,
      ),
    'heart_rate' => MetricTileData(
        metricType: type,
        label: 'Heart Rate',
        emoji: '❤️',
        categoryColor: AppColors.categoryHeart.toARGB32(),
        value:
            isLit ? '${(raw as num?)?.toInt() ?? '—'} bpm' : null,
        lastValue: lastValue,
        lastLoggedAt: lastLoggedAt,
      ),
    _ => MetricTileData(
        metricType: type,
        label: type,
        emoji: '📊',
        categoryColor: AppColors.categoryVitals.toARGB32(),
        lastValue: lastValue,
        lastLoggedAt: lastLoggedAt,
      ),
  };
}

/// Extracts the formatted last-ever value and its timestamp for [type] from
/// the [latest] map returned by `latestLogValuesProvider`.
///
/// The `/latest` endpoint returns type-specific shapes:
///   weight  → {"value_kg": 87.3, "logged_at": "...", ...}
///   steps   → {"steps": 8432,    "logged_at": "...", ...}
///   others  → {"value": 7.5,     "logged_at": "...", ...}
/// Extracts the formatted last-ever value and its timestamp for [type] from
/// the [latest] map returned by latestLogValuesProvider.
///
/// The /api/v1/metrics/latest endpoint returns a uniform shape per metric:
///   { "value": 87.3, "unit": "kg", "date": "2026-03-22" }
(String?, DateTime?) _extractLastLogged(
  String type,
  Map<String, dynamic> latest,
) {
  final raw = latest[type];
  if (raw is! Map<String, dynamic>) return (null, null);
  final entry = raw;

  // Parse the date (YYYY-MM-DD format from the server).
  DateTime? loggedAt;
  final dateStr = entry['date'] as String?;
  if (dateStr != null) {
    try {
      loggedAt = DateTime.parse(dateStr);
    } catch (_) {
      loggedAt = null;
    }
  }

  // Format value per type using the raw numeric value.
  final num? v = entry['value'] as num?;
  if (v == null) return (null, loggedAt);

  String? lastValue;
  try {
    lastValue = switch (type) {
      'weight'                                   => '${v.toStringAsFixed(1)}kg',
      'steps'                                    => formatSteps(v.toInt()),
      'sleep'                                    => formatSleepMinutes(v.toDouble()),
      'water'                                    => '${v.toStringAsFixed(0)}ml',
      'run'                                      => '${(v / 1000).toStringAsFixed(1)}km',
      'meal'                                     => '${v.toStringAsFixed(0)} kcal',
      'supplement'                               => '${v.toInt()} taken',
      'heart_rate'                               => '${v.toInt()} bpm',
      'mood' || 'energy' || 'stress'             => '${v.toStringAsFixed(1)}/10',
      'symptom'                                  => entry['unit'] as String? ?? v.toStringAsFixed(0),
      _                                          => '$v',
    };
  } catch (_) {
    lastValue = null;
  }

  return (lastValue, loggedAt);
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
    final colors = AppColorsOf(context);
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: colors.border),
      ),
    );
  }
}

// ── _MetricGridSkeleton ───────────────────────────────────────────────────────

/// Loading placeholder for the metric grid — two rows of three rounded rects.
class _MetricGridSkeleton extends StatelessWidget {
  const _MetricGridSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header placeholder
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
          child: Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(AppDimens.shapeXs),
            ),
          ),
        ),
        // Row 1: 3 tiles
        for (int row = 0; row < 2; row++) ...[
          Row(
            children: [
              for (int col = 0; col < 3; col++) ...[
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius:
                          BorderRadius.circular(AppDimens.shapeSm),
                      border: Border.all(color: colors.border),
                    ),
                  ),
                ),
                if (col < 2) const SizedBox(width: AppDimens.spaceXs),
              ],
            ],
          ),
          if (row < 1) const SizedBox(height: AppDimens.spaceXs),
        ],
      ],
    );
  }
}

// ── _MetricGridError ─────────────────────────────────────────────────────────

/// Compact error state shown when the metric grid fails to load.
class _MetricGridError extends StatelessWidget {
  const _MetricGridError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: AppDimens.iconSm,
            color: colors.textTertiary,
          ),
          const SizedBox(width: AppDimens.spaceXs),
          Text(
            "Couldn't load metrics",
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          GestureDetector(
            onTap: onRetry,
            child: Semantics(
              button: true,
              label: 'Retry loading metrics',
              child: Text(
                'Retry',
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns a time-of-day greeting string, optionally personalized with [name].
///
/// When [name] is provided and non-empty, returns e.g. "Good morning, Alex".
/// Falls back to the bare greeting when [name] is null or empty.
String _timeOfDayGreeting([String? name]) {
  final hour = DateTime.now().hour;
  String base;
  if (hour < 12) {
    base = 'Good morning';
  } else if (hour < 17) {
    base = 'Good afternoon';
  } else if (hour < 21) {
    base = 'Good evening';
  } else {
    base = 'Good night';
  }
  if (name != null && name.isNotEmpty) return '$base, $name';
  return base;
}

/// Returns a contextual subtitle for the greeting row, or null if none.
///
/// Priority order:
///   1. Sleep ≥ 180 min → "Sleep last night: Xh Ym"
///   2. Sleep < 180 min → skip sleep, show encouraging line
///   3. No sleep → Day 1: "Welcome to Zuralog", Days 2–6: "You're building
///      something real.", Day 7+: null (greeting alone suffices).
String? _greetingSubtitle(int dataDays, TodayLogSummary summary) {
  // Check for sleep data.
  final sleepMinutes = summary.latestValues['sleep'] as num?;
  if (sleepMinutes != null && sleepMinutes.toDouble() >= 180) {
    return 'Sleep last night: ${formatSleepMinutes(sleepMinutes.toDouble())}';
  }

  // No valid sleep — contextual fallback based on data maturity.
  if (dataDays == 0) return 'Welcome to Zuralog';
  if (dataDays < kMinDataDaysForMaturity) {
    return "You're building something real.";
  }
  return null; // Day 7+ with no sleep — greeting alone is sufficient.
}

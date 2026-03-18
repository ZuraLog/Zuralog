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
import 'package:zuralog/shared/widgets/streak_badge.dart';
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
          ref.invalidate(userLoggedTypesProvider);
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

            // ── Greeting + Streak ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: SectionHeader(
                title: _timeOfDayGreeting(profile?.aiName),
                trailing: feedAsync.whenOrNull(
                  data: (feed) => feed.streak != null
                      ? StreakBadge.inline(
                          count: feed.streak!.currentStreak,
                          isFrozen: feed.streak!.isFrozen,
                        )
                      : null,
                ),
              ),
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

            // ── Section: AI Insights ─────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: SectionHeader(title: 'AI Insights'),
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
                return feed.insights.map(
                  (insight) => Padding(
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
                ).toList();
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
                // No data or implausibly low score (< 20) → show the
                // sad-face zero state rather than a misleading 0 or near-0
                // ring. A real health score below 20 would be extraordinary;
                // a value that low almost always means the calculation hasn't
                // run yet or returned an error.
                if (data.dataDays == 0 || data.score < 20) {
                  return const HealthScoreZeroState();
                }
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
      loading: () => const SizedBox(height: 60),
      error: (e, _) => const SizedBox.shrink(),
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
(String?, DateTime?) _extractLastLogged(
  String type,
  Map<String, dynamic> latest,
) {
  final entry = latest[type] as Map<String, dynamic>?;
  if (entry == null) return (null, null);

  // Parse logged_at
  DateTime? loggedAt;
  final loggedAtRaw = entry['logged_at'] as String?;
  if (loggedAtRaw != null) {
    try {
      loggedAt = DateTime.parse(loggedAtRaw).toLocal();
    } catch (_) {
      loggedAt = null;
    }
  }

  // Format value per type
  String? lastValue;
  try {
    lastValue = switch (type) {
      'weight' => () {
          final v = entry['value_kg'] as num?;
          return v != null ? '${v.toStringAsFixed(1)}kg' : null;
        }(),
      'steps' => () {
          final v = entry['steps'] as num?;
          return v != null ? formatSteps(v.toInt()) : null;
        }(),
      'sleep' => () {
          final v = entry['value'] as num?;
          return v != null ? formatSleepMinutes(v.toDouble()) : null;
        }(),
      'water' => () {
          final v = entry['value'] as num?;
          return v != null ? '${v.toStringAsFixed(0)}ml' : null;
        }(),
      'run' => () {
          final v = entry['value'] as num?;
          return v != null ? '${v.toStringAsFixed(1)}km' : null;
        }(),
      'meal' => () {
          final v = entry['value'] as num?;
          return v != null ? '${v.toStringAsFixed(0)} kcal' : null;
        }(),
      'supplement' => () {
          final v = entry['value'] as num?;
          return v != null ? '${v.toInt()} taken' : null;
        }(),
      'heart_rate' => () {
          final v = entry['value'] as num?;
          return v != null ? '${v.toInt()} bpm' : null;
        }(),
      'mood' || 'energy' || 'stress' => () {
          final v = entry['value'] as num?;
          return v != null ? '${v.toStringAsFixed(1)}/10' : null;
        }(),
      'symptom' => entry['text_value'] as String?,
      _ => () {
          final v = entry['value'];
          return v != null ? '$v' : null;
        }(),
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
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _GoalsSkeleton extends StatelessWidget {
  const _GoalsSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: colors.border),
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

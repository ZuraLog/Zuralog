/// Today Feed — Tab 0 root screen.
///
/// Curated daily briefing: Health Score hero paired with the Log Ring,
/// AI insight cards, snapshot row, daily goals, and streak badge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/constants/app_constants.dart';
import 'package:zuralog/core/haptics/haptic_providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/data_maturity_banner.dart';
import 'package:zuralog/shared/widgets/health_score_widget.dart';
import 'package:zuralog/shared/widgets/health_score_zero_state.dart';
import 'package:zuralog/shared/widgets/onboarding_tooltip.dart';
import 'package:zuralog/shared/widgets/streak_badge.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── TodayFeedScreen ───────────────────────────────────────────────────────────

/// Today Feed screen — the curated daily briefing.
///
/// Displays the Health Score hero paired with the Log Ring, data maturity
/// banner, snapshot row, daily goals, AI insight cards, and streak badge.
class TodayFeedScreen extends ConsumerStatefulWidget {
  /// Creates the [TodayFeedScreen].
  const TodayFeedScreen({super.key});

  @override
  ConsumerState<TodayFeedScreen> createState() => _TodayFeedScreenState();
}

class _TodayFeedScreenState extends ConsumerState<TodayFeedScreen> {
  DateTime? _lastFabTap;

  void _openLogSheet() {
    if (!mounted) return;
    // _lastFabTap is shared across all entry points (FAB, ring tap, snapshot card tap)
    // so rapid taps from any source are all subject to the same 500ms window.
    final now = DateTime.now();
    if (_lastFabTap != null &&
        now.difference(_lastFabTap!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastFabTap = now;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ZLogGridSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    return ZuralogScaffold(
      addBottomNavPadding: true,
      floatingActionButton: ZLogFab(onPressed: _openLogSheet),
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
          // logRingProvider and snapshotProvider are derived — explicitly
          // invalidating their dependencies above causes them to recompute.
          // Also invalidate directly per spec requirement.
          ref.invalidate(logRingProvider);
          ref.invalidate(snapshotProvider);
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
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ── Health Score + Log Ring (side by side) ───────────────────────
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
                    // Log Ring — right half.
                    Flexible(
                       child: ZLogRingWidget(
                        onTap: _openLogSheet,
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

            // ── Snapshot Cards (horizontally scrollable row) ─────────────────
            _SnapshotRow(
              onCardTap: _openLogSheet,
            ),

            const SizedBox(height: AppDimens.spaceMd),

            // ── Daily Goals ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
              ),
              child: ZDailyGoalsCard(
                goals: const [], // MVP stub — Part 4 wires real goals data.
                onSetupTap: () {
                  // TODO(Part 4): Route to goals settings screen.
                },
              ),
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
                ZEmptyInsightsState(
                  onLogTap: _openLogSheet,
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
                    ZEmptyInsightsState(
                      onLogTap: _openLogSheet,
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
                // No data yet — welcome the user instead of showing a 0 ring.
                if (data.dataDays == 0 && data.score == 0) {
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

// ── _SnapshotRow ──────────────────────────────────────────────────────────────

/// Horizontally scrollable row of today's metric snapshot cards.
///
/// Hidden when the user has never logged anything (empty provider list).
class _SnapshotRow extends ConsumerWidget {
  const _SnapshotRow({required this.onCardTap});

  final VoidCallback onCardTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(snapshotProvider);

    return snapshotAsync.when(
      loading: () => const SizedBox(height: 110),
      error: (e, st) => const SizedBox.shrink(),
      data: (cards) {
        if (cards.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
            ),
            itemCount: cards.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppDimens.spaceSm),
            itemBuilder: (context, i) => ZSnapshotCard(
              data: cards[i],
              onTap: onCardTap,
            ),
          ),
        );
      },
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

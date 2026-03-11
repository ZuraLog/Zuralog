/// Today Feed — Tab 0 root screen.
///
/// Curated daily briefing: Health Score hero, AI insight cards, wellness
/// check-in, contextual quick actions, and streak badge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/haptics/haptic_providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/theme/category_colors.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/data_maturity_banner.dart';
import 'package:zuralog/shared/widgets/health_score_widget.dart';
import 'package:zuralog/shared/widgets/health_score_zero_state.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/shared/widgets/onboarding_tooltip.dart';
import 'package:zuralog/shared/widgets/quick_log_sheet.dart';
import 'package:zuralog/shared/widgets/streak_badge.dart';
import 'package:zuralog/shared/widgets/zuralog_app_bar.dart';

// ── TodayFeedScreen ───────────────────────────────────────────────────────────

/// Today Feed screen — the curated daily briefing.
///
/// Displays the Health Score hero, data maturity banner, AI insight cards,
/// contextual quick actions, streak badge, and wellness check-in card.
class TodayFeedScreen extends ConsumerWidget {
  /// Creates the [TodayFeedScreen].
  const TodayFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(healthScoreProvider);
    final feedAsync = ref.watch(todayFeedProvider);
    final bannerDismissed = ref.watch(dataMaturityBannerDismissedProvider);

    // Data maturity banner state computation.
    final dataDays = scoreAsync.valueOrNull?.dataDays ?? 0;
    final profile = ref.watch(userProfileProvider);
    final accountAge = profile?.createdAt != null
        ? DateTime.now().difference(profile!.createdAt!).inDays
        : 0;
    final accountMature = accountAge >= 7;
    final bannerMode = accountMature
        ? DataMaturityMode.stillBuilding
        : DataMaturityMode.progress;
    final wellnessCardVisible = ref.watch(wellnessCheckinCardVisibleProvider);
    final sessionDismissed = ref.watch(todayBannerSessionDismissed);
    final prefsAsync = ref.watch(userPreferencesProvider);
    final showBanner = dataDays < 7 &&
        !bannerDismissed &&
        !prefsAsync.isLoading && // Don't show banner while prefs loading — avoids silent dismiss drop
        (bannerMode == DataMaturityMode.progress || !sessionDismissed);

    void persistBannerDismissed() => ref
        .read(userPreferencesProvider.notifier)
        .mutate((p) => p.copyWith(dataMaturityBannerDismissed: true));

    return ZuralogScaffold(
      addBottomNavPadding: true,
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
        color: AppColors.primary,
        backgroundColor: AppColors.cardBackgroundDark,
        onRefresh: () async {
          ref.read(todayRepositoryProvider).invalidateFeedCache();
          ref.invalidate(healthScoreProvider);
          ref.invalidate(todayFeedProvider);
          await Future.wait([
            ref
                .read(healthScoreProvider.future)
                .catchError((Object _) => HealthScoreData(score: 0, trend: [])),
            ref
                .read(todayFeedProvider.future)
                .catchError(
                  (Object _) => TodayFeedData(
                    insights: [],
                    quickActions: [],
                    streak: null,
                  ),
                ),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ── Health Score hero ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
              ),
              child: OnboardingTooltip(
                screenKey: 'today_feed',
                tooltipKey: 'health_score',
                message: 'This is your daily health score — a composite of '
                    'all your health data from the last 24 hours.',
                child: _HealthScoreHero(scoreAsync: scoreAsync),
              ),
            ),

            // ── Data Maturity banner ────────────────────────────────────────
            if (showBanner)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: DataMaturityBanner(
                  daysWithData: dataDays,
                  targetDays: 7,
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

            // ── Section: Time-of-day greeting + streak ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: _SectionHeader(
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

            // ── AI Insight cards ────────────────────────────────────────────
            // Provider never errors — only loading and data branches needed.
            ...feedAsync.when(
              // Safety net: provider catches all errors and returns empty data,
              // so this branch should never be reached in practice.
              error: (err, stack) => [const _EmptyInsightsCard()],
              loading: () => [
                const SizedBox(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
              data: (feed) {
                if (feed.insights.isEmpty) {
                  return [const _EmptyInsightsCard()];
                }
                return feed.insights.map(
                  (insight) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceXs,
                    ),
                    child: _InsightCard(
                      insight: insight,
                      onTap: () {
                        ref.read(hapticServiceProvider).light();
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

            // ── Section: Quick Actions ──────────────────────────────────────
            if (feedAsync.hasValue &&
                feedAsync.value!.quickActions.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceLg,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: _SectionHeader(title: 'Quick Actions'),
              ),
              ...feedAsync.value!.quickActions.map((action) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                    vertical: AppDimens.spaceXs,
                  ),
                  child: _QuickActionCard(
                    action: action,
                    onTap: () {
                      ref.read(hapticServiceProvider).light();
                      ref.read(analyticsServiceProvider).capture(
                        event: AnalyticsEvents.quickActionTapped,
                        properties: {
                          'title': action.title,
                          'action_type': action.actionType,
                        },
                      );
                      switch (action.actionType) {
                        case 'log_water':
                          _showQuickLog(context, ref,
                              initialMetric: 'water');
                        case 'log_mood':
                          _showQuickLog(context, ref,
                              initialMetric: 'mood');
                        case 'log_meal':
                        case 'log_nutrition':
                          _showQuickLog(context, ref);
                        case 'log_energy':
                          _showQuickLog(context, ref,
                              initialMetric: 'energy');
                        case 'log_stress':
                          _showQuickLog(context, ref,
                              initialMetric: 'stress');
                        default:
                          final route = action.route;
                          if (route != null) context.go(route);
                      }
                    },
                  ),
                );
              }),
            ],

            // ── Wellness Check-in card ──────────────────────────────────────
            if (wellnessCardVisible)
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceLg,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                ),
                child: _WellnessCheckinCard(),
              ),
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
              color: AppColors.cardBackgroundDark,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: scoreAsync.when(
              // Provider never errors — this branch is a safety net only.
              error: (err, stack) => const HealthScoreZeroState(),
              loading: () => const SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
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

// ── _SectionHeader ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Editorial left accent bar — 3×18px sage green.
        Container(
          width: 3,
          height: 18,
          margin: const EdgeInsets.only(right: AppDimens.spaceSm),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.displaySmall.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ── _InsightCard ──────────────────────────────────────────────────────────────

class _InsightCard extends ConsumerStatefulWidget {
  const _InsightCard({required this.insight, required this.onTap});

  final InsightCard insight;
  final VoidCallback onTap;

  @override
  ConsumerState<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends ConsumerState<_InsightCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final categoryColor = categoryColorFromString(widget.insight.category);
    final isUnread = !widget.insight.isRead;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        ref.read(analyticsServiceProvider).capture(
          event: AnalyticsEvents.insightCardTapped,
          properties: {
            'insight_id': widget.insight.id,
            'insight_type': widget.insight.type.name,
            'category': widget.insight.category,
            'is_unread': !widget.insight.isRead,
          },
        );
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          child: Stack(
            children: [
              // Category-color radial glow (unread only) — top-right.
              if (isUnread)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.9, -0.9),
                          radius: 0.7,
                          colors: [
                            categoryColor.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Card body.
              Container(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.cardBackgroundDark,
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  border: Border.all(
                    color: isUnread
                        ? categoryColor.withValues(alpha: 0.20)
                        : AppColors.borderDark,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left accent bar for unread — 3px category-colored stripe.
                      if (isUnread)
                        Container(
                          width: 3,
                          height: double.infinity,
                          constraints:
                              const BoxConstraints(minHeight: 60),
                          margin: const EdgeInsets.only(
                              right: AppDimens.spaceSm),
                          decoration: BoxDecoration(
                            color: categoryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      // Category color icon badge.
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusSm),
                        ),
                        child: Icon(
                          _insightIcon(widget.insight.type),
                          size: AppDimens.iconMd,
                          color: categoryColor,
                        ),
                      ),
                      const SizedBox(width: AppDimens.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isUnread) ...[
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: categoryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppDimens.spaceXs),
                                ],
                                Expanded(
                                   child: Text(
                                     widget.insight.title,
                                     style: AppTextStyles.titleMedium.copyWith(
                                       color: AppColors.textPrimaryDark,
                                     ),
                                     maxLines: 2,
                                     overflow: TextOverflow.ellipsis,
                                   ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.insight.summary,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppDimens.spaceSm),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: categoryColor
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppDimens.radiusChip,
                                    ),
                                  ),
                                   child: Text(
                                     widget.insight.category,
                                     style: AppTextStyles.labelSmall.copyWith(
                                       color: categoryColor,
                                       fontWeight: FontWeight.w600,
                                     ),
                                   ),
                                ),
                                const Spacer(),
                                if (widget.insight.createdAt != null)
                                   Text(
                                     _relativeTime(widget.insight.createdAt!),
                                     style: AppTextStyles.labelSmall.copyWith(
                                       color: AppColors.textTertiary,
                                     ),
                                   ),
                                const SizedBox(width: AppDimens.spaceXs),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: AppDimens.iconSm,
                                  color: AppColors.primary
                                      .withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _QuickActionCard ──────────────────────────────────────────────────────────

class _QuickActionCard extends StatefulWidget {
  const _QuickActionCard({required this.action, required this.onTap});

  final QuickAction action;
  final VoidCallback onTap;

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.cardBackgroundDark,
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: AppDimens.iconMd,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.action.title,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    if (widget.action.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.action.subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: AppDimens.iconMd,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _WellnessCheckinCard ──────────────────────────────────────────────────────

/// Inline wellness check-in card — launches QuickLogSheet on tap.
class _WellnessCheckinCard extends ConsumerStatefulWidget {
  const _WellnessCheckinCard();

  @override
  ConsumerState<_WellnessCheckinCard> createState() =>
      _WellnessCheckinCardState();
}

class _WellnessCheckinCardState extends ConsumerState<_WellnessCheckinCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        ref.read(hapticServiceProvider).light();
        _showQuickLog(context, ref);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          child: Stack(
            children: [
              // Wellness-color radial glow — top-right corner.
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.9, -0.9),
                        radius: 0.8,
                        colors: [
                          AppColors.categoryWellness.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.cardBackgroundDark,
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  border: Border.all(
                    color: AppColors.categoryWellness.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            AppColors.categoryWellness.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: const Icon(
                        Icons.self_improvement_rounded,
                        size: AppDimens.iconMd,
                        color: AppColors.categoryWellness,
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(
                            'Wellness check-in',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.textPrimaryDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Log mood, energy, and water intake',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      size: AppDimens.iconMd,
                      color: AppColors.categoryWellness,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _EmptyInsightsCard ────────────────────────────────────────────────────────

class _EmptyInsightsCard extends ConsumerWidget {
  const _EmptyInsightsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm + 4),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 24,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Insights on the way',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your AI coach is ready — start logging to unlock personalized observations.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            // Two action prompts
            _InsightActionRow(
              icon: Icons.self_improvement_rounded,
              color: AppColors.categoryWellness,
              label: 'Log today\'s mood & energy',
              onTap: () => _showQuickLog(context, ref),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            _InsightActionRow(
              icon: Icons.cable_rounded,
              color: AppColors.categoryActivity,
              label: 'Connect a health app',
              onTap: () => context.push(RouteNames.settingsIntegrationsPath),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightActionRow extends StatefulWidget {
  const _InsightActionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  State<_InsightActionRow> createState() => _InsightActionRowState();
}

class _InsightActionRowState extends State<_InsightActionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm + 4),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: widget.color),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: widget.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: widget.color.withValues(alpha: 0.6),
              ),
            ],
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

/// Returns a human-readable relative time string (e.g. "2h ago").
String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Returns an icon for the given [InsightType].
IconData _insightIcon(InsightType type) {
  switch (type) {
    case InsightType.anomaly:
      return Icons.warning_amber_rounded;
    case InsightType.correlation:
      return Icons.compare_arrows_rounded;
    case InsightType.trend:
      return Icons.trending_up_rounded;
    case InsightType.recommendation:
      return Icons.tips_and_updates_rounded;
    case InsightType.achievement:
      return Icons.emoji_events_rounded;
    case InsightType.unknown:
      return Icons.lightbulb_outline_rounded;
  }
}

/// Shows the QuickLogSheet bottom sheet and handles submission.
void _showQuickLog(
  BuildContext context,
  WidgetRef ref, {
  String? initialMetric,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.25,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: const [0.75, 0.95],
      shouldCloseOnMinExtent: true,
      builder: (_, scrollController) => Consumer(
        builder: (ctx, r, _) {
          final isLoading = r.watch(quickLogLoadingProvider);
          return QuickLogSheet(
            isLoading: isLoading,
            initialMetric: initialMetric,
            scrollController: scrollController,
            onSubmit: (data) async {
              r.read(quickLogLoadingProvider.notifier).state = true;
              try {
                await r.read(todayRepositoryProvider).submitQuickLog({
                  'mood': data.mood,
                  'energy': data.energy,
                  'stress': data.stress,
                  'water_glasses': data.waterGlasses,
                  'notes': data.notes,
                  'symptoms': data.symptoms,
                });
                r.read(hapticServiceProvider).success();
                r.read(analyticsServiceProvider).capture(
                  event: AnalyticsEvents.quickLogSubmitted,
                  properties: {
                    'has_mood': data.mood > 0,
                    'has_energy': data.energy > 0,
                    'has_stress': data.stress > 0,
                    'water_glasses': data.waterGlasses,
                    'has_notes': data.notes.isNotEmpty,
                    'symptoms_count': data.symptoms.length,
                  },
                );
                // First-use guard.
                SharedPreferences.getInstance().then((prefs) {
                  if (prefs.getBool('analytics_first_quick_log') != true) {
                    prefs.setBool('analytics_first_quick_log', true);
                    r.read(analyticsServiceProvider).capture(
                      event: AnalyticsEvents.firstQuickLog,
                    );
                  }
                });
                r.invalidate(todayFeedProvider);
                r.invalidate(healthScoreProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
              } catch (_) {
                r.read(hapticServiceProvider).warning();
              } finally {
                r.read(quickLogLoadingProvider.notifier).state = false;
              }
            },
          );
        },
      ),
    ),
  );
}

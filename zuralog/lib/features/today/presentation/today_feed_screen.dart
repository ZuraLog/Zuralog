/// Today Feed — Tab 0 root screen.
///
/// Curated daily briefing: Health Score hero, AI insight cards, wellness
/// check-in, contextual quick actions, streak badge, and Quick Log FAB.
///
/// Full implementation: Phase 3, Task 3.1.
/// Design elevation: Phase 3 elevation pass — editorial animations & micro-interactions.
library;

import 'dart:ui' as ui;

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
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/data_maturity_banner.dart';
import 'package:zuralog/shared/widgets/health_score_widget.dart';
import 'package:zuralog/shared/widgets/onboarding_tooltip.dart';
import 'package:zuralog/shared/widgets/profile_avatar_button.dart';
import 'package:zuralog/shared/widgets/quick_log_sheet.dart';
import 'package:zuralog/shared/widgets/streak_badge.dart';

// ── TodayFeedScreen ───────────────────────────────────────────────────────────

/// Today Feed screen — the curated daily briefing.
///
/// Displays the Health Score hero, data maturity banner, AI insight cards,
/// contextual quick actions, streak badge, and Quick Log FAB.
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

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: _TodayAppBar(feedAsync: feedAsync),
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
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Health Score hero ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceLg,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                ),
                child: _FadeSlideIn(
                  delay: Duration.zero,
                  child: OnboardingTooltip(
                    screenKey: 'today_feed',
                    tooltipKey: 'health_score',
                    message: 'This is your daily health score — a composite of '
                        'all your health data from the last 24 hours.',
                    child: _HealthScoreHero(scoreAsync: scoreAsync),
                  ),
                ),
              ),
            ),

            // ── Data Maturity banner ──────────────────────────────────────
            if (showBanner)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                  ),
                  child: DataMaturityBanner(
                    daysWithData: dataDays,
                    targetDays: 7,
                    mode: bannerMode,
                    onDismiss: bannerMode == DataMaturityMode.progress
                        ? persistBannerDismissed
                        : () => ref.read(todayBannerSessionDismissed.notifier).state = true,
                    onPermanentDismiss: bannerMode == DataMaturityMode.stillBuilding
                        ? persistBannerDismissed
                        : null,
                  ),
                ),
              ),

            // ── Section: Time-of-day greeting + streak ────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceLg,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: _FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
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
              ),
            ),

            // ── AI Insight cards ──────────────────────────────────────────
            feedAsync.when(
              data: (feed) {
                if (feed.insights.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: _EmptyInsightsCard(),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceXs,
                      ),
                      child: _FadeSlideIn(
                        delay: Duration(milliseconds: 80 + index * 50),
                        child: _InsightCard(
                          insight: feed.insights[index],
                          onTap: () async {
                            ref.read(hapticServiceProvider).light();
                            context.pushNamed(
                              RouteNames.insightDetail,
                              pathParameters: {
                                'id': feed.insights[index].id,
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    childCount: feed.insights.length,
                  ),
                );
              },
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceXs,
                    ),
                    child: _InsightCardSkeleton(),
                  ),
                  childCount: 3,
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: _ErrorCard(
                    message: 'Could not load insights.',
                    onRetry: () => ref.invalidate(todayFeedProvider),
                  ),
                ),
              ),
            ),

            // ── Section: Quick Actions (hidden on error) ─────────────────
            if (feedAsync.hasValue &&
                feedAsync.value!.quickActions.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceLg,
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                  ),
                  child: _FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: const _SectionHeader(title: 'Quick Actions'),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final actions = feedAsync.value!.quickActions;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceXs,
                      ),
                      child: _FadeSlideIn(
                        delay: Duration(milliseconds: 220 + index * 50),
                        child: _QuickActionCard(
                          action: actions[index],
                          onTap: () {
                            ref.read(hapticServiceProvider).light();
                            ref.read(analyticsServiceProvider).capture(
                              event: AnalyticsEvents.quickActionTapped,
                              properties: {
                                'title': actions[index].title,
                                'action_type': actions[index].actionType,
                              },
                            );
                            final action = actions[index];
                            switch (action.actionType) {
                              case 'log_water':
                                _showQuickLog(context, ref, initialMetric: 'water');
                              case 'log_mood':
                                _showQuickLog(context, ref, initialMetric: 'mood');
                              case 'log_meal':
                              case 'log_nutrition':
                                _showQuickLog(context, ref);
                              case 'log_energy':
                                _showQuickLog(context, ref, initialMetric: 'energy');
                              case 'log_stress':
                                _showQuickLog(context, ref, initialMetric: 'stress');
                              default:
                                final route = action.route;
                                if (route != null) context.go(route);
                            }
                          },
                        ),
                      ),
                    );
                  },
                  childCount: feedAsync.value!.quickActions.length,
                ),
              ),
            ] else if (feedAsync.isLoading) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceLg,
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                  ),
                  child: _FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: const _SectionHeader(title: 'Quick Actions'),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceXs,
                    ),
                    child: _QuickActionSkeleton(),
                  ),
                  childCount: 2,
                ),
              ),
            ],

            // ── Wellness Check-in card ────────────────────────────────────
            if (wellnessCardVisible)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceLg,
                    AppDimens.spaceMd,
                    AppDimens.bottomClearance(context),
                  ),
                  child: _FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: const _WellnessCheckinCard(),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _QuickLogFAB(),
    );
  }
}

// ── _TodayAppBar ──────────────────────────────────────────────────────────────

class _TodayAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _TodayAppBar({required this.feedAsync});

  final AsyncValue<TodayFeedData> feedAsync;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: AppColors.backgroundDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        _formattedDate(),
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: AppColors.textSecondary,
          ),
          onPressed: () {
            ref.read(hapticServiceProvider).light();
            ref.read(analyticsServiceProvider).capture(
              event: AnalyticsEvents.notificationHistoryViewed,
            );
            context.pushNamed(RouteNames.notificationHistory);
          },
          tooltip: 'Notifications',
        ),
        const Padding(
          padding: EdgeInsets.only(right: AppDimens.spaceMd),
          child: ProfileAvatarButton(),
        ),
      ],
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
              data: (data) => Column(
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
              ),
              loading: () => const _ScoreHeroSkeleton(),
              error: (_, st) => GestureDetector(
                onTap: () => ref.invalidate(healthScoreProvider),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.spaceSm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Small placeholder ring with dash.
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.textTertiary.withValues(alpha: 0.3),
                            width: 4,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '—',
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.spaceMd),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Score unavailable',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppDimens.spaceXs),
                              Text(
                                'Tap to retry',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
            style: AppTextStyles.h2.copyWith(
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
    final categoryColor = _categoryColor(widget.insight.category);
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
                        constraints: const BoxConstraints(minHeight: 60),
                        margin: const EdgeInsets.only(right: AppDimens.spaceSm),
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
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
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
                                  style: AppTextStyles.h3.copyWith(
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
                                  color: categoryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusChip,
                                  ),
                                ),
                                child: Text(
                                  widget.insight.category,
                                  style: AppTextStyles.labelXs.copyWith(
                                    color: categoryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (widget.insight.createdAt != null)
                                Text(
                                  _relativeTime(widget.insight.createdAt!),
                                  style: AppTextStyles.labelXs.copyWith(
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
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    if (widget.action.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.action.subtitle,
                        style: AppTextStyles.caption.copyWith(
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
                        color: AppColors.categoryWellness.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
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
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.textPrimaryDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Log mood, energy, and water intake',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
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

// ── _QuickLogFAB ──────────────────────────────────────────────────────────────

class _QuickLogFAB extends ConsumerStatefulWidget {
  const _QuickLogFAB();

  @override
  ConsumerState<_QuickLogFAB> createState() => _QuickLogFABState();
}

class _QuickLogFABState extends ConsumerState<_QuickLogFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 0.88, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 20),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onPressed() async {
    ref.read(hapticServiceProvider).medium();
    ref.read(analyticsServiceProvider).capture(
      event: AnalyticsEvents.quickLogOpened,
      properties: {'source': 'fab'},
    );
    await _ctrl.forward(from: 0);
    if (mounted) _showQuickLog(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: FloatingActionButton(
        onPressed: _onPressed,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryButtonText,
        elevation: 0,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

// ── Skeleton widgets ──────────────────────────────────────────────────────────

class _ScoreHeroSkeleton extends StatelessWidget {
  const _ScoreHeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Shimmer(
          child: Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: AppColors.cardBackgroundDark,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        _Shimmer(
          child: Container(
            width: 160,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.cardBackgroundDark,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightCardSkeleton extends StatelessWidget {
  const _InsightCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Shimmer(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Shimmer(
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _Shimmer(
                  child: Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionSkeleton extends StatelessWidget {
  const _QuickActionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          _Shimmer(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: _Shimmer(
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInsightsCard extends StatelessWidget {
  const _EmptyInsightsCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
          vertical: AppDimens.spaceXl,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm + 4),
              ),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                size: 28,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'No insights yet',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              'Keep logging data to unlock\nAI-powered health insights.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.statusError.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 18,
              color: AppColors.statusError.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimens.radiusButton),
              ),
              child: Text(
                'Retry',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
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

// ── _FadeSlideIn ──────────────────────────────────────────────────────────────

/// Staggered fade + 6% slide-up entrance animation.
///
/// Animates once when the widget is first built. Pass a [delay] to create
/// a cascade effect across a list of items.
class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── _Shimmer ──────────────────────────────────────────────────────────────────

/// Horizontal shimmer sweep via ShaderMask + LinearGradient (1200ms loop).
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        // Sweep from -1 → +2 across the widget width.
        final progress = _ctrl.value;
        final shimmerStart = progress * 3.0 - 1.0;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => ui.Gradient.linear(
            Offset(bounds.width * shimmerStart, 0),
            Offset(bounds.width * (shimmerStart + 1.0), 0),
            const [
              AppColors.shimmerBase,
              AppColors.shimmerHighlight,
              AppColors.shimmerBase,
            ],
            const [0.0, 0.5, 1.0],
          ),
          child: child,
        );
      },
      child: widget.child,
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

/// Returns a formatted date string for the app bar (e.g. "Wednesday, Mar 4").
String _formattedDate() {
  final now = DateTime.now();
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final weekday = weekdays[now.weekday - 1];
  final month = months[now.month - 1];
  return '$weekday, $month ${now.day}';
}

/// Returns a human-readable relative time string (e.g. "2h ago").
String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Returns the category color token for a health category string.
Color _categoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'sleep':
      return AppColors.categorySleep;
    case 'activity':
    case 'fitness':
      return AppColors.categoryActivity;
    case 'heart':
    case 'cardio':
      return AppColors.categoryHeart;
    case 'body':
    case 'weight':
      return AppColors.categoryBody;
    case 'nutrition':
    case 'food':
      return AppColors.categoryNutrition;
    case 'wellness':
    case 'mood':
      return AppColors.categoryWellness;
    case 'vitals':
      return AppColors.categoryVitals;
    case 'cycle':
      return AppColors.categoryCycle;
    case 'mobility':
      return AppColors.categoryMobility;
    case 'environment':
      return AppColors.categoryEnvironment;
    default:
      return AppColors.primary;
  }
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

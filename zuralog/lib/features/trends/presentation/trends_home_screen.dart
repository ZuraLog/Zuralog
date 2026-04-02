/// Trends Home Screen — Tab 4 root screen.
///
/// Single-screen Trends experience: filter chips, hero pattern card,
/// ranked pattern feed, and in-place card expansion with sparkline charts.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/trends/domain/trends_models.dart';
import 'package:zuralog/features/trends/providers/trends_providers.dart';
import 'package:zuralog/features/subscription/domain/subscription_providers.dart';
import 'package:zuralog/features/trends/presentation/widgets/suggestion_card.dart';
import 'package:zuralog/features/trends/presentation/widgets/time_machine_strip.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/cards/z_locked_overlay.dart';
import 'package:zuralog/shared/widgets/cards/z_topographic_card.dart';
import 'package:zuralog/shared/widgets/feedback/z_premium_gate_sheet.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/shared/widgets/loading/z_loading_skeleton.dart';
import 'package:zuralog/shared/widgets/z_badge.dart';
import 'package:zuralog/shared/widgets/zuralog_app_bar.dart';

// ── Helper Functions ──────────────────────────────────────────────────────────

Color _categoryColor(String category, BuildContext context) {
  switch (category) {
    case 'sleep':
      return AppColors.categorySleep;
    case 'activity':
      return AppColors.categoryActivity;
    case 'heart':
      return AppColors.categoryHeart;
    case 'nutrition':
      return AppColors.categoryNutrition;
    case 'body':
      return AppColors.categoryBody;
    case 'wellness':
      return AppColors.categoryWellness;
    default:
      return AppColorsOf(context).trendsSage;
  }
}

String _strengthLabel(double coefficient) {
  final abs = coefficient.abs();
  if (abs >= 0.7) return 'Strong';
  if (abs >= 0.4) return 'Moderate';
  return 'Weak';
}

// ── TrendsHomeScreen ──────────────────────────────────────────────────────────

/// Root widget for the Trends tab.
class TrendsHomeScreen extends ConsumerWidget {
  const TrendsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(trendsHomeProvider);
    final isPremium = ref.watch(isPremiumProvider);

    String? subtitle;
    if (trendsAsync.hasValue) {
      final data = trendsAsync.value!;
      if (data.patternCount > 0) {
        // Free users see "3 of N patterns" when there are more than 3.
        subtitle = !isPremium && data.patternCount > 3
            ? '3 of ${data.patternCount} patterns'
            : '${data.patternCount} patterns discovered';
      }
    }

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: 'Trends',
        subtitle: subtitle,
      ),
      body: trendsAsync.when(
        loading: () => const _TrendsLoadingSkeleton(),
        error: (err, stack) => const _TrendsEmptyState(),
        data: (data) => _TrendsHomeBody(data: data, subtitle: subtitle),
      ),
    );
  }
}

// ── _TrendsHomeBody ───────────────────────────────────────────────────────────

class _TrendsHomeBody extends ConsumerStatefulWidget {
  const _TrendsHomeBody({required this.data, this.subtitle});

  final TrendsHomeData data;
  final String? subtitle;

  @override
  ConsumerState<_TrendsHomeBody> createState() => _TrendsHomeBodyState();
}

class _TrendsHomeBodyState extends ConsumerState<_TrendsHomeBody>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  List<CurvedAnimation> _animations = [];

  List<CorrelationHighlight> _buildFilteredList(String category) {
    final all = widget.data.correlationHighlights;
    final filtered =
        category == 'all' ? all : all.where((h) => h.category == category).toList();
    final sorted = [...filtered]
      ..sort((a, b) => b.coefficient.abs().compareTo(a.coefficient.abs()));
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    final category = ref.read(selectedCategoryFilterProvider);
    final filtered = _buildFilteredList(category);
    _buildAnimations(filtered.length);
  }

  void _buildAnimations(int count) {
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600 + count * 60),
    )..forward();

    _animations = List.generate(count + 1, (i) {
      final start = (i * 0.06).clamp(0.0, 1.0);
      final end = (i * 0.06 + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });
  }

  @override
  void dispose() {
    for (final anim in _animations) {
      anim.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _animFor(int index) {
    if (index < _animations.length) return _animations[index];
    return _animations.last;
  }

  String _capitalize(String category) =>
      category.isEmpty ? category : category[0].toUpperCase() + category.substring(1);

  /// Maximum number of patterns visible to free users (1 hero + 2 feed).
  static const _freePatternLimit = 3;

  @override
  Widget build(BuildContext context) {
    final category = ref.watch(selectedCategoryFilterProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final filtered = _buildFilteredList(category);

    final hero = filtered.isNotEmpty ? filtered.first : null;
    final allFeed =
        filtered.length > 1 ? filtered.sublist(1) : <CorrelationHighlight>[];

    // Free users see at most 2 unlocked feed cards (hero + 2 = 3 total).
    final int unlockedFeedCount =
        isPremium ? allFeed.length : (allFeed.length).clamp(0, _freePatternLimit - 1);
    final feed = allFeed;

    return RefreshIndicator(
      color: AppColorsOf(context).trendsSage,
      onRefresh: () async {
        ref.read(hapticServiceProvider).light();
        ref.invalidate(trendsHomeProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Filter chips row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppDimens.spaceSm),
              child: _FilterChipsRow(
                onCategoryChanged: (cat) {
                  final newFiltered = _buildFilteredList(cat);
                  for (final anim in _animations) {
                    anim.dispose();
                  }
                  _animations.clear();
                  if (_controller.isAnimating) _controller.stop();
                  _controller.dispose();
                  _buildAnimations(newFiltered.length);
                },
              ),
            ),
          ),

          // Empty state when not enough data
          if (!widget.data.hasEnoughData)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _TrendsEmptyState(),
            )
          // Data is ready but no correlations have been found yet
          else if (!widget.data.hasCorrelations)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _TrendsNoCorrelationsState(),
            )
          // Empty state when a category filter yields no results
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceLg,
                  ),
                  child: Text(
                    category == 'all'
                        ? 'No patterns found yet — keep logging and we\'ll discover your first connection soon.'
                        : 'No ${_capitalize(category)} patterns found.\nTry a different category or log more $category data.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColorsOf(context).trendsTextMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else ...[
            // Hero card
            if (hero != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceMd,
                    AppDimens.spaceMd,
                    0,
                  ),
                  child: FadeTransition(
                    opacity: _animFor(0),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(_animFor(0)),
                      child: _HeroPatternCard(highlight: hero),
                    ),
                  ),
                ),
              ),

            // Section header
            if (feed.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceLg,
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                  ),
                  child: _SectionHeader(title: 'Patterns'),
                ),
              ),

            // Ranked feed
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final h = feed[index];
                  // +1 because hero is index 0 in animation list
                  final anim = _animFor(index + 1);
                  final isLocked = index >= unlockedFeedCount;

                  Widget card = _PatternCard(
                    highlight: h,
                    isLocked: isLocked,
                  );

                  if (isLocked) {
                    card = ZLockedOverlay(
                      headline: 'See all your patterns',
                      body:
                          'Upgrade to Pro to explore every pattern Zuralog discovers in your data.',
                      icon: Icons.auto_awesome_rounded,
                      child: card,
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceSm / 2,
                    ),
                    child: FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(anim),
                        child: card,
                      ),
                    ),
                  );
                },
                childCount: feed.length,
              ),
            ),

            // Time Machine — weekly summaries (Pro only)
            if (isPremium && widget.data.timePeriods.isNotEmpty)
              SliverToBoxAdapter(
                child: TimeMachineStrip(periods: widget.data.timePeriods),
              ),

            // Suggestion Cards — AI-suggested data gaps (Pro only)
            if (isPremium && widget.data.suggestionCards.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceLg,
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                  ),
                  child: _SectionHeader(title: 'Unlock more patterns'),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceSm / 2,
                      ),
                      child: SuggestionCard(
                        suggestion: widget.data.suggestionCards[index],
                      ),
                    );
                  },
                  childCount: widget.data.suggestionCards.length,
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceXl)),
          ],
        ],
      ),
    );
  }
}

// ── _HeroPatternCard ──────────────────────────────────────────────────────────

class _HeroPatternCard extends ConsumerStatefulWidget {
  const _HeroPatternCard({required this.highlight});

  final CorrelationHighlight highlight;

  @override
  ConsumerState<_HeroPatternCard> createState() => _HeroPatternCardState();
}

class _HeroPatternCardState extends ConsumerState<_HeroPatternCard> {
  void _handleTap() {
    final h = widget.highlight;
    final strength = _strengthLabel(h.coefficient);
    final isExpanded = ref.read(expandedPatternIdsProvider).contains(h.id);

    ref.read(hapticServiceProvider).light();
    ref.read(analyticsServiceProvider).capture(
      event: AnalyticsEvents.trendsPatternTapped,
      properties: {
        'pattern_id': h.id,
        'category': h.category,
        'strength': strength,
        'is_new': h.isNew,
      },
    );

    if (!isExpanded) {
      ref.read(analyticsServiceProvider).capture(
        event: AnalyticsEvents.trendsPatternExpanded,
        properties: {'pattern_id': h.id, 'category': h.category},
      );
    }

    ref.read(expandedPatternIdsProvider.notifier).update((set) {
      final next = Set<String>.from(set);
      if (next.contains(h.id)) {
        next.remove(h.id);
      } else {
        next.add(h.id);
      }
      return next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.highlight;
    final catColor = _categoryColor(h.category, context);
    final strength = _strengthLabel(h.coefficient);
    final directionText = h.direction == CorrelationDirection.positive
        ? 'Positive relationship'
        : h.direction == CorrelationDirection.negative
            ? 'Negative relationship'
            : 'Neutral relationship';
    final isExpanded = ref.watch(expandedPatternIdsProvider).contains(h.id);

    return GestureDetector(
      onTap: _handleTap,
      child: ZTopographicCard(
        accentColor: catColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Eyebrow row
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: catColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Text(
                  'Strongest Pattern',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: catColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (h.isNew)
                  ZBadge(
                    label: 'New',
                    color: catColor.withValues(alpha: 0.18),
                    textColor: catColor,
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),

            // Headline
            Text(
              h.headline,
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColorsOf(context).trendsTextPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // Metric pills
            Row(
              children: [
                ZBadge(
                  label: h.metricA,
                  color: catColor.withValues(alpha: 0.15),
                  textColor: catColor,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                ZBadge(
                  label: h.metricB,
                  color: catColor.withValues(alpha: 0.10),
                  textColor: catColor.withValues(alpha: 0.8),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // Strength row
            Row(
              children: [
                ZBadge(
                  label: strength,
                  color: catColor.withValues(alpha: 0.15),
                  textColor: catColor,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Text(
                  h.coefficient.toStringAsFixed(2),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColorsOf(context).trendsTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Text(
                  '·  $directionText',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColorsOf(context).trendsTextMuted,
                  ),
                ),
              ],
            ),

            // Tap hint
            if (!isExpanded) ...[
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                'Tap to explore',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColorsOf(context).trendsTextMuted,
                ),
              ),
            ],

            // Expansion
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              child: isExpanded
                  ? _ExpandedPatternContent(
                      patternId: h.id,
                      categoryColor: catColor,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _PatternCard ──────────────────────────────────────────────────────────────

class _PatternCard extends ConsumerStatefulWidget {
  const _PatternCard({required this.highlight, this.isLocked = false});

  final CorrelationHighlight highlight;

  /// Whether this card is behind the premium gate (cannot expand).
  final bool isLocked;

  @override
  ConsumerState<_PatternCard> createState() => _PatternCardState();
}

class _PatternCardState extends ConsumerState<_PatternCard> {
  void _handleTap() {
    final h = widget.highlight;

    ref.read(hapticServiceProvider).light();

    // Locked cards cannot expand — show the premium gate instead.
    if (widget.isLocked) {
      ZPremiumGateSheet.show(
        context,
        headline: 'See all your patterns',
        body:
            'Upgrade to Pro to explore every pattern Zuralog discovers in your data.',
        icon: Icons.auto_awesome_rounded,
      );
      return;
    }

    final strength = _strengthLabel(h.coefficient);
    final isExpanded = ref.read(expandedPatternIdsProvider).contains(h.id);

    ref.read(analyticsServiceProvider).capture(
      event: AnalyticsEvents.trendsPatternTapped,
      properties: {
        'pattern_id': h.id,
        'category': h.category,
        'strength': strength,
        'is_new': h.isNew,
      },
    );

    if (!isExpanded) {
      ref.read(analyticsServiceProvider).capture(
        event: AnalyticsEvents.trendsPatternExpanded,
        properties: {'pattern_id': h.id, 'category': h.category},
      );
    }

    ref.read(expandedPatternIdsProvider.notifier).update((set) {
      final next = Set<String>.from(set);
      if (next.contains(h.id)) {
        next.remove(h.id);
      } else {
        next.add(h.id);
      }
      return next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.highlight;
    final catColor = _categoryColor(h.category, context);
    final strength = _strengthLabel(h.coefficient);
    final isExpanded = ref.watch(expandedPatternIdsProvider).contains(h.id);

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColorsOf(context).trendsSurface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: h.isNew
              ? Border(
                  left: BorderSide(width: 3, color: catColor),
                  top: BorderSide(color: AppColorsOf(context).trendsBorderDefault),
                  right: BorderSide(color: AppColorsOf(context).trendsBorderDefault),
                  bottom: BorderSide(color: AppColorsOf(context).trendsBorderDefault),
                )
              : Border.all(color: AppColorsOf(context).trendsBorderDefault),
        ),
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: New badge + strength badge
            Row(
              children: [
                if (h.isNew) ...[
                  ZBadge(
                    label: 'New',
                    color: catColor.withValues(alpha: 0.18),
                    textColor: catColor,
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                ],
                const Spacer(),
                ZBadge(
                  label: strength,
                  color: catColor.withValues(alpha: 0.15),
                  textColor: catColor,
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),

            // Headline
            Text(
              h.headline,
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColorsOf(context).trendsTextPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppDimens.spaceXs),

            // Body text
            Text(
              h.body,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColorsOf(context).trendsTextSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppDimens.spaceSm),

            // Metric pills
            Row(
              children: [
                ZBadge(
                  label: h.metricA,
                  color: catColor.withValues(alpha: 0.12),
                  textColor: catColor,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                ZBadge(
                  label: h.metricB,
                  color: catColor.withValues(alpha: 0.08),
                  textColor: catColor.withValues(alpha: 0.75),
                ),
              ],
            ),

            // Expansion
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              child: isExpanded
                  ? _ExpandedPatternContent(
                      patternId: h.id,
                      categoryColor: catColor,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _ExpandedPatternContent ───────────────────────────────────────────────────

class _ExpandedPatternContent extends ConsumerWidget {
  const _ExpandedPatternContent({
    required this.patternId,
    required this.categoryColor,
  });

  final String patternId;
  final Color categoryColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandAsync = ref.watch(patternExpandProvider(patternId));

    return expandAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.only(top: AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: AppColorsOf(context).trendsBorderDefault),
            const SizedBox(height: AppDimens.spaceSm),
            const ZLoadingSkeleton(width: double.infinity, height: 120),
            const SizedBox(height: AppDimens.spaceSm),
            const ZLoadingSkeleton(width: double.infinity, height: 16),
            const SizedBox(height: AppDimens.spaceXs),
            const ZLoadingSkeleton(width: 200, height: 16),
            const SizedBox(height: AppDimens.spaceSm),
            const ZLoadingSkeleton(width: double.infinity, height: 14),
          ],
        ),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.only(top: AppDimens.spaceMd),
        child: Center(
          child: Text(
            "Couldn't load details",
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColorsOf(context).trendsTextMuted,
            ),
          ),
        ),
      ),
      data: (data) => Padding(
        padding: const EdgeInsets.only(top: AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: AppColorsOf(context).trendsBorderDefault),
            const SizedBox(height: AppDimens.spaceSm),

            // Time range chips — wired to selectedTimeRangeProvider
            _TimeRangeChipsRow(
              patternId: patternId,
              categoryColor: categoryColor,
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // Sparkline chart
            if (data.seriesA.isNotEmpty || data.seriesB.isNotEmpty)
              _SparklineChart(
                seriesA: data.seriesA,
                seriesB: data.seriesB,
                color: categoryColor,
              ),

            const SizedBox(height: AppDimens.spaceSm),

            // Series labels
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Expanded(
                  child: Text(
                    data.seriesALabel,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColorsOf(context).trendsTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColorsOf(context).trendsTextMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Expanded(
                  child: Text(
                    data.seriesBLabel,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColorsOf(context).trendsTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // AI explanation
            if (data.aiExplanation.isNotEmpty) ...[
              Text(
                data.aiExplanation,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColorsOf(context).trendsTextSecondary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
            ],

            // Data days caption
            Text(
              'Based on ${data.dataDays} days of data',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColorsOf(context).trendsTextMuted,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),

            // Data sources
            if (data.dataSources.isNotEmpty) ...[
              Wrap(
                spacing: AppDimens.spaceXs,
                runSpacing: AppDimens.spaceXs,
                children: data.dataSources
                    .map(
                      (src) => ZBadge(
                        label: src,
                        color: AppColorsOf(context).trendsBorderDefault,
                        textColor: AppColorsOf(context).trendsTextMuted,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppDimens.spaceMd),
            ],

            // Ask Coach CTA
            _AskCoachButton(patternId: patternId, categoryColor: categoryColor),
          ],
        ),
      ),
    );
  }
}

// ── _TimeRangeChipsRow ────────────────────────────────────────────────────────

/// Row of time range chips for expanded pattern cards.
///
/// Pro users can switch between all ranges. Free users can only use 30D;
/// tapping a locked chip opens [ZPremiumGateSheet].
class _TimeRangeChipsRow extends ConsumerWidget {
  const _TimeRangeChipsRow({
    required this.patternId,
    required this.categoryColor,
  });

  final String patternId;
  final Color categoryColor;

  /// Display label -> query value mapping.
  static const _ranges = {
    '7D': '7d',
    '30D': '30d',
    '90D': '90d',
    '6M': '6m',
    '1Y': '1y',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(selectedTimeRangeProvider(patternId));
    final isPremium = ref.watch(isPremiumProvider);

    return Row(
      children: _ranges.entries.map((entry) {
        final label = entry.key;
        final value = entry.value;
        final isActive = value == selectedRange;
        // Free users can only use 30D.
        final isLocked = !isPremium && value != '30d';

        return Padding(
          padding: const EdgeInsets.only(right: AppDimens.spaceSm),
          child: Opacity(
            opacity: isLocked ? 0.5 : 1.0,
            child: GestureDetector(
              onTap: () {
                if (isLocked) {
                  ref.read(hapticServiceProvider).light();
                  ZPremiumGateSheet.show(
                    context,
                    headline: 'Explore longer time ranges',
                    body:
                        'Upgrade to Pro to see how your patterns change over weeks and months.',
                    icon: Icons.date_range_rounded,
                  );
                  return;
                }
                if (isActive) return;
                ref.read(hapticServiceProvider).selectionTick();
                ref.read(selectedTimeRangeProvider(patternId).notifier).state =
                    value;
                ref.read(analyticsServiceProvider).capture(
                  event: AnalyticsEvents.trendsTimeRangeChanged,
                  properties: {
                    'pattern_id': patternId,
                    'time_range': value,
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceSm,
                  vertical: AppDimens.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? categoryColor.withValues(alpha: 0.15)
                      : AppColorsOf(context).trendsBorderDefault,
                  borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                  border: Border.all(
                    color: isActive
                        ? categoryColor.withValues(alpha: 0.4)
                        : AppColorsOf(context).trendsBorderDefault,
                  ),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isActive
                        ? categoryColor
                        : AppColorsOf(context).trendsTextMuted,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── _AskCoachButton ───────────────────────────────────────────────────────────

class _AskCoachButton extends ConsumerWidget {
  const _AskCoachButton({
    required this.patternId,
    required this.categoryColor,
  });

  final String patternId;
  final Color categoryColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ZButton(
      label: 'Ask Coach',
      onPressed: () {
        ref.read(hapticServiceProvider).medium();
        ref.read(analyticsServiceProvider).capture(
          event: AnalyticsEvents.trendsCoachCtaTapped,
          properties: {'pattern_id': patternId},
        );
        context.go(RouteNames.coachPath);
      },
    );
  }
}

// ── _SparklineChart ───────────────────────────────────────────────────────────

class _SparklineChart extends StatelessWidget {
  const _SparklineChart({
    required this.seriesA,
    required this.seriesB,
    required this.color,
  });

  final List<ChartSeriesPoint> seriesA;
  final List<ChartSeriesPoint> seriesB;
  final Color color;

  List<FlSpot> _toSpots(List<ChartSeriesPoint> points) {
    return points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final spotsA = _toSpots(seriesA);
    final spotsB = _toSpots(seriesB);

    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            if (spotsA.isNotEmpty)
              LineChartBarData(
                spots: spotsA,
                isCurved: true,
                color: color,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            if (spotsB.isNotEmpty)
              LineChartBarData(
                spots: spotsB,
                isCurved: true,
                color: AppColorsOf(context).trendsTextMuted,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
          ],
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }
}

// ── _FilterChipsRow ───────────────────────────────────────────────────────────

class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow({this.onCategoryChanged});

  final void Function(String category)? onCategoryChanged;

  static const _categories = [
    'all',
    'sleep',
    'activity',
    'heart',
    'nutrition',
    'body',
    'wellness',
  ];

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryFilterProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Row(
        children: _categories.map((cat) {
          final isActive = cat == selected;
          final catColor = _categoryColor(cat, context);
          // Free users can only use the "All" chip.
          final isLockedChip = !isPremium && cat != 'all';

          return Padding(
            padding: const EdgeInsets.only(right: AppDimens.spaceSm),
            child: Opacity(
              opacity: isLockedChip ? 0.5 : 1.0,
              child: GestureDetector(
                onTap: () {
                  if (isLockedChip) {
                    ref.read(hapticServiceProvider).light();
                    ZPremiumGateSheet.show(
                      context,
                      headline: 'Filter by category',
                      body:
                          'Upgrade to Pro to filter patterns by Sleep, Activity, Heart, and more.',
                      icon: Icons.filter_list_rounded,
                    );
                    return;
                  }
                  ref.read(hapticServiceProvider).selectionTick();
                  ref.read(selectedCategoryFilterProvider.notifier).state = cat;
                  ref.read(analyticsServiceProvider).capture(
                    event: AnalyticsEvents.trendsFilterChanged,
                    properties: {'category': cat},
                  );
                  onCategoryChanged?.call(cat);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                    vertical: AppDimens.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? catColor.withValues(alpha: 0.15)
                        : AppColorsOf(context).trendsSurface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                    border: Border.all(
                      color: isActive
                          ? catColor.withValues(alpha: 0.4)
                          : AppColorsOf(context).trendsBorderDefault,
                    ),
                  ),
                  child: Text(
                    _capitalize(cat),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isActive ? catColor : AppColorsOf(context).trendsTextMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── _TrendsEmptyState ─────────────────────────────────────────────────────────

class _TrendsEmptyState extends StatelessWidget {
  const _TrendsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Three icon dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CategoryDot(
                icon: Icons.bedtime_rounded,
                color: AppColors.categorySleep,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              _CategoryDot(
                icon: Icons.auto_awesome_rounded,
                color: AppColorsOf(context).trendsSage,
                size: 52,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              _CategoryDot(
                icon: Icons.directions_run_rounded,
                color: AppColors.categoryActivity,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'This is where patterns hide',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColorsOf(context).trendsTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Keep logging for 7+ days and Zuralog will surface hidden connections — like how your sleep affects your workouts.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColorsOf(context).trendsTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AppColorsOf(context).trendsSage.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                'Keep logging for 7 days to unlock your first pattern.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColorsOf(context).trendsTextMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _TrendsNoCorrelationsState ────────────────────────────────────────────────

class _TrendsNoCorrelationsState extends StatelessWidget {
  const _TrendsNoCorrelationsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Single centered icon
          _CategoryDot(
            icon: Icons.search_off_rounded,
            color: AppColorsOf(context).trendsSage,
            size: 52,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Your data is ready',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColorsOf(context).trendsTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'No strong patterns have surfaced yet. Keep logging consistently and we\'ll let you know when a connection appears.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColorsOf(context).trendsTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CategoryDot extends StatelessWidget {
  const _CategoryDot({
    required this.icon,
    required this.color,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: size * 0.48,
        color: color.withValues(alpha: 0.8),
      ),
    );
  }
}

// ── _TrendsLoadingSkeleton ────────────────────────────────────────────────────

class _TrendsLoadingSkeleton extends StatelessWidget {
  const _TrendsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: AppDimens.bottomClearance(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter chip skeletons
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            child: Row(
              children: List.generate(
                5,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: AppDimens.spaceSm),
                  child: ZLoadingSkeleton(
                    width: i == 0 ? 48 : 72,
                    height: 32,
                    borderRadius: AppDimens.radiusChip,
                  ),
                ),
              ),
            ),
          ),

          // Hero skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: const ZLoadingSkeleton(
              width: double.infinity,
              height: 180,
              borderRadius: AppDimens.radiusCard,
            ),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // Feed card skeletons
          ...List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm / 2,
              ),
              child: const ZLoadingSkeleton(
                width: double.infinity,
                height: 110,
                borderRadius: AppDimens.radiusCard,
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
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.displaySmall.copyWith(
        color: AppColorsOf(context).trendsTextPrimary,
      ),
    );
  }
}

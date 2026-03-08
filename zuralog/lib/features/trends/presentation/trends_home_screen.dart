/// Trends Home Screen — Tab 4 root screen.
///
/// Surfaces AI-discovered correlations and a horizontal time-machine strip
/// that lets the user swipe through week-by-week historical summaries.
///
/// Layout:
///   - AppBar: "Trends" title + ProfileAvatarButton
///   - Time-machine horizontal scroll strip (periods, newest first)
///   - Section: "Patterns We Found" — correlation cards
///   - Onboarding empty state when [hasEnoughData] is false
///   - Quick-nav row → Correlations, Reports, Data Sources
library;

import 'dart:convert';

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
import 'package:zuralog/features/trends/domain/trends_models.dart';
import 'package:zuralog/features/trends/providers/trends_providers.dart';
import 'package:zuralog/shared/widgets/onboarding_tooltip.dart';
import 'package:zuralog/shared/widgets/profile_avatar_button.dart';

// ── TrendsHomeScreen ──────────────────────────────────────────────────────────

/// Trends Home screen — AI correlations + time-machine history strip.
class TrendsHomeScreen extends ConsumerWidget {
  /// Creates the [TrendsHomeScreen].
  const TrendsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(trendsHomeProvider);

    return Scaffold(
      appBar: AppBar(
        title: OnboardingTooltip(
          screenKey: 'trends_home',
          tooltipKey: 'welcome',
          message: 'This is where patterns hide. '
              'I\'ll surface correlations you\'d never find on your own.',
          child: const Text('Trends'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppDimens.spaceMd),
            child: const ProfileAvatarButton(),
          ),
        ],
      ),
      body: trendsAsync.when(
        loading: () => const _TrendsLoadingSkeleton(),
        error: (e, _) => _TrendsErrorState(
          onRetry: () => ref.invalidate(trendsHomeProvider),
        ),
        data: (data) => _TrendsHomeBody(data: data),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _TrendsHomeBody extends ConsumerStatefulWidget {
  const _TrendsHomeBody({required this.data});
  final TrendsHomeData data;

  @override
  ConsumerState<_TrendsHomeBody> createState() => _TrendsHomeBodyState();
}

class _TrendsHomeBodyState extends ConsumerState<_TrendsHomeBody> {
  static const _kDismissedKey = 'dismissed_correlation_suggestions';

  final Set<String> _dismissedSuggestions = {};

  @override
  void initState() {
    super.initState();
    _loadDismissals();
  }

  /// Loads persisted dismissed suggestion IDs from SharedPreferences.
  ///
  /// Called from [initState] (cannot be async directly). The widget renders
  /// immediately with an empty set; a [setState] call triggers a rebuild once
  /// the saved IDs are available.
  ///
  /// Intersects the stored IDs against [widget.data.suggestionCards] so that
  /// stale IDs (from previous sessions where suggestions have rotated) are
  /// pruned automatically. This prevents unbounded set growth and ensures a
  /// reused suggestion ID is always shown fresh.
  Future<void> _loadDismissals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDismissedKey);
      if (raw != null && mounted) {
        final stored = (jsonDecode(raw) as List<dynamic>)
            .whereType<String>()
            .toSet();
        // Only keep IDs that are still present in the current suggestion list.
        // This prunes stale IDs and prevents ID-reuse from hiding new cards.
        final currentIds =
            widget.data.suggestionCards.map((s) => s.id).toSet();
        final validIds = stored.intersection(currentIds);
        if (validIds.isNotEmpty) {
          setState(() => _dismissedSuggestions.addAll(validIds));
          // Re-persist the pruned set to keep storage clean.
          await prefs.setString(
            _kDismissedKey,
            jsonEncode(validIds.toList()),
          );
        } else if (stored.isNotEmpty) {
          // All stored IDs are stale — clear storage.
          await prefs.remove(_kDismissedKey);
        }
      }
    } catch (_) {
      // Corrupt or missing data — start with empty set.
    }
  }

  /// Persists the current [_dismissedSuggestions] set to SharedPreferences.
  ///
  /// Fire-and-forget: called without `await` so [setState] is not blocked.
  Future<void> _persistDismissals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kDismissedKey,
        jsonEncode(_dismissedSuggestions.toList()),
      );
    } catch (_) {
      // Write failures are non-fatal — the in-memory set remains correct.
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final visibleSuggestions = data.suggestionCards
        .where((s) => !_dismissedSuggestions.contains(s.id))
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(hapticServiceProvider).light();
        ref.invalidate(trendsHomeProvider);
      },
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Time-machine strip ─────────────────────────────────────────
          if (data.timePeriods.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: _SectionHeader(title: 'History'),
            ),
            SliverToBoxAdapter(
              child: _TimeMachineStrip(periods: data.timePeriods),
            ),
          ],

          // ── Correlation highlights ─────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Patterns We Found',
              subtitle: data.hasEnoughData
                  ? null
                  : 'Keep logging — patterns appear after 7+ days of data',
            ),
          ),

          if (!data.hasEnoughData || data.correlationHighlights.isEmpty)
            const SliverToBoxAdapter(child: _EmptyCorrelationsState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                    vertical: AppDimens.spaceSm / 2,
                  ),
                  child: _CorrelationCard(
                    highlight: data.correlationHighlights[index],
                    onTap: () => context.push(RouteNames.correlationsPath),
                  ),
                ),
                childCount: data.correlationHighlights.length,
              ),
            ),

          // ── Correlation suggestion cards ───────────────────────────────
          if (visibleSuggestions.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: _SectionHeader(title: 'Track More, Learn More'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final s = visibleSuggestions[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceSm / 2,
                    ),
                    child: _CorrelationSuggestionCard(
                      suggestion: s,
                      onDismiss: () {
                        setState(() => _dismissedSuggestions.add(s.id));
                        _persistDismissals(); // fire-and-forget
                      },
                      onCtaTap: () {
                        ref.read(hapticServiceProvider).light();
                        ref.read(analyticsServiceProvider).capture(
                          event:
                              AnalyticsEvents.correlationSuggestionTapped,
                          properties: {
                            'metric_needed': s.metricNeeded,
                            'cta_label': s.ctaLabel,
                          },
                        );
                        // Security: validate route against allowlist before
                        // navigating — ctaRoute is backend-supplied.
                        const allowedRoutes = {
                          RouteNames.settingsIntegrationsPath,
                        };
                        if (allowedRoutes.contains(s.ctaRoute)) {
                          context.push(s.ctaRoute);
                        }
                      },
                    ),
                  );
                },
                childCount: visibleSuggestions.length,
              ),
            ),
          ],

          // ── Quick-nav row ──────────────────────────────────────────────
          const SliverToBoxAdapter(child: _SectionHeader(title: 'Explore')),
          SliverToBoxAdapter(
            child: _QuickNavRow(),
          ),

          SliverToBoxAdapter(
            child: SizedBox(height: AppDimens.bottomClearance(context)),
          ),
        ],
      ),
    );
  }
}

// ── Time-Machine Strip ────────────────────────────────────────────────────────

class _TimeMachineStrip extends StatelessWidget {
  const _TimeMachineStrip({required this.periods});
  final List<TimePeriodSummary> periods;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        scrollDirection: Axis.horizontal,
        itemCount: periods.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppDimens.spaceSm),
        itemBuilder: (context, index) =>
            _TimePeriodCard(period: periods[index]),
      ),
    );
  }
}

class _TimePeriodCard extends StatelessWidget {
  const _TimePeriodCard({required this.period});
  final TimePeriodSummary period;

  Color _scoreColor(int score) {
    if (score >= 70) return AppColors.healthScoreGreen;
    if (score >= 40) return AppColors.healthScoreAmber;
    return AppColors.healthScoreRed;
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor(period.overallScore);
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  period.label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceSm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                ),
                child: Text(
                  '${period.overallScore}',
                  style: AppTextStyles.caption.copyWith(color: scoreColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ...period.highlights.take(2).map(
                (h) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          h.label,
                          style: AppTextStyles.labelXs.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${h.value} ${h.unit}'.trim(),
                        style: AppTextStyles.labelXs.copyWith(
                          color: AppColors.textPrimaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ── Correlation Card ──────────────────────────────────────────────────────────

class _CorrelationCard extends ConsumerWidget {
  const _CorrelationCard({
    required this.highlight,
    required this.onTap,
  });

  final CorrelationHighlight highlight;
  final VoidCallback onTap;

  Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    // Validate: must be exactly 6 hex characters — never trust backend-supplied color strings
    if (cleaned.length == 6 && RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(cleaned)) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return AppColors.primary;
  }

  IconData _directionIcon(CorrelationDirection dir) {
    switch (dir) {
      case CorrelationDirection.positive:
        return Icons.trending_up_rounded;
      case CorrelationDirection.negative:
        return Icons.trending_down_rounded;
      case CorrelationDirection.neutral:
        return Icons.trending_flat_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = _parseHex(highlight.categoryColorHex);
    final coeffAbs = highlight.coefficient.abs();

    return GestureDetector(
      onTap: () {
        ref.read(hapticServiceProvider).light();
        ref.read(analyticsServiceProvider).capture(
          event: AnalyticsEvents.correlationTapped,
          properties: {
            'metric_a': highlight.metricA,
            'metric_b': highlight.metricB,
            'direction': highlight.direction.name,
          },
        );
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: metrics + coefficient ─────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${highlight.metricA}  ×  ${highlight.metricB}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        highlight.headline,
                        style: AppTextStyles.h3,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                // Correlation strength indicator
                _CorrelationStrengthBadge(
                  coefficient: highlight.coefficient,
                  accentColor: accentColor,
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),

            // ── Progress bar showing correlation strength ──────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: coeffAbs,
                minHeight: 3,
                backgroundColor: AppColors.borderDark,
                color: accentColor,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),

            // ── Body text ─────────────────────────────────────────────
            Text(
              highlight.body,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppDimens.spaceSm),

            // ── Direction chip ─────────────────────────────────────────
            Row(
              children: [
                Icon(
                  _directionIcon(highlight.direction),
                  size: AppDimens.iconSm,
                  color: accentColor,
                ),
                const SizedBox(width: 4),
                Text(
                  highlight.direction.label,
                  style: AppTextStyles.labelXs.copyWith(color: accentColor),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  size: AppDimens.iconMd,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrelationStrengthBadge extends StatelessWidget {
  const _CorrelationStrengthBadge({
    required this.coefficient,
    required this.accentColor,
  });

  final double coefficient;
  final Color accentColor;

  String _strengthLabel(double coeff) {
    final abs = coeff.abs();
    if (abs >= 0.7) return 'Strong';
    if (abs >= 0.4) return 'Moderate';
    return 'Weak';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Column(
        children: [
          Text(
            coefficient.toStringAsFixed(2),
            style: AppTextStyles.h3.copyWith(color: accentColor),
          ),
          Text(
            _strengthLabel(coefficient),
            style: AppTextStyles.labelXs.copyWith(color: accentColor),
          ),
        ],
      ),
    );
  }
}

// ── Quick-nav Row ─────────────────────────────────────────────────────────────

class _QuickNavRow extends StatelessWidget {
  const _QuickNavRow();

  static const _items = [
    _QuickNavItem(
      icon: Icons.scatter_plot_rounded,
      label: 'Explorer',
      routePath: RouteNames.correlationsPath,
    ),
    _QuickNavItem(
      icon: Icons.summarize_rounded,
      label: 'Reports',
      routePath: RouteNames.reportsPath,
    ),
    _QuickNavItem(
      icon: Icons.device_hub_rounded,
      label: 'Sources',
      routePath: RouteNames.dataSourcesPath,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Row(
        children: _items
            .map(
              (item) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceXs),
                  child: _QuickNavButton(item: item),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

@immutable
class _QuickNavItem {
  const _QuickNavItem({
    required this.icon,
    required this.label,
    required this.routePath,
  });

  final IconData icon;
  final String label;
  final String routePath;
}

class _QuickNavButton extends ConsumerWidget {
  const _QuickNavButton({required this.item});
  final _QuickNavItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(hapticServiceProvider).light();
        ref.read(analyticsServiceProvider).capture(
          event: AnalyticsEvents.trendsNavTapped,
          properties: {'section': item.label.toLowerCase()},
        );
        context.push(item.routePath);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimens.spaceMd,
          horizontal: AppDimens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 22, color: AppColors.primary),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              item.label,
              style: AppTextStyles.labelXs.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty / Onboarding State ──────────────────────────────────────────────────

class _EmptyCorrelationsState extends StatelessWidget {
  const _EmptyCorrelationsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceLg,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'This is where patterns hide',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Keep logging your health data for 7+ days and Zuralog will start surfacing hidden connections — like how your sleep affects your workouts.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h2),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Correlation Suggestion Card ───────────────────────────────────────────────

class _CorrelationSuggestionCard extends ConsumerWidget {
  const _CorrelationSuggestionCard({
    required this.suggestion,
    required this.onDismiss,
    required this.onCtaTap,
  });

  final CorrelationSuggestion suggestion;
  final VoidCallback onDismiss;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
        AppDimens.spaceSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Icon ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 2, right: AppDimens.spaceSm),
            child: Icon(
              Icons.add_circle_outline_rounded,
              size: AppDimens.iconMd,
              color: AppColors.primary,
            ),
          ),

          // ── Text content + CTA ───────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.metricNeeded,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  suggestion.description,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimens.spaceXs),
                TextButton(
                  onPressed: onCtaTap,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    suggestion.ctaLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Dismiss button ───────────────────────────────────────────
          IconButton(
            onPressed: onDismiss,
            icon: Icon(
              Icons.close_rounded,
              size: AppDimens.iconSm,
              color: AppColors.textTertiary,
            ),
            padding: const EdgeInsets.all(AppDimens.spaceXs),
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading Skeleton ──────────────────────────────────────────────────────────

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
          const SizedBox(height: AppDimens.spaceLg),
          // Time strip skeleton
          SizedBox(
            height: 140,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: AppDimens.spaceSm),
              itemBuilder: (_, _) => _SkeletonBox(width: 160, height: 120),
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          // Correlation card skeletons
          ...List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm / 2,
              ),
              child: _SkeletonBox(width: double.infinity, height: 110),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
    );
  }
}

// ── Error State ───────────────────────────────────────────────────────────────

class _TrendsErrorState extends StatelessWidget {
  const _TrendsErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: AppDimens.bottomClearance(context),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Text('Could not load trends', style: AppTextStyles.h3),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                'Check your connection and try again.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.spaceLg),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryButtonText,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusButtonMd),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

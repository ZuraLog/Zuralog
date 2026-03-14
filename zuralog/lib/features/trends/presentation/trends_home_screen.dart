/// Trends Home Screen — Tab 4 root screen.
///
/// Surfaces AI-discovered correlations and a horizontal time-machine strip
/// that lets the user swipe through week-by-week historical summaries.
///
/// Layout:
///   - AppBar: ZuralogAppBar — "Trends" title + onboarding tooltip (avatar auto-appended)
///   - Time-machine horizontal scroll strip (periods, newest first)
///   - Section: "Patterns We Found" — correlation cards
///   - Onboarding empty state when [hasEnoughData] is false
///   - Quick-nav row → Correlations, Reports, Data Sources
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/trends/domain/trends_models.dart';
import 'package:zuralog/features/trends/providers/trends_providers.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/shared/widgets/loading/z_loading_skeleton.dart';
import 'package:zuralog/shared/widgets/zuralog_app_bar.dart';

// ── TrendsHomeScreen ──────────────────────────────────────────────────────────

/// Trends Home screen — AI correlations + time-machine history strip.
class TrendsHomeScreen extends ConsumerWidget {
  /// Creates the [TrendsHomeScreen].
  const TrendsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(trendsHomeProvider);

    return ZuralogScaffold(
      addBottomNavPadding: true,
      appBar: ZuralogAppBar(
        title: 'Trends',
        tooltipConfig: const ZuralogAppBarTooltipConfig(
          screenKey: 'trends_home',
          tooltipKey: 'welcome',
          message: 'This is where patterns hide. '
              "I'll surface correlations you'd never find on your own.",
        ),
      ),
      // Provider never errors — safety-net error branch shows the empty state
      // rather than any connection error message.
      body: trendsAsync.when(
        error: (err, stack) => _TrendsHomeBody(
          data: const TrendsHomeData(
            correlationHighlights: [],
            timePeriods: [],
            hasEnoughData: false,
          ),
        ),
        loading: () => const _TrendsLoadingSkeleton(),
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
  ///
  /// **Multi-account safety:** Suggestion IDs are derived server-side as
  /// `uuid5(userId, goal, category)` — they are unique per user. If a
  /// different user logs in, their suggestion IDs will never match the
  /// previous user's dismissed IDs, so the intersection will produce an
  /// empty set and `prefs.remove` will clean up the stale key. No SharedPreferences
  /// namespacing by user ID is required.
  Future<void> _loadDismissals() async {
    try {
      final prefs = ref.read(prefsProvider);
      final raw = prefs.getString(_kDismissedKey);
      if (raw != null) {
        final stored = (jsonDecode(raw) as List<dynamic>)
            .whereType<String>()
            .toSet();
        // Only keep IDs that are still present in the current suggestion list.
        // This prunes stale IDs and prevents ID-reuse from hiding new cards.
        final currentIds =
            widget.data.suggestionCards.map((s) => s.id).toSet();
        final validIds = stored.intersection(currentIds);
        if (validIds.isNotEmpty) {
          if (mounted) setState(() => _dismissedSuggestions.addAll(validIds));
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
  /// Synchronous via [prefsProvider] — no Future, no disposed-widget risk.
  void _persistDismissals() {
    try {
      unawaited(ref.read(prefsProvider).setString(
        _kDismissedKey,
        jsonEncode(_dismissedSuggestions.toList()),
      ));
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
    final colors = AppColorsOf(context);
    final scoreColor = _scoreColor(period.overallScore);
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: colors.cardBackground,
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
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
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
                  style: AppTextStyles.bodySmall.copyWith(color: scoreColor),
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
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${h.value} ${h.unit}'.trim(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: colors.textPrimary,
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
    final colors = AppColorsOf(context);
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
          color: colors.cardBackground,
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
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        highlight.headline,
                        style: AppTextStyles.titleMedium,
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
                backgroundColor: colors.border,
                color: accentColor,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),

            // ── Body text ─────────────────────────────────────────────
            Text(
              highlight.body,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
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
                  style: AppTextStyles.labelSmall.copyWith(color: accentColor),
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
            style: AppTextStyles.titleMedium.copyWith(color: accentColor),
          ),
          Text(
            _strengthLabel(coefficient),
            style: AppTextStyles.labelSmall.copyWith(color: accentColor),
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
    final colors = AppColorsOf(context);
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
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 22, color: AppColors.primary),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              item.label,
              style: AppTextStyles.labelSmall.copyWith(
                color: colors.textSecondary,
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
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon cluster hinting at multiple data connections
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CorrelationDot(
                  icon: Icons.bedtime_rounded,
                  color: AppColors.categorySleep,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                _CorrelationDot(
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 52,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                _CorrelationDot(
                  icon: Icons.directions_run_rounded,
                  color: AppColors.categoryActivity,
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'This is where patterns hide',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Keep logging for 7+ days and Zuralog will surface hidden connections — like how your sleep affects your workouts.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            // Progress hint row showing what's needed
            _ProgressHintRow(
              icon: Icons.calendar_today_rounded,
              label: '7 days of data unlocks your first pattern',
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrelationDot extends StatelessWidget {
  const _CorrelationDot({
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

class _ProgressHintRow extends StatelessWidget {
  const _ProgressHintRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
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
    final colors = AppColorsOf(context);
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
          Text(title, style: AppTextStyles.displaySmall),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
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
    final colors = AppColorsOf(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
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
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  suggestion.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
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
                    style: AppTextStyles.bodySmall.copyWith(
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
              itemBuilder: (_, _) => const ZLoadingSkeleton(width: 160, height: 120),
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
              child: const ZLoadingSkeleton(width: double.infinity, height: 110),
            ),
          ),
        ],
      ),
    );
  }
}



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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

class _TrendsHomeBody extends ConsumerWidget {
  const _TrendsHomeBody({required this.data});
  final TrendsHomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

          // ── Quick-nav row ──────────────────────────────────────────────
          const SliverToBoxAdapter(child: _SectionHeader(title: 'Explore')),
          SliverToBoxAdapter(
            child: _QuickNavRow(),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimens.spaceXxl),
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

// ── Loading Skeleton ──────────────────────────────────────────────────────────

class _TrendsLoadingSkeleton extends StatelessWidget {
  const _TrendsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
    return Center(
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
    );
  }
}

/// Insight Detail Screen — editorial full-screen view of a single AI insight.
///
/// The screen is a thin composition: editorial header → category body
/// slivers (dispatched on `detail.category`) → AI reasoning → data
/// sources → Discuss-with-Coach pill. Category-specific bodies live in
/// `widgets/<category>_insight_body.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/haptics/haptic_providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/theme/category_colors.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/presentation/widgets/activity_insight_body.dart';
import 'package:zuralog/features/today/presentation/widgets/generic_insight_body.dart';
import 'package:zuralog/features/today/presentation/widgets/heart_insight_body.dart';
import 'package:zuralog/features/today/presentation/widgets/nutrition_insight_body.dart';
import 'package:zuralog/features/today/presentation/widgets/sleep_insight_body.dart';
import 'package:zuralog/features/today/presentation/widgets/streak_insight_body.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class InsightDetailScreen extends ConsumerStatefulWidget {
  const InsightDetailScreen({super.key, required this.insightId});
  final String insightId;

  @override
  ConsumerState<InsightDetailScreen> createState() =>
      _InsightDetailScreenState();
}

class _InsightDetailScreenState extends ConsumerState<InsightDetailScreen> {
  bool _viewEventFired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(todayRepositoryProvider)
          .markInsightRead(widget.insightId)
          .catchError((Object e, StackTrace _) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(insightDetailProvider(widget.insightId));
    detailAsync.whenOrNull(data: (detail) {
      if (!_viewEventFired) {
        _viewEventFired = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(analyticsServiceProvider).capture(
            event: AnalyticsEvents.insightDetailViewed,
            properties: {
              'insight_id': widget.insightId,
              'insight_type': detail.type.name,
              'category': detail.category,
            },
          );
          SharedPreferences.getInstance().then((prefs) {
            if (prefs.getBool('analytics_first_insight_viewed') != true) {
              prefs.setBool('analytics_first_insight_viewed', true);
              ref.read(analyticsServiceProvider).capture(
                event: AnalyticsEvents.firstInsightViewed,
              );
            }
          });
        });
      }
    });

    return ZuralogScaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: detailAsync.when(
        data: (detail) => _DetailBody(detail: detail),
        loading: () => const _DetailSkeleton(),
        error: (e, st) => _DetailError(
          onRetry: () =>
              ref.invalidate(insightDetailProvider(widget.insightId)),
        ),
      ),
    );
  }
}

// ── _DetailBody ──────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});
  final InsightDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final categoryColor = categoryColorFromString(detail.category);
    // The Discuss-with-Coach pill sits above the floating bottom nav cluster
    // (pill ~56pt + 18pt bottom gap + device safe area). Pad the last sliver
    // by that cluster height so the pill never tucks under the nav.
    final bottomClusterHeight =
        MediaQuery.paddingOf(context).bottom + 56 + 18 + AppDimens.spaceMd;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _EditorialHeader(detail: detail, categoryColor: categoryColor),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
        ..._categoryBodySlivers(detail, context, ref),
        if (detail.reasoning.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceLg)),
          SliverToBoxAdapter(
            child: _AIReasoningBlock(
              reasoning: detail.reasoning,
              primary: colors.primary,
            ),
          ),
        ],
        if (detail.sources.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceLg)),
          SliverToBoxAdapter(
            child: _SourcesBlock(sources: detail.sources),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceLg,
              AppDimens.spaceMd,
              bottomClusterHeight,
            ),
            child: ZFadeSlideIn(
              delay: const Duration(milliseconds: 260),
              child: ZPatternPillButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Discuss with Coach',
                onPressed: () {
                  ref.read(hapticServiceProvider).medium();
                  ref.read(analyticsServiceProvider).capture(
                    event: AnalyticsEvents.insightDetailCoachTapped,
                    properties: {
                      'insight_id': detail.id,
                      'insight_type': detail.type.name,
                    },
                  );
                  final raw = "I'd like to discuss this insight: "
                      "${detail.title}";
                  final prefill = raw.length > 500 ? raw.substring(0, 500) : raw;
                  ref.read(coachPrefillProvider.notifier).state = prefill;
                  context.go(RouteNames.coachPath);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _categoryBodySlivers(
    InsightDetail detail,
    BuildContext context,
    WidgetRef ref,
  ) {
    switch (detail.category) {
      case 'sleep':
        return sleepInsightSlivers(context, ref);
      case 'heart':
        return heartInsightSlivers(context, ref);
      case 'nutrition':
        return nutritionInsightSlivers(context, ref);
      case 'activity':
        return activityInsightSlivers(context, ref, detail);
      case 'streak':
        return streakInsightSlivers(context, ref);
      default:
        return genericInsightSlivers(context, ref, detail);
    }
  }
}

// ── Editorial header ─────────────────────────────────────────────────────────

class _EditorialHeader extends StatelessWidget {
  const _EditorialHeader({required this.detail, required this.categoryColor});
  final InsightDetail detail;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZFadeSlideIn(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ZPatternOverlay(
                variant: _patternVariantForCategory(detail.category),
                opacity: 0.06,
                animate: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _chipLabel(detail).toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: categoryColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  detail.title,
                  style: GoogleFonts.lora(
                    textStyle: AppTextStyles.displayLarge.copyWith(
                      color: colors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  detail.summary,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textPrimary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _chipLabel(InsightDetail detail) {
    final cat = detail.category.isEmpty ? 'health' : detail.category;
    final type = _insightTypeLabel(detail.type);
    return '$cat · $type';
  }
}

ZPatternVariant _patternVariantForCategory(String category) {
  switch (category) {
    case 'sleep':
      return ZPatternVariant.periwinkle;
    case 'activity':
      return ZPatternVariant.green;
    case 'heart':
      return ZPatternVariant.rose;
    case 'nutrition':
      return ZPatternVariant.amber;
    default:
      return ZPatternVariant.sage;
  }
}

String _insightTypeLabel(InsightType type) {
  switch (type) {
    case InsightType.anomaly:
      return 'Anomaly';
    case InsightType.correlation:
      return 'Correlation';
    case InsightType.trend:
      return 'Trend';
    case InsightType.recommendation:
      return 'Recommendation';
    case InsightType.achievement:
      return 'Achievement';
    case InsightType.unknown:
      return 'Insight';
  }
}

// ── AI reasoning block ───────────────────────────────────────────────────────

class _AIReasoningBlock extends StatelessWidget {
  const _AIReasoningBlock({required this.reasoning, required this.primary});
  final String reasoning;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZFadeSlideIn(
      delay: const Duration(milliseconds: 160),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'AI Analysis',
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppDimens.spaceMd),
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusCard,
                        ),
                      ),
                      child: Text(
                        reasoning,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: colors.textPrimary,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sources block ────────────────────────────────────────────────────────────

class _SourcesBlock extends StatelessWidget {
  const _SourcesBlock({required this.sources});
  final List<InsightSource> sources;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZFadeSlideIn(
      delay: const Duration(milliseconds: 220),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Data sources',
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            Wrap(
              spacing: AppDimens.spaceSm,
              runSpacing: AppDimens.spaceSm,
              children: [
                for (final src in sources)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _sourceIcon(src.iconName),
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          src.name,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _sourceIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'apple_health':
        return Icons.favorite_rounded;
      case 'strava':
        return Icons.directions_run_rounded;
      case 'fitbit':
        return Icons.watch_rounded;
      case 'garmin':
        return Icons.gps_fixed_rounded;
      case 'whoop':
        return Icons.monitor_heart_rounded;
      case 'oura':
        return Icons.ring_volume_rounded;
      default:
        return Icons.device_hub_rounded;
    }
  }
}

// ── Skeleton & error states ──────────────────────────────────────────────────

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZLoadingSkeleton(width: 200, height: 34),
          SizedBox(height: AppDimens.spaceMd),
          ZLoadingSkeleton(width: double.infinity, height: 16),
          SizedBox(height: 8),
          ZLoadingSkeleton(width: 280, height: 16),
          SizedBox(height: AppDimens.spaceLg),
          ZLoadingSkeleton(width: double.infinity, height: 180),
          SizedBox(height: AppDimens.spaceLg),
          ZLoadingSkeleton(width: 120, height: 18),
          SizedBox(height: AppDimens.spaceSm),
          ZLoadingSkeleton(width: double.infinity, height: 100),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Could not load insight',
            style: AppTextStyles.titleMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Try again',
              style: AppTextStyles.bodyLarge.copyWith(color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

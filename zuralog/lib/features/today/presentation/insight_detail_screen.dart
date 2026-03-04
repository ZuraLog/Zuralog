/// Insight Detail Screen — pushed from Today Feed.
///
/// Full-screen explanation of a single AI insight: charts, data sources,
/// AI reasoning, and "Discuss with Coach" action.
///
/// Full implementation: Phase 3, Task 3.2.
/// Design elevation: Phase 3 elevation pass — editorial animations & micro-interactions.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/haptics/haptic_providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

// ── InsightDetailScreen ───────────────────────────────────────────────────────

/// Full-screen insight detail with charts, AI reasoning, and sources.
///
/// Navigated to via a named push route; uses a slide-up transition defined
/// in [AppRouter]. The [insightId] is read from the route path parameter.
class InsightDetailScreen extends ConsumerStatefulWidget {
  /// Creates an [InsightDetailScreen] for the given [insightId].
  const InsightDetailScreen({super.key, required this.insightId});

  /// The ID of the insight to display.
  final String insightId;

  @override
  ConsumerState<InsightDetailScreen> createState() =>
      _InsightDetailScreenState();
}

class _InsightDetailScreenState extends ConsumerState<InsightDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Mark as read when opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(todayRepositoryProvider)
          .markInsightRead(widget.insightId)
          .catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(insightDetailProvider(widget.insightId));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimaryDark,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: detailAsync.whenOrNull(
          data: (detail) => Text(
            _categoryLabel(detail.category),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ),
      ),
      body: detailAsync.when(
        data: (detail) => _DetailBody(detail: detail),
        loading: () => const _DetailSkeleton(),
        error: (e, _) => _DetailError(
          onRetry: () =>
              ref.invalidate(insightDetailProvider(widget.insightId)),
        ),
      ),
    );
  }
}

// ── _DetailBody ───────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});

  final InsightDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryColor = _categoryColor(detail.category);

    return CustomScrollView(
      slivers: [
        // ── Header: full-bleed category gradient wash + title ─────────────
        SliverToBoxAdapter(
          child: _FadeSlideIn(
            delay: Duration.zero,
            child: Stack(
              children: [
                // Edge-to-edge category-color gradient wash (10% opacity).
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            categoryColor.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                      ),
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
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusSm,
                              ),
                            ),
                            child: Icon(
                              _insightIcon(detail.type),
                              size: 24,
                              color: categoryColor,
                            ),
                          ),
                          const SizedBox(width: AppDimens.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        categoryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppDimens.radiusChip,
                                    ),
                                  ),
                                  child: Text(
                                    _insightTypeLabel(detail.type),
                                    style: AppTextStyles.labelXs.copyWith(
                                      color: categoryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      Text(
                        detail.title,
                        style: AppTextStyles.h1.copyWith(
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      Text(
                        detail.summary,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Chart ─────────────────────────────────────────────────────────
        if (detail.dataPoints.isNotEmpty)
          SliverToBoxAdapter(
            child: _FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm,
                ),
                child: _InsightChart(
                  detail: detail,
                  categoryColor: categoryColor,
                ),
              ),
            ),
          ),

        // ── AI Reasoning ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _FadeSlideIn(
            delay: const Duration(milliseconds: 130),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: Text(
                'AI Analysis',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: _FadeSlideIn(
            delay: const Duration(milliseconds: 160),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
              ),
              // Sage-green left border stripe on reasoning card.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(AppDimens.spaceMd),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackgroundDark,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusCard,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.psychology_outlined,
                                  size: AppDimens.iconMd,
                                  color:
                                      AppColors.primary.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: AppDimens.spaceSm),
                                Text(
                                  'Reasoning',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondaryDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimens.spaceSm),
                            Text(
                              detail.reasoning.isNotEmpty
                                  ? detail.reasoning
                                  : 'This insight was generated from your recent health data.',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textPrimaryDark,
                                height: 1.55,
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
          ),
        ),

        // ── Data Sources ──────────────────────────────────────────────────
        if (detail.sources.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceLg,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: Text(
                  'Data Sources',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _FadeSlideIn(
              delay: const Duration(milliseconds: 220),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: Wrap(
                  spacing: AppDimens.spaceSm,
                  runSpacing: AppDimens.spaceSm,
                  children: [
                    for (final src in detail.sources) _SourceChip(source: src),
                  ],
                ),
              ),
            ),
          ),
        ],

        // ── Discuss with Coach CTA ─────────────────────────────────────
        SliverToBoxAdapter(
          child: _FadeSlideIn(
            delay: const Duration(milliseconds: 260),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceXxl,
              ),
              child: _PressScaleButton(
                onPressed: () {
                  ref.read(hapticServiceProvider).medium();
                  context.go(
                    '${RouteNames.coachPath}?context=insight&id=${detail.id}',
                  );
                },
                child: FilledButton.icon(
                  onPressed: null, // handled by _PressScaleButton
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                  ),
                  label: const Text('Discuss with Coach'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryButtonText,
                    disabledBackgroundColor: AppColors.primary,
                    disabledForegroundColor: AppColors.primaryButtonText,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── _PressScaleButton ─────────────────────────────────────────────────────────

/// Wraps any widget with a 0.96× press-scale effect.
class _PressScaleButton extends StatefulWidget {
  const _PressScaleButton({required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback onPressed;

  @override
  State<_PressScaleButton> createState() => _PressScaleButtonState();
}

class _PressScaleButtonState extends State<_PressScaleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ── _FadeSlideIn ──────────────────────────────────────────────────────────────

/// Staggered fade + 6% slide-up entrance animation.
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

// ── _InsightChart ─────────────────────────────────────────────────────────────

/// Bar chart rendered from [InsightDetail.dataPoints].
class _InsightChart extends StatelessWidget {
  const _InsightChart({
    required this.detail,
    required this.categoryColor,
  });

  final InsightDetail detail;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final points = detail.dataPoints;
    final maxY = points.map((p) => p.value).reduce(math.max) * 1.2;

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.chartTitle != null) ...[
            Text(
              detail.chartTitle!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.borderDark.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            points[idx].label,
                            style: AppTextStyles.labelXs.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].value,
                          color: categoryColor,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: categoryColor.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                ],
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceDark,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final unit = detail.chartUnit ?? '';
                      return BarTooltipItem(
                        '${rod.toY.toStringAsFixed(1)} $unit',
                        AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimaryDark,
                        ),
                      );
                    },
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 400),
            ),
          ),
          if (detail.chartUnit != null) ...[
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              detail.chartUnit!,
              style: AppTextStyles.labelXs.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── _SourceChip ───────────────────────────────────────────────────────────────

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final InsightSource source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _sourceIcon(source.iconName),
            size: 14,
            color: AppColors.textSecondaryDark,
          ),
          const SizedBox(width: 6),
          Text(
            source.name,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _DetailSkeleton ───────────────────────────────────────────────────────────

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(width: 200, height: 34),
          const SizedBox(height: AppDimens.spaceMd),
          _SkeletonBox(width: double.infinity, height: 16),
          const SizedBox(height: 8),
          _SkeletonBox(width: 280, height: 16),
          const SizedBox(height: AppDimens.spaceLg),
          _SkeletonBox(width: double.infinity, height: 180),
          const SizedBox(height: AppDimens.spaceLg),
          _SkeletonBox(width: 120, height: 18),
          const SizedBox(height: AppDimens.spaceSm),
          _SkeletonBox(width: double.infinity, height: 100),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.cardBackgroundDark,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

// ── _DetailError ──────────────────────────────────────────────────────────────

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Try again',
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns a display label for an [InsightType].
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

/// Returns the title-cased category label.
String _categoryLabel(String category) =>
    category.isEmpty
        ? 'Health'
        : category[0].toUpperCase() + category.substring(1);

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

/// Returns a material icon for an integration source icon name.
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

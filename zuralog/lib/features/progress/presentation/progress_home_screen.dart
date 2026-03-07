/// Progress Home Screen — Tab 3 (Progress) root screen.
///
/// Displays active goals with animated progress rings, current streaks,
/// week-over-week comparison summary, quick nav shortcuts, and recent
/// achievements. Pull-to-refresh invalidates [progressHomeProvider].
library;

import 'dart:math' as math;

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
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/shared/widgets/onboarding_tooltip.dart';
import 'package:zuralog/shared/widgets/profile_avatar_button.dart';

// ── ProgressHomeScreen ────────────────────────────────────────────────────────

/// Progress Home screen — Tab 3 root.
///
/// Uses [ConsumerStatefulWidget] to host the [AnimationController] that drives
/// the goal progress ring fill animations.
class ProgressHomeScreen extends ConsumerStatefulWidget {
  /// Creates the [ProgressHomeScreen].
  const ProgressHomeScreen({super.key});

  @override
  ConsumerState<ProgressHomeScreen> createState() => _ProgressHomeScreenState();
}

class _ProgressHomeScreenState extends ConsumerState<ProgressHomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.read(hapticServiceProvider).medium();
    ref.invalidate(progressHomeProvider);
    // Wait for the new value to settle (swallow errors — UI handles them).
    try {
      await ref.read(progressHomeProvider.future);
    } catch (_) {
      // Error is displayed via asyncData.when(error: ...).
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(progressHomeProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        title: OnboardingTooltip(
          screenKey: 'progress_home',
          tooltipKey: 'welcome',
          message: 'Set goals and I\'ll track your streaks automatically. '
              'Consistency is what matters most.',
          child: Text('Progress', style: AppTextStyles.h2),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppDimens.spaceMd),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.cardBackgroundDark,
        onRefresh: _onRefresh,
        child: asyncData.when(
          loading: () => const _LoadingState(),
          error: (error, _) => _ErrorState(
            message: 'Something went wrong. Please try again.',
            onRetry: () => ref.invalidate(progressHomeProvider),
          ),
          data: (data) {
            // Start ring animation once data arrives.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _ringController.forward(from: 0);
            });

            final isEmpty =
                data.goals.isEmpty && data.streaks.isEmpty;

            if (isEmpty) {
              return _EmptyState(
                onSetGoal: () => context.push(RouteNames.goalsPath),
              );
            }

            return _ContentView(
              data: data,
              ringController: _ringController,
            );
          },
        ),
      ),
    );
  }
}

// ── _LoadingState ─────────────────────────────────────────────────────────────

class _LoadingState extends StatefulWidget {
  const _LoadingState();

  @override
  State<_LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<_LoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmerAnim = CurvedAnimation(
      parent: _shimmerCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, _) {
        final shimmerColor = Color.lerp(
          AppColors.surfaceDark,
          AppColors.cardBackgroundDark,
          _shimmerAnim.value,
        )!;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.bottomClearance(context),
          ),
          children: [
            // Hero ring skeleton
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: shimmerColor,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            // Section label
            Container(
              height: 16,
              width: 80,
              decoration: BoxDecoration(
                color: shimmerColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            // Goal cards x3
            for (int i = 0; i < 3; i++) ...[
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
            ],
            const SizedBox(height: AppDimens.spaceMd),
            // Streaks section
            Container(
              height: 16,
              width: 64,
              decoration: BoxDecoration(
                color: shimmerColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            for (int i = 0; i < 2; i++) ...[
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
            ],
          ],
        );
      },
    );
  }
}

// ── _ErrorState ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
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
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.statusError,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                'Could not load progress',
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppDimens.spaceLg),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryButtonText,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusButton),
                  ),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _EmptyState ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSetGoal});

  final VoidCallback onSetGoal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: AppDimens.bottomClearance(context),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag_rounded,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Text('Start your journey', style: AppTextStyles.h2),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                'Set a goal and I\'ll track your streaks and progress.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.spaceLg),
              FilledButton(
                onPressed: onSetGoal,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryButtonText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceLg,
                    vertical: AppDimens.spaceMd,
                  ),
                ),
                child: Text(
                  'Set First Goal',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.primaryButtonText,
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

// ── _ContentView ──────────────────────────────────────────────────────────────

class _ContentView extends StatelessWidget {
  const _ContentView({
    required this.data,
    required this.ringController,
  });

  final ProgressHomeData data;
  final AnimationController ringController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        bottom: AppDimens.bottomClearance(context),
      ),
      children: [
        // Goals section
        if (data.goals.isNotEmpty) ...[
          _SectionHeader(
            title: 'Goals',
            trailingLabel: 'See all',
            onTrailingTap: () => context.push(RouteNames.goalsPath),
          ),
          _GoalsRow(goals: data.goals, ringController: ringController),
          const SizedBox(height: AppDimens.spaceLg),
        ],

        // Streaks section
        if (data.streaks.isNotEmpty) ...[
          const _SectionHeader(title: 'Streaks'),
          _StreaksRow(streaks: data.streaks),
          const SizedBox(height: AppDimens.spaceLg),
        ],

        // Week-over-week summary
        if (data.wow.metrics.isNotEmpty) ...[
          _SectionHeader(title: data.wow.weekLabel),
          _WoWSection(summary: data.wow),
          const SizedBox(height: AppDimens.spaceLg),
        ],

        // Quick nav row
        const _QuickNavRow(),
        const SizedBox(height: AppDimens.spaceLg),

        // Recent achievements
        if (data.recentAchievements.isNotEmpty) ...[
          const _SectionHeader(title: 'Recent Achievements'),
          _AchievementsRow(achievements: data.recentAchievements),
          const SizedBox(height: AppDimens.spaceLg),
        ],
      ],
    );
  }
}

// ── _SectionHeader ────────────────────────────────────────────────────────────

class _SectionHeader extends ConsumerWidget {
  const _SectionHeader({
    required this.title,
    this.trailingLabel,
    this.onTrailingTap,
  });

  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Row(
        children: [
          Text(title, style: AppTextStyles.h3),
          const Spacer(),
          if (trailingLabel != null && onTrailingTap != null)
            GestureDetector(
              onTap: () {
                ref.read(hapticServiceProvider).light();
                onTrailingTap!();
              },
              child: Text(
                trailingLabel!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── _GoalsRow ─────────────────────────────────────────────────────────────────

class _GoalsRow extends StatelessWidget {
  const _GoalsRow({required this.goals, required this.ringController});

  final List<Goal> goals;
  final AnimationController ringController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        itemCount: goals.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppDimens.spaceMd),
        itemBuilder: (context, index) => _GoalCard(
          goal: goals[index],
          ringController: ringController,
        ),
      ),
    );
  }
}

// ── _GoalCard ─────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.ringController});

  final Goal goal;
  final AnimationController ringController;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress ring centred at top of card
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: goal.progressFraction),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return SizedBox(
                  width: 80,
                  height: 80,
                  child: CustomPaint(
                    painter: _RingPainter(progress: value),
                    child: Center(
                      child: Text(
                        '${(value * 100).round()}%',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            goal.title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            '${_formatValue(goal.currentValue)} / '
            '${_formatValue(goal.targetValue)} ${goal.unit}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          _StatusChip(isCompleted: goal.isCompleted),
        ],
      ),
    );
  }

  String _formatValue(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

// ── _RingPainter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  static const double _strokeWidth = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - _strokeWidth) / 2;
    const startAngle = -math.pi / 2; // 12-o'clock

    // Track
    final trackPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Fill arc
    if (progress > 0) {
      final fillPaint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * math.pi * progress,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ── _StatusChip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        isCompleted ? 'Completed' : 'In progress',
        style: AppTextStyles.labelXs.copyWith(
          color: isCompleted ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ── _StreaksRow ───────────────────────────────────────────────────────────────

class _StreaksRow extends StatelessWidget {
  const _StreaksRow({required this.streaks});

  final List<UserStreak> streaks;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        itemCount: streaks.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppDimens.spaceMd),
        itemBuilder: (context, index) =>
            _StreakCard(streak: streaks[index]),
      ),
    );
  }
}

// ── _StreakCard ───────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final UserStreak streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  streak.type.displayName,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (streak.isFrozen)
                const Icon(
                  Icons.shield_rounded,
                  size: AppDimens.iconSm,
                  color: AppColors.primary,
                ),
            ],
          ),
          const Spacer(),
          Text(
            '${streak.currentCount}',
            style: AppTextStyles.h1.copyWith(
              color: AppColors.primary,
              height: 1,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'day streak',
            style: AppTextStyles.labelXs.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _WoWSection ───────────────────────────────────────────────────────────────

class _WoWSection extends StatelessWidget {
  const _WoWSection({required this.summary});

  final WoWSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        children: [
          for (int i = 0; i < summary.metrics.length; i++) ...[
            _WoWMetricRow(metric: summary.metrics[i]),
            if (i < summary.metrics.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderDark,
                indent: AppDimens.spaceMd,
                endIndent: AppDimens.spaceMd,
              ),
          ],
        ],
      ),
    );
  }
}

// ── _WoWMetricRow ─────────────────────────────────────────────────────────────

class _WoWMetricRow extends StatelessWidget {
  const _WoWMetricRow({required this.metric});

  final WoWMetric metric;

  @override
  Widget build(BuildContext context) {
    final delta = metric.deltaPercent;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              metric.label,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          Text(
            '${_formatValue(metric.currentValue)} ${metric.unit}',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          _DeltaChip(delta: delta),
        ],
      ),
    );
  }

  String _formatValue(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

// ── _DeltaChip ────────────────────────────────────────────────────────────────

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta});

  final double? delta;

  @override
  Widget build(BuildContext context) {
    if (delta == null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceSm,
          vertical: AppDimens.spaceXs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        ),
        child: Text(
          '—',
          style: AppTextStyles.labelXs.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      );
    }

    final isPositive = delta! >= 0;
    final color = isPositive ? AppColors.categoryActivity : AppColors.statusError;
    final label = '${isPositive ? '+' : ''}${delta!.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelXs.copyWith(color: color),
      ),
    );
  }
}

// ── _QuickNavRow ──────────────────────────────────────────────────────────────

class _QuickNavRow extends ConsumerWidget {
  const _QuickNavRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void trackAndPush(String label, String path) {
      ref.read(analyticsServiceProvider).capture(
        event: AnalyticsEvents.progressNavTapped,
        properties: {'section': label.toLowerCase()},
      );
      context.push(path);
    }

    final items = [
      _QuickNavItem(
        icon: Icons.flag_rounded,
        label: 'Goals',
        onTap: () => trackAndPush('Goals', RouteNames.goalsPath),
      ),
      _QuickNavItem(
        icon: Icons.emoji_events_rounded,
        label: 'Achievements',
        onTap: () => trackAndPush('Achievements', RouteNames.achievementsPath),
      ),
      _QuickNavItem(
        icon: Icons.bar_chart_rounded,
        label: 'Report',
        onTap: () => trackAndPush('Report', RouteNames.weeklyReportPath),
      ),
      _QuickNavItem(
        icon: Icons.book_rounded,
        label: 'Journal',
        onTap: () => trackAndPush('Journal', RouteNames.journalPath),
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      padding: const EdgeInsets.symmetric(
        vertical: AppDimens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items,
      ),
    );
  }
}

class _QuickNavItem extends ConsumerWidget {
  const _QuickNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(hapticServiceProvider).light();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: AppDimens.touchTargetMin + 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppDimens.touchTargetMin,
              height: AppDimens.touchTargetMin,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Icon(icon, color: AppColors.primary, size: AppDimens.iconMd),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              label,
              style: AppTextStyles.labelXs.copyWith(
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

// ── _AchievementsRow ──────────────────────────────────────────────────────────

class _AchievementsRow extends StatelessWidget {
  const _AchievementsRow({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        itemCount: achievements.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppDimens.spaceMd),
        itemBuilder: (context, index) =>
            _AchievementBadge(achievement: achievements[index]),
      ),
    );
  }
}

// ── _AchievementBadge ─────────────────────────────────────────────────────────

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({required this.achievement});

  final Achievement achievement;

  IconData _iconForName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('trophy') || lower.contains('award')) {
      return Icons.emoji_events_rounded;
    } else if (lower.contains('flame') || lower.contains('fire') || lower.contains('streak')) {
      return Icons.local_fire_department_rounded;
    } else if (lower.contains('heart') || lower.contains('health')) {
      return Icons.favorite_rounded;
    } else if (lower.contains('run') || lower.contains('activity') || lower.contains('step')) {
      return Icons.directions_run_rounded;
    } else if (lower.contains('sleep')) {
      return Icons.bedtime_rounded;
    } else if (lower.contains('goal') || lower.contains('flag')) {
      return Icons.flag_rounded;
    } else if (lower.contains('data') || lower.contains('sync')) {
      return Icons.sync_rounded;
    } else if (lower.contains('coach') || lower.contains('chat')) {
      return Icons.chat_rounded;
    } else {
      return Icons.star_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconForName(achievement.iconName),
                color: AppColors.primary,
                size: AppDimens.iconMd,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceXs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimens.spaceXs),
                ),
                child: Text(
                  'NEW',
                  style: AppTextStyles.labelXs.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            achievement.title,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Goals Screen — pushed from Progress Home.
///
/// Full goal management: create, edit, delete goals. Each goal shows a
/// progress ring, deadline, trend line, and AI commentary.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/data/domain/unit_converter.dart';
import 'package:zuralog/features/progress/presentation/goal_create_edit_sheet.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── GoalsScreen ───────────────────────────────────────────────────────────────

/// Goals screen — full CRUD list of all user goals.
class GoalsScreen extends ConsumerStatefulWidget {
  /// Creates the [GoalsScreen].
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  Future<void> _onRefresh() async {
    ref.invalidate(goalsProvider);
    try {
      await ref.read(goalsProvider.future);
    } catch (_) {
      // Error shown in UI via asyncData.when(error: ...).
    }
  }

  void _openCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GoalCreateEditSheet(),
    );
  }

  void _openEditSheet(Goal goal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GoalCreateEditSheet(initialGoal: goal),
    );
  }

  Future<void> _deleteGoal(String goalId) async {
    final repo = ref.read(progressRepositoryProvider);
    try {
      await repo.deleteGoal(goalId);
      ref.read(analyticsServiceProvider).capture(
        event: 'goal_deleted',
        properties: {'goal_id': goalId},
      );
      ref.invalidate(goalsProvider);
      ref.invalidate(progressHomeProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete goal')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncGoals = ref.watch(goalsProvider);

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: 'Goals',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            color: AppColors.primary,
            onPressed: _openCreateSheet,
            tooltip: 'New goal',
          ),
          const SizedBox(width: AppDimens.spaceSm),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.cardBackgroundDark,
        onRefresh: _onRefresh,
        child: asyncGoals.when(
          loading: () => const _LoadingState(),
          error: (err, _) => ZErrorState(
            message: 'Something went wrong. Please try again.',
            onRetry: () => ref.invalidate(goalsProvider),
          ),
          data: (goalList) {
            final goals = goalList.goals;
            if (goals.isEmpty) {
              return ZEmptyState(
                icon: Icons.flag_rounded,
                title: 'No goals yet',
                message: "Create your first goal and I'll track your progress.",
                actionLabel: 'Add your first goal',
                onAction: _openCreateSheet,
              );
            }
            return _GoalsList(
              goals: goals,
              onTap: (goal) {
                ref.read(analyticsServiceProvider).capture(
                  event: 'goal_tapped',
                  properties: {
                    'goal_id': goal.id,
                    'goal_type': goal.type.name,
                    'progress_percent':
                        (goal.progressFraction * 100).round(),
                    'is_completed': goal.isCompleted,
                  },
                );
                context.push(
                  RouteNames.goalDetailPath.replaceFirst(':id', goal.id),
                );
              },
              onLongPress: _openEditSheet,
              onDelete: _deleteGoal,
            );
          },
        ),
      ),
    );
  }
}

// ── _LoadingState ─────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 2.5,
      ),
    );
  }
}

// ── _GoalsList ────────────────────────────────────────────────────────────────

class _GoalsList extends StatelessWidget {
  const _GoalsList({
    required this.goals,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  final List<Goal> goals;
  final void Function(Goal goal) onTap;
  final void Function(Goal goal) onLongPress;
  final Future<void> Function(String goalId) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceXxl,
      ),
      itemCount: goals.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimens.spaceMd),
      itemBuilder: (context, index) {
        final goal = goals[index];
        return Dismissible(
          key: ValueKey(goal.id),
          direction: DismissDirection.endToStart,
          background: _DismissBackground(),
          confirmDismiss: (_) => _confirmDelete(context),
          onDismissed: (_) => onDelete(goal.id),
          child: _GoalCard(
            goal: goal,
            onTap: () => onTap(goal),
            onLongPress: () => onLongPress(goal),
          ),
        );
      },
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.elevatedSurfaceDark,
        title: Text('Delete goal?', style: AppTextStyles.titleMedium),
        content: Text(
          'This action cannot be undone.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.statusError,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _DismissBackground ────────────────────────────────────────────────────────

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.statusError.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: AppColors.statusError,
        size: AppDimens.iconMd,
      ),
    );
  }
}

// ── _GoalCard ─────────────────────────────────────────────────────────────────

class _GoalCard extends ConsumerWidget {
  const _GoalCard({
    required this.goal,
    required this.onTap,
    required this.onLongPress,
  });

  final Goal goal;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsSystem = ref.watch(unitsSystemProvider);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress ring
            _GoalRing(progressFraction: goal.progressFraction),
            const SizedBox(width: AppDimens.spaceMd),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + period chip row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            style: AppTextStyles.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(width: AppDimens.spaceSm),
                      _PeriodChip(period: goal.period),
                    ],
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  // Type display name
                  Text(
                    goal.type.displayName,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  // Current / target
                  Text(
                    '${_fmtValue(goal.currentValue)} / '
                    '${_fmtValue(goal.targetValue)} ${displayUnit(goal.unit, unitsSystem)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // AI commentary
                  if (goal.aiCommentary != null) ...[
                    const SizedBox(height: AppDimens.spaceSm),
                    Text(
                      goal.aiCommentary!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Deadline
                  if (goal.deadline != null) ...[
                    const SizedBox(height: AppDimens.spaceSm),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: AppDimens.spaceXs),
                        Text(
                          'Due ${_formatDeadline(goal.deadline!)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Completed pill
                  if (goal.isCompleted) ...[
                    const SizedBox(height: AppDimens.spaceSm),
                    _CompletedPill(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtValue(double v) {
    if (v >= 1000) {
      // Show with comma thousands separator
      final int rounded = v.round();
      final s = rounded.toString();
      if (s.length > 3) {
        final buf = StringBuffer();
        final offset = s.length % 3;
        if (offset > 0) {
          buf.write(s.substring(0, offset));
          if (s.length > offset) buf.write(',');
        }
        for (int i = offset; i < s.length; i += 3) {
          buf.write(s.substring(i, i + 3));
          if (i + 3 < s.length) buf.write(',');
        }
        return buf.toString();
      }
      return s;
    }
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  String _formatDeadline(String iso) {
    try {
      final date = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── _GoalRing ─────────────────────────────────────────────────────────────────

class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.progressFraction});

  final double progressFraction;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progressFraction),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 64,
          height: 64,
          child: CustomPaint(
            painter: _RingPainter(progress: value),
            child: Center(
                child: Text(
                '${(value * 100).round()}%',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── _RingPainter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  static const double _strokeWidth = 5;

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
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── _PeriodChip ───────────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.period});

  final GoalPeriod period;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        period.displayName,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
      ),
    );
  }
}

// ── _CompletedPill ────────────────────────────────────────────────────────────

class _CompletedPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.categoryActivity.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 12,
            color: AppColors.categoryActivity,
          ),
          const SizedBox(width: AppDimens.spaceXs),
          Text(
            'Completed',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.categoryActivity,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

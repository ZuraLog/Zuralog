/// Goal Detail Screen — deep-dive view for a single goal.
///
/// Composes the eight section widgets that make up the redesigned Goal
/// Detail page: hero, coach take, stats grid, trend chart, activity
/// heatmap, milestones track, related journal, and share action.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/goal_create_edit_sheet.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_activity_heatmap.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_coach_take_card.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_detail_hero.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_milestones_track.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_related_journal.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_share_action.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_stats_grid.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_trend_chart_card.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/subscription/domain/subscription_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── GoalDetailScreen ──────────────────────────────────────────────────────────

/// Full detail view for a single [Goal] identified by [goalId].
class GoalDetailScreen extends ConsumerStatefulWidget {
  /// Creates a [GoalDetailScreen] for the given [goalId].
  const GoalDetailScreen({super.key, required this.goalId});

  /// The goal ID passed from GoRouter path parameters.
  final String goalId;

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  // ── Actions ─────────────────────────────────────────────────────────────────

  void _openEdit(BuildContext context, Goal goal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GoalCreateEditSheet(initialGoal: goal),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Goal goal) async {
    final colors = AppColorsOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        title: Text(
          'Delete Goal?',
          style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'This will permanently delete "${goal.title}". This action cannot be undone.',
          style:
              AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.titleMedium.copyWith(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style:
                  AppTextStyles.titleMedium.copyWith(color: colors.accent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final repo = ref.read(progressRepositoryProvider);
    try {
      await repo.deleteGoal(goal.id);
      ref.invalidate(goalsProvider);
      ref.invalidate(progressHomeProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete goal. Please try again.')),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final goalsAsync = ref.watch(goalsProvider);

    return goalsAsync.when(
      loading: () => ZuralogScaffold(
        appBar: const ZuralogAppBar(title: 'Goal'),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, _) => ZuralogScaffold(
        appBar: const ZuralogAppBar(title: 'Goal'),
        body: Center(
          child: Text(
            'Failed to load goal',
            style: AppTextStyles.bodyLarge.copyWith(color: colors.textSecondary),
          ),
        ),
      ),
      data: (goalList) {
        Goal? goal;
        for (final g in goalList.goals) {
          if (g.id == widget.goalId) {
            goal = g;
            break;
          }
        }

        if (goal == null) {
          return ZuralogScaffold(
            appBar: const ZuralogAppBar(title: 'Goal'),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.flag_rounded,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  Text(
                    'Goal not found',
                    style: AppTextStyles.titleMedium
                        .copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Go back',
                      style:
                          AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _GoalDetailView(
          goal: goal,
          onEdit: () => _openEdit(context, goal!),
          onDelete: () => _confirmDelete(context, goal!),
        );
      },
    );
  }
}

// ── _GoalDetailView ───────────────────────────────────────────────────────────

class _GoalDetailView extends ConsumerWidget {
  const _GoalDetailView({
    required this.goal,
    required this.onEdit,
    required this.onDelete,
  });

  final Goal goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final isPremium = ref.watch(isPremiumProvider);

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: goal.title,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: onEdit,
            tooltip: 'Edit goal',
          ),
          IconButton(
            icon: Icon(Icons.delete_rounded, color: colors.accent),
            onPressed: onDelete,
            tooltip: 'Delete goal',
          ),
          const SizedBox(width: AppDimens.spaceXs),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          AppDimens.spaceSm,
          AppDimens.spaceMd,
          AppDimens.spaceXl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GoalDetailHero(goal: goal),
            if (goal.aiCommentary != null && goal.aiCommentary!.trim().isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceMd),
              const _SectionLabel('COACH TAKE'),
              const SizedBox(height: AppDimens.spaceSm),
              GoalCoachTakeCard(commentary: goal.aiCommentary, isPremium: isPremium),
            ],
            const SizedBox(height: AppDimens.spaceMd),
            const _SectionLabel('AT A GLANCE'),
            const SizedBox(height: AppDimens.spaceSm),
            GoalStatsGrid(goal: goal),
            const SizedBox(height: AppDimens.spaceMd),
            const _SectionLabel('TREND'),
            const SizedBox(height: AppDimens.spaceSm),
            GoalTrendChartCard(goal: goal),
            const SizedBox(height: AppDimens.spaceMd),
            const _SectionLabel('30-DAY ACTIVITY'),
            const SizedBox(height: AppDimens.spaceSm),
            GoalActivityHeatmap(goal: goal),
            const SizedBox(height: AppDimens.spaceMd),
            const _SectionLabel('MILESTONES'),
            const SizedBox(height: AppDimens.spaceSm),
            GoalMilestonesTrack(goal: goal),
            GoalRelatedJournal(goal: goal),
            const SizedBox(height: AppDimens.spaceMd),
            const GoalShareAction(),
          ],
        ),
      ),
    );
  }
}

// ── _SectionLabel ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

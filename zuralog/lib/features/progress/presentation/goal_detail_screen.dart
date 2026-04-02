/// Goal Detail Screen — deep-dive view for a single goal.
///
/// Shows an animated progress ring, sparkline history chart, goal metadata,
/// AI commentary, and edit/delete actions.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/unit_converter.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/goal_create_edit_sheet.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
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

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringController;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _ringAnimation = CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOutCubic,
    );
    _ringController.forward();
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

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
    final unitsSystem = ref.watch(unitsSystemProvider);
    final isPremium = ref.watch(isPremiumProvider);

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
          ringAnimation: _ringAnimation,
          unitsSystem: unitsSystem,
          isPremium: isPremium,
          onEdit: () => _openEdit(context, goal!),
          onDelete: () => _confirmDelete(context, goal!),
        );
      },
    );
  }
}

// ── _GoalDetailView ───────────────────────────────────────────────────────────

class _GoalDetailView extends StatelessWidget {
  const _GoalDetailView({
    required this.goal,
    required this.ringAnimation,
    required this.unitsSystem,
    required this.isPremium,
    required this.onEdit,
    required this.onDelete,
  });

  final Goal goal;
  final Animation<double> ringAnimation;
  final UnitsSystem unitsSystem;
  final bool isPremium;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  /// Returns a human-readable projected completion date based on recent
  /// progress history, or null when a projection cannot be made.
  String? _projectCompletionDate(Goal goal) {
    final history = goal.progressHistory;
    if (history.length < 2) return null;

    // Use the last min(14, history.length) entries
    final n = history.length < 14 ? history.length : 14;
    final window = history.sublist(history.length - n);

    // Average daily gain over the window
    final avgGain = (window.last - window.first) / (n - 1);
    if (avgGain <= 0) return null;

    final remaining = goal.targetValue - goal.currentValue;
    if (remaining <= 0) return 'Already achieved!';

    final daysNeeded = (remaining / avgGain).ceil();
    final projectedDate = DateTime.now().add(Duration(days: daysNeeded));

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[projectedDate.month - 1]} ${projectedDate.day}, ${projectedDate.year}';
  }

  String _fmtValue(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final projected = _projectCompletionDate(goal);
    final hasAiCommentary = goal.aiCommentary != null;
    final showAiCard = hasAiCommentary || projected != null;

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
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroSection(colors),
            const SizedBox(height: AppDimens.spaceMd),
            if (goal.progressHistory.isNotEmpty) ...[
              _buildSparklineCard(colors),
              const SizedBox(height: AppDimens.spaceMd),
            ],
            _buildDetailsCard(colors, projected: projected),
            if (showAiCard) ...[
              const SizedBox(height: AppDimens.spaceMd),
              if (!isPremium && hasAiCommentary)
                ZLockedOverlay(
                  headline: 'Get AI insights on your goals',
                  body:
                      'Upgrade to Pro for personalized AI commentary that tells you exactly how your goals are tracking.',
                  icon: Icons.auto_awesome_rounded,
                  child: _buildAiCommentaryCard(colors, projected: projected),
                )
              else
                _buildAiCommentaryCard(colors, projected: projected),
            ],
            const SizedBox(height: AppDimens.spaceXl),
          ],
        ),
      ),
    );
  }

  // ── Hero Section ─────────────────────────────────────────────────────────────

  Widget _buildHeroSection(AppColorsOf colors) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        children: [
          // Animated progress ring
          AnimatedBuilder(
            animation: ringAnimation,
            builder: (context, child) {
              final progress = goal.progressFraction * ringAnimation.value;
              return SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: progress,
                    strokeWidth: 10,
                    trackColor: colors.border,
                    progressColor: AppColors.primary,
                  ),
                  child: Center(
                      child: Text(
                        '${(goal.progressFraction * 100).round()}%',
                        style: AppTextStyles.displaySmall.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppDimens.spaceMd),
          // Current value
          Text(
            _fmtValue(goal.currentValue),
            style: AppTextStyles.displayLarge.copyWith(
              color: colors.textPrimary,
              fontSize: 40,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          // Target unit subtitle
          Text(
            '/ ${_fmtValue(goal.targetValue)} ${displayUnit(goal.unit, unitsSystem)}',
            style: AppTextStyles.bodyLarge.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (goal.isCompleted) ...[
            const SizedBox(height: AppDimens.spaceMd),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceXs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusChip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppDimens.spaceXs),
                  Text(
                    'Completed',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sparkline Card ────────────────────────────────────────────────────────────

  Widget _buildSparklineCard(AppColorsOf colors) {
    final history = goal.progressHistory;
    final recent = history.length > 14
        ? history.sublist(history.length - 14)
        : history;

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress History',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          SizedBox(
            height: 80,
            child: CustomPaint(
              size: const Size(double.infinity, 80),
              painter: _SparklinePainter(
                values: recent,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Details Card ─────────────────────────────────────────────────────────────

  Widget _buildDetailsCard(AppColorsOf colors, {String? projected}) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _DetailRow(label: 'Type', value: goal.type.displayName),
          _DetailRow(label: 'Period', value: goal.period.displayName),
          _DetailRow(label: 'Started', value: _formatDate(goal.startDate)),
          if (goal.deadline != null)
            _DetailRow(label: 'Deadline', value: _formatDate(goal.deadline)),
          if (projected != null)
            _DetailRow(label: 'Projected', value: projected),
        ],
      ),
    );
  }

  // ── AI Commentary Card ────────────────────────────────────────────────────────

  Widget _buildAiCommentaryCard(AppColorsOf colors, {String? projected}) {
    // Build the display text: append projection sentence when available.
    final String displayText;
    if (goal.aiCommentary != null) {
      if (projected != null && projected != 'Already achieved!') {
        displayText =
            '${goal.aiCommentary!} At your current pace, you\'ll hit your target by $projected.';
      } else {
        displayText = goal.aiCommentary!;
      }
    } else {
      // No aiCommentary but there IS a projection — show only the projection.
      displayText =
          'At your current pace, you\'ll hit your target by $projected.';
    }

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: AppDimens.iconSm + 4,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              displayText,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _DetailRow ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _RingPainter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor;
}

// ── _SparklinePainter ─────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = (maxVal - minVal).abs();
    final effectiveRange = range < 1e-10 ? 1.0 : range;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final normalized = (values[i] - minVal) / effectiveRange;
      // Invert Y: high value = top of canvas
      final y = size.height * (1.0 - normalized * 0.8 - 0.1);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw last-point dot — inset by radius to stay within canvas bounds
    final lastX = size.width - 4.0;
    final lastNorm = (values.last - minVal) / effectiveRange;
    final lastY = size.height * (1.0 - lastNorm * 0.8 - 0.1);
    canvas.drawCircle(
      Offset(lastX, lastY),
      4,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      !listEquals(old.values, values) || old.color != color;
}

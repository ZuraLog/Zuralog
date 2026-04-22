/// Zuralog — Nutrition Macro Progress Card.
///
/// Shows a labeled progress bar for each macro nutrient that has a goal set,
/// with a color-coded status icon indicating whether the goal is on track,
/// at risk, or exceeded.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

// ── Color constants ────────────────────────────────────────────────────────────

const _colorProtein = Color(0xFF34C759); // green
const _colorCarbs = Color(0xFFFF9F0A);   // amber
const _colorFat = Color(0xFFFF9F0A);     // amber
const _colorFiber = Color(0xFF63E6BE);   // teal
const _colorSugar = Color(0xFF64D2FF);   // sky blue
const _colorSodium = Color(0xFFBF5AF2);  // purple
const _colorOffTrack = Color(0xFFFF3B30); // red

// ── _MacroRow helper ─────────────────────────────────────────────────────────

/// Data class representing a single macro row to display.
class _MacroRow {
  const _MacroRow({
    required this.label,
    required this.actual,
    required this.target,
    required this.unit,
    required this.isMin,
    required this.baseColor,
  });

  final String label;
  final double actual;
  final double target;
  final String unit;
  final bool isMin;
  final Color baseColor;
}

// ── NutritionMacroProgressCard ────────────────────────────────────────────────

/// Card that shows a progress bar row for each macro nutrient that has an
/// active goal. Rows only appear when the corresponding goal field is non-null.
///
/// When no goals are set at all, the widget renders an empty [SizedBox].
class NutritionMacroProgressCard extends ConsumerWidget {
  const NutritionMacroProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(nutritionGoalsProvider);
    final summaryAsync = ref.watch(nutritionDaySummaryProvider);

    return goalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (goals) {
        if (!goals.hasGoals) return const SizedBox.shrink();

        return summaryAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (summary) => _buildCard(context, goals, summary),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    NutritionGoals goals,
    NutritionDaySummary summary,
  ) {
    final rows = _buildRows(goals, summary);
    if (rows.isEmpty) return const SizedBox.shrink();

    return ZuralogCard(
      variant: ZCardVariant.data,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Macro Goals',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColorsOf(context).textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
              child: _MacroRowWidget(row: row),
            ),
          ),
        ],
      ),
    );
  }

  List<_MacroRow> _buildRows(NutritionGoals goals, NutritionDaySummary summary) {
    final rows = <_MacroRow>[];

    if (goals.proteinMinG != null) {
      rows.add(_MacroRow(
        label: 'Protein',
        actual: summary.totalProteinG,
        target: goals.proteinMinG!,
        unit: 'g',
        isMin: true,
        baseColor: _colorProtein,
      ));
    }

    if (goals.carbsMaxG != null) {
      rows.add(_MacroRow(
        label: 'Carbs',
        actual: summary.totalCarbsG,
        target: goals.carbsMaxG!,
        unit: 'g',
        isMin: false,
        baseColor: _colorCarbs,
      ));
    }

    if (goals.fatMaxG != null) {
      rows.add(_MacroRow(
        label: 'Fat',
        actual: summary.totalFatG,
        target: goals.fatMaxG!,
        unit: 'g',
        isMin: false,
        baseColor: _colorFat,
      ));
    }

    if (goals.fiberMinG != null) {
      rows.add(_MacroRow(
        label: 'Fiber',
        actual: summary.fiberG,
        target: goals.fiberMinG!,
        unit: 'g',
        isMin: true,
        baseColor: _colorFiber,
      ));
    }

    if (goals.sodiumMaxMg != null) {
      rows.add(_MacroRow(
        label: 'Sodium',
        actual: summary.sodiumMg,
        target: goals.sodiumMaxMg!,
        unit: 'mg',
        isMin: false,
        baseColor: _colorSodium,
      ));
    }

    if (goals.sugarMaxG != null) {
      rows.add(_MacroRow(
        label: 'Sugar',
        actual: summary.sugarG,
        target: goals.sugarMaxG!,
        unit: 'g',
        isMin: false,
        baseColor: _colorSugar,
      ));
    }

    return rows;
  }
}

// ── _MacroRowWidget ────────────────────────────────────────────────────────────

class _MacroRowWidget extends StatelessWidget {
  const _MacroRowWidget({required this.row});

  final _MacroRow row;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final status = nutritionGoalStatus(
      actual: row.actual,
      target: row.target,
      isMin: row.isMin,
    );
    final barColor = status == NutritionGoalStatus.offTrack
        ? _colorOffTrack
        : row.baseColor;
    final progress = row.target > 0
        ? (row.actual / row.target).clamp(0.0, 1.0)
        : 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Status icon.
        _StatusIcon(status: status),
        const SizedBox(width: AppDimens.spaceXs),

        // Label — fixed 50px so all bars align.
        SizedBox(
          width: 50,
          child: Text(
            row.label,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppDimens.spaceXs),

        // Progress bar.
        Expanded(
          child: _ColoredProgressBar(
            value: progress,
            color: barColor,
          ),
        ),
        const SizedBox(width: AppDimens.spaceXs),

        // actual / target unit label.
        Text(
          '${_fmt(row.actual)}/${_fmt(row.target)} ${row.unit}',
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Formats a number with no trailing decimal places when it is a whole
  /// number, otherwise shows one decimal place.
  static String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

// ── _StatusIcon ────────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final NutritionGoalStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case NutritionGoalStatus.onTrack:
        return const Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: _colorProtein, // green
        );
      case NutritionGoalStatus.atRisk:
        return const Icon(
          Icons.warning_amber_rounded,
          size: 16,
          color: _colorCarbs, // amber
        );
      case NutritionGoalStatus.offTrack:
        return const Icon(
          Icons.cancel_rounded,
          size: 16,
          color: _colorOffTrack, // red
        );
    }
  }
}

// ── _ColoredProgressBar ───────────────────────────────────────────────────────

/// A slim horizontal progress bar with a configurable fill color.
///
/// Built inline (not using [ZProgressBar]) because [ZProgressBar] always fills
/// with Sage green and the pattern overlay — macro rows need per-macro colors.
class _ColoredProgressBar extends StatelessWidget {
  const _ColoredProgressBar({
    required this.value,
    required this.color,
  });

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            // Inactive track.
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // Active fill with animation.
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: value),
                duration: AppMotion.durationMedium,
                curve: AppMotion.curveEntrance,
                builder: (context, animatedValue, _) {
                  if (animatedValue == 0) return const SizedBox.shrink();
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: animatedValue,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

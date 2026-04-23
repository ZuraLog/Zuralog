library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/nutrition/presentation/nutrition_goals_wizard.dart'
    show WeightGoalChoice;
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Args ──────────────────────────────────────────────────────────────────────

class NutritionMacroReviewArgs {
  const NutritionMacroReviewArgs({
    required this.calorieBudget,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.goalChoice,
  });

  final int calorieBudget;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final WeightGoalChoice goalChoice;
}

// ── Recommended ranges record ─────────────────────────────────────────────────

class MacroRanges {
  const MacroRanges({
    required this.proteinMin,
    required this.proteinMax,
    required this.carbsMin,
    required this.carbsMax,
    required this.fatMin,
    required this.fatMax,
  });

  final double proteinMin;
  final double proteinMax;
  final double carbsMin;
  final double carbsMax;
  final double fatMin;
  final double fatMax;

  double get proteinMid => (proteinMin + proteinMax) / 2;
  double get carbsMid => (carbsMin + carbsMax) / 2;
  double get fatMid => (fatMin + fatMax) / 2;
}

// ── NutritionMacroReviewScreen ────────────────────────────────────────────────

class NutritionMacroReviewScreen extends ConsumerStatefulWidget {
  const NutritionMacroReviewScreen({
    super.key,
    required this.calorieBudget,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.goalChoice,
  });

  static const routePath = '/nutrition/goals/review';

  final int calorieBudget;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final WeightGoalChoice goalChoice;

  static MacroRanges recommendedRanges(WeightGoalChoice goal) {
    return switch (goal) {
      WeightGoalChoice.lose => const MacroRanges(
          proteinMin: 0.30,
          proteinMax: 0.40,
          carbsMin: 0.35,
          carbsMax: 0.45,
          fatMin: 0.20,
          fatMax: 0.30,
        ),
      WeightGoalChoice.maintain => const MacroRanges(
          proteinMin: 0.25,
          proteinMax: 0.35,
          carbsMin: 0.40,
          carbsMax: 0.50,
          fatMin: 0.25,
          fatMax: 0.35,
        ),
      WeightGoalChoice.gain => const MacroRanges(
          proteinMin: 0.30,
          proteinMax: 0.40,
          carbsMin: 0.40,
          carbsMax: 0.50,
          fatMin: 0.20,
          fatMax: 0.30,
        ),
    };
  }

  @override
  ConsumerState<NutritionMacroReviewScreen> createState() =>
      _NutritionMacroReviewScreenState();
}

class _NutritionMacroReviewScreenState
    extends ConsumerState<NutritionMacroReviewScreen> {
  late double _proteinPct;
  late double _carbsPct;
  late double _fatPct;
  bool _isSaving = false;

  static final _calFmt = NumberFormat('#,###');

  late MacroRanges _ranges;

  int get _proteinG => ((widget.calorieBudget * _proteinPct) / 4).round();
  int get _carbsG => ((widget.calorieBudget * _carbsPct) / 4).round();
  int get _fatG => ((widget.calorieBudget * _fatPct) / 9).round();

  bool _inRange(double pct, double min, double max) => pct >= min && pct <= max;

  bool get _allInRange =>
      _inRange(_proteinPct, _ranges.proteinMin, _ranges.proteinMax) &&
      _inRange(_carbsPct, _ranges.carbsMin, _ranges.carbsMax) &&
      _inRange(_fatPct, _ranges.fatMin, _ranges.fatMax);

  @override
  void initState() {
    super.initState();
    _ranges = NutritionMacroReviewScreen.recommendedRanges(widget.goalChoice);
    final total = widget.calorieBudget.toDouble();
    _proteinPct = total > 0 ? (widget.proteinG * 4) / total : _ranges.proteinMid;
    _carbsPct = total > 0 ? (widget.carbsG * 4) / total : _ranges.carbsMid;
    _fatPct = total > 0 ? (widget.fatG * 9) / total : _ranges.fatMid;
  }

  void _resetToRecommended() {
    setState(() {
      _proteinPct = _ranges.proteinMid;
      _carbsPct = _ranges.carbsMid;
      _fatPct = _ranges.fatMid;
    });
  }

  Future<void> _saveGoals() async {
    setState(() => _isSaving = true);
    final repo = ref.read(progressRepositoryProvider);
    try {
      await repo.deleteNutritionGoals();
      await repo.createGoal(
        type: GoalType.dailyCalorieLimit,
        period: GoalPeriod.daily,
        title: 'Daily Calorie Limit',
        targetValue: widget.calorieBudget.toDouble(),
        unit: 'kcal',
      );
      await repo.createGoal(
        type: GoalType.dailyProteinMin,
        period: GoalPeriod.daily,
        title: 'Daily Protein Minimum',
        targetValue: _proteinG.toDouble(),
        unit: 'g',
      );
      await repo.createGoal(
        type: GoalType.dailyCarbsMax,
        period: GoalPeriod.daily,
        title: 'Daily Carbs Maximum',
        targetValue: _carbsG.toDouble(),
        unit: 'g',
      );
      await repo.createGoal(
        type: GoalType.dailyFatMax,
        period: GoalPeriod.daily,
        title: 'Daily Fat Maximum',
        targetValue: _fatG.toDouble(),
        unit: 'g',
      );

      ref.invalidate(nutritionGoalsProvider);
      ref.invalidate(goalsProvider);

      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save goals. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: colors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Review your goals',
          style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
                vertical: AppDimens.spaceMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calorie hero
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimens.spaceLg),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(AppDimens.shapeMd),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your daily calorie target',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceXs),
                        Text(
                          '${_calFmt.format(widget.calorieBudget)} kcal/day',
                          style: AppTextStyles.displayLarge.copyWith(color: colors.primary),
                        ),
                        const SizedBox(height: AppDimens.spaceXs),
                        Text(
                          'Calculated from your profile · ${switch (widget.goalChoice) {
                            WeightGoalChoice.lose => 'Losing weight',
                            WeightGoalChoice.maintain => 'Maintaining weight',
                            WeightGoalChoice.gain => 'Gaining weight',
                          }}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceMd),

                  // Recommended card
                  _RecommendedCard(
                    allInRange: _allInRange,
                    goalChoice: widget.goalChoice,
                    ranges: _ranges,
                    calorieBudget: widget.calorieBudget,
                    colors: colors,
                  ),

                  const SizedBox(height: AppDimens.spaceLg),

                  Text(
                    'Adjust your split',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceMd),

                  _MacroSliderRow(
                    label: 'Protein',
                    grams: _proteinG,
                    pct: _proteinPct,
                    color: const Color(0xFF5B8DB8),
                    rangeMin: _ranges.proteinMin,
                    rangeMax: _ranges.proteinMax,
                    onChanged: (v) => setState(() => _proteinPct = v),
                    colors: colors,
                  ),

                  const SizedBox(height: AppDimens.spaceMd),

                  _MacroSliderRow(
                    label: 'Carbohydrates',
                    grams: _carbsG,
                    pct: _carbsPct,
                    color: const Color(0xFF8FBC8F),
                    rangeMin: _ranges.carbsMin,
                    rangeMax: _ranges.carbsMax,
                    onChanged: (v) => setState(() => _carbsPct = v),
                    colors: colors,
                  ),

                  const SizedBox(height: AppDimens.spaceMd),

                  _MacroSliderRow(
                    label: 'Fat',
                    grams: _fatG,
                    pct: _fatPct,
                    color: const Color(0xFFD4A97A),
                    rangeMin: _ranges.fatMin,
                    rangeMax: _ranges.fatMax,
                    onChanged: (v) => setState(() => _fatPct = v),
                    colors: colors,
                  ),

                  if (!_allInRange) ...[
                    const SizedBox(height: AppDimens.spaceMd),
                    Center(
                      child: TextButton(
                        onPressed: _resetToRecommended,
                        child: Text(
                          'Reset to recommended split',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppDimens.spaceLg),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.fromLTRB(
              AppDimens.spaceLg,
              AppDimens.spaceSm,
              AppDimens.spaceLg,
              bottomPadding + AppDimens.spaceMd,
            ),
            decoration: BoxDecoration(
              color: colors.background,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ZButton(
              label: _isSaving ? 'Saving...' : 'Save Goals',
              onPressed: _isSaving ? null : _saveGoals,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _RecommendedCard ──────────────────────────────────────────────────────────

class _RecommendedCard extends StatelessWidget {
  const _RecommendedCard({
    required this.allInRange,
    required this.goalChoice,
    required this.ranges,
    required this.calorieBudget,
    required this.colors,
  });

  final bool allInRange;
  final WeightGoalChoice goalChoice;
  final MacroRanges ranges;
  final int calorieBudget;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    final borderColor = allInRange
        ? const Color(0xFF4CAF50)
        : const Color(0xFFFF8C42);
    final bgColor = allInRange
        ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
        : const Color(0xFFFF8C42).withValues(alpha: 0.08);

    final optProteinG = ((calorieBudget * ranges.proteinMid) / 4).round();
    final optCarbsG = ((calorieBudget * ranges.carbsMid) / 4).round();
    final optFatG = ((calorieBudget * ranges.fatMid) / 9).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceSm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(AppDimens.shapePill),
                ),
                child: Text(
                  allInRange ? 'RECOMMENDED FOR YOUR GOAL' : 'OUTSIDE RECOMMENDED RANGE',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          if (allInRange) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _OptimalMacro(
                  label: 'Protein',
                  grams: optProteinG,
                  pct: (ranges.proteinMid * 100).round(),
                  color: borderColor,
                ),
                Container(width: 1, height: 40, color: borderColor.withValues(alpha: 0.3)),
                _OptimalMacro(
                  label: 'Carbs',
                  grams: optCarbsG,
                  pct: (ranges.carbsMid * 100).round(),
                  color: borderColor,
                ),
                Container(width: 1, height: 40, color: borderColor.withValues(alpha: 0.3)),
                _OptimalMacro(
                  label: 'Fat',
                  grams: optFatG,
                  pct: (ranges.fatMid * 100).round(),
                  color: borderColor,
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Standard sports nutrition · optimised for ${switch (goalChoice) {
                WeightGoalChoice.lose => 'fat loss',
                WeightGoalChoice.maintain => 'maintenance',
                WeightGoalChoice.gain => 'muscle gain',
              }}',
              style: AppTextStyles.bodySmall.copyWith(color: borderColor),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              "Your macro split is outside the recommended range for your goal. You can still save — but moving closer to the recommended values will get you better results.",
              style: AppTextStyles.bodySmall.copyWith(color: borderColor),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Recommended: Protein ${(ranges.proteinMid * 100).round()}% · Carbs ${(ranges.carbsMid * 100).round()}% · Fat ${(ranges.fatMid * 100).round()}%',
              style: AppTextStyles.labelSmall.copyWith(
                color: borderColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptimalMacro extends StatelessWidget {
  const _OptimalMacro({
    required this.label,
    required this.grams,
    required this.pct,
    required this.color,
  });

  final String label;
  final int grams;
  final int pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${grams}g',
          style: AppTextStyles.labelLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '$label · $pct%',
          style: AppTextStyles.bodySmall.copyWith(color: color),
        ),
      ],
    );
  }
}

// ── _MacroSliderRow ────────────────────────────────────────────────────────────

class _MacroSliderRow extends StatelessWidget {
  const _MacroSliderRow({
    required this.label,
    required this.grams,
    required this.pct,
    required this.color,
    required this.rangeMin,
    required this.rangeMax,
    required this.onChanged,
    required this.colors,
  });

  final String label;
  final int grams;
  final double pct;
  final Color color;
  final double rangeMin;
  final double rangeMax;
  final ValueChanged<double> onChanged;
  final AppColorsOf colors;

  bool get _inRange => pct >= rangeMin && pct <= rangeMax;

  @override
  Widget build(BuildContext context) {
    final pctDisplay = (pct * 100).round();
    final thumbColor = _inRange ? color : const Color(0xFFFF8C42);
    final badgeColor = _inRange ? const Color(0xFF4CAF50) : const Color(0xFFFF8C42);
    final badgeBg = badgeColor.withValues(alpha: 0.12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppDimens.spaceXs),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(color: colors.textPrimary),
            ),
            const Spacer(),
            Text(
              '$grams g',
              style: AppTextStyles.labelMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppDimens.spaceXs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(AppDimens.shapePill),
              ),
              child: Text(
                _inRange ? '$pctDisplay% ok' : '$pctDisplay% !',
                style: AppTextStyles.labelSmall.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceXs),
        // Range band track using Stack
        SizedBox(
          height: 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background track
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Green recommended range band
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final trackWidth = constraints.maxWidth;
                  final leftFrac = rangeMin / 0.80;
                  final rightFrac = rangeMax / 0.80;
                  return Stack(
                    children: [
                      Positioned(
                        left: trackWidth * leftFrac,
                        width: trackWidth * (rightFrac - leftFrac),
                        top: 8,
                        height: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Slider (on top)
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbColor: thumbColor,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  overlayColor: thumbColor.withValues(alpha: 0.15),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: pct.clamp(0.05, 0.80),
                  min: 0.05,
                  max: 0.80,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('5%', style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary)),
            Text(
              'optimal ${(rangeMin * 100).round()}-${(rangeMax * 100).round()}%',
              style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF4CAF50)),
            ),
            Text('80%', style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

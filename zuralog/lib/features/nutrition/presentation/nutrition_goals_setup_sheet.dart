/// Zuralog — Nutrition Goals Setup Sheet.
///
/// A two-step guided wizard that collects the user's body metrics,
/// activity level, and weight goal, then calculates their TDEE and
/// routes to [NutritionMacroReviewScreen] to confirm macro targets.
///
/// Step 0 — Body metrics: height (cm), weight (kg), age (years), sex.
/// Step 1 — Lifestyle: activity level and weight goal.
///
/// Open via [NutritionGoalsSetupSheet.show].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/nutrition/domain/tdee_calculator.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/cards/z_selectable_tile.dart';
import 'package:zuralog/shared/widgets/feedback/z_bottom_sheet.dart';
import 'package:zuralog/shared/widgets/inputs/z_labeled_number_field.dart';
import 'package:zuralog/shared/widgets/inputs/z_slider.dart';
import 'package:zuralog/shared/widgets/inputs/z_toggle_group.dart';

// ── NutritionMacroReviewScreen ────────────────────────────────────────────────

/// Review screen shown after TDEE calculation.
///
/// Displays the calorie budget prominently and lets the user adjust their
/// protein, carbs, and fat split with sliders before saving four goals:
/// daily_calorie_limit, daily_protein_min, daily_carbs_max, daily_fat_max.
class NutritionMacroReviewScreen extends ConsumerStatefulWidget {
  const NutritionMacroReviewScreen({
    super.key,
    required this.calorieBudget,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  /// Daily calorie target calculated from TDEE.
  final int calorieBudget;

  /// Initial protein target in grams.
  final int proteinG;

  /// Initial carbohydrates target in grams.
  final int carbsG;

  /// Initial fat target in grams.
  final int fatG;

  @override
  ConsumerState<NutritionMacroReviewScreen> createState() =>
      _NutritionMacroReviewScreenState();
}

class _NutritionMacroReviewScreenState
    extends ConsumerState<NutritionMacroReviewScreen> {
  // ── Macro split percentages (protein / carbs / fat) ───────────────────────

  late double _proteinPct;
  late double _carbsPct;
  late double _fatPct;

  bool _isSaving = false;

  // ── Derived gram values from percentages ──────────────────────────────────

  int get _proteinG => ((widget.calorieBudget * _proteinPct) / 4).round();
  int get _carbsG => ((widget.calorieBudget * _carbsPct) / 4).round();
  int get _fatG => ((widget.calorieBudget * _fatPct) / 9).round();

  // ── Number formatter ──────────────────────────────────────────────────────

  static final _calFmt = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    // Convert initial gram values to percentage splits.
    final totalCals = widget.calorieBudget.toDouble();
    _proteinPct = totalCals > 0
        ? (widget.proteinG * 4) / totalCals
        : 0.30;
    _carbsPct = totalCals > 0
        ? (widget.carbsG * 4) / totalCals
        : 0.40;
    _fatPct = totalCals > 0
        ? (widget.fatG * 9) / totalCals
        : 0.30;
  }

  // ── Save all four nutrition goals ─────────────────────────────────────────

  Future<void> _saveGoals() async {
    setState(() => _isSaving = true);
    final repo = ref.read(progressRepositoryProvider);

    try {
      // Save calorie budget first, then the three macro goals.
      await repo.createGoal(
        type: GoalType.dailyCalorieLimit,
        period: GoalPeriod.daily,
        title: 'Daily Calorie Limit',
        targetValue: widget.calorieBudget.toDouble(),
        unit: 'kcal',
      );
      await repo.createGoal(
        type: GoalType.custom,
        period: GoalPeriod.daily,
        title: 'daily_protein_min',
        targetValue: _proteinG.toDouble(),
        unit: 'g',
      );
      await repo.createGoal(
        type: GoalType.custom,
        period: GoalPeriod.daily,
        title: 'daily_carbs_max',
        targetValue: _carbsG.toDouble(),
        unit: 'g',
      );
      await repo.createGoal(
        type: GoalType.custom,
        period: GoalPeriod.daily,
        title: 'daily_fat_max',
        targetValue: _fatG.toDouble(),
        unit: 'g',
      );

      // Refresh nutrition and goals state.
      ref.invalidate(nutritionGoalsProvider);
      ref.invalidate(goalsProvider);

      if (mounted) {
        // Pop back to the nutrition home (removes the review screen and the
        // setup bottom sheet that's underneath it).
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save goals. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
          style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          // ── Scrollable content ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
                vertical: AppDimens.spaceMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Calorie budget hero ──────────────────────────────
                  _CalorieBudgetHero(
                    calorieBudget: widget.calorieBudget,
                    formatter: _calFmt,
                    colors: colors,
                  ),

                  const SizedBox(height: AppDimens.spaceLg),

                  // ── Macro sliders heading ────────────────────────────
                  Text(
                    'Adjust your macro split',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  Text(
                    'Drag the sliders to change how your calories are spread '
                    'across protein, carbs, and fat.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceLg),

                  // ── Protein slider ───────────────────────────────────
                  _MacroSlider(
                    label: 'Protein',
                    grams: _proteinG,
                    pct: _proteinPct,
                    color: const Color(0xFF5B8DB8),
                    onChanged: (v) => setState(() => _proteinPct = v),
                    colors: colors,
                  ),

                  const SizedBox(height: AppDimens.spaceMd),

                  // ── Carbs slider ─────────────────────────────────────
                  _MacroSlider(
                    label: 'Carbohydrates',
                    grams: _carbsG,
                    pct: _carbsPct,
                    color: const Color(0xFF8FBC8F),
                    onChanged: (v) => setState(() => _carbsPct = v),
                    colors: colors,
                  ),

                  const SizedBox(height: AppDimens.spaceMd),

                  // ── Fat slider ───────────────────────────────────────
                  _MacroSlider(
                    label: 'Fat',
                    grams: _fatG,
                    pct: _fatPct,
                    color: const Color(0xFFD4A97A),
                    onChanged: (v) => setState(() => _fatPct = v),
                    colors: colors,
                  ),

                  const SizedBox(height: AppDimens.spaceLg),

                  // ── Macro summary row ────────────────────────────────
                  _MacroSummaryRow(
                    proteinG: _proteinG,
                    carbsG: _carbsG,
                    fatG: _fatG,
                    colors: colors,
                  ),

                  const SizedBox(height: AppDimens.spaceLg),
                ],
              ),
            ),
          ),

          // ── Sticky Save Goals button ───────────────────────────────────
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
              label: _isSaving ? 'Saving…' : 'Save Goals',
              onPressed: _isSaving ? null : _saveGoals,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calorie budget hero ───────────────────────────────────────────────────────

class _CalorieBudgetHero extends StatelessWidget {
  const _CalorieBudgetHero({
    required this.calorieBudget,
    required this.formatter,
    required this.colors,
  });

  final int calorieBudget;
  final NumberFormat formatter;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'Your daily calorie budget',
            style: AppTextStyles.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            '${formatter.format(calorieBudget)} kcal/day',
            style: AppTextStyles.h1.copyWith(color: colors.primary),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'Calculated from your body metrics and activity level.',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Macro slider row ──────────────────────────────────────────────────────────

class _MacroSlider extends StatelessWidget {
  const _MacroSlider({
    required this.label,
    required this.grams,
    required this.pct,
    required this.color,
    required this.onChanged,
    required this.colors,
  });

  final String label;
  final int grams;
  final double pct;
  final Color color;
  final ValueChanged<double> onChanged;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    final pctDisplay = (pct * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppDimens.spaceXs),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: colors.textPrimary,
              ),
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
            Text(
              '($pctDisplay%)',
              style: AppTextStyles.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        ZSlider(
          value: pct.clamp(0.05, 0.80),
          min: 0.05,
          max: 0.80,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── Macro summary row ─────────────────────────────────────────────────────────

class _MacroSummaryRow extends StatelessWidget {
  const _MacroSummaryRow({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.colors,
  });

  final int proteinG;
  final int carbsG;
  final int fatG;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryTile(
          label: 'Protein',
          value: '$proteinG g',
          color: const Color(0xFF5B8DB8),
          colors: colors,
        ),
        const SizedBox(width: AppDimens.spaceSm),
        _SummaryTile(
          label: 'Carbs',
          value: '$carbsG g',
          color: const Color(0xFF8FBC8F),
          colors: colors,
        ),
        const SizedBox(width: AppDimens.spaceSm),
        _SummaryTile(
          label: 'Fat',
          value: '$fatG g',
          color: const Color(0xFFD4A97A),
          colors: colors,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
  });

  final String label;
  final String value;
  final Color color;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceSm,
          vertical: AppDimens.spaceMd,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppDimens.shapeSm),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Label maps ────────────────────────────────────────────────────────────────

const _activityLabels = {
  ActivityLevel.sedentary: 'Sedentary (little or no exercise)',
  ActivityLevel.lightlyActive: 'Lightly active (1-3 days/week)',
  ActivityLevel.moderatelyActive: 'Moderately active (3-5 days/week)',
  ActivityLevel.veryActive: 'Very active (6-7 days/week)',
  ActivityLevel.extraActive: 'Extra active (physical job)',
};

const _goalLabels = {
  WeightGoal.loseFast: 'Lose weight fast (-500 kcal/day)',
  WeightGoal.loseHalf: 'Lose weight (-250 kcal/day)',
  WeightGoal.maintain: 'Maintain weight',
  WeightGoal.gainHalf: 'Gain weight (+250 kcal/day)',
  WeightGoal.gainFast: 'Gain weight fast (+500 kcal/day)',
};

// ── NutritionGoalsSetupSheet ──────────────────────────────────────────────────

/// Two-step wizard for setting up nutrition goals from scratch.
class NutritionGoalsSetupSheet extends ConsumerStatefulWidget {
  const NutritionGoalsSetupSheet({super.key});

  /// Shows this sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return ZBottomSheet.show<void>(
      context,
      title: 'Set up your goals',
      child: const NutritionGoalsSetupSheet(),
    );
  }

  @override
  ConsumerState<NutritionGoalsSetupSheet> createState() =>
      _NutritionGoalsSetupSheetState();
}

class _NutritionGoalsSetupSheetState
    extends ConsumerState<NutritionGoalsSetupSheet> {
  // ── Current step (0 = body metrics, 1 = activity + goal) ─────────────────

  int _step = 0;

  // ── Step 0 state ──────────────────────────────────────────────────────────

  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();

  /// Selected sex: 'male' or 'female'. null = not yet chosen.
  Set<String> _sexSelection = {};

  // ── Step 1 state ──────────────────────────────────────────────────────────

  ActivityLevel? _activityLevel;
  WeightGoal? _weightGoal;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  /// Returns true when step 0 has valid, non-empty inputs.
  bool get _step0Valid {
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);
    final age = int.tryParse(_ageController.text);
    return height != null &&
        height > 0 &&
        weight != null &&
        weight > 0 &&
        age != null &&
        age > 0 &&
        _sexSelection.isNotEmpty;
  }

  /// Returns true when step 1 has both selections made.
  bool get _step1Valid =>
      _activityLevel != null && _weightGoal != null;

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onNext() {
    if (!_step0Valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields before continuing.'),
        ),
      );
      return;
    }
    setState(() => _step = 1);
  }

  void _onCalculate() {
    if (!_step1Valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose your activity level and weight goal.'),
        ),
      );
      return;
    }

    final weightKg = double.parse(_weightController.text);
    final heightCm = double.parse(_heightController.text);
    final ageYears = int.parse(_ageController.text);
    final isMale = _sexSelection.contains('male');

    final calories = TdeeCalculator.calculate(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: ageYears,
      isMale: isMale,
      activityLevel: _activityLevel!,
      weightGoal: _weightGoal!,
    );

    // Rough macro split: 30% protein, 40% carbs, 30% fat.
    final proteinG = ((calories * 0.30) / 4).round();
    final carbsG = ((calories * 0.40) / 4).round();
    final fatG = ((calories * 0.30) / 9).round();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NutritionMacroReviewScreen(
          calorieBudget: calories,
          proteinG: proteinG,
          carbsG: carbsG,
          fatG: fatG,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return _step == 0 ? _buildStep0() : _buildStep1();
  }

  // ── Step 0: Body metrics ──────────────────────────────────────────────────

  Widget _buildStep0() {
    final colors = AppColorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Step indicator ───────────────────────────────────────────────
        _StepIndicator(current: 0, total: 2, colors: colors),

        const SizedBox(height: AppDimens.spaceLg),

        // ── Height ───────────────────────────────────────────────────────
        ZLabeledNumberField(
          label: 'Height',
          controller: _heightController,
          unit: 'cm',
          allowDecimal: true,
          textInputAction: TextInputAction.next,
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // ── Weight ───────────────────────────────────────────────────────
        ZLabeledNumberField(
          label: 'Weight',
          controller: _weightController,
          unit: 'kg',
          allowDecimal: true,
          textInputAction: TextInputAction.next,
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // ── Age ──────────────────────────────────────────────────────────
        ZLabeledNumberField(
          label: 'Age',
          controller: _ageController,
          unit: 'years',
          allowDecimal: false,
          textInputAction: TextInputAction.done,
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // ── Sex ──────────────────────────────────────────────────────────
        Text(
          'Sex',
          style: AppTextStyles.labelMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXxs),
        ZToggleGroup<String>(
          items: const [
            ZToggleGroupItem(value: 'male', label: 'Male'),
            ZToggleGroupItem(value: 'female', label: 'Female'),
          ],
          selectedValues: _sexSelection,
          onChanged: (updated) {
            // Allow only one selection at a time.
            setState(() {
              if (updated.length > 1) {
                // Keep the newly added value.
                final previous = _sexSelection;
                _sexSelection = updated.difference(previous).isEmpty
                    ? updated
                    : updated.difference(previous);
              } else {
                _sexSelection = updated;
              }
            });
          },
        ),

        const SizedBox(height: AppDimens.spaceLg),

        // ── Next button ──────────────────────────────────────────────────
        ZButton(
          label: 'Next',
          onPressed: _onNext,
        ),
      ],
    );
  }

  // ── Step 1: Activity level + weight goal ─────────────────────────────────

  Widget _buildStep1() {
    final colors = AppColorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Step indicator ───────────────────────────────────────────────
        _StepIndicator(current: 1, total: 2, colors: colors),

        const SizedBox(height: AppDimens.spaceLg),

        // ── Activity level ───────────────────────────────────────────────
        Text(
          'Activity level',
          style: AppTextStyles.labelLarge.copyWith(
            color: colors.textPrimary,
          ),
        ),

        const SizedBox(height: AppDimens.spaceSm),

        for (final level in ActivityLevel.values) ...[
          ZSelectableTile(
            isSelected: _activityLevel == level,
            onTap: () => setState(() => _activityLevel = level),
            showCheckIndicator: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm + 2,
            ),
            child: Text(
              _activityLabels[level]!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
        ],

        const SizedBox(height: AppDimens.spaceMd),

        // ── Weight goal ──────────────────────────────────────────────────
        Text(
          'Weight goal',
          style: AppTextStyles.labelLarge.copyWith(
            color: colors.textPrimary,
          ),
        ),

        const SizedBox(height: AppDimens.spaceSm),

        for (final goal in WeightGoal.values) ...[
          ZSelectableTile(
            isSelected: _weightGoal == goal,
            onTap: () => setState(() => _weightGoal = goal),
            showCheckIndicator: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm + 2,
            ),
            child: Text(
              _goalLabels[goal]!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
        ],

        const SizedBox(height: AppDimens.spaceLg),

        // ── Back + Calculate row ─────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: ZButton(
                label: 'Back',
                variant: ZButtonVariant.secondary,
                onPressed: () => setState(() => _step = 0),
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              flex: 2,
              child: ZButton(
                label: 'Calculate',
                onPressed: _onCalculate,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Step indicator ────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.current,
    required this.total,
    required this.colors,
  });

  final int current;
  final int total;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < total; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 3,
              decoration: BoxDecoration(
                color: i <= current ? colors.primary : colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < total - 1) const SizedBox(width: AppDimens.spaceXs),
        ],
      ],
    );
  }
}

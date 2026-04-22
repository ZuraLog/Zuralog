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

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/nutrition/domain/tdee_calculator.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/cards/z_selectable_tile.dart';
import 'package:zuralog/shared/widgets/feedback/z_bottom_sheet.dart';
import 'package:zuralog/shared/widgets/inputs/z_labeled_number_field.dart';
import 'package:zuralog/shared/widgets/inputs/z_toggle_group.dart';

// ── Placeholder screen (replaced by Task 5.2) ────────────────────────────────

/// Placeholder for [NutritionMacroReviewScreen] until Task 5.2 is implemented.
class NutritionMacroReviewScreen extends StatelessWidget {
  const NutritionMacroReviewScreen({
    super.key,
    required this.calorieBudget,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int calorieBudget;
  final int proteinG;
  final int carbsG;
  final int fatG;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Macro Review')));
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

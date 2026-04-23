/// Zuralog — Nutrition Goals Edit Sheet.
///
/// A bottom sheet that loads the user's existing nutrition goals and lets them
/// type new values for any or all fields. Pre-fills each field with the current
/// saved value. Saves only the fields that have a value entered.
///
/// Open via [NutritionGoalsEditSheet.show].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/feedback/z_bottom_sheet.dart';
import 'package:zuralog/shared/widgets/inputs/z_labeled_number_field.dart';

// ── NutritionGoalsEditSheet ───────────────────────────────────────────────────

/// Bottom sheet for editing existing nutrition goals.
///
/// Loads the user's current goals from [nutritionGoalsProvider] and pre-fills
/// one numeric field per goal type. The Save button writes only the fields that
/// have a value, then invalidates both [nutritionGoalsProvider] and
/// [goalsProvider] so downstream screens refresh.
class NutritionGoalsEditSheet extends ConsumerStatefulWidget {
  const NutritionGoalsEditSheet({super.key});

  /// Shows this sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return ZBottomSheet.show<void>(
      context,
      title: 'Edit your goals',
      child: const NutritionGoalsEditSheet(),
    );
  }

  @override
  ConsumerState<NutritionGoalsEditSheet> createState() =>
      _NutritionGoalsEditSheetState();
}

class _NutritionGoalsEditSheetState
    extends ConsumerState<NutritionGoalsEditSheet> {
  // ── Controllers — one per goal field ─────────────────────────────────────

  final _calorieController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sodiumController = TextEditingController();
  final _sugarController = TextEditingController();

  bool _isSaving = false;
  bool _initialized = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _calorieController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sodiumController.dispose();
    _sugarController.dispose();
    super.dispose();
  }

  // ── Pre-fill helpers ──────────────────────────────────────────────────────

  /// Converts a nullable double to a display string, dropping the trailing
  /// ".0" for whole numbers so the field looks clean (e.g. "2000" not "2000.0").
  static String _fmt(double? value) {
    if (value == null) return '';
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  void _initControllers(NutritionGoals goals) {
    if (_initialized) return;
    _initialized = true;
    _calorieController.text = _fmt(goals.calorieBudget);
    _proteinController.text = _fmt(goals.proteinMinG);
    _carbsController.text = _fmt(goals.carbsMaxG);
    _fatController.text = _fmt(goals.fatMaxG);
    _fiberController.text = _fmt(goals.fiberMinG);
    _sodiumController.text = _fmt(goals.sodiumMaxMg);
    _sugarController.text = _fmt(goals.sugarMaxG);
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final repo = ref.read(progressRepositoryProvider);
    try {
      await repo.deleteNutritionGoals();

      final fields = <(GoalType, String, double, String)>[
        if (_calorieController.text.isNotEmpty)
          (GoalType.dailyCalorieLimit, 'Daily Calorie Limit',
              double.parse(_calorieController.text), 'kcal'),
        if (_proteinController.text.isNotEmpty)
          (GoalType.dailyProteinMin, 'Daily Protein Minimum',
              double.parse(_proteinController.text), 'g'),
        if (_carbsController.text.isNotEmpty)
          (GoalType.dailyCarbsMax, 'Daily Carbs Maximum',
              double.parse(_carbsController.text), 'g'),
        if (_fatController.text.isNotEmpty)
          (GoalType.dailyFatMax, 'Daily Fat Maximum',
              double.parse(_fatController.text), 'g'),
        if (_fiberController.text.isNotEmpty)
          (GoalType.dailyFiberMin, 'Daily Fiber Minimum',
              double.parse(_fiberController.text), 'g'),
        if (_sodiumController.text.isNotEmpty)
          (GoalType.dailySodiumMax, 'Daily Sodium Maximum',
              double.parse(_sodiumController.text), 'mg'),
        if (_sugarController.text.isNotEmpty)
          (GoalType.dailySugarMax, 'Daily Sugar Maximum',
              double.parse(_sugarController.text), 'g'),
      ];

      for (final (type, title, value, unit) in fields) {
        await repo.createGoal(
          type: type,
          period: GoalPeriod.daily,
          title: title,
          targetValue: value,
          unit: unit,
        );
      }

      ref.invalidate(nutritionGoalsProvider);
      ref.invalidate(goalsProvider);
      if (mounted) Navigator.of(context).pop();
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final asyncGoals = ref.watch(nutritionGoalsProvider);

    return asyncGoals.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppDimens.spaceLg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => const Padding(
        padding: EdgeInsets.all(AppDimens.spaceLg),
        child: Center(child: Text('Unable to load your goals.')),
      ),
      data: (goals) {
        _initControllers(goals);
        return _GoalsForm(
          calorieController: _calorieController,
          proteinController: _proteinController,
          carbsController: _carbsController,
          fatController: _fatController,
          fiberController: _fiberController,
          sodiumController: _sodiumController,
          sugarController: _sugarController,
          isSaving: _isSaving,
          onSave: _save,
        );
      },
    );
  }
}

// ── _GoalsForm ────────────────────────────────────────────────────────────────

/// Stateless form body. Receives controllers from the parent stateful widget
/// so the fields are never rebuilt from scratch on re-render.
class _GoalsForm extends StatelessWidget {
  const _GoalsForm({
    required this.calorieController,
    required this.proteinController,
    required this.carbsController,
    required this.fatController,
    required this.fiberController,
    required this.sodiumController,
    required this.sugarController,
    required this.isSaving,
    required this.onSave,
  });

  final TextEditingController calorieController;
  final TextEditingController proteinController;
  final TextEditingController carbsController;
  final TextEditingController fatController;
  final TextEditingController fiberController;
  final TextEditingController sodiumController;
  final TextEditingController sugarController;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceSm,
        AppDimens.spaceLg,
        bottomPadding + AppDimens.spaceLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Calorie budget ──────────────────────────────────────────────
          ZLabeledNumberField(
            label: 'Calorie Budget (kcal)',
            controller: calorieController,
            unit: 'kcal',
            allowDecimal: false,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Protein ─────────────────────────────────────────────────────
          ZLabeledNumberField(
            label: 'Protein (g) — daily minimum',
            controller: proteinController,
            unit: 'g',
            allowDecimal: true,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Carbs ────────────────────────────────────────────────────────
          ZLabeledNumberField(
            label: 'Carbs (g) — daily maximum',
            controller: carbsController,
            unit: 'g',
            allowDecimal: true,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Fat ──────────────────────────────────────────────────────────
          ZLabeledNumberField(
            label: 'Fat (g) — daily maximum',
            controller: fatController,
            unit: 'g',
            allowDecimal: true,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Fiber ────────────────────────────────────────────────────────
          ZLabeledNumberField(
            label: 'Fiber (g) — daily minimum',
            controller: fiberController,
            unit: 'g',
            allowDecimal: true,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Sodium ───────────────────────────────────────────────────────
          ZLabeledNumberField(
            label: 'Sodium (mg) — daily maximum',
            controller: sodiumController,
            unit: 'mg',
            allowDecimal: false,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Sugar ────────────────────────────────────────────────────────
          ZLabeledNumberField(
            label: 'Sugar (g) — daily maximum',
            controller: sugarController,
            unit: 'g',
            allowDecimal: true,
            textInputAction: TextInputAction.done,
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Save button ──────────────────────────────────────────────────
          ZButton(
            label: isSaving ? 'Saving…' : 'Save',
            onPressed: isSaving ? null : onSave,
          ),
        ],
      ),
    );
  }
}

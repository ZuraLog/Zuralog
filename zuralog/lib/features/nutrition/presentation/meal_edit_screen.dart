/// ZuraLog — Meal Edit Screen.
///
/// Full-screen route for editing an existing meal. Receives the complete
/// [Meal] object via GoRouter extras, pre-fills every field, and lets the
/// user modify the meal name, type, time, and individual food entries
/// (including adding or removing foods).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Args ─────────────────────────────────────────────────────────────────────

/// Arguments passed to [MealEditScreen] via GoRouter's `extra`.
class MealEditArgs {
  const MealEditArgs({required this.meal});

  /// The meal to edit. All fields are pre-filled from this object.
  final Meal meal;
}

// ── Editable food entry ──────────────────────────────────────────────────────

/// Holds the [TextEditingController]s for a single editable food row.
///
/// Each food in the meal gets its own set of controllers so that the user
/// can freely edit name, calories, protein, carbs, and fat independently.
class _EditableFoodEntry {
  _EditableFoodEntry({
    required String name,
    required String calories,
    required String protein,
    required String carbs,
    required String fat,
  })  : nameController = TextEditingController(text: name),
        caloriesController = TextEditingController(text: calories),
        proteinController = TextEditingController(text: protein),
        carbsController = TextEditingController(text: carbs),
        fatController = TextEditingController(text: fat);

  final TextEditingController nameController;
  final TextEditingController caloriesController;
  final TextEditingController proteinController;
  final TextEditingController carbsController;
  final TextEditingController fatController;

  /// Releases all controller resources.
  void dispose() {
    nameController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
  }
}

// ── MealEditScreen ───────────────────────────────────────────────────────────

/// Lets the user edit every aspect of an existing meal: name, type, time,
/// and the full list of food items with their macros.
class MealEditScreen extends ConsumerStatefulWidget {
  const MealEditScreen({super.key, required this.args});

  /// The [MealEditArgs] containing the meal to edit.
  final MealEditArgs args;

  @override
  ConsumerState<MealEditScreen> createState() => _MealEditScreenState();
}

class _MealEditScreenState extends ConsumerState<MealEditScreen> {
  late final TextEditingController _nameController;
  late MealType _selectedMealType;
  late DateTime _loggedAt;
  late List<_EditableFoodEntry> _foods;
  bool _isSaving = false;

  Meal get _meal => widget.args.meal;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _meal.name);
    _selectedMealType = _meal.type;
    _loggedAt = _meal.loggedAt;
    _foods = _meal.foods.map((food) {
      return _EditableFoodEntry(
        name: food.name,
        calories: food.caloriesKcal.toString(),
        protein: food.proteinG.toStringAsFixed(
          food.proteinG.truncateToDouble() == food.proteinG ? 0 : 1,
        ),
        carbs: food.carbsG.toStringAsFixed(
          food.carbsG.truncateToDouble() == food.carbsG ? 0 : 1,
        ),
        fat: food.fatG.toStringAsFixed(
          food.fatG.truncateToDouble() == food.fatG ? 0 : 1,
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final entry in _foods) {
      entry.dispose();
    }
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _foods.isNotEmpty;

  // ── Time picker ─────────────────────────────────────────────────────────────

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _loggedAt = DateTime(
        _loggedAt.year,
        _loggedAt.month,
        _loggedAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  // ── Food management ─────────────────────────────────────────────────────────

  void _addFood() {
    setState(() {
      _foods.add(_EditableFoodEntry(
        name: '',
        calories: '0',
        protein: '0',
        carbs: '0',
        fat: '0',
      ));
    });
  }

  void _removeFood(int index) {
    if (_foods.length <= 1) return;
    setState(() {
      _foods[index].dispose();
      _foods.removeAt(index);
    });
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(nutritionRepositoryProvider);

      final updatedFoods = _foods.map((entry) {
        return MealFood(
          name: entry.nameController.text.trim(),
          portionGrams: 100, // Default portion — user edits macros directly.
          caloriesKcal:
              int.tryParse(entry.caloriesController.text.trim()) ?? 0,
          proteinG:
              double.tryParse(entry.proteinController.text.trim()) ?? 0.0,
          carbsG: double.tryParse(entry.carbsController.text.trim()) ?? 0.0,
          fatG: double.tryParse(entry.fatController.text.trim()) ?? 0.0,
        );
      }).toList();

      await repo.updateMeal(
        _meal.id,
        mealType: _selectedMealType.name,
        name: _nameController.text.trim(),
        loggedAt: _loggedAt,
        foods: updatedFoods,
      );

      // Refresh all related providers so every screen shows updated data.
      ref.invalidate(todayMealsProvider);
      ref.invalidate(nutritionDaySummaryProvider);
      ref.invalidate(mealDetailProvider(_meal.id));

      if (mounted) {
        ZToast.success(context, 'Meal updated');
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ZToast.error(context, 'Could not save changes. Please try again.');
        setState(() => _isSaving = false);
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    const catColor = AppColors.categoryNutrition;
    final timeFmt = DateFormat('h:mm a');

    return ZuralogScaffold(
      appBar: const ZuralogAppBar(
        title: 'Edit meal',
        showProfileAvatar: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceLg,
        ),
        children: [
          // ── Meal name ──────────────────────────────────────────────────
          ZLabeledTextField(
            label: 'Meal name',
            controller: _nameController,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Meal type picker ───────────────────────────────────────────
          ZMealTypePicker(
            value: _selectedMealType,
            onChanged: (v) => setState(() => _selectedMealType = v),
            label: 'Meal type',
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Time picker ────────────────────────────────────────────────
          SectionHeader(title: 'Time'),
          const SizedBox(height: AppDimens.spaceSm),
          GestureDetector(
            onTap: _pickTime,
            child: ZuralogCard(
              variant: ZCardVariant.data,
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: AppDimens.iconSm,
                    color: catColor,
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Text(
                    timeFmt.format(_loggedAt),
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: AppDimens.iconMd,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Foods section ──────────────────────────────────────────────
          SectionHeader(title: 'Foods'),
          const SizedBox(height: AppDimens.spaceSm),

          for (int i = 0; i < _foods.length; i++) ...[
            _FoodEditCard(
              entry: _foods[i],
              index: i,
              canDelete: _foods.length > 1,
              onDelete: () => _removeFood(i),
              catColor: catColor,
              colors: colors,
            ),
            const SizedBox(height: AppDimens.spaceSm),
          ],

          const SizedBox(height: AppDimens.spaceSm),

          // ── Add food ───────────────────────────────────────────────────
          ZButton(
            label: 'Add food',
            variant: ZButtonVariant.secondary,
            icon: Icons.add_rounded,
            onPressed: _addFood,
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Save ───────────────────────────────────────────────────────
          ZButton(
            label: 'Save changes',
            onPressed: _canSave && !_isSaving ? _handleSave : null,
            isLoading: _isSaving,
          ),

          const SizedBox(height: AppDimens.spaceXl),
        ],
      ),
    );
  }
}

// ── _FoodEditCard ────────────────────────────────────────────────────────────

/// An editable card for a single food entry within the meal.
///
/// Displays text fields for the food name, calories, protein, carbs, and fat,
/// plus a delete button when more than one food exists.
class _FoodEditCard extends StatelessWidget {
  const _FoodEditCard({
    required this.entry,
    required this.index,
    required this.canDelete,
    required this.onDelete,
    required this.catColor,
    required this.colors,
  });

  final _EditableFoodEntry entry;
  final int index;
  final bool canDelete;
  final VoidCallback onDelete;
  final Color catColor;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return ZuralogCard(
      variant: ZCardVariant.data,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food name + delete button row.
          Row(
            children: [
              Expanded(
                child: ZLabeledTextField(
                  label: 'Food name',
                  controller: entry.nameController,
                  textInputAction: TextInputAction.next,
                ),
              ),
              if (canDelete)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: AppDimens.iconSm,
                    color: colors.textSecondary,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Remove food',
                ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceSm),

          // Calories.
          ZLabeledNumberField(
            label: 'Calories',
            unit: 'kcal',
            allowDecimal: false,
            controller: entry.caloriesController,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: AppDimens.spaceSm),

          // Protein / Carbs / Fat row.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ZLabeledNumberField(
                  label: 'Protein',
                  unit: 'g',
                  allowDecimal: true,
                  controller: entry.proteinController,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: ZLabeledNumberField(
                  label: 'Carbs',
                  unit: 'g',
                  allowDecimal: true,
                  controller: entry.carbsController,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: ZLabeledNumberField(
                  label: 'Fat',
                  unit: 'g',
                  allowDecimal: true,
                  controller: entry.fatController,
                  textInputAction: TextInputAction.done,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

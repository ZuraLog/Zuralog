/// ZuraLog — Log Meal Bottom Sheet.
///
/// The primary entry point for logging a meal. Supports two modes:
///
/// - **Quick mode**: Describe food in natural language, search the database,
///   or pick from recently logged foods. One tap to save.
/// - **Guided mode**: Same input paths, but parsed items get extra refinement
///   controls — portion size (XS/S/M/L/XL) and cooking method chips that
///   adjust calorie estimates on the fly.
///
/// Opened via [LogMealSheet.show].
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/feedback/z_alert_banner.dart';
import 'package:zuralog/shared/widgets/feedback/z_toast.dart';
import 'package:zuralog/shared/widgets/inputs/app_text_field.dart';
import 'package:zuralog/shared/widgets/inputs/z_chip.dart';
import 'package:zuralog/shared/widgets/inputs/z_search_bar.dart';
import 'package:zuralog/shared/widgets/inputs/z_segmented_control.dart';
import 'package:zuralog/shared/widgets/inputs/z_text_area.dart';
import 'package:zuralog/shared/widgets/layout/section_header.dart';
import 'package:zuralog/shared/widgets/z_divider.dart';

/// Bottom sheet for logging a meal via natural-language description, food
/// search, or recent food shortcuts.
class LogMealSheet extends ConsumerStatefulWidget {
  const LogMealSheet({super.key});

  /// Opens the sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const LogMealSheet(),
    );
  }

  @override
  ConsumerState<LogMealSheet> createState() => _LogMealSheetState();
}

class _LogMealSheetState extends ConsumerState<LogMealSheet> {
  // ── State ──────────────────────────────────────────────────────────────────

  /// 0 = Quick, 1 = Guided.
  int _modeIndex = 0;

  /// Selected meal type — auto-suggested on init based on the current hour.
  MealType? _selectedMealType;

  /// Controller for the "describe what you ate" text area.
  final _describeController = TextEditingController();

  /// Controller for the food search bar.
  final _searchController = TextEditingController();

  /// Debounce timer for search queries.
  Timer? _searchDebounce;

  /// Foods the user has assembled for saving.
  final List<MealFood> _mealFoods = [];

  /// Raw AI parse results (used in Guided mode for confidence and refinement).
  List<ParsedFoodItem> _parsedItems = [];

  /// Whether the AI parser is currently running.
  bool _isParsing = false;

  /// Whether the save operation is currently running.
  bool _isSaving = false;

  /// Whether the user is in manual entry mode (instead of AI description).
  bool _isManualMode = false;

  /// Error message from the most recent parse attempt, if any.
  String? _parseError;

  /// Portion multipliers keyed by index in [_mealFoods]. Defaults to 1.0.
  final Map<int, double> _portionMultipliers = {};

  /// Cooking method overrides keyed by index in [_mealFoods].
  final Map<int, String> _cookingMethods = {};

  // ── Manual entry controllers ──────────────────────────────────────────────

  final _manualName = TextEditingController();
  final _manualCalories = TextEditingController();
  final _manualProtein = TextEditingController();
  final _manualCarbs = TextEditingController();
  final _manualFat = TextEditingController();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _autoSuggestMealType();
  }

  @override
  void dispose() {
    _describeController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _manualName.dispose();
    _manualCalories.dispose();
    _manualProtein.dispose();
    _manualCarbs.dispose();
    _manualFat.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get _canSave => _selectedMealType != null && _mealFoods.isNotEmpty;

  /// Picks a meal type based on the current hour of the day.
  void _autoSuggestMealType() {
    final hour = DateTime.now().hour;
    if (hour < 10) {
      _selectedMealType = MealType.breakfast;
    } else if (hour < 14) {
      _selectedMealType = MealType.lunch;
    } else if (hour < 17) {
      _selectedMealType = MealType.snack;
    } else {
      _selectedMealType = MealType.dinner;
    }
  }

  /// Joins the first 3 food names with " + ".
  String _generateMealName() {
    final names = _mealFoods.take(3).map((f) => f.name);
    return names.join(' + ');
  }

  /// Returns the effective calories for a food at [index], accounting for
  /// the Guided-mode portion multiplier and cooking method adjustment.
  int _effectiveCalories(int index) {
    final food = _mealFoods[index];
    final multiplier = _portionMultipliers[index] ?? 1.0;
    final method = _cookingMethods[index];
    var cals = food.caloriesKcal * multiplier;
    cals = _applyCookingMethodAdjustment(cals, method);
    return cals.round();
  }

  /// Returns the effective macros for a food at [index], accounting for
  /// the Guided-mode portion multiplier.
  ({double protein, double carbs, double fat}) _effectiveMacros(int index) {
    final food = _mealFoods[index];
    final multiplier = _portionMultipliers[index] ?? 1.0;
    return (
      protein: food.proteinG * multiplier,
      carbs: food.carbsG * multiplier,
      fat: food.fatG * multiplier,
    );
  }

  /// Applies a cooking method calorie adjustment.
  double _applyCookingMethodAdjustment(double calories, String? method) {
    return switch (method) {
      'Fried' => calories * 1.15,
      'Steamed' => calories * 0.95,
      'Baked' => calories * 1.05,
      'Grilled' => calories * 1.0,
      _ => calories,
    };
  }

  /// Whether a food item likely needs a cooking method selector.
  /// Skip for fruits, drinks, bread, and other items that are not "cooked"
  /// in a way that would meaningfully change calories.
  bool _needsCookingMethod(ParsedFoodItem item) {
    final lower = item.foodName.toLowerCase();
    const skipWords = [
      'fruit',
      'berry',
      'berries',
      'apple',
      'banana',
      'orange',
      'grape',
      'juice',
      'water',
      'milk',
      'coffee',
      'tea',
      'soda',
      'drink',
      'smoothie',
      'bread',
      'toast',
      'cereal',
      'yogurt',
      'cheese',
      'salad',
      'raw',
      'ice cream',
      'chocolate',
      'candy',
      'nuts',
      'granola',
    ];
    return !skipWords.any((word) => lower.contains(word));
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Adds a food item from the manual entry form fields.
  void _addManualFood() {
    final name = _manualName.text.trim();
    final cal = double.tryParse(_manualCalories.text) ?? 0;
    final protein = double.tryParse(_manualProtein.text) ?? 0;
    final carbs = double.tryParse(_manualCarbs.text) ?? 0;
    final fat = double.tryParse(_manualFat.text) ?? 0;

    if (name.isEmpty) return; // Name is required.

    setState(() {
      _mealFoods.add(MealFood(
        name: name,
        portionGrams: 1,
        portionUnit: 'serving',
        caloriesKcal: cal.round(),
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
      ));
      // Clear the fields for the next food.
      _manualName.clear();
      _manualCalories.clear();
      _manualProtein.clear();
      _manualCarbs.clear();
      _manualFat.clear();
    });
  }

  /// Parses the natural-language meal description via the AI endpoint.
  Future<void> _handleParse() async {
    final text = _describeController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isParsing = true;
      _parseError = null;
    });

    try {
      final repo = ref.read(nutritionRepositoryProvider);
      final results = await repo.parseMealDescription(text);
      if (!mounted) return;

      setState(() {
        _parsedItems = results;
        for (final item in results) {
          _mealFoods.add(item.toMealFood());
        }
        _isParsing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isParsing = false;
        _parseError = 'Could not understand the description. '
            'Try being more specific — for example, '
            '"grilled chicken breast 200g with steamed rice".';
      });
    }
  }

  /// Updates the food search query with a 300ms debounce.
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(foodSearchQueryProvider.notifier).state = query.trim();
    });
  }

  /// Adds a [FoodSearchResult] to the meal foods list.
  void _addSearchResult(FoodSearchResult result) {
    setState(() => _mealFoods.add(result.toMealFood()));
  }

  /// Adds a [RecentFood] to the meal foods list.
  void _addRecentFood(RecentFood recent) {
    setState(() => _mealFoods.add(recent.toMealFood()));
  }

  /// Removes a food at the given index.
  void _removeFood(int index) {
    setState(() {
      _mealFoods.removeAt(index);
      _portionMultipliers.remove(index);
      _cookingMethods.remove(index);
      // Re-key multipliers/methods above the removed index.
      final newMultipliers = <int, double>{};
      final newMethods = <int, String>{};
      for (final entry in _portionMultipliers.entries) {
        final newKey = entry.key > index ? entry.key - 1 : entry.key;
        newMultipliers[newKey] = entry.value;
      }
      for (final entry in _cookingMethods.entries) {
        final newKey = entry.key > index ? entry.key - 1 : entry.key;
        newMethods[newKey] = entry.value;
      }
      _portionMultipliers
        ..clear()
        ..addAll(newMultipliers);
      _cookingMethods
        ..clear()
        ..addAll(newMethods);
    });
  }

  /// Saves the meal and closes the sheet.
  Future<void> _handleSave() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(nutritionRepositoryProvider);

      // Build the final food list with multiplier/method adjustments applied.
      final adjustedFoods = <MealFood>[];
      for (var i = 0; i < _mealFoods.length; i++) {
        final food = _mealFoods[i];
        final multiplier = _portionMultipliers[i] ?? 1.0;
        final method = _cookingMethods[i];
        final adjustedCals =
            _applyCookingMethodAdjustment(food.caloriesKcal * multiplier, method);

        adjustedFoods.add(MealFood(
          name: food.name,
          portionGrams: (food.portionGrams * multiplier).round(),
          portionUnit: food.portionUnit,
          caloriesKcal: adjustedCals.round(),
          proteinG: food.proteinG * multiplier,
          carbsG: food.carbsG * multiplier,
          fatG: food.fatG * multiplier,
        ));
      }

      await repo.createMeal(
        mealType: _selectedMealType!.name,
        name: _generateMealName(),
        loggedAt: DateTime.now(),
        foods: adjustedFoods,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      // Invalidate providers after the sheet is dismissed so the home screen
      // refreshes with the new meal.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(todayMealsProvider);
        ref.invalidate(nutritionDaySummaryProvider);
        ref.invalidate(recentFoodsProvider);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ZToast.error(context, 'Failed to save meal. Please try again.');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimens.shapeXl),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: keyboardInset + AppDimens.bottomNavHeight,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: AppDimens.spaceSm),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Log a meal',
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Quick / Guided toggle ────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: ZSegmentedControl(
              selectedIndex: _modeIndex,
              onChanged: (i) => setState(() => _modeIndex = i),
              segments: const ['Quick', 'Guided'],
            ),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Scrollable body ──────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Meal type chips ─────────────────────────────────────
                  const SectionHeader(title: 'Meal type'),
                  const SizedBox(height: AppDimens.spaceSm),
                  _buildMealTypeChips(),

                  const SizedBox(height: AppDimens.spaceLg),

                  // ── Describe / Manual entry section ─────────────────────
                  if (_isManualMode) ...[
                    const SectionHeader(title: 'Enter nutrition manually'),
                    const SizedBox(height: AppDimens.spaceSm),
                    AppTextField(
                      controller: _manualName,
                      hintText: 'Food name (e.g. Chicken breast)',
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    AppTextField(
                      controller: _manualCalories,
                      hintText: 'Calories (kcal)',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _manualProtein,
                            hintText: 'Protein (g)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: AppTextField(
                            controller: _manualCarbs,
                            hintText: 'Carbs (g)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: AppTextField(
                            controller: _manualFat,
                            hintText: 'Fat (g)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    ZButton(
                      label: 'Add food',
                      variant: ZButtonVariant.secondary,
                      size: ZButtonSize.medium,
                      onPressed: _addManualFood,
                    ),
                  ] else ...[
                    const SectionHeader(title: 'Describe what you ate'),
                    const SizedBox(height: AppDimens.spaceSm),
                    ZTextArea(
                      controller: _describeController,
                      placeholder:
                          'e.g. grilled chicken with rice and a side salad',
                      minLines: 3,
                      maxLines: 4,
                    ),

                    const SizedBox(height: AppDimens.spaceSm),

                    ZButton(
                      label: 'Parse with AI',
                      icon: Icons.auto_awesome_outlined,
                      variant: ZButtonVariant.secondary,
                      size: ZButtonSize.medium,
                      isLoading: _isParsing,
                      onPressed: _isParsing ? null : _handleParse,
                    ),

                    // Parse error banner.
                    if (_parseError != null) ...[
                      const SizedBox(height: AppDimens.spaceSm),
                      ZAlertBanner(
                        variant: ZAlertVariant.error,
                        message: _parseError!,
                        onDismiss: () =>
                            setState(() => _parseError = null),
                      ),
                    ],
                  ],

                  // ── Manual / AI mode toggle ────────────────────────────
                  GestureDetector(
                    onTap: () =>
                        setState(() => _isManualMode = !_isManualMode),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.spaceSm,
                      ),
                      child: Text(
                        _isManualMode
                            ? 'Switch to AI description'
                            : 'Enter nutrition manually',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.categoryNutrition,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceLg),

                  // ── OR divider ──────────────────────────────────────────
                  _buildOrDivider(),

                  const SizedBox(height: AppDimens.spaceLg),

                  // ── Search section ──────────────────────────────────────
                  ZSearchBar(
                    controller: _searchController,
                    placeholder: 'Search for a food...',
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  _buildSearchResults(),

                  const SizedBox(height: AppDimens.spaceLg),

                  // ── Recents section ─────────────────────────────────────
                  _buildRecentsSection(),

                  const SizedBox(height: AppDimens.spaceLg),

                  // ── Selected foods list ─────────────────────────────────
                  if (_mealFoods.isNotEmpty) ...[
                    const SectionHeader(title: 'Your meal'),
                    const SizedBox(height: AppDimens.spaceSm),
                    _buildSelectedFoodsList(),
                    const SizedBox(height: AppDimens.spaceLg),
                  ],
                ],
              ),
            ),
          ),

          // ── Save button ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
            ),
            child: ZButton(
              label: 'Save meal',
              onPressed: _canSave ? _handleSave : null,
              isLoading: _isSaving,
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-builders ───────────────────────────────────────────────────────────

  /// Meal type chip row.
  Widget _buildMealTypeChips() {
    return Wrap(
      spacing: AppDimens.spaceSm,
      runSpacing: AppDimens.spaceSm,
      children: MealType.values.map((type) {
        return ZChip(
          label: type.label,
          icon: type.icon,
          isActive: _selectedMealType == type,
          onTap: () => setState(() => _selectedMealType = type),
        );
      }).toList(),
    );
  }

  /// "or" divider between describe and search.
  Widget _buildOrDivider() {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        const Expanded(child: ZDivider()),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Text(
            'or',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        const Expanded(child: ZDivider()),
      ],
    );
  }

  /// Search results list (watches the provider).
  Widget _buildSearchResults() {
    final searchAsync = ref.watch(foodSearchResultsProvider);
    final query = ref.watch(foodSearchQueryProvider);
    final colors = AppColorsOf(context);

    // Nothing typed yet — hide the results area entirely.
    if (query.trim().length < 2) return const SizedBox.shrink();

    return searchAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
        child: Text(
          'Search failed. Try again.',
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
            child: Text(
              'No foods found',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: results.map((result) {
            return _SearchResultRow(
              result: result,
              onTap: () => _addSearchResult(result),
            );
          }).toList(),
        );
      },
    );
  }

  /// Horizontal row of recent food chips.
  Widget _buildRecentsSection() {
    final recentsAsync = ref.watch(recentFoodsProvider);

    return recentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (recents) {
        if (recents.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionHeader(title: 'Recent'),
            const SizedBox(height: AppDimens.spaceSm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: recents.map((food) {
                  return Padding(
                    padding:
                        const EdgeInsets.only(right: AppDimens.spaceSm),
                    child: ZChip(
                      label: food.foodName,
                      onTap: () => _addRecentFood(food),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// List of foods currently assembled for saving.
  Widget _buildSelectedFoodsList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _mealFoods.length; i++) ...[
          _buildFoodRow(i),
          if (i < _mealFoods.length - 1)
            const SizedBox(height: AppDimens.spaceSm),
        ],
      ],
    );
  }

  /// A single food row with name, macros, and delete button. In Guided mode,
  /// shows extra refinement controls for AI-parsed items.
  Widget _buildFoodRow(int index) {
    final food = _mealFoods[index];
    final colors = AppColorsOf(context);
    final cals = _effectiveCalories(index);
    final macros = _effectiveMacros(index);

    // Check if this item came from AI parsing (i.e. has a matching parsed
    // item) and whether Guided mode is active.
    final isGuided = _modeIndex == 1;
    final ParsedFoodItem? parsedItem =
        index < _parsedItems.length ? _parsedItems[index] : null;
    final showRefinement = isGuided && parsedItem != null;

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceSm + 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Name + delete ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  food.name,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _removeFood(index),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceXs),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceXs),

          // ── Portion + macros ───────────────────────────────────────────
          Text(
            '${food.portionGrams}${food.portionUnit}'
            '  ·  $cals kcal'
            '  ·  P ${macros.protein.toStringAsFixed(1)}g'
            '  C ${macros.carbs.toStringAsFixed(1)}g'
            '  F ${macros.fat.toStringAsFixed(1)}g',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),

          // ── Guided refinement controls ─────────────────────────────────
          if (showRefinement) ...[
            const SizedBox(height: AppDimens.spaceSm),
            _buildPortionSelector(index),
            if (parsedItem.confidence < 0.8 &&
                _needsCookingMethod(parsedItem)) ...[
              const SizedBox(height: AppDimens.spaceSm),
              _buildCookingMethodSelector(index),
            ],
          ],
        ],
      ),
    );
  }

  /// Row of portion-size chips (XS/S/M/L/XL) for Guided mode.
  Widget _buildPortionSelector(int index) {
    final colors = AppColorsOf(context);
    const labels = ['XS', 'S', 'M', 'L', 'XL'];
    const multipliers = [0.5, 0.75, 1.0, 1.5, 2.0];
    final current = _portionMultipliers[index] ?? 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Portion size',
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Wrap(
          spacing: AppDimens.spaceXs,
          children: [
            for (var i = 0; i < labels.length; i++)
              ZChip(
                label: labels[i],
                isActive: current == multipliers[i],
                onTap: () {
                  setState(
                      () => _portionMultipliers[index] = multipliers[i]);
                },
              ),
          ],
        ),
      ],
    );
  }

  /// Row of cooking-method chips for Guided mode (low-confidence items).
  Widget _buildCookingMethodSelector(int index) {
    final colors = AppColorsOf(context);
    const methods = ['Grilled', 'Fried', 'Baked', 'Steamed'];
    final current = _cookingMethods[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Cooking method',
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Wrap(
          spacing: AppDimens.spaceXs,
          children: methods.map((method) {
            return ZChip(
              label: method,
              isActive: current == method,
              onTap: () {
                setState(() {
                  if (current == method) {
                    _cookingMethods.remove(index);
                  } else {
                    _cookingMethods[index] = method;
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Private sub-widgets ──────────────────────────────────────────────────────

/// A single search result row with name, serving, and calories.
class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.result,
    required this.onTap,
  });

  final FoodSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 20,
              color: AppColors.categoryNutrition,
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result.name,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '${result.servingSize.round()}${result.servingUnit}'
                    '${result.brand != null ? '  ·  ${result.brand}' : ''}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${result.caloriesPerServing.round()} kcal',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.categoryNutrition,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

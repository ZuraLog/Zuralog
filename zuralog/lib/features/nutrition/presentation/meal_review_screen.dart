/// ZuraLog — Meal Review Screen.
///
/// A full-screen, three-phase interactive experience for reviewing AI-parsed
/// meal data before saving. Supports three input types:
///
/// - **Describe**: the user typed a natural-language description.
/// - **Camera**: the user took or picked a photo of their food.
/// - **Barcode**: the user scanned a product barcode.
///
/// **Phase 1 — Analyzing:** Shows a pulsing brand pattern animation while
/// the AI backend processes the input.
///
/// **Phase 2 — Results:** Displays parsed food cards with inline editing,
/// optional Guided-mode refinement (portion + cooking method), a live
/// nutrition summary, meal-type selection, a time picker, and a save button.
///
/// Opened via [MealReviewScreen.show].
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/feedback/z_alert_banner.dart';
import 'package:zuralog/shared/widgets/feedback/z_toast.dart';
import 'package:zuralog/shared/widgets/inputs/z_chip.dart';
import 'package:zuralog/shared/widgets/inputs/app_text_field.dart';
import 'package:zuralog/shared/widgets/layout/section_header.dart';
import 'package:zuralog/shared/widgets/animations/z_fade_slide_in.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

// ── Input types ─────────────────────────────────────────────────────────────

/// How the user initiated the meal review.
enum MealReviewInputType {
  /// Natural-language text description.
  describe,

  /// Photo from camera or gallery.
  camera,

  /// Scanned product barcode.
  barcode,
}

/// Arguments passed to the [MealReviewScreen] via route navigation.
class MealReviewArgs {
  const MealReviewArgs({
    required this.inputType,
    this.descriptionText,
    this.imageFile,
    this.barcodeResult,
    required this.initialMealType,
    required this.isGuidedMode,
  });

  /// Which input path the user used.
  final MealReviewInputType inputType;

  /// The text the user typed (only set for [MealReviewInputType.describe]).
  final String? descriptionText;

  /// The photo file the user picked (only set for [MealReviewInputType.camera]).
  final File? imageFile;

  /// The barcode lookup result (only set for [MealReviewInputType.barcode]).
  final FoodSearchResult? barcodeResult;

  /// The meal type pre-selected based on the time of day.
  final MealType initialMealType;

  /// Whether the user chose Guided mode (adds portion + cooking refinement).
  final bool isGuidedMode;
}

// ── Internal phase enum ─────────────────────────────────────────────────────

enum _ReviewPhase { analyzing, results }

// ── Status text cycling ─────────────────────────────────────────────────────

const _describeStatusTexts = [
  'Reading your description...',
  'Identifying foods...',
  'Estimating nutrition...',
];

const _cameraStatusTexts = [
  'Analyzing your photo...',
  'Identifying foods...',
  'Estimating nutrition...',
];

// ── MealReviewScreen ────────────────────────────────────────────────────────

/// Full-screen review screen for AI-parsed meal data.
class MealReviewScreen extends ConsumerStatefulWidget {
  const MealReviewScreen({super.key, required this.args});

  /// The input data that drives what gets analyzed and displayed.
  final MealReviewArgs args;

  /// Navigates to the meal review screen via GoRouter.
  static void show(BuildContext context, MealReviewArgs args) {
    context.pushNamed(RouteNames.nutritionMealReview, extra: args);
  }

  @override
  ConsumerState<MealReviewScreen> createState() => _MealReviewScreenState();
}

class _MealReviewScreenState extends ConsumerState<MealReviewScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────

  _ReviewPhase _phase = _ReviewPhase.analyzing;
  List<ParsedFoodItem> _parsedItems = [];
  List<MealFood> _mealFoods = [];
  MealType? _selectedMealType;
  DateTime _loggedAt = DateTime.now();
  bool _isSaving = false;
  bool _rulesHandledEverything = false;
  String? _error;

  /// Portion multipliers keyed by food index. Defaults to 1.0 per item.
  final Map<int, double> _portionMultipliers = {};

  /// Cooking method overrides keyed by food index.
  final Map<int, String> _cookingMethods = {};

  /// Indices of food cards currently in inline-edit mode.
  final Set<int> _editingIndices = {};

  /// On-demand text controllers for inline editing (created only when needed).
  final Map<int, _InlineEditControllers> _editControllers = {};

  // ── Animation ──────────────────────────────────────────────────────────────

  late AnimationController _pulseController;
  int _statusTextIndex = 0;
  Timer? _statusTimer;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.args.initialMealType;

    // Pulse animation for the analyzing phase.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Status text cycling (every 2 seconds).
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _phase != _ReviewPhase.analyzing) return;
      final texts = widget.args.inputType == MealReviewInputType.camera
          ? _cameraStatusTexts
          : _describeStatusTexts;
      setState(() {
        _statusTextIndex = (_statusTextIndex + 1) % texts.length;
      });
    });

    _startAnalysis();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusTimer?.cancel();
    for (final controllers in _editControllers.values) {
      controllers.dispose();
    }
    super.dispose();
  }

  // ── Analysis ───────────────────────────────────────────────────────────────

  Future<void> _startAnalysis() async {
    final args = widget.args;

    // Barcode path: skip straight to results.
    if (args.inputType == MealReviewInputType.barcode &&
        args.barcodeResult != null) {
      final food = args.barcodeResult!.toMealFood();
      setState(() {
        _mealFoods = [food];
        _phase = _ReviewPhase.results;
      });
      return;
    }

    try {
      final repo = ref.read(nutritionRepositoryProvider);
      final MealParseResult parsed;

      if (args.inputType == MealReviewInputType.describe) {
        parsed = await repo.parseMealDescription(
          args.descriptionText ?? '',
          mode: 'quick',
        );
      } else {
        // Camera path.
        parsed = await repo.scanFoodImage(args.imageFile!, mode: 'quick');
      }

      final results = parsed.foods;

      if (!mounted) return;

      setState(() {
        _parsedItems = results;
        _mealFoods = results.map((item) => item.toMealFood()).toList();
        _phase = _ReviewPhase.results;

        // When in Guided mode and every parsed item is high confidence,
        // the user's rules already covered everything.
        if (args.isGuidedMode &&
            results.isNotEmpty &&
            results.every((item) => item.confidence >= 0.8)) {
          _rulesHandledEverything = true;
        }
      });

      if (_rulesHandledEverything && mounted) {
        ZToast.success(context, 'Your rules covered everything!');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not analyze your input. Please try again.';
        _phase = _ReviewPhase.results;
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get _canSave =>
      _selectedMealType != null && _mealFoods.isNotEmpty && !_isSaving;

  /// Joins the first 3 food names with " + " for the meal name.
  String _generateMealName() {
    final names = _mealFoods.take(3).map((f) => f.name);
    return names.join(' + ');
  }

  /// Returns the effective calories for a food at [index], accounting for
  /// portion multiplier and cooking method adjustment.
  int _effectiveCalories(int index) {
    final food = _mealFoods[index];
    final multiplier = _portionMultipliers[index] ?? 1.0;
    final method = _cookingMethods[index];
    var cals = food.caloriesKcal * multiplier;
    cals = _applyCookingMethodAdjustment(cals, method);
    return cals.round();
  }

  /// Returns the effective macros for a food at [index].
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
  bool _needsCookingMethod(ParsedFoodItem item) {
    final lower = item.foodName.toLowerCase();
    const skipWords = [
      'fruit', 'berry', 'berries', 'apple', 'banana', 'orange', 'grape',
      'juice', 'water', 'milk', 'coffee', 'tea', 'soda', 'drink',
      'smoothie', 'bread', 'toast', 'cereal', 'yogurt', 'cheese', 'salad',
      'raw', 'ice cream', 'chocolate', 'candy', 'nuts', 'granola',
    ];
    return !skipWords.any((word) => lower.contains(word));
  }

  /// Computed total calories across all foods (with adjustments applied).
  int get _totalCalories {
    var total = 0;
    for (var i = 0; i < _mealFoods.length; i++) {
      total += _effectiveCalories(i);
    }
    return total;
  }

  /// Computed total macros across all foods.
  ({double protein, double carbs, double fat}) get _totalMacros {
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    for (var i = 0; i < _mealFoods.length; i++) {
      final m = _effectiveMacros(i);
      protein += m.protein;
      carbs += m.carbs;
      fat += m.fat;
    }
    return (protein: protein, carbs: carbs, fat: fat);
  }

  // ── Inline editing ─────────────────────────────────────────────────────────

  _InlineEditControllers _getOrCreateControllers(int index) {
    return _editControllers.putIfAbsent(index, () {
      final food = _mealFoods[index];
      return _InlineEditControllers(
        name: TextEditingController(text: food.name),
        calories: TextEditingController(text: '${food.caloriesKcal}'),
        protein: TextEditingController(text: food.proteinG.toStringAsFixed(1)),
        carbs: TextEditingController(text: food.carbsG.toStringAsFixed(1)),
        fat: TextEditingController(text: food.fatG.toStringAsFixed(1)),
      );
    });
  }

  void _toggleEdit(int index) {
    setState(() {
      if (_editingIndices.contains(index)) {
        // Save the edited values back to the food list.
        final c = _editControllers[index];
        if (c != null) {
          final name = c.name.text.trim();
          if (name.isNotEmpty) {
            _mealFoods[index] = MealFood(
              name: name,
              portionGrams: _mealFoods[index].portionGrams,
              portionUnit: _mealFoods[index].portionUnit,
              caloriesKcal:
                  int.tryParse(c.calories.text) ?? _mealFoods[index].caloriesKcal,
              proteinG:
                  double.tryParse(c.protein.text) ?? _mealFoods[index].proteinG,
              carbsG:
                  double.tryParse(c.carbs.text) ?? _mealFoods[index].carbsG,
              fatG: double.tryParse(c.fat.text) ?? _mealFoods[index].fatG,
            );
          }
        }
        _editingIndices.remove(index);
        // Dispose and remove the controllers.
        _editControllers[index]?.dispose();
        _editControllers.remove(index);
      } else {
        _editingIndices.add(index);
      }
    });
  }

  void _removeFood(int index) {
    setState(() {
      _mealFoods.removeAt(index);
      _portionMultipliers.remove(index);
      _cookingMethods.remove(index);
      _editingIndices.remove(index);
      _editControllers[index]?.dispose();
      _editControllers.remove(index);
      if (index < _parsedItems.length) {
        _parsedItems = List.of(_parsedItems)..removeAt(index);
      }

      // Re-key maps above the removed index.
      final newMultipliers = <int, double>{};
      final newMethods = <int, String>{};
      final newEditing = <int>{};
      final newControllers = <int, _InlineEditControllers>{};

      for (final entry in _portionMultipliers.entries) {
        final newKey = entry.key > index ? entry.key - 1 : entry.key;
        newMultipliers[newKey] = entry.value;
      }
      for (final entry in _cookingMethods.entries) {
        final newKey = entry.key > index ? entry.key - 1 : entry.key;
        newMethods[newKey] = entry.value;
      }
      for (final i in _editingIndices) {
        newEditing.add(i > index ? i - 1 : i);
      }
      for (final entry in _editControllers.entries) {
        final newKey = entry.key > index ? entry.key - 1 : entry.key;
        newControllers[newKey] = entry.value;
      }

      _portionMultipliers
        ..clear()
        ..addAll(newMultipliers);
      _cookingMethods
        ..clear()
        ..addAll(newMethods);
      _editingIndices
        ..clear()
        ..addAll(newEditing);
      _editControllers
        ..clear()
        ..addAll(newControllers);
    });
  }

  // ── Time picker ────────────────────────────────────────────────────────────

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

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(nutritionRepositoryProvider);

      // Build the final food list with adjustments applied.
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
        loggedAt: _loggedAt,
        foods: adjustedFoods,
      );

      if (!mounted) return;

      // Pop back and refresh providers so the home screen picks up the new meal.
      context.pop();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(todayMealsProvider);
        ref.invalidate(nutritionDaySummaryProvider);
        ref.invalidate(recentFoodsProvider);
      });

      if (mounted) {
        ZToast.success(context, 'Meal saved!');
      }
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

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Review meal',
          style: AppTextStyles.titleMedium.copyWith(
            color: colors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _phase == _ReviewPhase.analyzing
          ? _buildAnalyzingPhase(colors)
          : _buildResultsPhase(colors),
    );
  }

  // ── Phase 1: Analyzing ─────────────────────────────────────────────────────

  Widget _buildAnalyzingPhase(AppColorsOf colors) {
    final statusTexts = widget.args.inputType == MealReviewInputType.camera
        ? _cameraStatusTexts
        : _describeStatusTexts;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Input preview.
            _buildInputPreview(colors),

            const SizedBox(height: AppDimens.spaceLg + AppDimens.spaceMd),

            // Pulsing brand pattern animation.
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                // Opacity oscillates between 0.15 and 0.40.
                final opacity =
                    0.15 + (_pulseController.value * 0.25);
                return SizedBox(
                  height: 120,
                  width: 120,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppDimens.shapeLg),
                    child: ZPatternOverlay(
                      variant: ZPatternVariant.amber,
                      opacity: opacity,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: AppDimens.spaceLg),

            // Status text.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                statusTexts[_statusTextIndex],
                key: ValueKey(_statusTextIndex),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputPreview(AppColorsOf colors) {
    final args = widget.args;

    if (args.inputType == MealReviewInputType.describe &&
        args.descriptionText != null) {
      return Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.shapeSm),
        ),
        child: Row(
          children: [
            Icon(
              Icons.format_quote_rounded,
              size: AppDimens.iconMd,
              color: AppColors.categoryNutrition,
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: Text(
                args.descriptionText!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textPrimary,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (args.inputType == MealReviewInputType.camera &&
        args.imageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
        child: Image.file(
          args.imageFile!,
          height: 80,
          width: 80,
          fit: BoxFit.cover,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ── Phase 2: Results ───────────────────────────────────────────────────────

  Widget _buildResultsPhase(AppColorsOf colors) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error banner (if analysis failed).
                if (_error != null) ...[
                  const SizedBox(height: AppDimens.spaceMd),
                  ZAlertBanner(
                    variant: ZAlertVariant.error,
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Center(
                    child: ZButton(
                      label: 'Try again',
                      variant: ZButtonVariant.secondary,
                      size: ZButtonSize.medium,
                      icon: Icons.refresh,
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _phase = _ReviewPhase.analyzing;
                          _statusTextIndex = 0;
                        });
                        _startAnalysis();
                      },
                    ),
                  ),
                ],

                // Food cards.
                if (_mealFoods.isNotEmpty) ...[
                  const SizedBox(height: AppDimens.spaceMd),
                  const SectionHeader(title: "Here's what I found"),
                  const SizedBox(height: AppDimens.spaceSm),
                  for (var i = 0; i < _mealFoods.length; i++) ...[
                    ZFadeSlideIn(
                      delay: Duration(milliseconds: i * 60),
                      child: _buildFoodCard(i, colors),
                    ),
                    if (i < _mealFoods.length - 1)
                      const SizedBox(height: AppDimens.spaceSm),
                  ],

                  // Total summary card.
                  const SizedBox(height: AppDimens.spaceMd),
                  ZFadeSlideIn(
                    delay: Duration(
                      milliseconds: _mealFoods.length * 60,
                    ),
                    child: _buildTotalSummary(colors),
                  ),
                ],

                // Meal type chips.
                const SizedBox(height: AppDimens.spaceLg),
                const SectionHeader(title: 'Meal type'),
                const SizedBox(height: AppDimens.spaceSm),
                _buildMealTypeChips(),

                // Time picker.
                const SizedBox(height: AppDimens.spaceLg),
                const SectionHeader(title: 'Time'),
                const SizedBox(height: AppDimens.spaceSm),
                _buildTimePicker(colors),

                const SizedBox(height: AppDimens.spaceLg),
              ],
            ),
          ),
        ),

        // Save button (pinned to bottom).
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            MediaQuery.of(context).padding.bottom + AppDimens.spaceMd,
          ),
          child: ZButton(
            label: 'Save meal',
            onPressed: _canSave ? _handleSave : null,
            isLoading: _isSaving,
          ),
        ),
      ],
    );
  }

  // ── Food card ──────────────────────────────────────────────────────────────

  Widget _buildFoodCard(int index, AppColorsOf colors) {
    final food = _mealFoods[index];
    final cals = _effectiveCalories(index);
    final macros = _effectiveMacros(index);
    final isEditing = _editingIndices.contains(index);

    // Guided mode refinement controls.
    final isGuided = widget.args.isGuidedMode;
    final ParsedFoodItem? parsedItem =
        index < _parsedItems.length ? _parsedItems[index] : null;
    final showRefinement =
        isGuided && parsedItem != null && !_rulesHandledEverything;

    // Confidence dot color.
    final confidenceColor = parsedItem != null
        ? (parsedItem.confidence >= 0.8
            ? AppColors.success
            : parsedItem.confidence >= 0.5
                ? AppColors.warning
                : AppColors.error)
        : AppColors.success;

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
          // Name row with confidence dot, edit icon, and delete.
          Row(
            children: [
              // Confidence dot.
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: AppDimens.spaceSm),
                decoration: BoxDecoration(
                  color: confidenceColor,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  food.name,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              // Edit icon.
              GestureDetector(
                onTap: () => _toggleEdit(index),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceXs),
                  child: Icon(
                    isEditing ? Icons.check : Icons.edit_outlined,
                    size: 18,
                    color: isEditing
                        ? AppColors.categoryNutrition
                        : colors.textSecondary,
                  ),
                ),
              ),
              // Delete icon.
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

          // Inline edit form (shown when editing).
          if (isEditing) ...[
            _buildInlineEditForm(index, colors),
            const SizedBox(height: AppDimens.spaceSm),
          ],

          // Portion + macros summary (always visible).
          if (!isEditing)
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

          // Rules-applied badge — only shown if this food had rules applied.
          if (parsedItem != null && parsedItem.appliedRules.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceSm),
            GestureDetector(
              onTap: () => _showAppliedRulesSheet(context, parsedItem),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceSm,
                  vertical: AppDimens.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.categoryNutrition.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                  border: Border.all(
                    color: AppColors.categoryNutrition.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      size: AppDimens.iconSm,
                      color: AppColors.categoryNutrition,
                    ),
                    const SizedBox(width: AppDimens.spaceXs),
                    Text(
                      '${parsedItem.appliedRules.length} ${parsedItem.appliedRules.length == 1 ? "rule" : "rules"} applied',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.categoryNutrition,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceXs),
                    const Icon(
                      Icons.chevron_right,
                      size: AppDimens.iconSm,
                      color: AppColors.categoryNutrition,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Guided refinement controls.
          if (showRefinement) ...[
            const SizedBox(height: AppDimens.spaceSm),
            _buildPortionSelector(index, colors),
            if (parsedItem.confidence < 0.8 &&
                _needsCookingMethod(parsedItem)) ...[
              const SizedBox(height: AppDimens.spaceSm),
              _buildCookingMethodSelector(index, colors),
            ],
          ],
        ],
      ),
    );
  }

  // ── Inline edit form ───────────────────────────────────────────────────────

  Widget _buildInlineEditForm(int index, AppColorsOf colors) {
    final c = _getOrCreateControllers(index);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          controller: c.name,
          hintText: 'Food name',
        ),
        const SizedBox(height: AppDimens.spaceXs),
        AppTextField(
          controller: c.calories,
          hintText: 'Calories (kcal)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: c.protein,
                hintText: 'P (g)',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppDimens.spaceXs),
            Expanded(
              child: AppTextField(
                controller: c.carbs,
                hintText: 'C (g)',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppDimens.spaceXs),
            Expanded(
              child: AppTextField(
                controller: c.fat,
                hintText: 'F (g)',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Portion selector ───────────────────────────────────────────────────────

  Widget _buildPortionSelector(int index, AppColorsOf colors) {
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

  // ── Cooking method selector ────────────────────────────────────────────────

  Widget _buildCookingMethodSelector(int index, AppColorsOf colors) {
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

  // ── Total summary card ─────────────────────────────────────────────────────

  Widget _buildTotalSummary(AppColorsOf colors) {
    final macros = _totalMacros;

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.categoryNutrition.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      ),
      child: Row(
        children: [
          _TotalStat(
            value: '$_totalCalories',
            label: 'kcal',
            colors: colors,
          ),
          _TotalStat(
            value: macros.protein.toStringAsFixed(0),
            label: 'protein',
            colors: colors,
          ),
          _TotalStat(
            value: macros.carbs.toStringAsFixed(0),
            label: 'carbs',
            colors: colors,
          ),
          _TotalStat(
            value: macros.fat.toStringAsFixed(0),
            label: 'fat',
            colors: colors,
          ),
        ],
      ),
    );
  }

  // ── Meal type chips ────────────────────────────────────────────────────────

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

  // ── Applied rules sheet ────────────────────────────────────────────────────

  void _showAppliedRulesSheet(BuildContext context, ParsedFoodItem food) {
    final colors = AppColorsOf(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.shapeXl)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  color: AppColors.categoryNutrition,
                  size: AppDimens.iconMd,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Text(
                    'Rules applied to ${food.foodName}',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'The AI used these rules while estimating this food:',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            for (final rule in food.appliedRules) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.categoryNutrition,
                      size: AppDimens.iconSm,
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Expanded(
                      child: Text(
                        rule,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppDimens.spaceMd),
          ],
        ),
      ),
    );
  }

  // ── Time picker row ────────────────────────────────────────────────────────

  Widget _buildTimePicker(AppColorsOf colors) {
    final formatted = DateFormat('h:mm a').format(_loggedAt);

    return GestureDetector(
      onTap: _pickTime,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm + 4,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.shapeSm),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              size: AppDimens.iconMd,
              color: AppColors.categoryNutrition,
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Text(
              formatted,
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              size: AppDimens.iconMd,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private sub-widgets ─────────────────────────────────────────────────────

/// A single stat column in the total summary card.
class _TotalStat extends StatelessWidget {
  const _TotalStat({
    required this.value,
    required this.label,
    required this.colors,
  });

  final String value;
  final String label;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXxs),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inline edit controllers ─────────────────────────────────────────────────

/// Groups the text editing controllers needed for inline food editing.
class _InlineEditControllers {
  _InlineEditControllers({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final TextEditingController name;
  final TextEditingController calories;
  final TextEditingController protein;
  final TextEditingController carbs;
  final TextEditingController fat;

  void dispose() {
    name.dispose();
    calories.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/presentation/meal_review_screen.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';

/// A test-only stub that delegates everything to [MockNutritionRepository]
/// except [parseMealDescription], which hangs forever so the screen stays
/// in the analyzing phase.
class _AnalyzingStub implements NutritionRepositoryInterface {
  final _delegate = const MockNutritionRepository();

  @override
  Future<MealParseResult> parseMealDescription(
    String description, {
    required String mode,
  }) =>
      Completer<MealParseResult>().future; // never completes

  // ── All other methods delegate to the mock ───────────────────────────────

  @override
  Future<List<Meal>> getTodayMeals() => _delegate.getTodayMeals();

  @override
  Future<NutritionDaySummary> getTodaySummary() => _delegate.getTodaySummary();

  @override
  Future<Meal?> getMealById(String id) => _delegate.getMealById(id);

  @override
  Future<void> deleteMeal(String id) => _delegate.deleteMeal(id);

  @override
  Future<Meal> createMeal({
    required String mealType,
    String? name,
    required DateTime loggedAt,
    required List<MealFood> foods,
  }) =>
      _delegate.createMeal(
        mealType: mealType,
        name: name,
        loggedAt: loggedAt,
        foods: foods,
      );

  @override
  Future<Meal> updateMeal(
    String id, {
    required String mealType,
    String? name,
    required DateTime loggedAt,
    required List<MealFood> foods,
  }) =>
      _delegate.updateMeal(
        id,
        mealType: mealType,
        name: name,
        loggedAt: loggedAt,
        foods: foods,
      );

  @override
  Future<List<RecentFood>> getRecentFoods() => _delegate.getRecentFoods();

  @override
  Future<List<FoodSearchResult>> searchFoods(String query, {int limit = 10}) =>
      _delegate.searchFoods(query, limit: limit);

  @override
  Future<MealRefineResult> refineMeal({
    required String description,
    required List<ParsedFoodItem> foods,
    required List<GuidedQuestion> questionsHistory,
    required List<Map<String, dynamic>> answersHistory,
    required int round,
  }) =>
      _delegate.refineMeal(
        description: description,
        foods: foods,
        questionsHistory: questionsHistory,
        answersHistory: answersHistory,
        round: round,
      );

  @override
  Future<void> submitCorrection({
    required String foodName,
    required double originalCalories,
    required double correctedCalories,
    required double originalProteinG,
    required double correctedProteinG,
    required double originalCarbsG,
    required double correctedCarbsG,
    required double originalFatG,
    required double correctedFatG,
  }) =>
      _delegate.submitCorrection(
        foodName: foodName,
        originalCalories: originalCalories,
        correctedCalories: correctedCalories,
        originalProteinG: originalProteinG,
        correctedProteinG: correctedProteinG,
        originalCarbsG: originalCarbsG,
        correctedCarbsG: correctedCarbsG,
        originalFatG: originalFatG,
        correctedFatG: correctedFatG,
      );

  @override
  Future<MealParseResult> scanFoodImage(
    File imageFile, {
    required String mode,
  }) =>
      _delegate.scanFoodImage(imageFile, mode: mode);

  @override
  Future<FoodSearchResult?> lookupBarcode(String code) =>
      _delegate.lookupBarcode(code);

  @override
  Future<List<NutritionRule>> getRules() => _delegate.getRules();

  @override
  Future<NutritionRule> createRule(
    String ruleText, {
    String? suppressedQuestionId,
    String? suppressedAnswerValue,
  }) =>
      _delegate.createRule(
        ruleText,
        suppressedQuestionId: suppressedQuestionId,
        suppressedAnswerValue: suppressedAnswerValue,
      );

  @override
  Future<NutritionRule> updateRule(String ruleId, String ruleText) =>
      _delegate.updateRule(ruleId, ruleText);

  @override
  Future<void> deleteRule(String ruleId) => _delegate.deleteRule(ruleId);

  @override
  Future<void> dismissRuleSuggestion({
    required String questionId,
    required String answerValue,
  }) =>
      _delegate.dismissRuleSuggestion(
        questionId: questionId,
        answerValue: answerValue,
      );

  @override
  Future<String?> fetchFoodImage(String query) =>
      _delegate.fetchFoodImage(query);
}

void main() {
  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          nutritionRepositoryProvider.overrideWithValue(_AnalyzingStub()),
        ],
        child: MaterialApp(home: child),
      );

  testWidgets(
    'analyzing phase renders the Stack with pulsing pattern layer',
    (tester) async {
      await tester.pumpWidget(wrap(
        MealReviewScreen(
          args: const MealReviewArgs(
            inputType: MealReviewInputType.describe,
            descriptionText: 'eggs with toast',
            initialMealType: MealType.breakfast,
            isGuidedMode: false,
          ),
        ),
      ));
      // parseMealDescription never completes, so the screen stays in the
      // analyzing phase. Verify the Stack with the pulsing pattern and the
      // FutureBuilder for the food image are present in the widget tree.
      expect(find.byType(Stack), findsWidgets);
      expect(find.byType(FutureBuilder<String?>), findsOneWidget);
    },
  );
}

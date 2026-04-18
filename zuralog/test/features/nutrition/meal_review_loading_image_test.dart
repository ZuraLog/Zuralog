import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/presentation/meal_review_screen.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';

// ---------------------------------------------------------------------------
// Slim stub — extends MockNutritionRepository, overrides only what tests need.
// ---------------------------------------------------------------------------

/// Keeps the screen permanently in the analyzing phase by hanging both
/// [parseMealDescription] and [scanFoodImage]. Also counts how many times
/// [fetchFoodImage] is called so tests can assert on the input-type guard.
class _AnalyzingStub extends MockNutritionRepository {
  int fetchFoodImageCallCount = 0;

  @override
  Future<MealParseResult> parseMealDescription(
    String description, {
    required String mode,
  }) =>
      Completer<MealParseResult>().future; // never completes

  @override
  Future<MealParseResult> scanFoodImage(
    File imageFile, {
    required String mode,
  }) =>
      Completer<MealParseResult>().future; // never completes

  @override
  Future<String?> fetchFoodImage(String query) {
    fetchFoodImageCallCount++;
    // Return a never-completing future so the image doesn't render during the
    // test — we only need to assert the Stack exists and the call was made.
    return Completer<String?>().future;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, _AnalyzingStub stub) => ProviderScope(
      overrides: [
        nutritionRepositoryProvider.overrideWithValue(stub),
      ],
      child: MaterialApp(home: child),
    );

const _describeArgs = MealReviewArgs(
  inputType: MealReviewInputType.describe,
  descriptionText: 'eggs with toast',
  initialMealType: MealType.breakfast,
  isGuidedMode: false,
);

// Camera path requires a non-null imageFile to avoid the null assertion in
// _startAnalysis. We use a placeholder path — the file is never opened.
final _cameraArgs = MealReviewArgs(
  inputType: MealReviewInputType.camera,
  imageFile: File('/dev/null'),
  initialMealType: MealType.breakfast,
  isGuidedMode: false,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Test A ─────────────────────────────────────────────────────────────────

  testWidgets(
    'describe path: keyed image Stack is present and no Image widget is shown '
    'while the food-image future is still in flight',
    (tester) async {
      final stub = _AnalyzingStub();

      await tester.pumpWidget(
        _wrap(MealReviewScreen(args: _describeArgs), stub),
      );
      // One pump — analyzing phase begins, futures have not resolved.
      await tester.pump();

      // The keyed Stack MUST exist — deleting the feature makes this fail.
      expect(
        find.byKey(const Key('meal-review-loading-image-stack')),
        findsOneWidget,
        reason: 'loading-image Stack should be present during analyzing phase',
      );

      // No Image widget should be visible yet (future still in flight).
      expect(
        find.byType(Image),
        findsNothing,
        reason: 'Image should not appear until the food-image future resolves',
      );

      // fetchFoodImage should have been called exactly once — confirms the
      // feature is actually wired up for the describe path.
      expect(
        stub.fetchFoodImageCallCount,
        equals(1),
        reason: 'fetchFoodImage should be called once for the describe path',
      );
    },
  );

  // ── Test B ─────────────────────────────────────────────────────────────────

  testWidgets(
    'camera path: keyed image Stack is present and fetchFoodImage is NEVER '
    'called (camera photos skip the image-lookup service)',
    (tester) async {
      final stub = _AnalyzingStub();

      await tester.pumpWidget(
        _wrap(MealReviewScreen(args: _cameraArgs), stub),
      );
      await tester.pump();

      // The keyed Stack must be present on the camera path too.
      expect(
        find.byKey(const Key('meal-review-loading-image-stack')),
        findsOneWidget,
        reason: 'loading-image Stack should be present on the camera path',
      );

      // fetchFoodImage must NOT be called — the image future stays null so the
      // Stack shows only the pulsing pattern.  If the input-type guard is
      // removed or inverted this assertion fails.
      expect(
        stub.fetchFoodImageCallCount,
        equals(0),
        reason: 'fetchFoodImage must not be called for camera/barcode paths',
      );
    },
  );
}

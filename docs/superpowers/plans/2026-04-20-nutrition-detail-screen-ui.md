# Nutrition Detail Screen UI — Plan 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an AI Summary card, Calories + Protein trend charts, and a "View All Data →" button to the Nutrition home screen — all wired to mock data with no backend changes required.

**Architecture:** Two new widgets (`NutritionAiSummaryCard`, `NutritionTrendSection`) slot into the existing `NutritionHomeScreen` between the macro summary card and the "Today's Meals" header. The data layer receives a new `NutritionTrendDay` model, `aiSummary`/`aiGeneratedAt` fields on `NutritionDaySummary`, and a `getTrend(String range)` method on the repository interface + mock. The `nutritionRepositoryProvider` gets the `USE_MOCK_DATA` compile flag so mock data works without a backend. A placeholder "View All Data →" row at the bottom of the new block shows a `ZProBadge(showLock: true)` and navigates to a coming-soon SnackBar until Plan 2 wires up the actual route.

**Tech Stack:** Flutter 3.x, Riverpod 2.0 (`FutureProvider.family`), existing `BarRenderer` + `ZuralogCard` + `ZProBadge` from the shared widget library (`zuralog/lib/shared/widgets/widgets.dart`).

---

## File Map

| Action | Path | Responsibility |
|--------|------|---------------|
| Modify | `zuralog/lib/features/nutrition/domain/nutrition_models.dart` | Add `NutritionTrendDay`; extend `NutritionDaySummary` with `aiSummary`, `aiGeneratedAt` |
| Modify | `zuralog/lib/features/nutrition/data/mock_nutrition_repository.dart` | Add `getTrend(String range)` to interface + mock; update `getTodaySummary` to return mock AI summary |
| Modify | `zuralog/lib/features/nutrition/data/api_nutrition_repository.dart` | Add `getTrend(String range)` calling `GET /api/v1/nutrition/trend?range=<range>` |
| Modify | `zuralog/lib/features/nutrition/providers/nutrition_providers.dart` | Add `_useMock` flag; update repository provider; add `nutritionTrendProvider` |
| Create | `zuralog/lib/features/nutrition/presentation/widgets/nutrition_ai_summary_card.dart` | Sparkle icon + AI summary text or skeleton; mirrors `SleepAiSummaryCard` |
| Create | `zuralog/lib/features/nutrition/presentation/widgets/nutrition_trend_section.dart` | Two `BarRenderer` charts (calories + protein) with shared 7d/30d toggle |
| Modify | `zuralog/lib/features/nutrition/presentation/nutrition_home_screen.dart` | Insert both new widgets + "View All Data →" row after macro summary card |
| Create | `zuralog/test/features/nutrition/domain/nutrition_trend_day_test.dart` | Unit tests for `NutritionTrendDay.fromJson` + extended `NutritionDaySummary.fromJson` |
| Create | `zuralog/test/features/nutrition/data/nutrition_repository_trend_test.dart` | Unit tests for `MockNutritionRepository.getTrend` and `getTodaySummary` AI fields |
| Create | `zuralog/test/features/nutrition/presentation/widgets/nutrition_ai_summary_card_test.dart` | Widget tests: text state + skeleton state |
| Create | `zuralog/test/features/nutrition/presentation/widgets/nutrition_trend_section_test.dart` | Widget test: empty state (no-data path) |

---

## Task 1: Extend nutrition domain models

**Files:**
- Modify: `zuralog/lib/features/nutrition/domain/nutrition_models.dart:239-283`
- Create: `zuralog/test/features/nutrition/domain/nutrition_trend_day_test.dart`

- [ ] **Step 1.1 — Write failing tests**

Create `zuralog/test/features/nutrition/domain/nutrition_trend_day_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';

void main() {
  group('NutritionTrendDay', () {
    test('fromJson parses all fields correctly', () {
      final day = NutritionTrendDay.fromJson({
        'date': '2026-04-19',
        'is_today': true,
        'calories': 1850.0,
        'protein_g': 120.5,
      });
      expect(day.date, '2026-04-19');
      expect(day.isToday, true);
      expect(day.calories, 1850.0);
      expect(day.proteinG, 120.5);
    });

    test('fromJson tolerates null optional fields', () {
      final day = NutritionTrendDay.fromJson({
        'date': '2026-04-18',
        'is_today': false,
      });
      expect(day.calories, isNull);
      expect(day.proteinG, isNull);
    });

    test('fromJson defaults isToday to false when missing', () {
      final day = NutritionTrendDay.fromJson({'date': '2026-04-17'});
      expect(day.isToday, false);
    });
  });

  group('NutritionDaySummary', () {
    test('fromJson parses aiSummary and aiGeneratedAt', () {
      final summary = NutritionDaySummary.fromJson({
        'total_calories': 1800,
        'total_protein_g': 110.0,
        'total_carbs_g': 220.0,
        'total_fat_g': 60.0,
        'meal_count': 3,
        'ai_summary': 'Great day of eating!',
        'ai_generated_at': '2026-04-19T10:00:00.000Z',
      });
      expect(summary.aiSummary, 'Great day of eating!');
      expect(summary.aiGeneratedAt, isNotNull);
    });

    test('fromJson tolerates missing ai fields', () {
      final summary = NutritionDaySummary.fromJson({
        'total_calories': 1500,
        'total_protein_g': 90.0,
        'total_carbs_g': 200.0,
        'total_fat_g': 50.0,
        'meal_count': 2,
      });
      expect(summary.aiSummary, isNull);
      expect(summary.aiGeneratedAt, isNull);
    });

    test('empty constant has null ai fields', () {
      expect(NutritionDaySummary.empty.aiSummary, isNull);
      expect(NutritionDaySummary.empty.aiGeneratedAt, isNull);
    });
  });
}
```

- [ ] **Step 1.2 — Run tests to confirm they fail**

```bash
cd zuralog && flutter test test/features/nutrition/domain/nutrition_trend_day_test.dart --reporter compact
```

Expected: compile error — `NutritionTrendDay` does not exist yet.

- [ ] **Step 1.3 — Add `NutritionTrendDay` class to `nutrition_models.dart`**

After the `NutritionDaySummary` class (after line 283), add:

```dart
// -- NutritionTrendDay --------------------------------------------------------

/// A single day's nutrition totals used by the trend chart.
class NutritionTrendDay {
  const NutritionTrendDay({
    required this.date,
    required this.isToday,
    this.calories,
    this.proteinG,
  });

  /// ISO-8601 date string (e.g. `'2026-04-19'`).
  final String date;

  /// Whether this day is today (used by the chart renderer to highlight the bar).
  final bool isToday;

  /// Total calories for the day, or `null` if no meals were logged.
  final double? calories;

  /// Total protein (grams) for the day, or `null` if no meals were logged.
  final double? proteinG;

  factory NutritionTrendDay.fromJson(Map<String, dynamic> json) {
    return NutritionTrendDay(
      date: json['date'] as String? ?? '',
      isToday: json['is_today'] as bool? ?? false,
      calories: (json['calories'] as num?)?.toDouble(),
      proteinG: (json['protein_g'] as num?)?.toDouble(),
    );
  }
}
```

- [ ] **Step 1.4 — Extend `NutritionDaySummary` with AI fields**

Replace the existing `NutritionDaySummary` class (lines 239–283 in `nutrition_models.dart`) with:

```dart
// -- NutritionDaySummary ------------------------------------------------------

/// Aggregated nutrition totals for a single day.
///
/// Used by the nutrition dashboard to show daily calorie and macro progress.
class NutritionDaySummary {
  const NutritionDaySummary({
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.mealCount,
    this.aiSummary,
    this.aiGeneratedAt,
  });

  /// Total kilocalories consumed today.
  final int totalCalories;

  /// Total protein consumed today (grams).
  final double totalProteinG;

  /// Total carbohydrates consumed today (grams).
  final double totalCarbsG;

  /// Total fat consumed today (grams).
  final double totalFatG;

  /// Number of meals logged today.
  final int mealCount;

  /// AI-generated observation about today's nutrition. Null until the backend
  /// has processed enough data to produce a summary.
  final String? aiSummary;

  /// When the [aiSummary] was generated. Null when [aiSummary] is null.
  final DateTime? aiGeneratedAt;

  factory NutritionDaySummary.fromJson(Map<String, dynamic> json) {
    return NutritionDaySummary(
      totalCalories: (json['total_calories'] as num?)?.round() ?? 0,
      totalProteinG: (json['total_protein_g'] as num?)?.toDouble() ?? 0.0,
      totalCarbsG: (json['total_carbs_g'] as num?)?.toDouble() ?? 0.0,
      totalFatG: (json['total_fat_g'] as num?)?.toDouble() ?? 0.0,
      mealCount: (json['meal_count'] as num?)?.toInt() ?? 0,
      aiSummary: json['ai_summary'] as String?,
      aiGeneratedAt: json['ai_generated_at'] != null
          ? DateTime.tryParse(json['ai_generated_at'] as String)
          : null,
    );
  }

  /// An empty summary with all values at zero and no AI summary.
  static const empty = NutritionDaySummary(
    totalCalories: 0,
    totalProteinG: 0,
    totalCarbsG: 0,
    totalFatG: 0,
    mealCount: 0,
  );
}
```

Also update the library doc comment at the top of `nutrition_models.dart` to include the new model in the overview list:

```dart
/// - [NutritionTrendDay]        — per-day calorie and protein totals for trend charts
```

- [ ] **Step 1.5 — Run tests to confirm they pass**

```bash
cd zuralog && flutter test test/features/nutrition/domain/nutrition_trend_day_test.dart --reporter compact
```

Expected: all 6 tests pass, 0 failures.

- [ ] **Step 1.6 — Verify no analysis errors**

```bash
cd zuralog && flutter analyze lib/features/nutrition/domain/nutrition_models.dart
```

Expected: `No issues found!`

- [ ] **Step 1.7 — Commit**

Use the `git` subagent with this message:

```
feat(nutrition): add NutritionTrendDay model and aiSummary fields to NutritionDaySummary
```

Stage: `zuralog/lib/features/nutrition/domain/nutrition_models.dart`, `zuralog/test/features/nutrition/domain/nutrition_trend_day_test.dart`

---

## Task 2: Add `getTrend` to the repository interface and mock

**Files:**
- Modify: `zuralog/lib/features/nutrition/data/mock_nutrition_repository.dart`
- Create: `zuralog/test/features/nutrition/data/nutrition_repository_trend_test.dart`

- [ ] **Step 2.1 — Write failing tests**

Create `zuralog/test/features/nutrition/data/nutrition_repository_trend_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';

void main() {
  const repo = MockNutritionRepository();

  group('MockNutritionRepository.getTrend', () {
    test('returns exactly 7 items for "7d"', () async {
      final days = await repo.getTrend('7d');
      expect(days.length, 7);
    });

    test('returns exactly 30 items for "30d"', () async {
      final days = await repo.getTrend('30d');
      expect(days.length, 30);
    });

    test('last entry is marked as today', () async {
      final days = await repo.getTrend('7d');
      expect(days.last.isToday, true);
    });

    test('all entries before today have non-null calories and protein', () async {
      final days = await repo.getTrend('7d');
      for (final day in days.take(days.length - 1)) {
        expect(day.calories, isNotNull,
            reason: 'day ${day.date} should have calories');
        expect(day.proteinG, isNotNull,
            reason: 'day ${day.date} should have protein');
      }
    });

    test('date strings are ISO-format substrings (YYYY-MM-DD)', () async {
      final days = await repo.getTrend('7d');
      for (final day in days) {
        expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day.date), true,
            reason: '${day.date} is not YYYY-MM-DD');
      }
    });
  });

  group('MockNutritionRepository.getTodaySummary AI fields', () {
    test('returns a non-null aiSummary string', () async {
      final summary = await repo.getTodaySummary();
      expect(summary.aiSummary, isA<String>());
      expect(summary.aiSummary, isNotEmpty);
    });

    test('returns a non-null aiGeneratedAt timestamp', () async {
      final summary = await repo.getTodaySummary();
      expect(summary.aiGeneratedAt, isA<DateTime>());
    });
  });
}
```

- [ ] **Step 2.2 — Run tests to confirm they fail**

```bash
cd zuralog && flutter test test/features/nutrition/data/nutrition_repository_trend_test.dart --reporter compact
```

Expected: compile error — `getTrend` does not exist yet.

- [ ] **Step 2.3 — Add `getTrend` to `NutritionRepositoryInterface`**

In `zuralog/lib/features/nutrition/data/mock_nutrition_repository.dart`, add the following method to the `NutritionRepositoryInterface` abstract interface (after `fetchFoodImage`, before the closing brace):

```dart
  /// Returns per-day calorie and protein totals for the given [range].
  ///
  /// [range] is either `'7d'` (last 7 days) or `'30d'` (last 30 days).
  Future<List<NutritionTrendDay>> getTrend(String range);
```

- [ ] **Step 2.4 — Implement `getTrend` and update `getTodaySummary` in `MockNutritionRepository`**

In `MockNutritionRepository`, add `getTrend` after the existing `fetchFoodImage` override:

```dart
  @override
  Future<List<NutritionTrendDay>> getTrend(String range) async {
    await Future<void>.delayed(_readDelay);
    final count = range == '30d' ? 30 : 7;
    final today = DateTime.now();
    return List.generate(count, (i) {
      final date = today.subtract(Duration(days: count - 1 - i));
      final isToday = i == count - 1;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return NutritionTrendDay(
        date: dateStr,
        isToday: isToday,
        calories: isToday ? null : (1600 + (i * 47) % 800).toDouble(),
        proteinG: isToday ? null : (90 + (i * 13) % 60).toDouble(),
      );
    });
  }
```

Then replace the existing `getTodaySummary` method body to include mock AI fields:

```dart
  @override
  Future<NutritionDaySummary> getTodaySummary() async {
    await Future<void>.delayed(_readDelay);
    final meals = _mockMeals();
    final totalCalories =
        meals.fold(0, (sum, meal) => sum + meal.totalCalories);
    final totalProtein =
        meals.fold(0.0, (sum, meal) => sum + meal.totalProtein);
    final totalCarbs = meals.fold(0.0, (sum, meal) => sum + meal.totalCarbs);
    final totalFat = meals.fold(0.0, (sum, meal) => sum + meal.totalFat);
    return NutritionDaySummary(
      totalCalories: totalCalories,
      totalProteinG: totalProtein,
      totalCarbsG: totalCarbs,
      totalFatG: totalFat,
      mealCount: meals.length,
      aiSummary:
          "You're off to a solid start. Protein is tracking well at ${totalProtein.round()}g so far, "
          'and your morning meal set a nutritious foundation. Consider a balanced dinner to round out '
          'the day — you have about ${(2000 - totalCalories).clamp(0, 2000)} kcal remaining.',
      aiGeneratedAt: DateTime.now().subtract(const Duration(minutes: 23)),
    );
  }
```

- [ ] **Step 2.5 — Run tests to confirm they pass**

```bash
cd zuralog && flutter test test/features/nutrition/data/nutrition_repository_trend_test.dart --reporter compact
```

Expected: all 7 tests pass, 0 failures.

- [ ] **Step 2.6 — Run the full nutrition test suite to check for regressions**

```bash
cd zuralog && flutter test test/features/nutrition/ --reporter compact
```

Expected: all existing tests still pass.

- [ ] **Step 2.7 — Commit**

Use the `git` subagent:

```
feat(nutrition): add getTrend to repository interface and mock; add AI summary to mock getTodaySummary
```

Stage: `zuralog/lib/features/nutrition/data/mock_nutrition_repository.dart`, `zuralog/test/features/nutrition/data/nutrition_repository_trend_test.dart`

---

## Task 3: Add `getTrend` to `ApiNutritionRepository`

**Files:**
- Modify: `zuralog/lib/features/nutrition/data/api_nutrition_repository.dart`

No unit test here — this would require mocking `ApiClient` (HTTP layer), which is out of scope for this plan. The API implementation will be exercised in integration testing once the backend endpoint is live.

- [ ] **Step 3.1 — Add `getTrend` to `ApiNutritionRepository`**

In `zuralog/lib/features/nutrition/data/api_nutrition_repository.dart`, add this override after `fetchFoodImage`:

```dart
  // ── Nutrition Trend ───────────────────────────────────────────────────────

  @override
  Future<List<NutritionTrendDay>> getTrend(String range) async {
    final response = await _api.get(
      '/api/v1/nutrition/trend',
      queryParameters: {'range': range},
    );
    final days = response.data['days'] as List<dynamic>? ?? [];
    return days
        .map((e) => NutritionTrendDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }
```

- [ ] **Step 3.2 — Verify no analysis errors**

```bash
cd zuralog && flutter analyze lib/features/nutrition/data/api_nutrition_repository.dart
```

Expected: `No issues found!`

- [ ] **Step 3.3 — Commit**

Use the `git` subagent:

```
feat(nutrition): implement getTrend in ApiNutritionRepository
```

Stage: `zuralog/lib/features/nutrition/data/api_nutrition_repository.dart`

---

## Task 4: Update nutrition providers

**Files:**
- Modify: `zuralog/lib/features/nutrition/providers/nutrition_providers.dart`

- [ ] **Step 4.1 — Add `_useMock` compile flag and update `nutritionRepositoryProvider`**

At the top of the providers file, after the `import` block and before the `nutritionRepositoryProvider` definition, add:

```dart
const _useMock = bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);
```

Then replace the `nutritionRepositoryProvider` definition with:

```dart
/// Singleton [NutritionRepositoryInterface] for the nutrition feature.
///
/// Returns [MockNutritionRepository] when the app is compiled with
/// `--dart-define=USE_MOCK_DATA=true`. Otherwise uses [ApiNutritionRepository].
final nutritionRepositoryProvider =
    Provider<NutritionRepositoryInterface>((ref) {
  if (_useMock) return const MockNutritionRepository();
  return ApiNutritionRepository(apiClient: ref.read(apiClientProvider));
});
```

- [ ] **Step 4.2 — Add `nutritionTrendProvider`**

After the `nutritionRulesProvider` definition (at the end of the file), add:

```dart
// ── Nutrition Trend ──────────────────────────────────────────────────────────

/// Async family provider for per-day calorie and protein totals.
///
/// Keyed by the range string (`'7d'` or `'30d'`).
/// Never puts the UI into an error state — failures resolve to an empty list.
final nutritionTrendProvider =
    FutureProvider.family<List<NutritionTrendDay>, String>((ref, range) async {
  final repo = ref.read(nutritionRepositoryProvider);
  try {
    return await repo.getTrend(range);
  } catch (e, st) {
    debugPrint('nutritionTrendProvider($range) failed: $e\n$st');
    return const [];
  }
});
```

Also update the provider inventory doc comment at the top of the file to include the two new providers:

```dart
/// - [nutritionRepositoryProvider]  — singleton repository (mock or API)
/// - [nutritionTrendProvider]        — family: per-day calorie/protein for trend charts
```

- [ ] **Step 4.3 — Verify no analysis errors**

```bash
cd zuralog && flutter analyze lib/features/nutrition/providers/nutrition_providers.dart
```

Expected: `No issues found!`

- [ ] **Step 4.4 — Commit**

Use the `git` subagent:

```
feat(nutrition): add USE_MOCK_DATA flag and nutritionTrendProvider to providers
```

Stage: `zuralog/lib/features/nutrition/providers/nutrition_providers.dart`

---

## Task 5: Create `NutritionAiSummaryCard` widget

**Files:**
- Create: `zuralog/lib/features/nutrition/presentation/widgets/nutrition_ai_summary_card.dart`
- Create: `zuralog/test/features/nutrition/presentation/widgets/nutrition_ai_summary_card_test.dart`

- [ ] **Step 5.1 — Write failing widget tests**

Create `zuralog/test/features/nutrition/presentation/widgets/nutrition_ai_summary_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_ai_summary_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('NutritionAiSummaryCard', () {
    testWidgets('shows "AI Summary" label always', (tester) async {
      await tester.pumpWidget(_wrap(const NutritionAiSummaryCard(aiSummary: null)));
      expect(find.text('AI Summary'), findsOneWidget);
    });

    testWidgets('shows provided summary text when aiSummary is not null', (tester) async {
      await tester.pumpWidget(_wrap(
        const NutritionAiSummaryCard(aiSummary: 'Looking good today!'),
      ));
      expect(find.text('Looking good today!'), findsOneWidget);
    });

    testWidgets('does not show summary text when aiSummary is null', (tester) async {
      await tester.pumpWidget(_wrap(const NutritionAiSummaryCard(aiSummary: null)));
      expect(find.text('Looking good today!'), findsNothing);
    });

    testWidgets('shows "Generated Xm ago" when generatedAt is provided', (tester) async {
      final recent = DateTime.now().subtract(const Duration(minutes: 5));
      await tester.pumpWidget(_wrap(
        NutritionAiSummaryCard(
          aiSummary: 'Great job!',
          generatedAt: recent,
        ),
      ));
      expect(find.textContaining('Generated'), findsOneWidget);
      expect(find.textContaining('m ago'), findsOneWidget);
    });

    testWidgets('does not show timestamp row when generatedAt is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const NutritionAiSummaryCard(aiSummary: 'Great job!'),
      ));
      expect(find.textContaining('Generated'), findsNothing);
    });
  });
}
```

- [ ] **Step 5.2 — Run tests to confirm they fail**

```bash
cd zuralog && flutter test test/features/nutrition/presentation/widgets/nutrition_ai_summary_card_test.dart --reporter compact
```

Expected: compile error — file does not exist yet.

- [ ] **Step 5.3 — Create the widget**

Create `zuralog/lib/features/nutrition/presentation/widgets/nutrition_ai_summary_card.dart`:

```dart
// zuralog/lib/features/nutrition/presentation/widgets/nutrition_ai_summary_card.dart
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

class NutritionAiSummaryCard extends StatelessWidget {
  const NutritionAiSummaryCard({
    super.key,
    required this.aiSummary,
    this.generatedAt,
  });

  final String? aiSummary;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: AppColors.categoryNutrition,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: AppDimens.iconSm,
                  color: AppColors.categoryNutrition,
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Text(
                  'AI Summary',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.categoryNutrition,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            aiSummary != null
                ? Text(
                    aiSummary!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      height: 1.55,
                    ),
                  )
                : const _SkeletonText(),
            if (generatedAt != null) ...[
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                'Generated ${_relativeTime(generatedAt!)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SkeletonText extends StatelessWidget {
  const _SkeletonText();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final width in [1.0, 0.85, 0.72])
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
            child: Container(
              height: 13,
              width: MediaQuery.of(context).size.width * width,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.shapeXs),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5.4 — Run tests to confirm they pass**

```bash
cd zuralog && flutter test test/features/nutrition/presentation/widgets/nutrition_ai_summary_card_test.dart --reporter compact
```

Expected: all 5 tests pass, 0 failures.

- [ ] **Step 5.5 — Commit**

Use the `git` subagent:

```
feat(nutrition): add NutritionAiSummaryCard widget
```

Stage: `zuralog/lib/features/nutrition/presentation/widgets/nutrition_ai_summary_card.dart`, `zuralog/test/features/nutrition/presentation/widgets/nutrition_ai_summary_card_test.dart`

---

## Task 6: Create `NutritionTrendSection` widget

**Files:**
- Create: `zuralog/lib/features/nutrition/presentation/widgets/nutrition_trend_section.dart`
- Create: `zuralog/test/features/nutrition/presentation/widgets/nutrition_trend_section_test.dart`

- [ ] **Step 6.1 — Write failing widget test**

Create `zuralog/test/features/nutrition/presentation/widgets/nutrition_trend_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_trend_section.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
}

void main() {
  group('NutritionTrendSection', () {
    testWidgets('shows "No data for this period" for both charts when provider returns empty list',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NutritionTrendSection(),
          overrides: [
            nutritionTrendProvider('7d').overrideWith(
              (ref) async => const <NutritionTrendDay>[],
            ),
          ],
        ),
      );
      // Pump twice: once for the widget build, once for the FutureProvider to resolve.
      await tester.pump();
      await tester.pump();
      expect(find.text('No data for this period'), findsNWidgets(2));
    });

    testWidgets('shows "Nutrition Trend" label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NutritionTrendSection(),
          overrides: [
            nutritionTrendProvider('7d').overrideWith(
              (ref) async => const <NutritionTrendDay>[],
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Nutrition Trend'), findsOneWidget);
    });

    testWidgets('shows "Calories" and "Protein" chart labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NutritionTrendSection(),
          overrides: [
            nutritionTrendProvider('7d').overrideWith(
              (ref) async => const <NutritionTrendDay>[],
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Calories'), findsOneWidget);
      expect(find.textContaining('Protein'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 6.2 — Run tests to confirm they fail**

```bash
cd zuralog && flutter test test/features/nutrition/presentation/widgets/nutrition_trend_section_test.dart --reporter compact
```

Expected: compile error — file does not exist yet.

- [ ] **Step 6.3 — Create the widget**

Create `zuralog/lib/features/nutrition/presentation/widgets/nutrition_trend_section.dart`:

```dart
// zuralog/lib/features/nutrition/presentation/widgets/nutrition_trend_section.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';
import 'package:zuralog/shared/widgets/charts/chart_mode.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/renderers/bar_renderer.dart';

class NutritionTrendSection extends ConsumerStatefulWidget {
  const NutritionTrendSection({super.key});

  @override
  ConsumerState<NutritionTrendSection> createState() =>
      _NutritionTrendSectionState();
}

class _NutritionTrendSectionState extends ConsumerState<NutritionTrendSection> {
  String _range = '7d';

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final trendAsync = ref.watch(nutritionTrendProvider(_range));
    final days = trendAsync.valueOrNull ?? const [];

    final calorieBars = days
        .map((d) => BarPoint(
              label: d.date.length >= 10 ? d.date.substring(5) : d.date,
              value: d.calories ?? 0,
              isToday: d.isToday,
            ))
        .toList();

    final proteinBars = days
        .map((d) => BarPoint(
              label: d.date.length >= 10 ? d.date.substring(5) : d.date,
              value: d.proteinG ?? 0,
              isToday: d.isToday,
            ))
        .toList();

    final avgCalories = calorieBars.isEmpty
        ? null
        : calorieBars.fold<double>(0, (s, b) => s + b.value) /
            calorieBars.length;

    final avgProtein = proteinBars.isEmpty
        ? null
        : proteinBars.fold<double>(0, (s, b) => s + b.value) /
            proteinBars.length;

    return ZuralogCard(
      variant: ZCardVariant.data,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: title + range toggle
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nutrition Trend',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                _RangeToggle(
                  selected: _range,
                  onChanged: (r) => setState(() => _range = r),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // Calories chart
            Text(
              avgCalories != null
                  ? 'Calories  ·  Avg ${avgCalories.round()} kcal'
                  : 'Calories',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            if (calorieBars.isNotEmpty)
              SizedBox(
                height: 120,
                child: BarRenderer(
                  config: BarChartConfig(
                    bars: calorieBars,
                    goalValue: 2000,
                    showAvgLine: true,
                  ),
                  color: AppColors.categoryNutrition,
                  renderCtx: ChartRenderContext.fromMode(ChartMode.tall).copyWith(
                    showAxes: true,
                    showGrid: false,
                    animationProgress: 1.0,
                  ),
                ),
              )
            else
              SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    'No data for this period',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: AppDimens.spaceLg),

            // Protein chart
            Text(
              avgProtein != null
                  ? 'Protein  ·  Avg ${avgProtein.round()}g'
                  : 'Protein',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            if (proteinBars.isNotEmpty)
              SizedBox(
                height: 120,
                child: BarRenderer(
                  config: BarChartConfig(
                    bars: proteinBars,
                    goalValue: 150,
                    showAvgLine: true,
                  ),
                  color: AppColors.categoryNutrition,
                  renderCtx: ChartRenderContext.fromMode(ChartMode.tall).copyWith(
                    showAxes: true,
                    showGrid: false,
                    animationProgress: 1.0,
                  ),
                ),
              )
            else
              SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    'No data for this period',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ['7d', '30d'].map((r) {
        final isSelected = selected == r;
        return GestureDetector(
          onTap: () => onChanged(r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm,
              vertical: AppDimens.spaceXs,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.categoryNutrition.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimens.shapeXs),
              border: Border.all(
                color: isSelected
                    ? AppColors.categoryNutrition.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              r,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected
                    ? AppColors.categoryNutrition
                    : AppColorsOf(context).textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 6.4 — Run tests to confirm they pass**

```bash
cd zuralog && flutter test test/features/nutrition/presentation/widgets/nutrition_trend_section_test.dart --reporter compact
```

Expected: all 3 tests pass, 0 failures.

- [ ] **Step 6.5 — Commit**

Use the `git` subagent:

```
feat(nutrition): add NutritionTrendSection widget with calories and protein bar charts
```

Stage: `zuralog/lib/features/nutrition/presentation/widgets/nutrition_trend_section.dart`, `zuralog/test/features/nutrition/presentation/widgets/nutrition_trend_section_test.dart`

---

## Task 7: Wire both widgets into `NutritionHomeScreen` + add "View All Data →" row

**Files:**
- Modify: `zuralog/lib/features/nutrition/presentation/nutrition_home_screen.dart`

No new test file — the existing `swipe_actions_test.dart` will be used to verify no regressions. The `NutritionTrendSection` widget tests cover the chart logic.

- [ ] **Step 7.1 — Add imports to `NutritionHomeScreen`**

In `zuralog/lib/features/nutrition/presentation/nutrition_home_screen.dart`, add these three imports after the existing import block (the barrel export `widgets.dart` already includes `ZProBadge`, so no separate import is needed for it):

```dart
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_ai_summary_card.dart';
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_trend_section.dart';
```

- [ ] **Step 7.2 — Update `nutritionDaySummaryProvider` invalidation in `onRefresh`**

In the `onRefresh` closure (inside the `data:` branch), add `nutritionTrendProvider` invalidation so the charts refresh on pull-to-refresh. Replace the existing `onRefresh`:

```dart
Future<void> onRefresh() async {
  ref.invalidate(todayMealsProvider);
  ref.invalidate(nutritionDaySummaryProvider);
  ref.invalidate(nutritionTrendProvider('7d'));
  ref.invalidate(nutritionTrendProvider('30d'));
  await Future.wait([
    ref
        .read(todayMealsProvider.future)
        .catchError((_) => <Meal>[]),
    ref
        .read(nutritionDaySummaryProvider.future)
        .catchError((_) => NutritionDaySummary.empty),
  ]);
}
```

- [ ] **Step 7.3 — Insert new widgets and update animation delays**

In the `ListView` children of the populated state, replace the block from the daily summary card through the section header. The new order is:

```
0ms    — date header  (unchanged)
60ms   — macro summary card  (unchanged)
120ms  — NutritionAiSummaryCard  ← NEW
180ms  — NutritionTrendSection  ← NEW
240ms  — "View All Data →" row  ← NEW
300ms  — "Today's Meals" section header  (was 120ms)
360ms + (i * 60)ms — meal cards  (was 180ms + ...)
360ms + (meals.length * 60) + 60ms — "Log a meal" CTA  (was 180ms + ...)
```

After the existing `// ── Daily summary card ─────────────────────────────────` block, add:

```dart
                // ── AI Summary card ─────────────────────────────────────
                ZFadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceMd,
                      AppDimens.spaceMd,
                      0,
                    ),
                    child: NutritionAiSummaryCard(
                      aiSummary: summary.aiSummary,
                      generatedAt: summary.aiGeneratedAt,
                    ),
                  ),
                ),

                // ── Nutrition Trend ─────────────────────────────────────
                ZFadeSlideIn(
                  delay: const Duration(milliseconds: 180),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceMd,
                      AppDimens.spaceMd,
                      0,
                    ),
                    child: NutritionTrendSection(),
                  ),
                ),

                // ── View All Data row ────────────────────────────────────
                ZFadeSlideIn(
                  delay: const Duration(milliseconds: 240),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceSm,
                      AppDimens.spaceMd,
                      0,
                    ),
                    child: GestureDetector(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All-Data screen coming in a future update'),
                          duration: Duration(seconds: 2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'View All Data',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppDimens.spaceXs),
                          const ZProBadge(showLock: true),
                          const SizedBox(width: AppDimens.spaceXs),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: AppDimens.iconSm,
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
```

Then update the `// ── Section header` block's delay from `120` to `300`:

```dart
                // ── Section header ─────────────────────────────────────
                ZFadeSlideIn(
                  delay: const Duration(milliseconds: 300),   // was 120
                  ...
```

Update the `// ── Meal cards` loop delay from `180` to `360`:

```dart
                  ZFadeSlideIn(
                    delay: Duration(milliseconds: 360 + (i * 60)),  // was 180
                    ...
```

Update the `// ── Log a meal CTA` delay from `180` to `360`:

```dart
                ZFadeSlideIn(
                  delay: Duration(
                    milliseconds: 360 + (meals.length * 60) + 60,  // was 180
                  ),
                  ...
```

- [ ] **Step 7.4 — Run the full nutrition test suite to verify no regressions**

```bash
cd zuralog && flutter test test/features/nutrition/ --reporter compact
```

Expected: all tests pass.

- [ ] **Step 7.5 — Run `flutter analyze` on the full project**

```bash
cd zuralog && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 7.6 — Commit**

Use the `git` subagent:

```
feat(nutrition): wire AI summary card, trend charts, and View All Data row into NutritionHomeScreen
```

Stage: `zuralog/lib/features/nutrition/presentation/nutrition_home_screen.dart`

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Covered by |
|-----------------|-----------|
| `NutritionAiSummaryCard` with sparkle icon, text or skeleton, timestamp | Task 5 |
| `NutritionTrendSection` with calories chart (goal 2000) | Task 6 |
| `NutritionTrendSection` with protein chart (goal 150g) | Task 6 |
| 7d / 30d range toggle | Task 6 |
| Both charts use shared toggle (same range) | Task 6 — single `_range` state |
| Mock data via `USE_MOCK_DATA` flag | Task 4 |
| `NutritionTrendDay` model with `date`, `isToday`, `calories`, `proteinG` | Task 1 |
| `NutritionDaySummary` extended with `aiSummary`, `aiGeneratedAt` | Task 1 |
| `getTrend` on interface, mock, and API repository | Tasks 2 + 3 |
| `nutritionTrendProvider` Riverpod family | Task 4 |
| "View All Data →" button with `ZProBadge(showLock: true)` | Task 7 |
| Wired into `NutritionHomeScreen` populated state | Task 7 |
| `onRefresh` invalidates trend provider | Task 7 |
| `flutter analyze` clean at every step | Each task |
| Git commit at each logical checkpoint | Each task |

**Type consistency check:** `NutritionTrendDay` defined in Task 1 and consumed in Tasks 2, 6. `nutritionTrendProvider` defined in Task 4 and watched in Task 6. All `BarPoint`, `BarChartConfig`, `BarRenderer`, `ChartRenderContext`, `ChartMode` APIs used in Task 6 match the existing `SleepTrendSection` pattern confirmed in earlier research. `ZProBadge(showLock: true)` confirmed available in `widgets.dart` barrel.

**Placeholder scan:** No TBDs. All code blocks are complete. API endpoint path (`/api/v1/nutrition/trend`) matches the project's REST pattern.

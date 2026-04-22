# Nutrition Goals & Tracking — Design Spec
**Date:** 2026-04-23  
**Status:** Approved — ready for implementation planning  
**Scope:** Mobile app (`zuralog/`) + backend (`cloud-brain/`)

---

## Overview

The nutrition feature currently shows raw numbers (calories, protein, carbs, fat) with no goals, no targets, and no sense of whether the user is on track. This spec adds a complete goal-tracking layer: a daily calorie budget with exercise offset, visual macro progress bars, six nutrient targets, TDEE-based goal setup, pre-logging, meal templates, streaks, and a weekly summary. Everything plugs into the existing goal system — no parallel storage.

---

## 1. Architecture

### Single goal system, two entry points
All nutrition goals are stored in the existing `Goal` table alongside every other goal type. The Goals tab is the single source of truth. The nutrition screen adds a shortcut that opens the same goal creation flow pre-filtered to nutrition goal types — saving from either place writes to the same table.

### New `GoalType` values
Add to the `GoalType` enum (Flutter) and `goal_type` accepted values (backend):

| Type | Direction | Unit |
|------|-----------|------|
| `dailyProteinTarget` | minimum (hit it) | g |
| `dailyCarbLimit` | maximum (stay under) | g |
| `dailyFatLimit` | maximum (stay under) | g |
| `dailyFiberTarget` | minimum (hit it) | g |
| `dailySodiumLimit` | maximum (stay under) | mg |
| `dailySugarLimit` | maximum (stay under) | g |

The existing `dailyCalorieLimit` goal type is kept and properly wired up for the first time.

### Extended `NutritionDaySummary` model
Add to `NutritionDaySummary` (Flutter model) and `GET /api/v1/nutrition/today` summary object (backend):

```
total_fiber_g          float
total_sodium_mg        float
total_sugar_g          float
exercise_calories_burned  int   // workouts + manual entries combined
```

### Extended food-level data
Add optional fields to `MealFood` and `ParsedFoodItem` models and all food endpoints:

```
fiber_g      float?   // defaults to 0.0 if absent
sodium_mg    float?   // defaults to 0.0 if absent
sugar_g      float?   // defaults to 0.0 if absent
```

Older meals without these fields default to `0` on the client — no migration needed.

### New Flutter provider: `nutritionGoalsProvider`
Reads from the existing goals system and exposes a single structured object containing all the user's active nutrition goal values:

```dart
class NutritionGoals {
  final int? dailyCalorieBudget;
  final double? proteinTargetG;
  final double? carbLimitG;
  final double? fatLimitG;
  final double? fiberTargetG;
  final double? sodiumLimitMg;
  final double? sugarLimitG;
}
```

Returns `NutritionGoals` with all nulls when no nutrition goals are set. The nutrition home screen reads this provider to drive the ring, bars, and status icons. Null goals mean no ring or bars are shown — replaced by a prompt card ("Set your nutrition goals to track your progress").

### Exercise calorie source
The workout feature writes `calories_burned` when a session is saved. The nutrition backend reads all of today's workout sessions and sums them into `exercise_calories_burned`. Manual exercise entries (new endpoint) are added on top. The Flutter side consumes this as a single combined field — it never needs to know the source breakdown.

### Weight: single source of truth
Body weight lives in the user's profile, logged via the existing FAB. Both nutrition and fitness read from this shared value. No weight logging is added to the nutrition screen. A full weight tracking feature (history chart, trend) is out of scope for this spec.

---

## 2. Nutrition Goals Setup Flow

### First-time onboarding sheet
Triggered when the user taps the goals icon in the nutrition app bar (or creates a nutrition goal from the Goals tab) and has no nutrition goals set yet. A bottom sheet walks through 3 steps in sequence:

**Step 1 — Your body**  
Pulls the user's current weight from the FAB log automatically. Asks for:
- Height (cm or ft/in based on units preference)
- Age
- Biological sex (for TDEE formula accuracy)

These save to the user's profile. Never asked again unless the user manually resets.

**Step 2 — Activity level**  
Five-option picker:
- Sedentary (desk job, little movement)
- Lightly active (walks, light exercise 1–3×/week)
- Moderately active (exercise 3–5×/week)
- Very active (hard training 6–7×/week)
- Athlete (physical job + daily training)

**Step 3 — Your goal**  
Three cards:
- Lose weight → −500 kcal/day deficit
- Maintain weight → TDEE = budget
- Gain muscle → +300 kcal/day surplus

### TDEE calculation
Using the Mifflin-St Jeor formula × activity multiplier. From these three steps the app proposes:

| Nutrient | Proposed value |
|----------|---------------|
| Daily calorie budget | TDEE ± adjustment |
| Protein | 1.6g × bodyweight (kg) |
| Carbs | 40% of calorie budget ÷ 4 |
| Fat | 30% of calorie budget ÷ 9 |
| Fiber | 25g (women) / 38g (men) |
| Sodium limit | 2,300mg |
| Sugar limit | 50g |

### Macro split calculator (review & adjust screen)
Before saving, the user sees all proposed values and can edit any of them. A percentage toggle switches macro targets between grams and percentages — changing one macro percentage adjusts the others proportionally and updates gram targets in real time (slider-based). The gram view and percentage view stay in sync.

The user can override any value manually. Tapping "Use recommended" restores the calculated defaults.

### Saving
Each nutrient target saves as its own `Goal` record in the goals table. Up to 7 goal records are created in one flow. Each has `period: daily`.

### Returning users
After first setup, the goals icon opens a simpler edit sheet showing current targets with an option to "Recalculate" (re-runs the TDEE flow with updated weight/activity).

---

## 3. Nutrition Home Screen Redesign

### Screen order (top to bottom)

| Position | Component | Change |
|----------|-----------|--------|
| 1 | App bar: "Nutrition" + goals icon (🎯) + rules icon | Goals icon added |
| 2 | Date header | Unchanged |
| 3 | **Budget Hero Card** | **New — replaces old summary card** |
| 4 | **Macro Progress Card** | **New** |
| 5 | AI Summary card | Unchanged |
| 6 | Nutrition Trend section | Goal lines use real values (minor update) |
| 7 | View All Data row | Unchanged |
| 8 | Today's Meals section + meal cards | Unchanged |
| 9 | Log a meal button | Unchanged |

### Removed
The plain row of four numbers (kcal / protein / carbs / fat with no context) is removed entirely and replaced by the two new cards.

### Budget Hero Card (new)
A `ZCardVariant.plain` data card containing:

- **Ring** (left): circular progress ring, 80px diameter. Fill colour is `AppColors.categoryNutrition` (amber). Percentage shown in centre is `(calories eaten / budget) × 100`. The ring fills as food is consumed — it does NOT shrink when exercise is added back.
- **Budget info** (right):
  - Large number: kcal remaining (`budget − eaten + exercise_burned`)
  - Subtitle: "remaining today"
  - Two chips: "Budget 2,500" and "Eaten 653"
  - Green exercise badge (visible only when exercise calories > 0): "+ 350 kcal from morning run". Tapping opens the exercise entries sheet.
  - When no exercise logged: a small muted "+ Add exercise" text link in place of the badge.

When no calorie goal is set: the card shows a prompt instead — "Set a calorie goal to see your daily budget" with a "Set goals →" button.

### Macro Progress Card (new)
A `ZCardVariant.data` card (no pattern — raw numbers stay clean) with two sections separated by a subtle divider:

**Main macros:**
- Protein — progress bar, target direction is minimum (fill = eaten / target)
- Carbs — progress bar, target direction is maximum (fill = eaten / limit)
- Fat — progress bar, target direction is maximum

**Other nutrients:**
- Fiber — minimum target
- Sugar — maximum limit
- Sodium — maximum limit

Each row shows: nutrient name + status icon + current value / target + horizontal bar.

**Status icons — minimum targets (Protein, Fiber):**
- 🟢 eaten ≥ 100% of target (goal met)
- 🟡 eaten 50–99% of target (making progress)
- 🔴 eaten < 50% of target (significantly behind)

**Status icons — maximum limits (Carbs, Fat, Sugar, Sodium):**
- 🟢 eaten ≤ 75% of limit (plenty of room)
- 🟡 eaten 75–100% of limit (approaching or at limit)
- 🔴 eaten > 100% of limit (over — bar fills completely and turns red)

**Bar colours:** Protein = `#34C759` (green), Carbs = `#FF9F0A` (amber), Fat = `#FF9F0A`, Fiber = `#63E6BE` (teal), Sugar = `#64D2FF` (blue), Sodium = `#BF5AF2` (purple). Bars turn `#FF3B30` (red) when over limit.

"Edit goals →" text link in bottom-right corner opens the returning-user goals edit sheet.

When no macro goals are set: the card is hidden entirely. The prompt inside the Budget Hero Card covers this.

### Nutrition Trend section (minor update)
The two hardcoded `goalValue` numbers (`2000` for calories, `150` for protein) are replaced with values read from `nutritionGoalsProvider`. If no goals are set, the goal line is hidden.

---

## 4. Exercise Calorie Integration

### Automatic
The workout feature writes `calories_burned` per session. The nutrition backend sums all today's sessions into `exercise_calories_burned` on the `NutritionDaySummary`. No user action required — pulling to refresh or opening the nutrition screen picks it up.

### Manual entry sheet
Tapping the exercise badge (or the "+ Add exercise" link) opens a bottom sheet:

- List of today's exercise entries — each row: activity name, calories, source label ("From workout" or "Manual"), swipe to delete (manual only; workout-sourced entries cannot be deleted here)
- "Add manually" button → inline form: activity name (text field) + calories burned (number field) → saves to `POST /api/v1/nutrition/exercise`

### Net calorie formula
```
Remaining = Budget − Calories eaten + Exercise calories burned
```
Computed server-side and returned in `NutritionDaySummary`. The ring percentage uses `Calories eaten / Budget` only — exercise does not shrink the ring.

---

## 5. Pre-logging, Quick Re-log & Meal Templates

### Quick re-log
The existing `recentFoodsProvider` is surfaced more prominently. A "Recent" chip row at the top of the log meal sheet shows the last 5 foods as tappable chips. One tap adds the food at its last-used portion. No new backend work needed.

### Pre-logging
A date selector at the top of the log meal sheet defaults to today but allows selecting up to 7 days ahead. When a future date is selected, the sheet header changes to "Plan for [day]" and the `logged_at` field in `POST /api/v1/nutrition/meals` sends that future date. The backend already accepts any `logged_at` — no new endpoint needed. Pre-logged meals appear automatically on the nutrition home screen when that day arrives.

### Meal templates
After confirming food items in the log meal sheet, a "Save as template" option appears. The user names the template (e.g. "My usual breakfast"). A "Templates" tab appears in the log meal sheet alongside "Recent" and "Search".

New endpoints:
- `GET /api/v1/nutrition/templates` — list saved templates
- `POST /api/v1/nutrition/templates` — save template (name + list of foods)
- `DELETE /api/v1/nutrition/templates/:id` — delete template

---

## 6. Streaks & Weekly Summary

### Goal hit streaks
The backend evaluates each day whether all active nutrition goals were met:
- Calorie budget: stayed within budget (or no calorie goal set)
- Protein: hit the minimum target
- Carbs/Fat/Sugar/Sodium: stayed under the limits
- Fiber: hit the minimum target

A new `StreakType.nutritionGoals` value is added to the existing streak system. The streak increments for each consecutive day all set goals are met. It appears as a streak card on the Progress tab alongside existing streaks.

### Weekly summary card
Appears at the top of the nutrition home screen (above the Budget Hero Card) on Sundays, or the first time the user opens the screen after a week has ended. Dismissible — disappears until next Sunday.

Uses `ZCardVariant.feature` with the amber nutrition pattern (consistent with AI Summary card). Contains:
- Days this week calorie goal was hit (e.g. "5 / 7 days")
- Days protein target was hit
- Average daily calories vs budget
- Total weekly calorie deficit or surplus (e.g. "−2,100 kcal this week")
- Projected outcome line (only shown with ≥ 3 days of data): "At this pace you'll reach your goal weight by ~June 15"

### Today tab pillar card status dot
The nutrition pillar card on the Today tab gains a small status dot:
- 🟢 All nutrition goals on track for today
- 🟡 Any nutrient approaching its limit (>80%)
- 🔴 Any nutrient over its limit

No dot shown when no nutrition goals are set.

---

## 7. Backend API Changes

### Modified endpoints

| Endpoint | Change |
|----------|--------|
| `GET /api/v1/nutrition/today` | Add `total_fiber_g`, `total_sodium_mg`, `total_sugar_g`, `exercise_calories_burned` to summary object |
| `POST /api/v1/nutrition/meals` | Accept optional `fiber_g`, `sodium_mg`, `sugar_g` per food item |
| `GET /api/v1/nutrition/meals/:id` | Return `fiber_g`, `sodium_mg`, `sugar_g` per food item |
| `POST /api/v1/nutrition/meals/parse` | Return `fiber_g`, `sodium_mg`, `sugar_g` on parsed food items |
| `POST /api/v1/nutrition/meals/refine` | Return `fiber_g`, `sodium_mg`, `sugar_g` on refined food items |
| `GET /api/v1/nutrition/trend` | Goal line values sourced from user's actual goals |

### New endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /api/v1/nutrition/exercise` | Log a manual exercise entry (activity name + calories) |
| `GET /api/v1/nutrition/exercise/today` | List today's exercise entries (workout-sourced + manual) |
| `DELETE /api/v1/nutrition/exercise/:id` | Delete a manual exercise entry |
| `GET /api/v1/nutrition/templates` | List saved meal templates |
| `POST /api/v1/nutrition/templates` | Save a new meal template |
| `DELETE /api/v1/nutrition/templates/:id` | Delete a meal template |

### New goal types (backend)
Accept in `goal_type` field on `POST /api/v1/goals`:
`daily_protein_target`, `daily_carb_limit`, `daily_fat_limit`, `daily_fiber_target`, `daily_sodium_limit`, `daily_sugar_limit`

### Nutrition goals evaluation (backend)
Daily cron job (or on-demand at day rollover) evaluates whether all nutrition goals were met and updates the `nutritionGoals` streak accordingly.

---

## 8. Deferred (Out of Scope)

The following were discussed and explicitly deferred to future specs:

| Feature | Reason deferred |
|---------|----------------|
| BMI calculator | Belongs in a future "Body" section alongside the workout feature |
| Body fat % estimator | Same as BMI |
| Ideal weight calculator | Same as BMI |
| Micronutrients beyond fiber/sodium/sugar (vitamins, minerals, amino acids) | Foundational six nutrients first; expand in a future iteration |
| Full weight tracking (history chart, trend) | Separate feature; weight read-only from FAB for now |
| Water intake tracking | Exists as a separate `waterIntake` goal type already; not part of nutrition screen |

---

## 9. Complete Feature Checklist

Everything below must be implemented before this spec is considered done.

### Flutter — Domain & Providers
- [ ] Add `dailyProteinTarget`, `dailyCarbLimit`, `dailyFatLimit`, `dailyFiberTarget`, `dailySodiumLimit`, `dailySugarLimit` to `GoalType` enum
- [ ] Add `fiber_g`, `sodium_mg`, `sugar_g` fields to `MealFood` and `ParsedFoodItem` models
- [ ] Add `totalFiberG`, `totalSodiumMg`, `totalSugarG`, `exerciseCaloriesBurned` to `NutritionDaySummary` model
- [ ] Create `NutritionGoals` model
- [ ] Create `nutritionGoalsProvider` reading from the goals system

### Flutter — Nutrition Goals Setup
- [ ] Build first-time onboarding bottom sheet (3-step: body → activity → goal)
- [ ] Build TDEE calculator (Mifflin-St Jeor × activity multiplier)
- [ ] Build review & adjust screen with macro split calculator (percentage ↔ gram toggle)
- [ ] Build returning-user edit sheet (current targets + recalculate option)
- [ ] Wire goals icon in nutrition app bar to open correct sheet

### Flutter — Nutrition Home Screen
- [ ] Remove old raw numbers summary card
- [ ] Build `NutritionBudgetHeroCard` widget (ring + remaining + chips + exercise badge)
- [ ] Build `NutritionMacroProgressCard` widget (6 bars, status icons, edit goals link)
- [ ] Add no-goals prompt state to both new cards
- [ ] Update `NutritionTrendSection` to read goal values from `nutritionGoalsProvider`
- [ ] Add goals icon (🎯) to nutrition app bar actions

### Flutter — Exercise Calorie Integration
- [ ] Build exercise entries bottom sheet (list + add manually form)
- [ ] Connect exercise badge tap to open exercise entries sheet
- [ ] Show "+ Add exercise" text link when no exercise logged
- [ ] Create exercise repository interface + API implementation + mock
- [ ] Create `todayExerciseProvider`

### Flutter — Pre-logging, Quick Re-log & Templates
- [ ] Surface recent foods more prominently in log meal sheet (chip row)
- [ ] Add date selector to log meal sheet (today + up to 7 days ahead)
- [ ] Build "Save as template" flow in log meal sheet
- [ ] Build Templates tab in log meal sheet
- [ ] Create templates repository interface + API implementation + mock

### Flutter — Streaks & Weekly Summary
- [ ] Add `nutritionGoals` to `StreakType` enum
- [ ] Build `NutritionWeeklySummaryCard` widget (feature card, amber pattern)
- [ ] Wire weekly summary card to appear on nutrition home screen at week rollover
- [ ] Add status dot to `NutritionPillarCard` on Today tab

### Backend — Modified Endpoints
- [ ] Add `total_fiber_g`, `total_sodium_mg`, `total_sugar_g`, `exercise_calories_burned` to `GET /api/v1/nutrition/today` summary
- [ ] Accept + return `fiber_g`, `sodium_mg`, `sugar_g` on all meal food endpoints
- [ ] Accept + return `fiber_g`, `sodium_mg`, `sugar_g` on parse and refine endpoints
- [ ] Source trend goal lines from user's actual goal values

### Backend — New Endpoints
- [ ] `POST /api/v1/nutrition/exercise`
- [ ] `GET /api/v1/nutrition/exercise/today`
- [ ] `DELETE /api/v1/nutrition/exercise/:id`
- [ ] `GET /api/v1/nutrition/templates`
- [ ] `POST /api/v1/nutrition/templates`
- [ ] `DELETE /api/v1/nutrition/templates/:id`

### Backend — Goals System
- [ ] Accept new nutrition goal types: `daily_protein_target`, `daily_carb_limit`, `daily_fat_limit`, `daily_fiber_target`, `daily_sodium_limit`, `daily_sugar_limit`
- [ ] Daily evaluation job for `nutritionGoals` streak
- [ ] TDEE calculation performed client-side in Flutter (pure math, no server round-trip needed)

### Backend — Database
- [ ] Add `fiber_g`, `sodium_mg`, `sugar_g` columns to `meal_foods` table (nullable, default 0)
- [ ] Create `exercise_entries` table (`id`, `user_id`, `date`, `activity_name`, `calories_burned`, `source`, `session_id?`, `created_at`)
- [ ] Create `meal_templates` table (`id`, `user_id`, `name`, `foods_json`, `created_at`)

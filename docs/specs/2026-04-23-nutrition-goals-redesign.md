# Nutrition Goals Redesign

**Date:** 2026-04-23  
**Branch:** `feat/nutrition-goals-redesign`  
**Status:** Approved — ready for implementation planning

---

## Overview

A full redesign of the nutrition goals setup flow, fixing a broken save path, establishing a single source of truth for body stats, and replacing the cramped multi-field wizard with an immersive one-question-per-screen experience.

---

## 1. Single Source of Truth — Body Stats in Settings

### Problem
The nutrition goals wizard currently asks for height, weight, age, and biological sex every time it opens and discards them after the TDEE calculation. Nothing is persisted. The user has to retype everything on each visit.

### Solution
Body stats live in Settings → Account → Edit Profile → **Health Profile section**. The wizard reads from there. No new top-level Settings section is needed — the "Health Profile" section already exists with the right name.

**What already exists:**
- `height_cm` on backend `users` table + Flutter `UserProfile` model
- Birthday (age derived from this), gender — both in profile
- Metric/Imperial toggle in Account → Preferences, already drives height display
- `_HeightPickerSheet` in Edit Profile with full cm ↔ ft/in support

**What needs to be added — backend (`cloud-brain`):**
- Add `weight_kg` column to `users` table: `Numeric(5,1)`, nullable, range 1–500
- Add `weight_kg` to `UpdateProfileRequest` Pydantic schema (optional field)
- Return `weight_kg` in the `UserProfile` response from `GET /api/v1/users/me/profile`

**What needs to be added — Flutter (`zuralog`):**
- Add `weightKg` (`double?`) to `UserProfile` model + `fromJson`
- Add `weightKg` parameter to `AuthRepository.updateProfile()`
- Add a **Weight tile** to Edit Profile → Health Profile section
- Build `_WeightPickerSheet` — same pattern as `_HeightPickerSheet`, showing kg (metric) or lbs (imperial) based on `unitsSystemProvider`. Store internally as kg.
- Add `weightKg` to `_hasChanges` check and `_save()` call in `EditProfileScreen`

**Unit conversion:**
- Internal storage is always metric (kg, cm)
- Display converts based on `unitsSystemProvider` (already exists in Account → Preferences)
- 1 kg = 2.20462 lbs

---

## 2. Immersive Wizard — One Question Per Screen

### Problem
The current setup is a bottom sheet with two dense steps: step 0 packs height, weight, age, and sex into one screen; step 1 packs activity level and weight goal into another. No immersion. The wizard replaces itself with `MaterialPageRoute`, breaking navigation.

### Solution
Replace `NutritionGoalsSetupSheet` with a full-screen wizard pushed via GoRouter. Each step is its own screen with one question, a progress bar, and a Continue button.

**New route:**
- `RouteNames.nutritionGoalsSetup` → `/nutrition/goals/setup`
- Pushed from the nutrition home screen when goals are not set

**Step sequence (dynamic — steps skipped when data already exists):**

| Step | Screen | Condition |
|------|--------|-----------|
| 0a | Height | Only if `profile.heightCm == null` |
| 0b | Weight | Only if `profile.weightKg == null` |
| 0c | Date of Birth | Only if `profile.birthday == null` |
| 0d | Biological Sex | Only if `profile.gender == null` |
| 0e | Stats summary (editable) | Always shown when all stats exist |
| 1 | What's your goal? | Always |
| 2 | How fast? | Only if goal ≠ Maintain |
| 3 | How active are you? | Always |
| 4 | Macro review | Always |

**Step 0 — missing stats (inline, saves to profile):**
- Each missing stat gets its own full-screen question (same one-question style as steps 1–3)
- On Continue, the value is saved immediately via `PATCH /api/v1/users/me/profile`
- A subtitle reads: *"This updates your Health Profile in Settings and drives your calorie calculation."*
- Uses the same unit-aware inputs as Edit Profile (cm or ft/in, kg or lbs)

**Step 0e — stats summary (when profile is complete):**
- Shown as a compact card at the top of Step 1 (not a separate screen)
- Displays: Height · Weight · Age · Sex
- An "Edit" button opens the per-field inline editing flow
- Note reads: *"Changing these will update your Health Profile and recalculate your targets."*

**Step 1 — What's your goal?**
- Three large option cards: **Lose weight** · **Maintain weight** · **Gain weight**
- Each card includes a one-line explanation (e.g. "You'll eat below your burn rate")
- Selection stored in wizard state

**Step 2 — How fast?** (skipped if Maintain)
- Two cards: **Steady** (±250 kcal/day, ~0.25 kg/week) · **Aggressive** (±500 kcal/day, ~0.5 kg/week)
- Subtitle: *"Steady is more sustainable and easier to maintain long-term."*

**Step 3 — How active are you?**
- Five option cards matching `ActivityLevel` enum values
- Descriptions: Sedentary · Lightly active (1–3 days/week) · Moderately active (3–5 days/week) · Very active (6–7 days/week) · Extra active (physical job)

**Step 4 — Macro review** (see Section 3)

**Navigation:**
- Back button on each step returns to the previous step (pop within wizard state, not the route)
- Progress bar at top shows position (filled segments = completed steps)
- Tapping the X dismisses the entire wizard

---

## 3. Macro Review Screen — Recommended Ranges + Deviation Warning

### Layout (top to bottom)

**Calorie hero card:**
- Large display of calculated daily calorie target (e.g. "1,850 kcal/day")
- Subtitle: "Based on your profile · Losing weight (−250 kcal/day)"

**Recommended preset card (from design option B):**
- Green border + "RECOMMENDED FOR YOUR GOAL" badge when all macros are in range
- Shows the three optimal gram values and percentages side-by-side
- Footer: "Standard sports nutrition · optimised for [goal]"
- **When any macro is outside range:** card border and badge turn orange, badge reads "OUTSIDE RECOMMENDED RANGE", body shows a plain-language explanation. The recommended values remain visible below it.

**"Adjust your split" section label**

**Per-macro slider rows (from design option A):**
- Each row: colour dot + name, gram value, percentage badge (green ✓ or orange ⚠)
- Slider track with a green band marking the recommended range
- Vertical tick marks at the range boundaries
- Slider thumb: macro colour when in range, orange when outside
- Below track: range label (e.g. "optimal 25–35%") in green
- Out-of-range rows show a small inline note (e.g. "Above recommended range")

**"Reset to recommended split" link:** appears only when any macro is outside range. Snaps all sliders back to the calculated optimal values instantly.

**Save Goals button:** always active — user is never blocked from saving their custom split.

### Recommended ranges by goal

| Goal | Protein | Carbs | Fat |
|------|---------|-------|-----|
| Lose weight | 30–40% | 35–45% | 20–30% |
| Maintain | 25–35% | 40–50% | 25–35% |
| Gain weight | 30–40% | 40–50% | 20–30% |

*Higher protein range for weight loss/gain supports muscle retention. Carbs flex up for maintenance.*

### Calculation

Calorie budget → macro grams (default/recommended):
- Protein (g) = `(calories × proteinPct) / 4`
- Carbs (g) = `(calories × carbsPct) / 4`
- Fat (g) = `(calories × fatPct) / 9`

Default percentages use the midpoint of the recommended range for the selected goal.

---

## 4. Fix the Save Error

### Root causes (three bugs)

**Bug 1 — Wrong goal type slugs sent to backend:**  
Macro goals are saved as `GoalType.custom` with human-readable title strings (`"daily_protein_min"` etc.). The backend accepts `custom` as a valid type, so the API call succeeds, but the app reads them back looking for specific enum types that don't exist — all macro values are silently lost on load.

**Bug 2 — Missing enum values in Flutter:**  
`GoalType` in `progress_models.dart` is missing `dailyProteinMin`, `dailyCarbsMax`, `dailyFatMax`, `dailyFiberMin`, `dailySodiumMax`, `dailySugarMax`. The commented-out lines in `NutritionGoals.fromGoalList()` are waiting for these. The backend already accepts these type slugs (`daily_protein_min`, `daily_carbs_max`, etc.) — Flutter just needs to catch up.

**Bug 3 — Edit sheet creates duplicates on every save:**  
`NutritionGoalsEditSheet._save()` always calls `createGoal()`, never checks for an existing goal of that type. Every save stacks a new duplicate record. The provider uses `.firstOrNull` so the UI doesn't visibly break, but orphaned records accumulate.

### Fixes

1. Add to `GoalType` enum in `progress_models.dart`:
   ```
   dailyProteinMin → "daily_protein_min"
   dailyCarbsMax   → "daily_carbs_max"
   dailyFatMax     → "daily_fat_max"
   dailyFiberMin   → "daily_fiber_min"
   dailySodiumMax  → "daily_sodium_max"
   dailySugarMax   → "daily_sugar_max"
   ```
   Each value's serialised string must match exactly the backend's `VALID_TYPES`.

2. Uncomment the six blocked lines in `NutritionGoals.fromGoalList()` once the enum values exist.

3. Replace the save logic in both the new wizard and the edit sheet with a **clean-slate approach**: delete all existing nutrition goal types for the user first, then create fresh ones. This is atomic, eliminates duplicates, and removes the need to track individual goal IDs.

4. Add a `DELETE /api/v1/goals/nutrition` endpoint on the backend that sets `is_active = False` on all goals whose `type` is in `{daily_calorie_limit, daily_protein_min, daily_carbs_max, daily_fat_max, daily_fiber_min, daily_sodium_max, daily_sugar_max}` for the authenticated user. Returns `204 No Content`. Rate-limited at 10/minute.

---

## 5. Data Flow

```
Wizard opens
  └─ Read profile (height, weight, birthday→age, gender)
  └─ Missing fields → ask inline → PATCH /api/v1/users/me/profile

Wizard step 4 reached (Calculate)
  └─ TdeeCalculator.calculate(height, weight, age, sex, activityLevel, weightGoal)
      └─ Mifflin-St Jeor BMR × activity multiplier ± goal adjustment
  └─ Recommended macros = calorieBudget × goal-specific pct / kcal-factor

Save Goals tapped
  └─ DELETE /api/v1/goals/nutrition  (clean slate)
  └─ POST /api/v1/goals × 4:
       daily_calorie_limit · daily_protein_min · daily_carbs_max · daily_fat_max
  └─ Invalidate nutritionGoalsProvider + goalsProvider
  └─ Navigate to nutrition home
```

---

## 6. Out of Scope

- Fiber, sodium, sugar goal fields — they exist in the edit sheet already and are not touched by this redesign
- The onboarding chat flow — body stats captured there should already save to the profile; this redesign only ensures the nutrition wizard reads from it
- Calorie calculation moving to the backend — stays client-side (Mifflin-St Jeor is deterministic, no server needed)
- The `NutritionGoalsEditSheet` full redesign — Bug 3 (duplicate saves) is fixed, but the edit sheet layout is not redesigned as part of this spec

---

## Files Affected

### Backend
| File | Change |
|------|--------|
| `cloud-brain/app/models/user.py` | Add `weight_kg` column |
| `cloud-brain/alembic/versions/` | New migration for `weight_kg` |
| `cloud-brain/app/api/v1/user_schemas.py` | Add `weight_kg` to request + response |
| `cloud-brain/app/api/v1/user_routes.py` | Handle `weight_kg` in PATCH profile |
| `cloud-brain/app/api/v1/goal_routes.py` | Add DELETE nutrition goals endpoint |

### Flutter
| File | Change |
|------|--------|
| `zuralog/lib/features/auth/domain/user_profile.dart` | Add `weightKg` field |
| `zuralog/lib/features/auth/data/auth_repository.dart` | Add `weightKg` to `updateProfile()` |
| `zuralog/lib/features/settings/presentation/edit_profile_screen.dart` | Add Weight tile + `_WeightPickerSheet` |
| `zuralog/lib/features/progress/domain/progress_models.dart` | Add 6 new `GoalType` enum values |
| `zuralog/lib/features/nutrition/domain/nutrition_goals_model.dart` | Uncomment 6 `fromGoalList` reads |
| `zuralog/lib/features/nutrition/domain/tdee_calculator.dart` | No changes needed |
| `zuralog/lib/features/nutrition/presentation/nutrition_goals_setup_sheet.dart` | Replace with new full-screen wizard |
| `zuralog/lib/features/nutrition/presentation/nutrition_goals_wizard.dart` | New file — full-screen wizard |
| `zuralog/lib/features/nutrition/presentation/nutrition_macro_review_screen.dart` | Redesigned A+B macro review |
| `zuralog/lib/features/nutrition/presentation/nutrition_goals_edit_sheet.dart` | Fix duplicate-create bug |
| `zuralog/lib/core/router/app_router.dart` | Add `/nutrition/goals/setup` route |
| `zuralog/lib/core/router/route_names.dart` | Add `nutritionGoalsSetup` constant |

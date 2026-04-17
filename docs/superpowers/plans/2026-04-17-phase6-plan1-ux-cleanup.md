# Phase 6 — Plan 1: UX Cleanup Pass

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** Fix two rough edges in the guided logging flow. Move the walkthrough's Back / Skip / Next buttons into the same centered stack as the question card so the thumb doesn't have to reach the bottom of the phone, and give every editable macro field a persistent label above it and a visible soft outline even when it isn't focused.

**Architecture:** Purely presentational — no new providers, routes, or backend work. One shared widget is added to the component library (`ZLabeledNumberField`) because the same labeled-field pattern is used across two screens (Meal Edit and Meal Review inline edit), putting it past the "used on 2+ screens" bar. The walkthrough layout change is a local rewrite of the `Scaffold` body in `meal_walkthrough_screen.dart` — no state or logic changes. All state stays local, so no rebuild spirals.

**Tech Stack:** Flutter 3.19+, no new packages.

**Depends on:** Phase 5A (backend Guided questions) and Phase 5B (Flutter walkthrough screen) — both must be shipped and merged before starting this plan.

---

## Files touched

| File | Changes |
|------|---------|
| `lib/shared/widgets/inputs/z_labeled_number_field.dart` | New file — labeled numeric field with persistent label and unfocused outline |
| `lib/shared/widgets/widgets.dart` | Add export for the new field |
| `lib/features/nutrition/presentation/meal_walkthrough_screen.dart` | Re-anchor the button Row into the centered question stack |
| `lib/features/nutrition/presentation/meal_edit_screen.dart` | Swap the four macro `AppTextField`s for `ZLabeledNumberField` |
| `lib/features/nutrition/presentation/meal_review_screen.dart` | Swap inline-edit macro `AppTextField`s for `ZLabeledNumberField` |

All paths relative to `zuralog/`.

---

## Task 1: Re-anchor the walkthrough buttons under the question card

**File:** `zuralog/lib/features/nutrition/presentation/meal_walkthrough_screen.dart`

Current structure (see `build` around line 188): `Scaffold > SafeArea > Column([topBar, Expanded(PageView), bottomBar])`. The question card itself is inside each PageView page wrapped in `Center`, so it floats in the middle. The `_buildBottomBar` Row with Back / Skip / Next sits pinned to the bottom. The user has to stretch their thumb from the card down to the bottom of the phone.

Target structure: the buttons travel with the card inside the same centered stack. The progress bar stays at the top (it needs to stay visible while scrolling long questions), the button Row moves into each question page just below the card.

- [ ] **Step 1.1** Extract the existing `_buildBottomBar(colors, isFirst, isLast)` contents into a helper that returns the raw Row widget (no outer Padding). Keep the original method name but have it return only the button Row plus its top spacer — no bottom safe-area padding, since it is no longer pinned to the bottom of the Scaffold.

- [ ] **Step 1.2** In `_buildQuestionPage`, append the button Row as a second child of the inner `Column` that currently contains `ZuralogCard`. The `Center` widget stays; the `Column` inside it gains one more child with `SizedBox(height: AppDimens.spaceLg)` between the card and the buttons. Pass `isFirst` and `isLast` into `_buildQuestionPage` so it can render the right button states (this is already derivable from `_currentIndex`).

- [ ] **Step 1.3** Remove the `_buildBottomBar` call from the outer `Scaffold > Column` tree. The outer Column now holds just `[topBar, Expanded(PageView)]`. This frees the PageView to fill the remaining space so the card + buttons stay vertically centered.

- [ ] **Step 1.4** Keep the safe-area bottom inset intact — wrap the PageView's `SingleChildScrollView` padding with `MediaQuery.of(context).padding.bottom + AppDimens.spaceLg` at the bottom so the buttons never sit under the home indicator on devices that have one.

- [ ] **Step 1.5** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 1.6** Commit: `fix(nutrition): move walkthrough buttons into the centered card stack`

**Verification:** Launch the app on an emulator. Log a meal via Describe ("scrambled eggs with rice"), Guided mode. When the first walkthrough question appears, Back / Skip / Next should sit directly under the question card, not at the bottom of the phone. Rotate to landscape — the buttons should still sit under the card. Scroll a long question (try a long free-text prompt) — the buttons should scroll with the card, not stay pinned. Skip all should still work.

---

## Task 2: Build the shared `ZLabeledNumberField`

Decision: **new shared widget**. The labeled-number pattern is about to be used on the Meal Edit screen (5 fields: calories + protein + carbs + fat + serving-size-if-present) and on the Meal Review inline-edit form (4 macro fields). That's already 2 screens and 9 occurrences, well past the reuse bar. One-off treatment would duplicate ~40 lines of field setup twice and drift on its own. Library it is.

**File:** `zuralog/lib/shared/widgets/inputs/z_labeled_number_field.dart` (new)

- [ ] **Step 2.1** Create the widget as a `StatelessWidget` that wraps a `Column(crossAxisAlignment: start)` with:
  - A `Text` label drawn in `AppTextStyles.labelMedium` using `colors.textSecondary`
  - A `SizedBox(height: AppDimens.spaceXxs)` gap
  - A `TextFormField` configured for numeric input

  Parameters: `label` (String, required), `controller` (TextEditingController, required), `unit` (String?, optional — e.g. `"g"`), `allowDecimal` (bool, default true), `textInputAction` (TextInputAction?), `onChanged` (ValueChanged<String>?), `focusNode` (FocusNode?).

- [ ] **Step 2.2** Wire the `TextFormField`'s `decoration` with an explicit `OutlineInputBorder` on both `border` and `enabledBorder`, using `colors.border` at width 1 and `AppDimens.shapeSm` radius. `focusedBorder` uses `AppColors.categoryNutrition` at width 1.5 so focus is visibly different. Add `contentPadding` of `EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceSm)` so the field does not look cramped.

- [ ] **Step 2.3** When `unit` is not null, set `suffixText: unit` on the `InputDecoration` and style it via `suffixStyle: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary)`. This gives the user the "g" / "kcal" affordance inline without stealing horizontal space.

- [ ] **Step 2.4** `inputFormatters`: if `allowDecimal`, use `FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))`; else `FilteringTextInputFormatter.digitsOnly`. `keyboardType` picks the matching `TextInputType.numberWithOptions(decimal: allowDecimal)`.

- [ ] **Step 2.5** Export the new widget from the barrel. Add to `lib/shared/widgets/widgets.dart` in the inputs block (alphabetical order): `export 'inputs/z_labeled_number_field.dart';`

- [ ] **Step 2.6** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 2.7** Commit: `feat(widgets): add ZLabeledNumberField with persistent label and unfocused outline`

**Verification:** Build the app. Open the component showcase if it picks up the export automatically; otherwise, wait for Task 3 verification.

---

## Task 3: Adopt `ZLabeledNumberField` across the meal edit flow

**Files:**
- `zuralog/lib/features/nutrition/presentation/meal_edit_screen.dart`
- `zuralog/lib/features/nutrition/presentation/meal_review_screen.dart`

- [ ] **Step 3.1** In `meal_edit_screen.dart > _FoodEditCard.build`, replace the four `AppTextField` instances for `calories` / `protein` / `carbs` / `fat` with `ZLabeledNumberField`. Labels: `"Calories"` (unit `"kcal"`, `allowDecimal: false`), `"Protein"` (unit `"g"`), `"Carbs"` (unit `"g"`), `"Fat"` (unit `"g"`). Keep the existing `TextInputAction.next` / `TextInputAction.done` chain.

- [ ] **Step 3.2** Still in `_FoodEditCard.build`, if the food entry has a visible serving-size/serving-unit row (check the current widget tree — today the screen does not have one, but if Stage 2's attribution adds a portion field later, apply the same field treatment). For this plan, leave the food-name field as the existing `AppTextField` (it is a free-text field, not numeric) — `ZLabeledNumberField` is numeric-only.

- [ ] **Step 3.3** In `meal_review_screen.dart > _buildInlineEditForm` (around line 940), replace the four macro `AppTextField` widgets (they currently use `hintText: 'P (g)'` / `'C (g)'` / `'F (g)'` and `hintText: 'Calories (kcal)'`) with `ZLabeledNumberField` using the same label + unit pairs as Step 3.1. The food-name `AppTextField` stays unchanged.

- [ ] **Step 3.4** Remove the now-unused `hintText` strings and the single-letter macro abbreviations — the visible label makes them unnecessary. The existing `_InlineEditControllers` class does not change.

- [ ] **Step 3.5** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 3.6** Commit: `feat(nutrition): use ZLabeledNumberField for all macro inputs in meal edit flow`

**Verification:**
1. Launch on emulator. Log a meal via Describe in Guided mode.
2. On Meal Review, tap the edit pencil on the first food card. Each macro field should show its label ("Calories", "Protein", "Carbs", "Fat") above the field and a visible grey outline even before tapping. The unit ("kcal" / "g") should sit inside the field on the right.
3. Tap into a field — the outline should switch to the amber nutrition color and thicken slightly.
4. Save the meal and open it from Nutrition Home. Tap Edit on Meal Detail. Every macro field on the Meal Edit screen should render the same way.
5. Log a meal in Quick mode — the walkthrough should not appear (already the case, verifying no regression).
6. Log a meal via Manual entry — no walkthrough, no Meal Review (already the case, verifying no regression).

---

## Definition of done

- [ ] `ZLabeledNumberField` exists under `lib/shared/widgets/inputs/` and is exported from `widgets.dart`
- [ ] Field shows a text label above it at all times (not a floating Material label)
- [ ] Field shows a visible soft outline when unfocused and a thicker amber outline when focused
- [ ] Optional unit suffix renders inside the field on the right (`"g"`, `"kcal"`)
- [ ] Meal Edit screen uses `ZLabeledNumberField` for calories, protein, carbs, fat on every food row
- [ ] Meal Review inline-edit form uses `ZLabeledNumberField` for the same four macros
- [ ] Walkthrough: Back / Skip / Next Row sits immediately under the question card, not at the bottom of the phone
- [ ] Walkthrough still respects the device's bottom safe-area inset
- [ ] `flutter analyze` is clean
- [ ] `flutter build apk --debug` succeeds
- [ ] Quick-mode logging still works end to end (no walkthrough appears)
- [ ] Manual-entry logging still bypasses the walkthrough and Meal Review

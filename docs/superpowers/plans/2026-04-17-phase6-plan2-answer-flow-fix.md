# Phase 6 — Plan 2: Answer-Flow Fix with Attribution Badges

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** Make the walkthrough's answers actually change the meal. Today the AI asks smart follow-up questions, the user answers them, and the answers get silently thrown away. This plan fixes that. The initial parse response will ship a small *adjustment recipe* (`on_answer`) for every possible answer to every question, the Flutter app will apply that recipe instantly when the user taps an answer, and a new violet "From your answer" badge will show on any food line that came from the walkthrough. No extra AI call, no loading spinner, no network round trip.

**Architecture:** Single-LLM-call design. The backend embeds a deterministic per-answer operation inside each `GuidedQuestion`. Four operation types cover everything the walkthrough emits today — `add_food`, `scale_food`, `replace_food`, `no_op`. Flutter applies the op locally against its working food list. Every food gets an optional `origin` (`"user"` or `"from_answer"`) plus `source_question_id` and `source_answer_value` fields so the UI can show attribution and so Stage 4 (rule suggestions) can mine the repetition signal later. The violet "From your answer" badge is a new shared widget that lives next to the amber rules badge in the exact same card slot — same structure, different color, different copy. The LLM payload is treated as untrusted: every op, every food, every numeric value is validated and clamped on both sides of the wire.

**Tech Stack:** Flutter 3.19+, Pydantic v2 on FastAPI. No new packages on either side.

**Depends on:** Phase 5A (backend Guided questions), Phase 5B (Flutter walkthrough screen), and Phase 6 Plan 1 (UX cleanup) — all three must be shipped and merged before starting this plan. No database schema changes are required, so the `db` subagent does not need to be invoked.

**Scale / payload note:** Adding `on_answer` roughly doubles the size of the `questions` array in the parse response. Today that array is typically 3–8 questions and ~1 KB; after this plan it will be ~2–3 KB. That is well under any real concern at 1M users, but it is worth flagging because the payload grows with the number of possible answers per question.

---

## Files touched

| File | Changes |
|------|---------|
| `cloud-brain/app/api/v1/nutrition_schemas.py` | Add `OnAnswerOp` union and extend `GuidedQuestion` with `on_answer`. Extend `ParsedFoodItem` with `origin` / `source_question_id` / `source_answer_value`. |
| `cloud-brain/app/api/v1/nutrition_routes.py` | Update `_MEAL_PARSE_SYSTEM_PROMPT` and `_IMAGE_SCAN_SYSTEM_PROMPT` — remove the "do not add foods" rule, add the `on_answer` contract section. |
| `cloud-brain/tests/api/test_nutrition_parse.py` (or equivalent) | Add tests for the new schema fields and one round-trip test that verifies a yes_no with `add_food` parses cleanly. |
| `zuralog/lib/features/nutrition/domain/guided_question.dart` | Extend `GuidedQuestion` with `onAnswer`. Add `OnAnswerOp` sealed class (`AddFoodOp`, `ScaleFoodOp`, `ReplaceFoodOp`, `NoOp`) and a factory that parses the op map defensively. |
| `zuralog/lib/features/nutrition/domain/nutrition_models.dart` | Extend `ParsedFoodItem` with `origin`, `sourceQuestionId`, `sourceAnswerValue`. Update `fromJson` / `toJson` / `copyWith`. |
| `zuralog/lib/features/nutrition/presentation/meal_review_screen.dart` | Rewrite `_applyWalkthroughAnswers` to read `on_answer` and execute the op. Wire the new badge into each food card when `origin == "from_answer"`. |
| `zuralog/lib/shared/widgets/nutrition/z_answer_origin_badge.dart` | New shared widget — violet pill with tap handler that opens a bottom sheet. |
| `zuralog/lib/shared/widgets/widgets.dart` | Export the new badge widget. |

All Flutter paths relative to `zuralog/`. All backend paths relative to `cloud-brain/`.

---

## Task 1: Extend the `GuidedQuestion` Pydantic schema with `on_answer`

**File:** `cloud-brain/app/api/v1/nutrition_schemas.py`

- [ ] **Step 1.1** Add a new `OnAnswerFood` model that mirrors `ParsedFoodItem` but only carries the fields needed for an `add_food` or `replace_food` op: `food_name`, `portion_amount`, `portion_unit`, `calories`, `protein_g`, `carbs_g`, `fat_g`. Reuse the same clamping validators (`clamp_calories`, `clamp_macros`, `truncate_food_name`) so untrusted LLM values cannot exceed sane bounds.

- [ ] **Step 1.2** Add four discriminated models: `AddFoodOp(op: Literal["add_food"], food: OnAnswerFood)`, `ScaleFoodOp(op: Literal["scale_food"], factor: float)` with `factor` clamped to `[0.1, 10.0]`, `ReplaceFoodOp(op: Literal["replace_food"], food: OnAnswerFood)`, and `NoOp(op: Literal["no_op"])`. Union them under `OnAnswerOp = AddFoodOp | ScaleFoodOp | ReplaceFoodOp | NoOp` using Pydantic's discriminated union with `Field(discriminator="op")`.

- [ ] **Step 1.3** Extend `GuidedQuestion` with `on_answer: dict[str, OnAnswerOp] | None = None`. The keys are answer values as strings (`"yes"`, `"no"`, `"Scrambled"`, `"Small 100g"`, a numeric slider value rendered as a string, etc.). Add a `@field_validator("on_answer")` that (a) caps the map size at 10 entries to prevent payload abuse and (b) caps each key at 50 characters.

- [ ] **Step 1.4** Run: `cd c:/Projects/Zuralog/cloud-brain && uv run pytest tests/api/test_nutrition_parse.py -q` to confirm existing tests still pass. If the file does not exist yet, look for any existing parse test (grep `MealParseResponse` in `tests/`).

- [ ] **Step 1.5** Commit: `feat(nutrition): add on_answer adjustment recipe to GuidedQuestion schema`

**Verification:** Construct a `GuidedQuestion` instance in a Python shell (`uv run python`) with an `on_answer` dict containing one `yes_no` → `add_food` recipe. Dump to JSON via `.model_dump()` — confirm the structure matches the shape shown in the Stage 2 design doc. Try to pass a `factor` of `99.9` to `ScaleFoodOp` — confirm it clamps to `10.0`. Try to pass an `on_answer` dict with 50 keys — confirm it rejects with a validation error.

---

## Task 2: Extend `ParsedFoodItem` with attribution fields

**File:** `cloud-brain/app/api/v1/nutrition_schemas.py`

- [ ] **Step 2.1** Add three optional fields to `ParsedFoodItem`, all defaulted so older LLM responses still parse:
  - `origin: Literal["user", "from_answer"] = "user"`
  - `source_question_id: str | None = None`
  - `source_answer_value: str | None = None`

- [ ] **Step 2.2** Add `@field_validator` on `source_question_id` and `source_answer_value` to strip whitespace and truncate to 50 characters. This is pure defence against a hostile LLM response — these strings are round-tripped to the client and eventually to the database via Stage 4, so they must be bounded.

- [ ] **Step 2.3** Confirm the existing `MealParseResponse` picks up the change automatically (it does — `foods: list[ParsedFoodItem]`).

- [ ] **Step 2.4** Run: `cd c:/Projects/Zuralog/cloud-brain && uv run pytest -q` and `uv run ruff check app/api/v1/nutrition_schemas.py`.

- [ ] **Step 2.5** Commit: `feat(nutrition): add origin and source attribution fields to ParsedFoodItem`

**Verification:** Round-trip a `ParsedFoodItem` missing the three new fields through `.model_validate(dict)` — confirm it parses and the defaults are `"user"` / `None` / `None`. This guarantees old parse responses still deserialize.

---

## Task 3: Update the backend parse and vision system prompts

**File:** `cloud-brain/app/api/v1/nutrition_routes.py`

- [ ] **Step 3.1** In `_MEAL_PARSE_SYSTEM_PROMPT`, **delete** rule 7 (`"Do not add foods that are not mentioned in the description."`). This rule was the original reason answers that implied a new food (like "yes, I used oil") were getting dropped — the model was forbidden from ever emitting oil. Renumber the remaining rules.

- [ ] **Step 3.2** In both `_MEAL_PARSE_SYSTEM_PROMPT` and `_IMAGE_SCAN_SYSTEM_PROMPT`, add a new top-level section titled `ON_ANSWER CONTRACT` below the existing `GUIDED MODE QUESTIONS` section. The section explains: for every question emitted in Guided mode, the model must also emit an `on_answer` map that maps each possible answer value to a deterministic operation. Document the four op types (`add_food`, `scale_food`, `replace_food`, `no_op`) with one concrete example each, using conservative nutrition estimates (e.g. 1 tsp cooking oil = 45 kcal / 5g fat). Include the full example JSON from the design doc verbatim so the model can see the exact shape.

- [ ] **Step 3.3** Add a sentence to the existing system-prompt rules: `"When you generate an on_answer for an add_food or replace_food op, use realistic and conservative nutrition estimates — never optimistic, never punitive."` This guards against the LLM inventing a 400-kcal pat of butter.

- [ ] **Step 3.4** Add a sentence: `"For slider, number_stepper, and size_picker questions, emit on_answer keys for the default value plus the min/max extremes; the client interpolates intermediate values via the scale_food op. For yes_no, emit 'yes' and 'no'. For button_group, emit one key per option. For free_text, emit a single 'default' key with no_op (Stage 3 will replace this with a needs_followup op)."`

- [ ] **Step 3.5** Run: `cd c:/Projects/Zuralog/cloud-brain && uv run ruff check app/api/v1/nutrition_routes.py`.

- [ ] **Step 3.6** Commit: `feat(nutrition): update parse/vision prompts with on_answer contract`

**Verification:** Hit `POST /api/v1/nutrition/meals/parse` against local dev with body `{"description": "scrambled eggs with rice", "mode": "guided"}`. Inspect the response. Every question in the `questions` array should now carry a non-null `on_answer` map with keys that match the question's possible answers. Sanity-check the nutrition numbers inside any `add_food` recipe against reality (cooking oil should be ~40–50 kcal per tsp, not 400).

---

## Task 4: Extend the Dart `GuidedQuestion` model with `onAnswer` and `OnAnswerOp`

**File:** `zuralog/lib/features/nutrition/domain/guided_question.dart`

- [ ] **Step 4.1** Add a sealed base class `OnAnswerOp` (Dart 3 sealed classes) with four subclasses: `AddFoodOp`, `ScaleFoodOp`, `ReplaceFoodOp`, `NoOpOp`. Each subclass is a small immutable data class:
  - `AddFoodOp({required OnAnswerFood food})`
  - `ScaleFoodOp({required double factor})`
  - `ReplaceFoodOp({required OnAnswerFood food})`
  - `NoOpOp()` (singleton via `const NoOpOp._(); static const instance = NoOpOp._();`)

- [ ] **Step 4.2** Add a lightweight `OnAnswerFood` class near the top of the file with the seven fields (`foodName`, `portionAmount`, `portionUnit`, `calories`, `proteinG`, `carbsG`, `fatG`) plus `fromJson` and a `toParsedFoodItem({required String sourceQuestionId, required String sourceAnswerValue})` method that returns a `ParsedFoodItem` with `origin: "from_answer"` and the source fields populated.

- [ ] **Step 4.3** Add a factory `OnAnswerOp.fromJson(Map<String, dynamic> json)` that dispatches on `json['op']`:
  - `"add_food"` → `AddFoodOp(food: OnAnswerFood.fromJson(json['food']))`
  - `"scale_food"` → `ScaleFoodOp(factor: ((json['factor'] as num?) ?? 1.0).toDouble().clamp(0.1, 10.0))`
  - `"replace_food"` → `ReplaceFoodOp(food: OnAnswerFood.fromJson(json['food']))`
  - `"no_op"` or anything unrecognised → `NoOpOp.instance`

  Defensive parsing — never throw on malformed LLM output, always fall through to `NoOpOp` so the walkthrough continues.

- [ ] **Step 4.4** Extend `GuidedQuestion` with `final Map<String, OnAnswerOp>? onAnswer;`. Update the constructor, add it to `fromJson` — iterate `json['on_answer']` as a `Map<String, dynamic>` and map each entry through `OnAnswerOp.fromJson`, skipping entries where the value is not a map.

- [ ] **Step 4.5** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 4.6** Commit: `feat(nutrition): add OnAnswerOp sealed hierarchy and wire into GuidedQuestion`

**Verification:** Add a unit test under `zuralog/test/features/nutrition/guided_question_test.dart` that parses the design-doc example JSON and asserts the `onAnswer["yes"]` is an `AddFoodOp` with `food.calories == 45`.

---

## Task 5: Extend the Dart `ParsedFoodItem` with attribution fields

**File:** `zuralog/lib/features/nutrition/domain/nutrition_models.dart`

- [ ] **Step 5.1** Add three fields to `ParsedFoodItem` with defaults: `final String origin` (default `'user'`), `final String? sourceQuestionId`, `final String? sourceAnswerValue`. Update the const constructor parameter list to include them as optional named parameters.

- [ ] **Step 5.2** Update `ParsedFoodItem.fromJson` to read `origin` / `source_question_id` / `source_answer_value` defensively — missing fields default to `'user'` / `null` / `null`.

- [ ] **Step 5.3** Update `ParsedFoodItem.toJson` to include the three new fields.

- [ ] **Step 5.4** Add a `copyWith` method that covers every field. The answer-flow mapping function will lean on this heavily when scaling or replacing foods.

- [ ] **Step 5.5** Update `toMealFood()` — no change needed; the three attribution fields do not flow into `MealFood` (they are parse-time only and are dropped once the meal is saved, which is fine for Plan 2; Stage 4 will persist them via a separate mechanism).

- [ ] **Step 5.6** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 5.7** Commit: `feat(nutrition): add origin and source fields to ParsedFoodItem`

**Verification:** Round-trip an old-shape `ParsedFoodItem` JSON (no `origin`) through `fromJson` + `toJson` — confirm `origin == 'user'` on the way out.

---

## Task 6: Rewrite `_applyWalkthroughAnswers` to execute `on_answer` ops

**File:** `zuralog/lib/features/nutrition/presentation/meal_review_screen.dart`

- [ ] **Step 6.1** Replace the entire body of `_applyWalkthroughAnswers` (around line 1164–1224). The new body iterates the answers map and, for each answer, looks up the matching `OnAnswerOp` via `question.onAnswer?[_answerKeyFor(answer)]`. If the op is null or `NoOpOp`, skip. Otherwise dispatch on the sealed type using a Dart `switch` expression (exhaustive).

- [ ] **Step 6.2** Implement `_answerKeyFor(Object answer)`: `bool` → `'yes'` / `'no'`, `num` → `.toString()` matching the JSON emitted by the backend, `String` → passthrough. Trim and clamp to 50 characters to mirror backend validation.

- [ ] **Step 6.3** Implement the four op branches against the screen's working `_parsedFoods` list (the `ParsedFoodItem` list — not `_mealFoods`, which is the downstream display list):
  - `AddFoodOp` → convert the embedded `OnAnswerFood` into a `ParsedFoodItem` via `toParsedFoodItem(sourceQuestionId: q.id, sourceAnswerValue: key)` and append to `_parsedFoods`.
  - `ScaleFoodOp` → locate `_parsedFoods[q.foodIndex]`; if it exists, replace it with `existing.copyWith(calories: existing.calories * op.factor, proteinG: existing.proteinG * op.factor, carbsG: existing.carbsG * op.factor, fatG: existing.fatG * op.factor, portionAmount: existing.portionAmount * op.factor)`. Do not change `origin` — a scaled user food is still a user food.
  - `ReplaceFoodOp` → same as `AddFoodOp`, but replace at `q.foodIndex` instead of appending. Tag with `origin: 'from_answer'` so the user can still unwind the change via the badge.
  - `NoOpOp` → no action.

- [ ] **Step 6.4** After the loop, rebuild `_mealFoods` from the updated `_parsedFoods` (the existing code already derives one from the other — find the single source of truth and reuse it). Call `setState(() {})` once at the end, not inside the loop.

- [ ] **Step 6.5** Delete the now-dead `_cookingMethods` and `_portionMultipliers` state if they were only used by the old heuristics. Keep them if the inline-edit UI still reads them (search the file first).

- [ ] **Step 6.6** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 6.7** Commit: `fix(nutrition): apply walkthrough answers via on_answer ops`

**Verification:** Hot-reload the app. Describe "scrambled eggs with rice" in Guided mode. Answer yes to the oil/butter question. In the Results phase, confirm a new food line "cooking oil" appears at the bottom of the list and the totals reflect ~40–50 extra kcal. Go back and answer no instead — confirm no oil line appears and totals do not bump.

---

## Task 7: Build the shared "From your answer" badge widget

**File:** `zuralog/lib/shared/widgets/nutrition/z_answer_origin_badge.dart` (new — create the `nutrition/` subdir if it does not exist)

- [ ] **Step 7.1** Build `ZAnswerOriginBadge` as a `StatelessWidget` that mirrors the structure of the existing amber "N rules applied" pill (see `meal_review_screen.dart` around lines 878–921) but uses `AppColors.categorySleep` (violet, `#5E5CE6`) as the accent color. The pill renders a small `Icon(Icons.question_answer_outlined)` on the left, the text `"From your answer"`, and an `Icons.chevron_right` on the right. Same padding, same radius (`AppDimens.shapeSm`), same alpha ramp (0.12 background, 0.30 border).

- [ ] **Step 7.2** Parameters: `onTap: VoidCallback` (opens the bottom sheet — the screen owns that logic, the badge is presentational only).

- [ ] **Step 7.3** Export from the barrel. Add to `lib/shared/widgets/widgets.dart` in alphabetical order under a new `nutrition/` block: `export 'nutrition/z_answer_origin_badge.dart';`.

- [ ] **Step 7.4** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 7.5** Commit: `feat(widgets): add ZAnswerOriginBadge violet pill for answer-origin foods`

**Verification:** No visual test yet — deferred to Task 9's full flow check.

---

## Task 8: Build the badge's bottom sheet with Remove + Change actions

**File:** `zuralog/lib/features/nutrition/presentation/meal_review_screen.dart`

- [ ] **Step 8.1** Add a new private method `_showAnswerOriginSheet(BuildContext context, ParsedFoodItem food)`. Mirror the structure of the existing `_showAppliedRulesSheet` method (same drag handle, same shape, same padding). Body contents:
  - Title: `"From your answer"`
  - Section 1: the question text — look up the question by `food.sourceQuestionId` in `_questions` (the screen already stores them). Prefix with a small label "Question".
  - Section 2: the user's answer — render `food.sourceAnswerValue` with a small "Your answer" label.
  - Section 3: contribution — `"Added ${food.calories.round()} kcal, ${food.proteinG.toStringAsFixed(1)}g protein, ${food.carbsG.toStringAsFixed(1)}g carbs, ${food.fatG.toStringAsFixed(1)}g fat"`.
  - Two full-width `ZButton`s stacked:
    1. Primary: "Remove this food" — destructive variant.
    2. Secondary: "Change my answer" — tertiary variant.

- [ ] **Step 8.2** Wire "Remove this food" to:
  1. Remove the food from `_parsedFoods` by identity (not index — indexes shift).
  2. If the original question was a `yes_no`, flip the recorded answer in `_walkthroughAnswers` from `true` to `false` (locked decision B from the design doc — matches user intuition: removing the oil means "I didn't use oil"). For other question types, just delete the answer entry so the user can re-answer next time.
  3. Call `setState` and `Navigator.pop` the sheet.

- [ ] **Step 8.3** Wire "Change my answer" to pop the sheet and push the walkthrough screen back in, pre-filled with the current `_walkthroughAnswers` map via `MealWalkthroughArgs.initialAnswers`. On return, re-run `_applyWalkthroughAnswers` against the original `_parsedFoods` snapshot (take a copy before applying ops so re-entry is idempotent).

- [ ] **Step 8.4** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 8.5** Commit: `feat(nutrition): add answer-origin bottom sheet with Remove and Change actions`

**Verification:** In the emulator, tap the violet badge on the cooking-oil line. Confirm the sheet shows the original question ("Did you use oil or butter?"), the answer ("yes"), and the contribution line. Tap Remove — the oil line disappears and the totals drop back to the uncooked-egg baseline. Re-open the walkthrough from scratch (log a new meal) and confirm the oil question now has "no" pre-selected when re-asked (snapshot of the flip).

---

## Task 9: Wire the badge into the Meal Review food card

**File:** `zuralog/lib/features/nutrition/presentation/meal_review_screen.dart`

- [ ] **Step 9.1** Locate the food-card builder (around line 878 where the rules badge is rendered today). Directly below the existing "N rules applied" pill block, add a sibling `if (parsedItem?.origin == 'from_answer') ...[ const SizedBox(height: AppDimens.spaceSm), ZAnswerOriginBadge(onTap: () => _showAnswerOriginSheet(context, parsedItem!)), ]`.

- [ ] **Step 9.2** Confirm both badges can render at the same time on the same card — if the AI ever returns a food where `applied_rules` is non-empty AND `origin == "from_answer"`, both pills stack with `AppDimens.spaceSm` between them. That combination is unlikely but the layout must not break.

- [ ] **Step 9.3** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze` and `flutter build apk --debug`.

- [ ] **Step 9.4** Commit: `feat(nutrition): wire ZAnswerOriginBadge into Meal Review food cards`

**Verification:** Log "scrambled eggs with rice" in Guided mode, answer yes to oil/butter. The oil food card should show the violet "From your answer" pill directly below its name. Log a meal with no such addition ("just an apple", Guided mode) — no violet pill anywhere.

---

## Task 10: End-to-end verification pass

- [ ] **Step 10.1** Manual smoke test — scenario A ("scrambled eggs with rice" + yes):
  1. Quick mode: confirm no walkthrough, no violet badges. Baseline numbers match today's behaviour.
  2. Switch to Guided. Log the same text. Answer yes to the oil/butter question. Confirm: (a) a "cooking oil" food appears, (b) it carries the violet pill, (c) totals are ~40–50 kcal above the Quick-mode baseline.

- [ ] **Step 10.2** Manual smoke test — scenario B ("scrambled eggs with rice" + no):
  1. Guided mode, answer no to the oil/butter question.
  2. Confirm no oil line, no violet pill, totals match Quick-mode baseline.

- [ ] **Step 10.3** Manual smoke test — scenario C (scale_food via portion slider):
  1. Log "half a cup of rice" in Guided mode.
  2. On a portion-size question, drag the slider up to the max value.
  3. Confirm the rice calories scale proportionally and no new food line is added (scale ≠ add).

- [ ] **Step 10.4** Manual smoke test — scenario D (remove + auto-flip):
  1. Redo scenario A.
  2. Tap the violet pill on the oil line → tap Remove.
  3. Confirm the oil line disappears, totals drop, and the recorded answer for that question is now `false` (inspect via debugger or log).

- [ ] **Step 10.5** Regression smoke — confirm the existing amber "N rules applied" pill still renders on foods where the AI used a user rule (e.g. with a "I always use oil spray" rule saved, log an egg dish and see the amber pill on the egg, not the violet one).

- [ ] **Step 10.6** Run the full backend test suite: `cd c:/Projects/Zuralog/cloud-brain && uv run pytest -q`.

- [ ] **Step 10.7** Run the Flutter test suite: `cd c:/Projects/Zuralog/zuralog && flutter test`.

- [ ] **Step 10.8** Commit any test fixture updates that fell out of the verification pass. Nothing to commit is fine.

---

## Definition of done

- [ ] Backend `GuidedQuestion` carries an optional `on_answer` map validated for size and key length
- [ ] Backend `ParsedFoodItem` carries optional `origin`, `source_question_id`, `source_answer_value` — all backwards-compatible
- [ ] Parse and vision system prompts no longer forbid adding foods that were not mentioned in the description
- [ ] Parse and vision system prompts document the `on_answer` contract with concrete examples
- [ ] Dart `GuidedQuestion` deserialises `on_answer` into a sealed `OnAnswerOp` hierarchy
- [ ] Dart `ParsedFoodItem` carries the three attribution fields with safe defaults
- [ ] `_applyWalkthroughAnswers` executes `add_food`, `scale_food`, `replace_food`, and `no_op` against the working food list
- [ ] Any food with `origin == "from_answer"` renders the violet `ZAnswerOriginBadge`
- [ ] Tapping the badge opens a bottom sheet showing the source question, the user's answer, and the contribution
- [ ] "Remove this food" deletes the food and flips a yes_no answer behind the scenes
- [ ] "Change my answer" reopens the walkthrough with prior answers preserved
- [ ] `ZAnswerOriginBadge` lives under `lib/shared/widgets/nutrition/` and is exported from the barrel
- [ ] `flutter analyze`, `flutter test`, and `flutter build apk --debug` all pass
- [ ] `uv run pytest -q` and `uv run ruff check` pass on the backend
- [ ] Quick-mode logging is unchanged end-to-end
- [ ] Manual-entry logging still bypasses the walkthrough and Meal Review
- [ ] End-to-end scenarios A–D all behave as specified

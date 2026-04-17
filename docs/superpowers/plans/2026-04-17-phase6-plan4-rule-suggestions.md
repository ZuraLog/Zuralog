# Phase 6 — Plan 4: Rule Suggestions (Feature 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** Stop nagging users with the same question every time they log the same meal. When the backend notices the user has given the same answer to the same follow-up question three times across their saved meals, the next parse response ships a plain-language suggested rule (e.g. *"I always use oil when cooking eggs"*). Flutter shows it as a small inline banner at the top of Meal Review — **after** the walkthrough ends, so it never interrupts the flow. Yes saves the rule via the existing Phase 3D rules system and suppresses that question forever. No snoozes the suggestion for 10 more occurrences.

**Architecture:** Detection runs server-side on every parse/refine/scan response so the client stays dumb. We need real persistence of the attribution fields that Plan 2 shipped on `ParsedFoodItem` — today `toMealFood()` drops `origin`, `source_question_id`, and `source_answer_value` on the floor, so there is no signal to mine. Plan 4 persists them on `meal_foods` (schema change via `db` subagent) and threads them through `POST /meals` and `PUT /meals/{id}`. A new `rule_suggestion_snooze` table tracks per-user dismissals with a decrementing counter. A detection service counts `(source_question_id, source_answer_value)` pairs across the user's non-deleted meals in the last 60 days and returns the single best candidate above threshold. Parse and refine responses gain an optional `suggested_rule` field. A `POST /meals/rule-suggestion/dismiss` endpoint upserts the snooze row. `POST /rules` takes optional `suppressed_question_id` + `suppressed_answer_value` so accepting a suggestion also clears its snooze.

**Tech Stack:** FastAPI + SQLAlchemy 2.0 + Alembic on the backend, Flutter 3.19+ on the client. No new packages.

**Depends on:** Phase 6 Plan 2 (attribution fields on `ParsedFoodItem`) and Plan 3 (refine endpoint) — both must ship and merge first. Phase 3D (nutrition rules CRUD) is live.

**Scale note (1M users):** Detection runs on every parse — hot path. We add a partial composite index on `meal_foods(source_question_id, source_answer_value, meal_id) WHERE source_question_id IS NOT NULL`; the join filters user via the existing `ix_meals_user_active`. Without the index a 60-day scan table-scans at scale; with it it is a bounded index range. `db` subagent to confirm the shape during migration review.

**Security note:** `suggested_rule` text is composed server-side from validated `(question_id, answer_value)` pairs via a hand-written template map — never a raw LLM string. Final text is clamped to 200 chars and stripped of newlines. Dismiss endpoint is rate-limited at 30/minute per user; the snooze table's unique constraint on `(user_id, question_id, answer_value)` prevents row bloat from repeated dismisses. All inputs capped at the same widths as Plan 2's existing `source_question_id`/`source_answer_value` validators (20 / 50 chars).

---

## Files touched

| File | Changes |
|------|---------|
| `cloud-brain/alembic/versions/<new>_add_meal_food_attribution_and_rule_snooze.py` | New Alembic migration: add `origin` / `source_question_id` / `source_answer_value` to `meal_foods`, create `rule_suggestion_snooze` table, add composite index. |
| `cloud-brain/app/models/meal_food.py` | Add three attribution columns to the ORM model. |
| `cloud-brain/app/models/rule_suggestion_snooze.py` (new) | ORM model for the new snooze table. |
| `cloud-brain/app/models/__init__.py` | Export the new model. |
| `cloud-brain/app/api/v1/nutrition_schemas.py` | Add `SuggestedRule` schema. Add `suggested_rule: SuggestedRule \| None` to `MealParseResponse` and `MealRefineResponse`. Add `RuleSuggestionDismissRequest`. Add three attribution fields to `FoodItemRequest`. |
| `cloud-brain/app/api/v1/nutrition_routes.py` | Persist attribution on create/update meal. Wire detection into parse and refine responses. Add `POST /meals/rule-suggestion/dismiss`. Extend `POST /rules` to clear matching snoozes. |
| `cloud-brain/app/services/rule_suggestion.py` (new) | Detection service: `detect_suggested_rule(db, user_id) -> SuggestedRule \| None`. |
| `cloud-brain/tests/api/test_rule_suggestions.py` (new) | Threshold, snooze, decrement, rate-limit tests. |
| `zuralog/lib/features/nutrition/domain/nutrition_models.dart` | Add `SuggestedRule` model. Add `suggestedRule` field to `MealParseResult` and `MealRefineResult`. |
| `zuralog/lib/features/nutrition/data/mock_nutrition_repository.dart` | Add `dismissRuleSuggestion` to the interface. Stub the mock. |
| `zuralog/lib/features/nutrition/data/api_nutrition_repository.dart` | Implement `dismissRuleSuggestion`. |
| `zuralog/lib/shared/widgets/nutrition/z_suggested_rule_banner.dart` (new) | Shared banner widget. |
| `zuralog/lib/shared/widgets/widgets.dart` | Export the new banner. |
| `zuralog/lib/features/nutrition/presentation/meal_review_screen.dart` | Carry `suggestedRule` from parse/refine into state. Render banner at top of "Here's what I found". Wire Yes/No handlers. |

All Flutter paths relative to `zuralog/`. All backend paths relative to `cloud-brain/`.

---

## Task 1: Database migration — add attribution columns and snooze table

**File:** `cloud-brain/alembic/versions/<new>_add_meal_food_attribution_and_rule_snooze.py`

> **Invoke the `db` subagent for this task.** Schema change on a hot table — confirm online-safety (add nullable, no backfill) and the final shape of the partial index for the Task 5 query.

- [ ] **Step 1.1** Generate a new Alembic revision named `add_meal_food_attribution_and_rule_snooze`. Parent: current head.

- [ ] **Step 1.2** `upgrade()` adds three nullable columns to `meal_foods`: `origin VARCHAR(20)`, `source_question_id VARCHAR(20)`, `source_answer_value VARCHAR(50)`. No backfill — historical meals stay untagged and never count.

- [ ] **Step 1.3** `upgrade()` creates a partial composite index `ix_meal_foods_attribution` on `(source_question_id, source_answer_value, meal_id) WHERE source_question_id IS NOT NULL`. The partial predicate keeps the index small — only tagged rows participate. User filtering lives on the `meals` join.

- [ ] **Step 1.4** `upgrade()` creates `rule_suggestion_snooze` with columns: `id UUID PK`, `user_id TEXT NOT NULL FK→users ON DELETE CASCADE`, `question_id VARCHAR(20) NOT NULL`, `answer_value VARCHAR(50) NOT NULL`, `occurrences_remaining INTEGER NOT NULL DEFAULT 10`, `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`. Unique constraint on `(user_id, question_id, answer_value)` — enforcement point for Task 8's upsert.

- [ ] **Step 1.5** `downgrade()` drops the table, the partial index, and the three columns in reverse order.

- [ ] **Step 1.6** Run `uv run alembic upgrade head`. Confirm upgrade + downgrade + upgrade all run cleanly. Commit via `git` subagent: `feat(nutrition): add meal_foods attribution columns and rule_suggestion_snooze table`

**Verification:** `psql` — `\d meal_foods` shows the new columns, `\d rule_suggestion_snooze` shows the unique constraint, `\di ix_meal_foods_attribution` shows the partial predicate.

---

## Task 2: Update `MealFood` and add `RuleSuggestionSnooze` ORM models

- [ ] **Step 2.1** In `cloud-brain/app/models/meal_food.py`, add three nullable mapped columns to `MealFood` matching the migration shapes. Doc-comment them as "Populated when the food was added via the guided walkthrough — mined by the rule-suggestion detector."

- [ ] **Step 2.2** Create `cloud-brain/app/models/rule_suggestion_snooze.py` with the `RuleSuggestionSnooze` model. Include `__table_args__ = (sa.UniqueConstraint("user_id", "question_id", "answer_value"),)`.

- [ ] **Step 2.3** Export `RuleSuggestionSnooze` from `cloud-brain/app/models/__init__.py`.

- [ ] **Step 2.4** Run `uv run ruff check && uv run pytest -q`. Commit: `feat(nutrition): add attribution columns to MealFood and RuleSuggestionSnooze model`

**Verification:** `uv run python -c "from app.models import MealFood, RuleSuggestionSnooze; print(MealFood.__table__.columns.keys())"` lists the new fields.

---

## Task 3: Extend `FoodItemRequest` and persist attribution on save

**Files:** `cloud-brain/app/api/v1/nutrition_schemas.py`, `cloud-brain/app/api/v1/nutrition_routes.py`

- [ ] **Step 3.1** Add three optional fields to `FoodItemRequest`: `origin: Literal["user", "from_answer"] | None`, `source_question_id: str | None`, `source_answer_value: str | None`. Add a `@field_validator` that strips whitespace and truncates to 20 / 50 chars — mirror Plan 2's validator on `ParsedFoodItem`. These values land in a hot index, so the caps matter.

- [ ] **Step 3.2** In `create_meal` (line 553) and `update_meal` (line 645), pass the three new fields when constructing each `MealFood`.

- [ ] **Step 3.3** Run: `uv run ruff check && uv run pytest -q`. Commit: `feat(nutrition): persist attribution fields on meal create and update`

**Verification:** POST a meal with a food carrying `{"origin": "from_answer", "source_question_id": "q_oil", "source_answer_value": "yes"}`. `psql` → fields round-trip.

---

## Task 4: Update Flutter `toMealFood` to forward attribution

**File:** `zuralog/lib/features/nutrition/domain/nutrition_models.dart`

- [ ] **Step 4.1** In `ParsedFoodItem.toMealFood()` (line 397 — today it drops attribution), forward all three fields into the new `MealFood`.

- [ ] **Step 4.2** Add `origin`, `sourceQuestionId`, `sourceAnswerValue` to the Dart `MealFood` class. `toJson` emits the snake_case keys only when non-null (keeps manual-entry payloads small). `fromJson` reads them defensively.

- [ ] **Step 4.3** Run: `flutter analyze`. Commit: `feat(nutrition): forward attribution fields from ParsedFoodItem through MealFood.toJson`

**Verification:** Log a Guided meal with an oil answer. The outgoing `POST /meals` payload carries the three fields on the oil line. Manual-entry meals do not.

---

## Task 5: Build the detection service

**File:** `cloud-brain/app/services/rule_suggestion.py` (new)

- [ ] **Step 5.1** Add `async def detect_suggested_rule(db: AsyncSession, user_id: str) -> SuggestedRule | None`. Flow: run one aggregate query over the user's tagged meal_foods from the last 60 days, then filter candidates against existing rules and active snoozes, return the first survivor.

- [ ] **Step 5.2** Aggregate query (final shape reviewed by `db` subagent):
  ```sql
  SELECT mf.source_question_id, mf.source_answer_value, COUNT(*) AS n
  FROM meal_foods mf JOIN meals m ON m.id = mf.meal_id
  WHERE m.user_id = :user_id AND m.deleted_at IS NULL
    AND m.logged_at >= now() - interval '60 days'
    AND mf.source_question_id IS NOT NULL
  GROUP BY mf.source_question_id, mf.source_answer_value
  HAVING COUNT(*) >= 3
  ORDER BY COUNT(*) DESC LIMIT 5;
  ```

- [ ] **Step 5.3** For each candidate: reject if any `NutritionRule` row for this user already contains both tokens (case-insensitive substring on `rule_text` — detection is advisory); reject if any `RuleSuggestionSnooze` row has `occurrences_remaining > 0`. Return the first survivor.

- [ ] **Step 5.4** Add `_build_rule_text(question_id, answer_value) -> str` with a hand-written template map keyed on `(question_id, answer_value)` for every question ID the parse prompt emits today. Fallback for unknown IDs: `"I always answer '{answer_value}' for this question"`. Final string stripped of newlines and clamped to 200 chars. (We do not store question text, so the template map is the source of truth for human-readable rules.)

- [ ] **Step 5.5** Skip the LRU cache optimisation the design doc flags — one indexed aggregate per parse is fine; profile before adding complexity.

- [ ] **Step 5.6** Run: `cd c:/Projects/Zuralog/cloud-brain && uv run ruff check app/services/rule_suggestion.py`

- [ ] **Step 5.7** Commit: `feat(nutrition): add rule-suggestion detection service with 60-day window`

**Verification:** Unit-test in Task 12. Manual-smoke in Task 14.

---

## Task 6: Add `SuggestedRule` and dismissal schemas

**File:** `cloud-brain/app/api/v1/nutrition_schemas.py`

- [ ] **Step 6.1** Add `SuggestedRule` with `rule_text: str` (1–200, strip + truncate validator), `question_id: str` (1–20), `answer_value: str` (1–50). Validators match Plan 2's `ParsedFoodItem` caps so nothing wider than 200 chars leaves the server.

- [ ] **Step 6.2** Add `suggested_rule: SuggestedRule | None = None` to `MealParseResponse` and `MealRefineResponse`.

- [ ] **Step 6.3** Add `RuleSuggestionDismissRequest` with `question_id` (1–20) and `answer_value` (1–50).

- [ ] **Step 6.4** Run `uv run ruff check && uv run pytest -q`. Commit: `feat(nutrition): add SuggestedRule and dismissal request schemas`

**Verification:** `SuggestedRule(rule_text="x" * 500, ...)` clamps to 200.

---

## Task 7: Wire detection into parse and refine responses

**File:** `cloud-brain/app/api/v1/nutrition_routes.py`

- [ ] **Step 7.1** Just before each of the final `return` statements in `parse_meal_description`, `refine_meal`, and `scan_food_image`, call `suggested = await detect_suggested_rule(db, user_id)` and pass it as `suggested_rule=suggested` into the response. One indexed aggregate per call — add it unconditionally. Camera-logged meals should surface suggestions the same way as text.

- [ ] **Step 7.2** Run: `uv run ruff check`. Commit: `feat(nutrition): include suggested_rule in parse, refine, and scan responses`

**Verification:** After three eggs-with-oil logs, the fourth parse response carries `suggested_rule`.

---

## Task 8: Add `POST /meals/rule-suggestion/dismiss` endpoint

**File:** `cloud-brain/app/api/v1/nutrition_routes.py`

- [ ] **Step 8.1** Add the endpoint below the rules CRUD block: `@limiter.limit("30/minute")`, `@router.post("/meals/rule-suggestion/dismiss", status_code=204)`, standard `request`/`body: RuleSuggestionDismissRequest`/`user_id`/`db` params.

- [ ] **Step 8.2** Body upserts via SQLAlchemy 2.0 `postgresql.insert(...).on_conflict_do_update(...)` on `(user_id, question_id, answer_value)`, setting `occurrences_remaining = 10` and `created_at = now()`. Return 204 with no body.

- [ ] **Step 8.3** Run: `uv run ruff check`. Commit: `feat(nutrition): add rule-suggestion dismiss endpoint`

**Verification:** `curl` the endpoint — row appears with `occurrences_remaining = 10`. Repeat `curl` — still one row, counter reset to 10.

---

## Task 9: Decrement snoozes on meal save; clear on rule accept

**File:** `cloud-brain/app/api/v1/nutrition_routes.py`

- [ ] **Step 9.1** In `create_meal`, after commit but before `recompute_nutrition_summary`, run one UPDATE decrementing every active snooze for this user: `UPDATE rule_suggestion_snooze SET occurrences_remaining = occurrences_remaining - 1 WHERE user_id = :user_id AND occurrences_remaining > 0;`. Counter never goes negative, so zero-rows naturally stop blocking detection.

- [ ] **Step 9.2** Extend `NutritionRuleCreate` with two optional fields: `suppressed_question_id: str | None = None` and `suppressed_answer_value: str | None = None`, validated like their counterparts in `RuleSuggestionDismissRequest`.

- [ ] **Step 9.3** In `create_rule` (around line 853), after the rule is committed, if both suppression fields are present, delete the matching `rule_suggestion_snooze` row. (We do not infer the pair from rule text — the client sends it explicitly. Keeps the server logic testable.)

- [ ] **Step 9.4** Run: `cd c:/Projects/Zuralog/cloud-brain && uv run ruff check && uv run pytest -q`

- [ ] **Step 9.5** Commit: `feat(nutrition): decrement snoozes on save and clear snooze on matching rule accept`

**Verification:** Create a snooze via dismiss. Log 10 meals. The 10th save drops the counter to 0; the next parse re-shows the suggestion. Separately: dismiss, then accept the rule with `suppressed_question_id` set — the snooze row disappears.

---

## Task 10: Flutter — add `SuggestedRule` domain model

**File:** `zuralog/lib/features/nutrition/domain/nutrition_models.dart`

- [ ] **Step 10.1** Add an immutable `SuggestedRule` class with `ruleText`, `questionId`, `answerValue`, plus defensive `fromJson` / `toJson`.

- [ ] **Step 10.2** Add `final SuggestedRule? suggestedRule;` to both `MealParseResult` and `MealRefineResult`. Each `fromJson` reads `json['suggested_rule']` defensively — missing or malformed → `null`, never throws.

- [ ] **Step 10.3** Run `flutter analyze`. Commit: `feat(nutrition): add SuggestedRule model and plumb through parse/refine results`

**Verification:** Unit test round-trips a fixture with `suggested_rule` through `fromJson`/`toJson` losslessly.

---

## Task 11: Flutter repository — `dismissRuleSuggestion` + `createRule` suppression

**Files:** `mock_nutrition_repository.dart`, `api_nutrition_repository.dart`

- [ ] **Step 11.1** Add to the interface: `Future<void> dismissRuleSuggestion({required String questionId, required String answerValue});`. Mock stubs throw `UnimplementedError`.

- [ ] **Step 11.2** API repo implements `dismissRuleSuggestion` as a `POST /api/v1/nutrition/meals/rule-suggestion/dismiss` with body `{question_id, answer_value}`.

- [ ] **Step 11.3** Extend `createRule` with optional `suppressedQuestionId` / `suppressedAnswerValue` named parameters, forwarded into the body as `suppressed_question_id` / `suppressed_answer_value` when non-null. Existing callers keep working.

- [ ] **Step 11.4** Run `flutter analyze`. Commit: `feat(nutrition): add dismissRuleSuggestion and optional rule suppression on createRule`

---

## Task 12: Backend tests

**File:** `cloud-brain/tests/api/test_rule_suggestions.py` (new)

- [ ] **Step 12.1** Skeleton mirrors `tests/api/test_nutrition_parse.py` — `@pytest.mark.asyncio`, existing `async_client` / `authenticated_user_id` fixtures.

- [ ] **Step 12.2** Tests to add:
  - `test_detection_threshold` — 2 tagged meals → `None`; 3rd → suggestion; 4th → still a suggestion.
  - `test_detection_respects_existing_rule` — 3 tagged meals + matching `NutritionRule` → `None`.
  - `test_detection_respects_snooze` — 3 tagged meals + active snooze → `None`.
  - `test_snooze_decrement_on_meal_save` — snooze → 10 saves → counter hits 0 → suggestion re-appears.
  - `test_dismiss_upsert_resets_counter` — dismiss → 10 → save → 9 → dismiss → back to 10.
  - `test_create_rule_clears_snooze_when_suppressed_pair_provided` — snooze + `POST /rules` with suppression fields → snooze gone.
  - `test_dismiss_rate_limited` — 31 hits in a minute → 429 on the 31st.
  - `test_dismiss_validates_input` — 100-char `question_id` → 422.

- [ ] **Step 12.3** Run: `cd c:/Projects/Zuralog/cloud-brain && uv run pytest tests/api/test_rule_suggestions.py -q`

- [ ] **Step 12.4** Commit: `test(nutrition): add rule-suggestion detection, snooze, and endpoint tests`

---

## Task 13: Build the shared `ZSuggestedRuleBanner` widget

**File:** `zuralog/lib/shared/widgets/nutrition/z_suggested_rule_banner.dart` (new)

- [ ] **Step 13.1** Build `ZSuggestedRuleBanner` as a `StatelessWidget` wrapping a `ZuralogCard` (feature variant) with `AppColors.categoryNutrition` accent — matches the existing amber rules-applied pill. Contents: `Icons.lightbulb_outline`, a "Suggested rule" eyebrow label in `AppTextStyles.labelSmall`, the rule text in `AppTextStyles.bodyMedium`, and two `ZButton`s — "Save rule" (primary) and "Not now" (tertiary). Stack side-by-side when width allows.

- [ ] **Step 13.2** Parameters: `String ruleText`, `VoidCallback onAccept`, `VoidCallback onDismiss`, `bool isSaving` (spinner inside the primary button).

- [ ] **Step 13.3** Export: add `export 'nutrition/z_suggested_rule_banner.dart';` to `lib/shared/widgets/widgets.dart` under the nutrition block.

- [ ] **Step 13.4** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 13.5** Commit: `feat(widgets): add ZSuggestedRuleBanner for save-as-rule prompt`

---

## Task 14: Wire the banner into Meal Review

**File:** `zuralog/lib/features/nutrition/presentation/meal_review_screen.dart`

Banner renders **after** the walkthrough ends (or immediately in Quick mode). Placement: above the "Here's what I found" section header in `_buildResultsPhase` (around line 725).

- [ ] **Step 14.1** Add state: `SuggestedRule? _suggestedRule;` and `bool _savingSuggestedRule = false;`.

- [ ] **Step 14.2** Populate `_suggestedRule` from the parse result in `_startAnalysis`. When Plan 3's refine returns with a newer `suggestedRule`, adopt it — later rounds override earlier suggestions.

- [ ] **Step 14.3** In `_buildResultsPhase`, inject `if (_suggestedRule != null) ZSuggestedRuleBanner(...)` above the food cards. Wire `onAccept` to `_handleAcceptSuggestedRule` and `onDismiss` to `_handleDismissSuggestedRule`; pass `isSaving: _savingSuggestedRule`.

- [ ] **Step 14.4** `_handleAcceptSuggestedRule`: set saving → call `repo.createRule(rule.ruleText, suppressedQuestionId: rule.questionId, suppressedAnswerValue: rule.answerValue)`. On success: `ZToast.success('Rule saved — we will stop asking.')`, clear banner. On error: `ZToast.error('Could not save rule. Try again.')`, clear saving flag, **keep** the banner so the user can retry.

- [ ] **Step 14.5** `_handleDismissSuggestedRule`: optimistically hide the banner, fire-and-forget `repo.dismissRuleSuggestion(...)` inside a try/catch — silent failure is fine because worst case the banner reappears next parse.

- [ ] **Step 14.6** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze && flutter build apk --debug`.

- [ ] **Step 14.7** Commit: `feat(nutrition): render suggested-rule banner in Meal Review and wire save/dismiss actions`

---

## Task 15: End-to-end verification pass

- [ ] **Step 15.1** Scenario A (happy path): Guided mode, log "scrambled eggs" three times answering yes to oil. 4th log — banner *"I always use oil when cooking eggs"* appears. Tap Save rule → toast. 5th log — oil question skipped, no banner.

- [ ] **Step 15.2** Scenario B (dismiss + re-surface): Tap Not now on the 4th log. Banner disappears. Log eggs 10 more times — the 11th surfaces the banner again.

- [ ] **Step 15.3** Scenario C (existing rule blocks): Dismiss. Manually add the same rule via Settings. Next eggs log — no banner (rule filter wins over snooze state).

- [ ] **Step 15.4** Scenario D (historical meals ignored): Back-date a `logged_at` beyond 60 days ago — not counted.

- [ ] **Step 15.5** Scenario E (Quick mode): Log in Quick after crossing the threshold — banner still renders. Detection is mode-agnostic.

- [ ] **Step 15.6** Scenario F (manual entry): Manual meal carries no attribution, never surfaces a banner.

- [ ] **Step 15.7** Run: `cd c:/Projects/Zuralog/cloud-brain && uv run pytest -q && uv run ruff check`

- [ ] **Step 15.8** Run: `cd c:/Projects/Zuralog/zuralog && flutter test && flutter analyze && flutter build apk --debug`.

---

## Definition of done

- [ ] `meal_foods` carries `origin`, `source_question_id`, `source_answer_value` — nullable, backfill-free, with partial composite index
- [ ] `rule_suggestion_snooze` table exists with unique constraint on `(user_id, question_id, answer_value)`
- [ ] `POST /meals` and `PUT /meals/{id}` persist attribution; Flutter `toMealFood` forwards all three fields
- [ ] `detect_suggested_rule` uses the indexed query, enforces 60-day window, filters existing rules + active snoozes
- [ ] `MealParseResponse`, `MealRefineResponse`, and scan-image response all carry an optional `suggested_rule`
- [ ] `POST /meals/rule-suggestion/dismiss` upserts at `occurrences_remaining = 10`, rate-limited 30/minute
- [ ] Meal save decrements every active snooze by 1; `POST /rules` with suppression fields deletes the matching snooze
- [ ] Backend tests pass: threshold (2/3/4), existing-rule skip, active-snooze skip, decrement-on-save, dismiss upsert, accept-clears-snooze, rate limit, input validation
- [ ] Flutter `SuggestedRule` model + `suggestedRule` fields on both results round-trip cleanly
- [ ] `ZSuggestedRuleBanner` exported from the nutrition block of the widget barrel and renders above "Here's what I found" when `suggestedRule != null`
- [ ] Save rule flow: `createRule(..., suppressedQuestionId, suppressedAnswerValue)` → success toast → banner hides; failure keeps banner for retry
- [ ] Not now flow: banner hides optimistically, `dismissRuleSuggestion` fires in the background
- [ ] `flutter analyze`, `flutter test`, `flutter build apk --debug`, `uv run pytest -q`, `uv run ruff check` all pass
- [ ] End-to-end scenarios A–F all behave as specified

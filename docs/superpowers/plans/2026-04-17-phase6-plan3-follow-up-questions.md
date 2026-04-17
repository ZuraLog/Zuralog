# Phase 6 — Plan 3: Follow-up Questions (Feature 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** Give the guided walkthrough a second wind. When the first round of questions isn't enough — because the user typed a free-text answer, or because the AI itself flagged an answer as too coarse ("yes, I used oil or butter" is still ambiguous) — the app quietly asks the backend for one more round. Up to 3 rounds total, then we commit whatever we have. Between rounds the user sees a clean "Asking one more thing…" transition card so it's obvious the app is doing extra work on their behalf.

**Architecture:** Plan 2 shipped the one-LLM-call design where every possible answer carries a deterministic recipe. Plan 3 is the escape hatch for cases those recipes can't cover. We add a fifth op — `needs_followup` — that tells the client "this answer needs a second AI round to resolve." Free-text answers always route through refine too, because open-ended sentences can't be mapped to a fixed recipe. A new backend endpoint `POST /api/v1/nutrition/meals/refine` takes the original parse plus the question-and-answer history, runs a second LLM call, and returns either (a) a final refined food list or (b) one more batch of follow-up questions. The server enforces a hard 3-round cap so a misbehaving client can't burn unbounded AI spend per meal. The walkthrough screen handles multiple rounds inside the same `PageView`, appending new questions as they arrive.

**Tech Stack:** Flutter 3.19+, Pydantic v2 on FastAPI. No new packages.

**Depends on:** Phase 6 Plan 1 and Plan 2 — both must ship and merge first. Plan 3 builds directly on Plan 2's `OnAnswerOp` hierarchy, the attribution fields on `ParsedFoodItem`, and the rewritten `_applyWalkthroughAnswers`. No database schema changes.

**Scale / cost note:** Refine fires a second LLM call per meal, but only when the model or the user's answer demands it — not on the hot path. Conservative estimate: 10–20% of guided meals trigger at least one refine round. At 1M meals/day that's 100k–200k extra calls, within our OpenRouter budget since we stay on the cheaper Qwen 3.5 Flash insight model. The 3-round cap bounds worst-case cost at 4 LLM calls per meal (1 parse + 3 refines), enforced server-side so a malicious client cannot force a fourth round.

**Security note:** Refine mirrors every defence `/meals/parse` has — same `10/minute` rate limit, same auth dependency, same `_call_llm_with_json_retry` wrapper, same structured Pydantic validation on every food and every op. All user-supplied strings (description, question text, answers) are passed through `sanitize_for_llm` before re-injection into the prompt. The round counter is validated server-side on every request.

---

## Files touched

| File | Changes |
|------|---------|
| `cloud-brain/app/api/v1/nutrition_schemas.py` | Add `NeedsFollowupOp` variant to the `OnAnswerOp` union. Add `MealRefineRequest` / `MealRefineResponse` schemas. |
| `cloud-brain/app/api/v1/nutrition_routes.py` | Thread `needs_followup` through `_MEAL_PARSE_SYSTEM_PROMPT` and `_IMAGE_SCAN_SYSTEM_PROMPT`. Add `_MEAL_REFINE_SYSTEM_PROMPT`. Add `POST /meals/refine` endpoint. |
| `cloud-brain/tests/api/test_nutrition_refine.py` (new) | Round-cap enforcement, schema round-trip, refine-with-free-text smoke test. |
| `zuralog/lib/features/nutrition/domain/guided_question.dart` | Extend `OnAnswerOp` sealed hierarchy with `NeedsFollowupOp`. Update the `fromJson` factory. |
| `zuralog/lib/features/nutrition/domain/nutrition_models.dart` | Add `MealRefineResult` result model (mirrors `MealParseResult` plus an `isFinal` flag). |
| `zuralog/lib/features/nutrition/data/mock_nutrition_repository.dart` | Add `refineMeal(...)` to the repository interface. Stub it in the mock. |
| `zuralog/lib/features/nutrition/data/api_nutrition_repository.dart` | Implement `refineMeal(...)` against `POST /api/v1/nutrition/meals/refine`. |
| `zuralog/lib/features/nutrition/presentation/meal_walkthrough_screen.dart` | Handle `needs_followup` ops and free-text answers. Append new questions across rounds. Enforce client-side 3-round cap. |
| `zuralog/lib/shared/widgets/nutrition/z_refine_transition_card.dart` (new) | "Asking one more thing…" transition card shown between rounds. |
| `zuralog/lib/shared/widgets/widgets.dart` | Export the new transition card. |
| `zuralog/lib/features/nutrition/presentation/meal_review_screen.dart` | Pass the repository into `MealWalkthroughArgs`. Accept the refined food list back from the walkthrough and render it instead of the pre-refine parse. |

All Flutter paths relative to `zuralog/`. All backend paths relative to `cloud-brain/`.

---

## Task 1: Add `NeedsFollowupOp` to the backend `OnAnswerOp` union

**File:** `cloud-brain/app/api/v1/nutrition_schemas.py`

- [ ] **Step 1.1** Add `NeedsFollowupOp(BaseModel)` below `NoOp` with `op: Literal["needs_followup"]` and optional `reason: str | None = None`. Add a `@field_validator` on `reason` that strips whitespace and caps at 200 characters. The field is advisory — it hints the refine prompt about what's still unclear — and is never shown to the user.

- [ ] **Step 1.2** Update the `OnAnswerOp` discriminated union to include `NeedsFollowupOp` in the `Union[...]`.

- [ ] **Step 1.3** Run: `cd c:/Projects/Zuralog/cloud-brain && uv run ruff check app/api/v1/nutrition_schemas.py`

- [ ] **Step 1.4** Commit: `feat(nutrition): add NeedsFollowupOp variant to OnAnswerOp union`

**Verification:** In `uv run python`, round-trip a `GuidedQuestion` with `on_answer={"yes": {"op": "needs_followup", "reason": "oil or butter?"}}` — confirm `.model_dump()` preserves both fields. Pass a 500-char reason — confirm it truncates to 200.

---

## Task 2: Add refine request and response schemas

**File:** `cloud-brain/app/api/v1/nutrition_schemas.py`

- [ ] **Step 2.1** Add `AnswerHistoryEntry(BaseModel)` with `question_id: str` (1–20 chars), `answer_value: str` (1–500 chars, trimmed via `@field_validator`), and `round: int` (1–3).

- [ ] **Step 2.2** Add `MealRefineRequest(BaseModel)` with:
  - `description: str` (1–500 chars) — original user input
  - `foods: list[ParsedFoodItem]` (1–50) — current food list
  - `questions_history: list[GuidedQuestion]` (1–30) — every question asked so far
  - `answers_history: list[AnswerHistoryEntry]` (1–30) — every answer given so far
  - `round: int` (1–3) — which refine round this is

- [ ] **Step 2.3** Add `MealRefineResponse(BaseModel)` with `foods: list[ParsedFoodItem]`, `questions: list[GuidedQuestion]` (default empty), `is_final: bool`, and `rounds_remaining: int` (0–2). Any new food the refine added should carry `origin: "from_answer"` and the correct source attribution.

- [ ] **Step 2.4** Run: `cd c:/Projects/Zuralog/cloud-brain && uv run ruff check app/api/v1/nutrition_schemas.py && uv run pytest -q`

- [ ] **Step 2.5** Commit: `feat(nutrition): add MealRefineRequest and MealRefineResponse schemas`

**Verification:** In `uv run python`, build a `MealRefineRequest` with a 40-entry `answers_history` — confirm it rejects (cap 30). Build a `MealRefineResponse` with `rounds_remaining=5` — confirm rejection (max 2).

---

## Task 3: Update parse prompts to emit `needs_followup`

**File:** `cloud-brain/app/api/v1/nutrition_routes.py`

- [ ] **Step 3.1** In `_MEAL_PARSE_SYSTEM_PROMPT`, under the "Four operations are supported" section, add a fifth entry describing `needs_followup`: use it when an answer is ambiguous or open-ended (e.g. user said "yes" to "oil or butter?" — we still don't know which). Shape: `{"op": "needs_followup", "reason": "was it oil or butter?"}`. Use sparingly — prefer concrete add/scale/replace recipes when possible. Always emit `needs_followup` for `free_text` questions.

- [ ] **Step 3.2** In the "Which answer keys to emit per question type" block, replace the `free_text` line with: `free_text → emit a single "default" key with {"op": "needs_followup", "reason": "..."}. The client will collect the typed answer and POST to /meals/refine for a second AI round.`

- [ ] **Step 3.3** Repeat Steps 3.1 and 3.2 verbatim in `_IMAGE_SCAN_SYSTEM_PROMPT` so vision parses stay in lock-step with text parses.

- [ ] **Step 3.4** Run: `cd c:/Projects/Zuralog/cloud-brain && uv run ruff check app/api/v1/nutrition_routes.py`

- [ ] **Step 3.5** Commit: `feat(nutrition): document needs_followup op in parse and vision prompts`

**Verification:** Hit `POST /api/v1/nutrition/meals/parse` with `{"description": "eggs with some kind of sauce I forgot", "mode": "guided"}`. At least one question should carry an `on_answer` entry with `needs_followup`. All `free_text` questions must emit `needs_followup` under `default`.

---

## Task 4: Build the refine system prompt

**File:** `cloud-brain/app/api/v1/nutrition_routes.py`

- [ ] **Step 4.1** Add a module-level `_MEAL_REFINE_SYSTEM_PROMPT` constant. Core instruction: "You are refining an existing meal estimate. You already parsed the meal once and asked the user some follow-up questions. Use their answers to either (a) return a refined food list, or (b) ask one more round of follow-ups if something is still unclear. Use the same JSON schema as `/meals/parse` (`foods` array, optional `questions` array with the same `on_answer` contract). Also emit `is_final: true` when done, `false` when you want another round."

- [ ] **Step 4.2** Include the full `ON_ANSWER CONTRACT` block from the parse prompt verbatim (they must stay in lock-step), including the new `needs_followup` op from Task 3.

- [ ] **Step 4.3** Add these rules:
  - **Round-3 hard stop:** "If you are told this is round 3, you MUST return `is_final: true` with a best-effort refined `foods` list and an empty `questions` array."
  - **Conservative estimates:** "Realistic and conservative numbers only. A teaspoon of cooking oil is ~40–50 kcal, not 200 or 10."
  - **Attribution preservation:** "Preserve `origin`, `source_question_id`, and `source_answer_value` on every food the prior rounds already attributed. Only set `origin: from_answer` on newly-added foods from this round."

- [ ] **Step 4.4** Commit: `feat(nutrition): add _MEAL_REFINE_SYSTEM_PROMPT for second-round meal refinement`

**Verification:** No runtime test yet — exercised end-to-end in Task 5.

---

## Task 5: Build the `POST /meals/refine` endpoint

**File:** `cloud-brain/app/api/v1/nutrition_routes.py`

- [ ] **Step 5.1** Add `POST /meals/refine` below `parse_meal_description`. Same decorator pair as parse: `@limiter.limit("10/minute")`, same `request`/`body`/`user_id`/`db` params, same `response_model=MealRefineResponse`.

- [ ] **Step 5.2** **Round cap — server-side hard limit.** Before any LLM call: `if body.round > 3: raise HTTPException(status_code=400, detail="Maximum refinement rounds exceeded.")`. Client also enforces this, but we never trust the client.

- [ ] **Step 5.3** Build the LLM user message by running the description, every question's text, and every answer through `sanitize_for_llm`. Format as a structured recap: original description, current foods as compact JSON, a bulleted Q&A history list with each entry tagged by its round, and a final line stating `"This is refinement round <N> of 3."` Inject user rules via `_get_user_rules_prompt(db, user_id)` — same as parse.

- [ ] **Step 5.4** On round 3, prepend `"THIS IS THE FINAL ROUND. Return is_final=true and empty questions. Best-effort foods only."` to the user message so the model can't wander.

- [ ] **Step 5.5** Run `_call_llm_with_json_retry(llm, messages, temperature=0.3, max_tokens=2048)` with `settings.openrouter_insight_model`. Validate the response exactly like `parse_meal_description` does: reject missing `foods`, validate each food through `ParsedFoodItem.model_validate` and skip invalid entries, validate each question through `GuidedQuestion.model_validate` and drop any with out-of-range `food_index`, coerce `is_final` to `bool` defensively.

- [ ] **Step 5.6** **Server-side override.** If `body.round == 3`, force `is_final = True` and drop any questions the model returned. Last line of defence against runaway rounds.

- [ ] **Step 5.7** Compute `rounds_remaining = max(0, 3 - body.round)` and return the response.

- [ ] **Step 5.8** Run: `cd c:/Projects/Zuralog/cloud-brain && uv run ruff check app/api/v1/nutrition_routes.py`

- [ ] **Step 5.9** Commit: `feat(nutrition): add POST /meals/refine endpoint for second-round refinement`

**Verification:** Hit the endpoint locally with a round-2 payload where the history has a yes on oil/butter. Response is either (a) refined foods naming oil or butter (never both, never generic "cooking fat"), or (b) one more question. `round=4` → 400. `round=3` with a model asking for more → response still has `is_final=true` and empty `questions`.

---

## Task 6: Add refine tests

**File:** `cloud-brain/tests/api/test_nutrition_refine.py` (new)

- [ ] **Step 6.1** Skeleton follows the existing `tests/api/test_nutrition_parse.py` shape — `@pytest.mark.asyncio`, `async_client` fixture, `authenticated_user_id` fixture. If those fixtures do not exist by name, search existing tests under `cloud-brain/tests/` for the closest match and mirror them.

- [ ] **Step 6.2** Test `test_refine_rejects_round_four`: POST with `round=4` → expect 400 with a clear error message.

- [ ] **Step 6.3** Test `test_refine_forces_final_on_round_three` (mocks the LLM client to return a response with `is_final=false` and a non-empty `questions` array on round 3) → assert the endpoint still returns `is_final=true` and `questions=[]`.

- [ ] **Step 6.4** Test `test_refine_preserves_attribution` (mocks the LLM to return a food with `origin="from_answer"` and a `source_question_id`) → assert the response round-trips those fields.

- [ ] **Step 6.5** Test `test_refine_rate_limited` — hit the endpoint 11 times in a minute, expect the 11th to return 429.

- [ ] **Step 6.6** Run: `cd c:/Projects/Zuralog/cloud-brain && uv run pytest tests/api/test_nutrition_refine.py -q`

- [ ] **Step 6.7** Commit: `test(nutrition): add refine endpoint round-cap and attribution tests`

---

## Task 7: Extend the Dart `OnAnswerOp` hierarchy with `NeedsFollowupOp`

**File:** `zuralog/lib/features/nutrition/domain/guided_question.dart`

- [ ] **Step 7.1** Add a new sealed subclass `NeedsFollowupOp({this.reason})` with a single `final String? reason` field. Doc-comment it: "Signals the answer needs a second AI round; emitted for free-text or ambiguous answers. The walkthrough collects the answer, pauses, calls refine, and continues with the server's response."

- [ ] **Step 7.2** Update `OnAnswerOp.fromJson` — add a `'needs_followup'` branch that reads `json['reason']` as a trimmed string and caps it at 200 chars, defaulting to `null` when missing or empty.

- [ ] **Step 7.3** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 7.4** Commit: `feat(nutrition): add NeedsFollowupOp to OnAnswerOp hierarchy`

**Verification:** In `test/features/nutrition/guided_question_test.dart`, add cases for `{"op": "needs_followup", "reason": "oil or butter?"}` → `NeedsFollowupOp(reason: "oil or butter?")` and `{"op": "needs_followup"}` → `NeedsFollowupOp(reason: null)`.

---

## Task 8: Add `MealRefineResult` domain model and repository method

**Files:**
- `zuralog/lib/features/nutrition/domain/nutrition_models.dart`
- `zuralog/lib/features/nutrition/data/mock_nutrition_repository.dart`
- `zuralog/lib/features/nutrition/data/api_nutrition_repository.dart`

- [ ] **Step 8.1** In `nutrition_models.dart`, add `MealRefineResult` below `MealParseResult` — same `foods` / `questions` fields plus `final bool isFinal` and `final int roundsRemaining`. `fromJson` defensively coerces every field.

- [ ] **Step 8.2** In `NutritionRepositoryInterface` (in `mock_nutrition_repository.dart`), add `refineMeal({required String description, required List<ParsedFoodItem> foods, required List<GuidedQuestion> questionsHistory, required List<Map<String, dynamic>> answersHistory, required int round}) → Future<MealRefineResult>`. Stub the mock with `throw UnimplementedError('Mock does not support refineMeal');`.

- [ ] **Step 8.3** In `api_nutrition_repository.dart`, implement `refineMeal` as a `POST /api/v1/nutrition/meals/refine` with body `{description, foods: foods.map((f) => f.toJson()), questions_history: questionsHistory.map((q) => q.toJson()), answers_history: answersHistory, round}`. Deserialise via `MealRefineResult.fromJson`.

- [ ] **Step 8.4** If `ParsedFoodItem.toJson` or `GuidedQuestion.toJson` don't exist yet, add them — symmetric with `fromJson`, including every Plan 2 attribution field (`origin`, `source_question_id`, `source_answer_value`).

- [ ] **Step 8.5** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 8.6** Commit: `feat(nutrition): add refineMeal repository method and MealRefineResult model`

---

## Task 9: Build the "Asking one more thing…" transition card

Decision: **new shared widget.** This is the user-facing signal between refine rounds; we want a consistent treatment for any future "pausing for AI" visuals. Lives under `lib/shared/widgets/nutrition/` alongside Plan 2's `ZAnswerOriginBadge`.

**File:** `zuralog/lib/shared/widgets/nutrition/z_refine_transition_card.dart` (new)

- [ ] **Step 9.1** Build `ZRefineTransitionCard` as a `StatelessWidget` wrapping `ZuralogCard(variant: feature, category: AppColors.categoryNutrition)` with a small animated spinner (reuse `ZPulsingDot` or equivalent — search `lib/shared/widgets/` first), a primary `"Asking one more thing…"` label in `AppTextStyles.titleMedium`, and an optional `subLabel` parameter (defaulting to `"Your last answer needs a little more detail."`). Padding matches the walkthrough question card so the transition feels like "same card, different contents."

- [ ] **Step 9.2** Export from the barrel: add `export 'nutrition/z_refine_transition_card.dart';` to `lib/shared/widgets/widgets.dart` under the nutrition block.

- [ ] **Step 9.3** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 9.4** Commit: `feat(widgets): add ZRefineTransitionCard for between-round refine state`

**Verification:** Deferred to Task 10's full flow.

---

## Task 10: Multi-round walkthrough logic

**File:** `zuralog/lib/features/nutrition/presentation/meal_walkthrough_screen.dart`

This is the biggest change in the plan. The walkthrough used to be linear and one-shot; now it can grow mid-session.

- [ ] **Step 10.1** Extend `MealWalkthroughArgs` with three optional fields, all defaulted so Plan 2's callers keep working:
  - `final NutritionRepositoryInterface? repository` — used for `refineMeal`.
  - `final String? description` — the original user text, needed for refine requests.
  - `final int initialRound = 1`.
  
  If `repository` is null, the `needs_followup` path degrades gracefully to a `NoOpOp`.

- [ ] **Step 10.2** In `_MealWalkthroughScreenState`, add state for multi-round tracking: `int _round` (init from `args.initialRound`), `bool _refining`, mutable `List<GuidedQuestion> _questions` (copied from `args.questions` in `initState`), `List<ParsedFoodItem> _currentFoods` (from `args.foods`), and `List<Map<String, dynamic>> _answersHistory` (each entry `{question_id, answer_value, round}`). Replace every `widget.args.questions` reference with `_questions` — it's no longer immutable.

- [ ] **Step 10.3** Back the `PageView` with `_questions.length + (_refining ? 1 : 0)`. When `_refining` is true the extra slot renders `ZRefineTransitionCard` at the current index; when it flips back to false, the extra slot disappears and the user sees the next real question.

- [ ] **Step 10.4** In `_goNext`, after flushing any free-text answer into `_answers`, detect the refine trigger:
  ```dart
  final current = _questions[_currentIndex];
  final key = _answerKeyFor(_answers[current.id]);
  final op = current.onAnswer?[key];
  final shouldRefine = op is NeedsFollowupOp
      || current.componentType == GuidedComponentType.freeText;
  if (shouldRefine && widget.args.repository != null && _round < 3) {
    await _triggerRefine();
    return;
  }
  ```
  Fall through to normal advancement otherwise.

- [ ] **Step 10.5** Implement `_triggerRefine()`:
  1. Append the current answer to `_answersHistory` with `round: _round`.
  2. `setState(() => _refining = true);` so the transition card shows.
  3. Call `widget.args.repository!.refineMeal(description, _currentFoods, _questions, _answersHistory, round: _round + 1)`.
  4. On success: `_round += 1`, replace `_currentFoods` with `result.foods`. If `result.isFinal` OR `result.questions.isEmpty` OR `_round >= 3`: finish via `_finish()`. Else: append `result.questions` to `_questions`, flip `_refining` back to false, advance to the first new question.
  5. On failure (network error, any non-2xx): log, treat as no-op, advance past the problem question, show a discreet `ZToast.error('Couldn\'t refine. Continuing with your answer.')`. Never crash.

- [ ] **Step 10.6** Update `_finish()` to return a record: `(answers: _answers, foods: _currentFoods, wasRefined: _round > 1)`. Type-annotate via `context.pop<({Map<String, dynamic> answers, List<ParsedFoodItem> foods, bool wasRefined})>(...)`. Meal Review unpacks this in Task 12.

- [ ] **Step 10.7** In `_buildQuestionPage`, when `_refining == true` AND the page is the extra transition slot, render `ZRefineTransitionCard(subLabel: <reason-from-last-needs_followup-op or null>)` instead of a question. Freeze the progress bar at its current value while refining so the user doesn't see it jump.

- [ ] **Step 10.8** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 10.9** Commit: `feat(nutrition): multi-round walkthrough with needs_followup and free-text refine`

**Verification:** Run in emulator. Log "eggs with some kind of sauce" in Guided mode. First round asks about the sauce. Answer with free text "chipotle mayo". Expect: transition card appears, ~1–2s later a new question appears (or the walkthrough finishes with chipotle mayo added to the food list).

---

## Task 11: Honour the server-side 3-round cap on the client

**File:** `zuralog/lib/features/nutrition/presentation/meal_walkthrough_screen.dart`

- [ ] **Step 11.1** If the server ever returns `is_final: true` OR `rounds_remaining == 0`, the client treats the walkthrough as done — call `_finish()` with the returned foods.

- [ ] **Step 11.2** If the client has already reached `_round == 3` locally, stop calling refine entirely. Even if a question still has a `needs_followup` op on it, skip the refine call and treat the answer as a `NoOpOp`. The user sees no error — just the last question, then the final review.

- [ ] **Step 11.3** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 11.4** Commit: `fix(nutrition): enforce 3-round walkthrough cap on client and honour server is_final`

**Verification:** Mock the repository to always return `is_final: false` and a new question. Open the walkthrough with a `needs_followup` answer. Expect: the walkthrough ends after round 3 regardless, with no fourth refine call and no crash.

---

## Task 12: Wire the refined foods back into Meal Review

**File:** `zuralog/lib/features/nutrition/presentation/meal_review_screen.dart`

- [ ] **Step 12.1** Change `_pushWalkthrough` to pass the repository and the original user description into `MealWalkthroughArgs`. Search the file for `nutritionRepositoryProvider` (or the provider this screen already uses to read the repo) and reuse it. Capture the original description once in `_startAnalysis` (reuse an existing field if the screen has one, add `_originalDescription` if not).

- [ ] **Step 12.2** Update both callers of `_pushWalkthrough` (`_startAnalysis` initial push and `_handleChangeAnswer` re-push) to unpack the new record `(answers, foods, wasRefined)`:
  - If `wasRefined == true`: the server already applied the answers into `foods`. Adopt `_parsedItems = result.foods` and rebuild `_mealFoods` from it. Skip `_applyWalkthroughAnswers`.
  - If `wasRefined == false`: run `_applyWalkthroughAnswers` against the answers as before (Plan 2 behaviour, unchanged).

- [ ] **Step 12.3** The Plan 2 "From your answer" badge keeps working — the refine prompt (Step 4.5) preserves `origin`, `source_question_id`, and `source_answer_value` on every food.

- [ ] **Step 12.4** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 12.5** Commit: `feat(nutrition): adopt refined food list from walkthrough when refine ran`

---

## Task 13: End-to-end verification pass

- [ ] **Step 13.1** Scenario A (canonical) — "scrambled eggs with rice" → guided → yes on oil/butter → follow-up "oil or butter?" → oil. Expected: final review shows a `cooking oil` line with the violet "From your answer" badge; totals rise ~40–50 kcal; food is named `cooking oil`, not generic `cooking fat`.

- [ ] **Step 13.2** Scenario B (free text) — "chipotle mayo sauce on a sandwich" → guided → AI free-text question about sandwich contents. Type "turkey and swiss, sourdough bread". Expected: transition card shows, backend returns either refined foods (turkey, swiss, sourdough broken out) or one more question. No crash, no silent drop.

- [ ] **Step 13.3** Scenario C (3-round cap) — mock repository always returns `is_final: false` with a new question. Expected: walkthrough ends after round 3, no fourth call.

- [ ] **Step 13.4** Scenario D (refine failure) — cut the network, give a free-text answer. Expected: `ZToast.error` fires, walkthrough continues, no crash.

- [ ] **Step 13.5** Scenario E (Quick mode regression) — no walkthrough, no refine call. Identical to today.

- [ ] **Step 13.6** Scenario F (Plan 2 regression) — "scrambled eggs" in Guided with a plain `add_food` recipe. Instant add, no refine call, violet badge shows. Unchanged from Plan 2.

- [ ] **Step 13.7** Run: `cd c:/Projects/Zuralog/cloud-brain && uv run pytest -q`

- [ ] **Step 13.8** Run: `cd c:/Projects/Zuralog/zuralog && flutter test && flutter analyze && flutter build apk --debug`. All clean.

---

## Definition of done

- [ ] Backend `OnAnswerOp` union includes `NeedsFollowupOp` with a bounded `reason` field
- [ ] `MealRefineRequest` / `MealRefineResponse` schemas validate and clamp every LLM-returned value
- [ ] Parse and vision prompts document `needs_followup` and route every `free_text` through it
- [ ] `POST /meals/refine` mirrors `/meals/parse` — same auth, rate limit, retry wrapper, validation
- [ ] Refine rejects `round > 3` with a 400 and forces `is_final=true` on round 3 regardless of LLM output
- [ ] Refine tests cover round-cap enforcement, round-3 forcing, attribution preservation, and rate limit
- [ ] Dart `OnAnswerOp.fromJson` handles `needs_followup` defensively (never throws)
- [ ] Flutter repository exposes `refineMeal(...)` with symmetric `toJson` helpers on `ParsedFoodItem` and `GuidedQuestion`
- [ ] Walkthrough supports multiple rounds inside the same `PageView`, appending questions as they arrive
- [ ] Walkthrough routes `needs_followup` ops AND free-text answers through refine
- [ ] Walkthrough caps at 3 rounds client-side, independent of the server
- [ ] `ZRefineTransitionCard` renders between rounds with "Asking one more thing…"
- [ ] Meal Review adopts the refined foods when refine ran, or applies ops locally when it didn't
- [ ] Plan 2's "From your answer" badge still works on refined foods
- [ ] Quick mode and manual entry remain unchanged
- [ ] `flutter analyze`, `flutter test`, `flutter build apk --debug`, `uv run pytest -q`, and `uv run ruff check` all pass
- [ ] End-to-end scenarios A–F all behave as specified

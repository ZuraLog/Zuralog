# Phase 6 — Plan 5: UX Consistency + Meal Type Flow Restructure

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** Close out eight rough edges that were found during the first hands-on pass of the guided meal flow. Kill the "your rules covered everything" toast. Scrub the universal toast so it stops showing an unintended amber accent line. Give every walkthrough question card a consistent floor size so short questions don't look like tiny floating pills. Promote the labeled-field treatment introduced in Plan 1 from numeric-only to a general text variant and roll it out to every meaningful free-text input in the app. Then restructure the "log a meal" popup so it becomes the pure entry-point chooser it was always supposed to be — meal type lives inside the logging flow, not on the launch pad.

**Architecture:** Purely presentational. No new providers, routes, API calls, schema fields, or backend work. Two new shared widgets — `ZLabeledTextField` (free-text sibling of `ZLabeledNumberField`) and `ZMealTypePicker` (the dropdown that today lives as a private helper inside Meal Review gets lifted into the component library so every screen can use the same one). Everything else is local edits to existing screens. All state stays local. The meal-type auto-suggest logic moves from `LogMealSheet.initState` into the screens that now own the meal-type field — so the user still gets a smart default, just later in the flow.

**Tech Stack:** Flutter 3.19+, no new packages.

**Depends on:** Phase 6 Plan 1 (UX cleanup — ships `ZLabeledNumberField`, the template this plan mirrors) and Phase 6 Plan 2 (answer flow fix — touches the same `meal_review_screen.dart` regions) must both be shipped and merged before starting this plan. Running this plan on a branch where Plan 2 has not merged will create messy conflicts around the food-card builder.

---

## Files touched

| File | Changes |
|------|---------|
| `lib/features/nutrition/presentation/meal_review_screen.dart` | Delete the "Your rules covered everything!" toast + the `_rulesHandledEverything` flag. Swap inline-edit food-name `AppTextField` for `ZLabeledTextField`. Extract the meal-type dropdown into the new shared widget and use it here. |
| `lib/shared/widgets/feedback/z_toast.dart` | Audit and strip any decoration that could render as a double-line accent; land on a single clean pill with just the status dot. |
| `lib/features/nutrition/presentation/meal_walkthrough_screen.dart` | Give the question card a hard `minWidth` (full available width) and a reasonable `minHeight` so short RICE-style questions don't look tiny. |
| `lib/shared/widgets/inputs/z_labeled_text_field.dart` | New file — free-text sibling of `ZLabeledNumberField`. |
| `lib/shared/widgets/nutrition/z_meal_type_picker.dart` | New file — shared dropdown meal type picker, promoted from the private helper inside Meal Review. |
| `lib/shared/widgets/widgets.dart` | Export both new widgets. |
| `lib/features/nutrition/presentation/log_meal_sheet.dart` | Remove meal type from the popup entirely. Strip the meal-type chip row, the auto-suggest, the `_selectedMealType` state, and the "Meal type" section header. Replace the four manual-entry `AppTextField`s with `ZLabeledTextField` for name and `ZLabeledNumberField` for calories/protein/carbs/fat. |
| `lib/features/nutrition/presentation/meal_edit_screen.dart` | Replace the chip-based meal-type Wrap with `ZMealTypePicker`. Swap meal-name + food-name `AppTextField`s for `ZLabeledTextField`. |
| `lib/features/settings/presentation/account_settings_screen.dart` | Replace `AppTextField` instances that carry a `labelText` with `ZLabeledTextField` (5 call sites). |
| `lib/features/settings/presentation/edit_profile_screen.dart` | Same replacement (4 call sites). |
| `lib/features/today/presentation/log_screens/supplements_log_screen.dart` | Same replacement (2 call sites). |
| `lib/features/today/presentation/log_screens/run_log_screen.dart` | Same replacement (3 call sites). |
| `lib/shared/widgets/log_panels/z_wellness_log_panel.dart`, `z_water_log_panel.dart`, `z_steps_log_panel.dart` | Same replacement where labels apply (1 call site each). |

All paths relative to `zuralog/`.

Auth screens (`login_screen.dart`, `register_screen.dart`, `forgot_password_screen.dart`, `reset_password_screen.dart`), `journal_save_confirmation_sheet.dart`, the `dev/component_showcase_screen.dart` demo, and `z_password_field.dart` (which internally wraps `AppTextField`) are **left alone** — auth fields already have their own focus and label conventions that would regress if bulk-swapped, and the showcase is an intentional gallery of the old and new.

---

## Task 1: Delete the "rules covered everything" toast

**File:** `zuralog/lib/features/nutrition/presentation/meal_review_screen.dart`

The toast fires on line 280 after the guided parse returns, gated by `_rulesHandledEverything`. The user found it noisy — any meal where the AI is confident on every item triggers it, which is most meals. It adds nothing the results screen isn't already showing.

- [ ] **Step 1.1** Delete the `_rulesHandledEverything` boolean field (declared near the other `_ReviewPhase` state around line 170ish — grep for `_rulesHandledEverything` and remove every reference).

- [ ] **Step 1.2** In the setState block around line 272–276, delete the whole `if (args.isGuidedMode && results.isNotEmpty && results.every(...)) { _rulesHandledEverything = true; }` branch plus the comment block above it (lines 270–276 in the current file).

- [ ] **Step 1.3** Delete the follow-up `if (_rulesHandledEverything && mounted) { ZToast.success(...); }` block on lines 279–281.

- [ ] **Step 1.4** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 1.5** Commit: `fix(nutrition): remove "rules covered everything" toast`

**Verification:** Launch the emulator, log "scrambled eggs with rice" in Guided mode with a couple of saved rules. No toast appears on the Meal Review screen. Negative meals (low-confidence parse) are unaffected — there was never a toast in that branch.

---

## Task 2: Scrub the toast visual so there is no accent line

**File:** `zuralog/lib/shared/widgets/feedback/z_toast.dart`

The current `_buildToast` renders a `Container` with `color: colors.surfaceRaised` and `borderRadius: BorderRadius.circular(AppDimens.shapePill)` — no border, no underline. The "double yellow line" the user sees is the warning toast's amber status dot plus a thin amber hairline produced by the raised surface on top of the warning-tinted accent banner sometimes visible behind it on the nutrition screens. The fix is defensive: explicitly pin the decoration to a single surface color with no border, no shadow edge, no outline, no implicit divider, and make sure every variant shares the exact same visual chrome (only the dot color differs).

- [ ] **Step 2.1** In `_ZToastOverlayState._buildToast`, rewrite the outer `Container`'s `BoxDecoration` to: `color: colors.surfaceRaised`, `borderRadius: BorderRadius.circular(AppDimens.shapePill)`, **explicit** `border: null`, **explicit** `boxShadow: const []`. The explicitness is the point — it locks out any theme-level inheritance that could reintroduce an accent edge.

- [ ] **Step 2.2** Confirm the status dot Container (inner) has only `shape: BoxShape.circle` and `color: widget.variant.dotColor` — no border there either. (It currently does; add a comment to lock the intent.)

- [ ] **Step 2.3** Remove the odd `@workaround` comment block at the bottom of the file (lines 319–322) — it is stale noise referring to an `AnimatedBuilder` that is not a workaround.

- [ ] **Step 2.4** Do a visual read through the file for any `border: Border(...)` / `BorderSide(...)` / `Divider(...)` / `LinearProgressIndicator(...)` that could paint a line — remove any found. (Today, there are none — this step is a safety pass.)

- [ ] **Step 2.5** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 2.6** Commit: `fix(feedback): strip any accent borders from ZToast universally`

**Verification:** In the component showcase, trigger the four toast variants (Success, Error, Warning, Info) in sequence. Each should render as a solid surface-raised pill with only the status dot coloured — no amber, red, or green line above, below, or on either side of the pill. Log a meal in Guided mode with rules saved — even though Task 1 removed the specific offender, confirm other toasts (save success, save error) still show clean.

---

## Task 3: Give walkthrough question cards a consistent floor size

**File:** `zuralog/lib/features/nutrition/presentation/meal_walkthrough_screen.dart`

Today the question is rendered inside `Center(child: Column(mainAxisSize: MainAxisSize.min, children: [ZuralogCard(...), buttons]))` inside a `ConstrainedBox(minHeight: constraints.maxHeight)` — vertical sizing is handled, but horizontally the card shrinks to fit its content. For a three-word question ("RICE / White or brown?") the card renders at maybe 40% of screen width and looks abandoned.

The fix: force the card to occupy the full available horizontal width inside the scroll padding, and give the content block a reasonable `minHeight` so a short question doesn't look squatter than a long one.

- [ ] **Step 3.1** In `_buildQuestionPage` around lines 608–662, wrap the `ZuralogCard` in a `SizedBox(width: double.infinity, child: ZuralogCard(...))`. This makes every card fill the row.

- [ ] **Step 3.2** Inside the `ZuralogCard`'s inner `Column`, wrap the existing children in a `ConstrainedBox(constraints: const BoxConstraints(minHeight: 220), child: Column(...))`. 220 logical pixels is enough to keep short questions feeling grounded — the food eyebrow + question + a yes/no button row already clears that on most devices, but a single-line question with a short button group does not.

- [ ] **Step 3.3** Confirm long questions (multi-line free-text prompts, slider with markers) still fit without overflow — the constraint is a **min**, not a fixed height, so they grow naturally. Verify on the `freeText` and `slider` component paths.

- [ ] **Step 3.4** Apply the same `SizedBox(width: double.infinity)` wrap to the `ZRefineTransitionCard` inside `_buildTransitionPage` (lines 567–591) so the refine transition card doesn't shrink either.

- [ ] **Step 3.5** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 3.6** Commit: `fix(nutrition): pin walkthrough question cards to full width and a min height`

**Verification:** Log "white rice" in Guided mode. The "What type of rice was it?" question card should fill the horizontal padding, not shrink to fit "White / Brown" buttons. Log a meal that triggers a slider question and a free-text question — each card should still render cleanly without overflow or excessive empty space.

---

## Task 4: Build the shared `ZLabeledTextField`

Decision: **new shared widget**. Plan 1 set the precedent — persistent label, visible soft outline when unfocused, amber focus color. That pattern is only half applied today: numeric fields have it, free-text fields don't. The inconsistency is jarring on the same form (the Meal Review inline-edit form has four labeled numeric fields and one bare food-name field). This plan lifts the treatment to free text too, and reuses it app-wide.

**File:** `zuralog/lib/shared/widgets/inputs/z_labeled_text_field.dart` (new)

- [ ] **Step 4.1** Create the widget as a `StatelessWidget` that mirrors `ZLabeledNumberField`'s structure:
  - A `Semantics(label: label, textField: true, container: true)` wrapper.
  - A `Column(crossAxisAlignment: start)` with a `Text(label, style: labelMedium, color: textSecondary)`, a `SizedBox(height: spaceXxs)`, and a `TextFormField`.
  - The `TextFormField`'s `decoration` uses the same `OutlineInputBorder` on `border`, `enabledBorder`, and a thicker `AppColors.categoryNutrition` border on `focusedBorder`. Same `contentPadding` (`horizontal: spaceMd, vertical: spaceSm`).

- [ ] **Step 4.2** Parameters (named, all optional except `label` and `controller`):
  - `label: String` (required)
  - `controller: TextEditingController` (required)
  - `hint: String?`
  - `textInputAction: TextInputAction?`
  - `keyboardType: TextInputType?` — defaults to `TextInputType.text`; callers pass `emailAddress` / `phone` / `multiline` as needed.
  - `obscureText: bool` — defaults false.
  - `maxLines: int?` — defaults 1. Pass `null` for unlimited. When `maxLines != 1`, keep the same outline (multi-line labeled textarea looks native when the border wraps cleanly).
  - `maxLength: int?` — optional, forwarded.
  - `onChanged: ValueChanged<String>?`
  - `onSubmitted: ValueChanged<String>?`
  - `focusNode: FocusNode?`
  - `autofillHints: List<String>?`
  - `autofocus: bool` — defaults false.
  - `enabled: bool` — defaults true.

- [ ] **Step 4.3** Do **not** accept arbitrary `InputDecoration` — the point is consistency. Callers who need unusual chrome keep using `AppTextField` (auth screens, showcase) or `TextFormField` directly.

- [ ] **Step 4.4** Export from the barrel. Add to `lib/shared/widgets/widgets.dart` in alphabetical order next to `z_labeled_number_field.dart`: `export 'inputs/z_labeled_text_field.dart';`.

- [ ] **Step 4.5** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 4.6** Commit: `feat(widgets): add ZLabeledTextField free-text sibling of ZLabeledNumberField`

**Verification:** Deferred to Task 5. The widget compiles on its own; behaviour is proven by the adoption pass.

---

## Task 5: Roll `ZLabeledTextField` into every meaningful free-text input

Scope: the grep found 34 `AppTextField` call sites across 15 files. Replacements happen everywhere the field is stacked vertically with a clear label and is not auth or the showcase gallery. Bare fields (like the search-in-dialog field in the rule editor) stay as is — they're not displayed stacked with a sibling label.

**Per-file checklist — each file gets its own step so commits stay small:**

- [ ] **Step 5.1** `lib/features/nutrition/presentation/meal_review_screen.dart` — line 1057 inline-edit food-name. Label `'Food name'`, passthrough `controller`, `textInputAction: TextInputAction.next`. Commit: `feat(nutrition): apply ZLabeledTextField to Meal Review inline food name`.

- [ ] **Step 5.2** `lib/features/nutrition/presentation/meal_edit_screen.dart` — line 235 meal name (label `'Meal name'`), line 372 food-name inside `_FoodEditCard.build` (label `'Food name'`). Commit: `feat(nutrition): apply ZLabeledTextField to Meal Edit name fields`.

- [ ] **Step 5.3** `lib/features/nutrition/presentation/log_meal_sheet.dart` — line 520 manual name (label `'Food name'`), lines 525/534/542/550 manual macros (swap these four to `ZLabeledNumberField` with labels `'Calories'` / `'Protein'` / `'Carbs'` / `'Fat'` and unit `'kcal'` / `'g'` / `'g'` / `'g'`). This tightens the manual-entry form to match the Meal Edit / Meal Review treatment. Commit: `feat(nutrition): upgrade manual-entry fields in log-meal sheet`.

- [ ] **Step 5.4** `lib/features/settings/presentation/account_settings_screen.dart` — 5 `AppTextField` call sites (lines 386, 538, 559, 579, 779). Replace with `ZLabeledTextField`, reading the existing `labelText:` prop as the new `label:`. Commit: `feat(settings): apply ZLabeledTextField to account settings fields`.

- [ ] **Step 5.5** `lib/features/settings/presentation/edit_profile_screen.dart` — 4 `AppTextField` call sites (lines 622, 764, 776, 786). Same replacement. Commit: `feat(settings): apply ZLabeledTextField to edit profile fields`.

- [ ] **Step 5.6** `lib/features/today/presentation/log_screens/supplements_log_screen.dart` — 2 call sites (lines 261, 263). `labelText` already set, swap. Commit: `feat(today): apply ZLabeledTextField to supplements log`.

- [ ] **Step 5.7** `lib/features/today/presentation/log_screens/run_log_screen.dart` — 3 call sites (lines 205, 225, 242). Commit: `feat(today): apply ZLabeledTextField to run log`.

- [ ] **Step 5.8** `lib/shared/widgets/log_panels/z_wellness_log_panel.dart` / `z_water_log_panel.dart` / `z_steps_log_panel.dart` — one call each (163 / 199 / 157). Commit: `feat(log-panels): apply ZLabeledTextField to today log panels`.

- [ ] **Step 5.9** Search input handling — `ZSearchBar` already has its own iconified visual with a focus border. **Do not** swap it. Confirm its unfocused state renders a visible outline on light and dark — it does today (it uses a Sage focus border with a subtle surface fill).

- [ ] **Step 5.10** Journal save confirmation sheet (`lib/features/progress/presentation/journal_save_confirmation_sheet.dart` line 103) — the field is a 6-line free-text with no label. Leave it alone per the "Data Tab hands-off / Progress preferences" memory unless the user asks otherwise.

- [ ] **Step 5.11** Auth screens (`login_screen.dart`, `register_screen.dart`, `forgot_password_screen.dart`, `reset_password_screen.dart`) — explicitly **not** swapped. These screens have a bespoke floating-label flow from Flutter's Material theme that will regress if swapped. Leave for a future auth polish pass.

- [ ] **Step 5.12** After all replacements, run: `cd c:/Projects/Zuralog/zuralog && flutter analyze` and `flutter build apk --debug`.

**Verification:** Visit Meal Review inline edit, Meal Edit, Log-Meal manual entry, Account Settings, Edit Profile, Supplements log, Run log, each log panel. Every labeled field shows its label above the box and a visible grey outline when empty. Tapping focuses to amber (nutrition) for nutrition contexts; elsewhere the focus color inherits the nutrition accent — this is intentional and matches `ZLabeledNumberField`. If a team reviewer wants per-feature focus colors later, that becomes a follow-up by adding a `focusColor` parameter.

---

## Task 6: Promote the Meal Review meal-type dropdown into a shared widget

The dropdown helper `_buildMealTypeDropdown` lives inside `meal_review_screen.dart` at lines 1221–1258. It is the one place today where meal type is picked via a dropdown — every other site uses chips. Before wiring the dropdown into Meal Edit and anywhere else it needs to appear, lift it out of the screen so every call site uses the exact same widget.

**File:** `zuralog/lib/shared/widgets/nutrition/z_meal_type_picker.dart` (new)

- [ ] **Step 6.1** Create `ZMealTypePicker` as a `StatelessWidget`. Parameters: `value: MealType?`, `onChanged: ValueChanged<MealType>`, and optional `label: String?` (defaults to null — caller may stack a `Text` label above the widget, matching how meal review does it today).

- [ ] **Step 6.2** Port the contents of `_buildMealTypeDropdown` verbatim: outer `Container` with surface background, `shapeSm` radius, `border: Border.all(color: colors.border)`, horizontal padding `spaceSm`, inner `DropdownButtonHideUnderline` wrapping a `DropdownButton<MealType>` with the amber `MealType.icon` + label for each item.

- [ ] **Step 6.3** Accept a `String? label` parameter; when non-null, wrap the container in a `Column(crossAxisAlignment: start)` with a `Text(label, labelMedium)` above, matching the labeled-field pattern. This lets callers get the same vertical rhythm as `ZLabeledTextField` / `ZLabeledNumberField` for free.

- [ ] **Step 6.4** Export from the barrel: `export 'nutrition/z_meal_type_picker.dart';` in the nutrition block.

- [ ] **Step 6.5** Delete `_buildMealTypeDropdown` from `meal_review_screen.dart` and replace the call site (around line 870 where the meal-type field renders today) with `ZMealTypePicker(value: _selectedMealType, onChanged: (v) => setState(() => _selectedMealType = v))`.

- [ ] **Step 6.6** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 6.7** Commit: `feat(widgets): extract ZMealTypePicker as shared dropdown`

**Verification:** Log a meal via Describe (Guided mode). On Meal Review, the meal-type field looks identical to before — same dropdown chrome, same amber icon per option, same tap-to-open behavior.

---

## Task 7: Strip meal type from the log-a-meal popup entirely

**File:** `zuralog/lib/features/nutrition/presentation/log_meal_sheet.dart`

The popup today asks the user to pick a meal type before they've committed to logging — it sits right at the top under the Quick/Guided toggle. The user wants the popup to be a pure entry-point chooser: toggle, Scan buttons, Search, and Describe/Manual. Meal type is decided *during* the logging flow (Meal Review and the non-AI path both need it, but the popup doesn't).

- [ ] **Step 7.1** Delete the `MealType? _selectedMealType;` field (line 72) and its initialisation call `_selectedMealType = _autoSuggestMealType();` (line 111). Keep `_autoSuggestMealType` as a `static` utility function on `LogMealSheet` so the downstream screens can still use it (or move it to a new `lib/features/nutrition/domain/meal_type_defaults.dart` helper — the static-on-class route is simpler and matches how `LogMealSheet.show` is already exposed).

- [ ] **Step 7.2** Delete the chip row section on lines 413–416 (`SectionHeader(title: 'Meal type')` + `SizedBox` + `_buildMealTypeChips()`) and the `_buildMealTypeChips` method itself (lines 641–655).

- [ ] **Step 7.3** Update `_canSave` (line 130) to drop the `_selectedMealType != null` guard — the save path is only reached by non-AI manual / search / recents entries inside the sheet, and those meals need a meal type too. The fix: auto-assign the meal type at save time via `_autoSuggestMealType()`, but also add a `ZMealTypePicker` inline above the Save button so the user can override it there. Keep meal type **out** of the top of the sheet (the user's architectural point) but **in** the final confirmation area where the meal is about to be committed. Label it `'Meal type'`.

- [ ] **Step 7.4** Update `_handleSave` on line 313 to pass `_selectedMealType?.name ?? _autoSuggestMealType().name` — because Task 7.3 adds the override, `_selectedMealType` is back as state but now only surfaces near the Save button, not at the top.

- [ ] **Step 7.5** For the three AI paths (`_handleParse`, `_pickAndScanImage`, `_handleBarcodeScan`) that call `MealReviewScreen.show`, replace `initialMealType: _selectedMealType ?? _autoSuggestMealType()` with `initialMealType: _autoSuggestMealType()`. The Meal Review screen already has its own `ZMealTypePicker` (from Task 6), so the user can change it there; the sheet no longer needs to pre-seed from its own state.

- [ ] **Step 7.6** Drop any now-unused imports in `log_meal_sheet.dart` (likely `z_chip.dart` if chips are only used in recents — keep if still used, remove otherwise).

- [ ] **Step 7.7** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`

- [ ] **Step 7.8** Commit: `refactor(nutrition): remove meal type from log-meal popup top; keep it near save only`

**Verification:** Open the log-meal popup. The first thing under the Quick/Guided toggle is Scan Food (camera/photos/barcode). No meal-type selector at the top. Scroll to the bottom — above the Save button, the meal-type picker appears with the auto-suggested option pre-filled. Tap Describe, parse a meal — the Meal Review screen opens with the auto-suggested type; change it there, save, confirm the correct meal type lands on Nutrition Home.

---

## Task 8: Make every meal-type picker a dropdown (audit + fix)

Grep for every `MealType.values.map` and `ZChip(.*mealType` call site. Each one is either the popup (Task 7 removed it), Meal Review (Task 6 already uses the dropdown), or Meal Edit (chips today).

- [ ] **Step 8.1** `zuralog/lib/features/nutrition/presentation/meal_edit_screen.dart` lines 247–258 — the chip Wrap. Replace the entire `Wrap` + preceding `SectionHeader` with a single `ZMealTypePicker(value: _selectedMealType, onChanged: (v) => setState(() => _selectedMealType = v), label: 'Meal type')`. Delete the now-unused `ZChip` import if it was only for this.

- [ ] **Step 8.2** Run a final repo grep for `ZChip(.*MealType` and `MealType.values.map` to confirm no other chip-based picker survives. (Today the list is: `log_meal_sheet.dart` — deleted in Task 7 — and `meal_edit_screen.dart` — swapped in Step 8.1. If Plan 4 or an earlier task added another, it catches it here.)

- [ ] **Step 8.3** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze` and `flutter build apk --debug`.

- [ ] **Step 8.4** Commit: `feat(nutrition): use ZMealTypePicker dropdown across meal edit`

**Verification:** Edit an existing meal from Nutrition Home. The meal-type field is a dropdown — tap it, pick Dinner, save, reload the meal, dinner persists. Same visual as on Meal Review.

---

## Task 9: End-to-end verification pass

Since we cannot run the emulator from this plan, the user runs the following smoke test after all tasks land. Every bullet should pass before merging.

- [ ] **Step 9.1** Toast sanity — trigger Success, Error, Warning, Info toasts (via Settings save, a failed save, a form validation warning, and any info path). Each pill is clean: surface-raised background, single status dot, no visible accent lines on any edge.

- [ ] **Step 9.2** Meal Review — log "scrambled eggs with rice" in Guided mode with a saved rule. The Meal Review screen appears without the "Your rules covered everything" toast. The food-name inline-edit field has a visible label and outline.

- [ ] **Step 9.3** Walkthrough — the "What type of rice was it?" question fills the full width; the card doesn't look small. Long slider questions and free-text questions still render cleanly without overflow.

- [ ] **Step 9.4** Log-meal popup — open it. Top of the sheet is the Quick/Guided toggle; directly below it is Scan Food. No meal-type selector at the top. Scroll to bottom — meal-type picker sits above the Save button with the time-of-day default pre-filled.

- [ ] **Step 9.5** Meal Edit — open an existing meal, tap Edit. Meal-name field and food-name fields show the labeled outline treatment. Meal-type field is a dropdown, not chips.

- [ ] **Step 9.6** Account Settings, Edit Profile, Supplements log, Run log — every labeled text field has the consistent label + outline chrome.

- [ ] **Step 9.7** Auth screens (Login, Register, Forgot Password, Reset Password) — **unchanged** from before this plan; their bespoke Material-floating-label treatment still works.

- [ ] **Step 9.8** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze && flutter test`.

---

## Definition of done

- [ ] "Your rules covered everything!" toast is deleted along with its gating flag.
- [ ] `ZToast` renders every variant as a clean pill — no accent line on any edge, no stale workaround comments.
- [ ] Walkthrough question card fills the full horizontal width and has a 220 px minimum height floor.
- [ ] `ZLabeledTextField` exists under `lib/shared/widgets/inputs/` and is exported from `widgets.dart`.
- [ ] Every labeled text field across Nutrition, Settings, Edit Profile, Today log screens, and the three log panels uses `ZLabeledTextField`.
- [ ] `ZSearchBar`, `ZPasswordField`, and auth `AppTextField`s are deliberately left alone and still work.
- [ ] `ZMealTypePicker` lives under `lib/shared/widgets/nutrition/` and is exported from the barrel.
- [ ] Meal Review and Meal Edit both use `ZMealTypePicker`; no chip-based meal-type picker remains anywhere.
- [ ] The log-meal popup has **no** meal-type selector at the top; the entry-point choices (Quick/Guided toggle, Scan Food, Search, Describe/Manual) are the only things the user sees above the fold.
- [ ] The log-meal popup still supports the non-AI save path by showing the meal-type dropdown above the Save button with a time-of-day default.
- [ ] AI paths (Describe, Camera, Barcode) no longer read meal type from popup state — they pre-seed Meal Review with the auto-suggested default.
- [ ] `flutter analyze` is clean.
- [ ] `flutter build apk --debug` succeeds.
- [ ] `flutter test` passes.
- [ ] End-to-end scenarios 9.1–9.8 all behave as specified.

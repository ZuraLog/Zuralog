# Phase 6 - Plan 6: Global Visible Outline on Every Text Input

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** Every single text input in the app - no matter how it is reached - must render a clearly visible grey outline when it is empty and unfocused, in both light and dark mode. Previous passes fixed individual fields one at a time and kept missing ones (most recently the big "Describe what you ate" box in the log-meal popup). This plan ends that cycle by fixing the problem at its two real sources: the app-wide theme's `inputDecorationTheme` and every shared input widget under `lib/shared/widgets/inputs/`. Individual screens get audited, but they are not where the fix lives. The only edits that touch screen files are migrations away from hand-rolled `TextField` blocks that were bypassing the shared library in the first place.

**Architecture:** Two source layers, one guarantee. Layer one is the theme - we replace the current `inputDecorationTheme` (which sets `enabledBorder` to `BorderSide.none` in dark mode, the actual root cause of the invisible outline in dark mode) with a decoration that paints a visible outline in every state in every brightness. Layer two is the shared-widget library - every file under `lib/shared/widgets/inputs/` is reviewed, and any widget that today explicitly sets `BorderSide.none` or `InputBorder.none` on its `border` / `enabledBorder` gets rewritten to inherit the theme default or to set an explicit visible outline. After those two layers land, anything built on top of the shared library is automatically correct. Bare `TextField` / `TextFormField` usages found outside the input folder are either migrated to a shared widget or given the same explicit outline inline. No new packages, no new providers, no routing changes.

**Tech Stack:** Flutter 3.19+, no new dependencies.

**Depends on:** Phase 6 Plans 1 through 5 - all shipped and merged. In particular, Plan 5 introduced `ZLabeledTextField` and added an explicit unfocused outline to `AppTextField`; this plan re-verifies those changes still line up and extends the same treatment to every other input widget.

**Why this keeps happening:** The theme says "no outline" in dark mode. A dozen shared widgets were copy-pasted from an early pattern that said `BorderSide.none`. Every time a developer checks the live app and adds an outline on the one specific field that is broken in front of them, it fixes that field but leaves every other field hidden behind the same silent default. The only cure is to stop fighting at the screen layer and make the default itself visible.

---

## Files touched

| File | Changes |
|------|---------|
| `lib/core/theme/app_theme.dart` | Rewrite `inputDecorationTheme` - visible outline on `border` and `enabledBorder` in both light and dark mode; stronger focused outline; explicit `errorBorder` / `focusedErrorBorder` / `disabledBorder`. |
| `lib/shared/widgets/inputs/z_text_area.dart` | Replace the two `BorderSide.none` borders with a visible outline matching `ZLabeledTextField` - this is the widget that renders "Describe what you ate". |
| `lib/shared/widgets/inputs/app_text_field.dart` | Re-verify the Plan 5 outline fix; keep it explicit so it cannot regress to theme inheritance silently. |
| `lib/shared/widgets/inputs/z_search_bar.dart` | Re-verify - already has an explicit outline; lock the intent with a comment. |
| `lib/shared/widgets/inputs/z_password_field.dart` | Re-verify - composes `AppTextField` and inherits its outline; no code change, audit only. |
| `lib/shared/widgets/inputs/z_labeled_text_field.dart` | Re-verify - already explicit; lock with a comment. |
| `lib/shared/widgets/inputs/z_labeled_number_field.dart` | Re-verify - already explicit; lock with a comment. |
| `lib/shared/widgets/inputs/z_otp_input.dart` | Keep the invisible driver `TextField` as is - justified exception (see Task 5). Add a block comment explaining the deliberate `InputBorder.none`. |
| `lib/shared/widgets/coach_input_bar.dart` | Keep the chat-bubble chrome and add an explicit outline on the outer container so the send/attach icons keep their layout. |
| `lib/features/nutrition/presentation/nutrition_rules_screen.dart` | Replace the inline `TextField` inside the Add Rule dialog with `ZTextArea` so it picks up the new outline automatically. |
| `lib/features/data/presentation/widgets/search_overlay.dart` | Replace the inline `TextField` with `ZSearchBar` (same look, built-in outline). |
| `lib/features/profile/presentation/emergency_card_edit_screen.dart` | Two hand-rolled `TextField` helpers (tag input and `_ContactField`). Add explicit visible outlines. |
| `lib/features/profile/presentation/profile_screen.dart` | Inline `TextField` for the name-edit row. Add an explicit visible outline. |
| `lib/features/progress/presentation/goal_create_edit_sheet.dart` | Rewrite the private `_inputDecoration` helper - the two `BorderSide.none` lines become visible outlines. |
| `lib/features/progress/presentation/journal_diary_screen.dart` | The full-screen diary field deliberately uses `InputBorder.none` for a chromeless writing surface - keep it, but add a block comment documenting the exception. |
| `lib/features/integrations/presentation/widgets/integrations_search_bar.dart` | Replace the bespoke `TextField` with `ZSearchBar`. |
| `lib/features/harness/harness_screen.dart` | Dev-only developer harness. Annotate the read-only log output's `InputBorder.none` as a deliberate exception. |

All paths relative to `zuralog/`.

---

## Pass 1 - Shared input widget inventory

The grep across `lib/shared/widgets/inputs/` returned 20 files. Only 8 of them render a text input; the rest are chips, toggles, calendars, sliders, radios, ratings, etc. Current state:

| Widget | Renders what | Current `border` | Current `enabledBorder` | Status |
|--------|--------------|------------------|-------------------------|--------|
| `app_text_field.dart` | `TextFormField` | Explicit outline (`colors.border`, Plan 5) | Explicit, same outline | OK - lock with comment |
| `z_labeled_text_field.dart` | `TextFormField` | Explicit outline (`colors.border`) | Explicit, same outline | OK - lock with comment |
| `z_labeled_number_field.dart` | `TextFormField` | Explicit outline (`colors.border`) | Explicit, same outline | OK - lock with comment |
| `z_search_bar.dart` | `TextFormField` | Explicit outline (`colors.border`) | Explicit, same outline | OK - lock with comment |
| `z_password_field.dart` | Wraps `AppTextField` | Inherited | Inherited | OK - no code change |
| `z_text_area.dart` | `TextFormField` | `BorderSide.none` | `BorderSide.none` | BROKEN - renders "Describe what you ate" |
| `z_otp_input.dart` | Hidden `TextField` overlay | `InputBorder.none` | n/a | Intentional invisibility - keep, annotate |
| `z_email_typo_suggestion.dart` | Chip only | n/a | n/a | Not a text input - skip |

The other 12 files (`z_calendar`, `z_checkbox`, `z_chip`, `z_number_stepper`, `z_password_requirements`, `z_radio_group`, `z_rating_bar`, `z_segmented_control`, `z_select`, `z_slider`, `z_toggle`, `z_toggle_group`) render no text input at all.

---

## Pass 2 - Bare `TextField` / `TextFormField` call sites outside the input folder

Grepped the entire Flutter codebase for direct `TextField(`, `TextFormField(`, `CupertinoTextField(`, and `EditableText(` outside `lib/shared/widgets/inputs/`. Findings:

| File | Line | What it is | Current border state | Fix |
|------|------|------------|----------------------|-----|
| `lib/shared/widgets/coach_input_bar.dart` | 350 | Coach chat input | `InputBorder.none`, outer `Container` has no border | Add visible border to the outer `Container.BoxDecoration` |
| `lib/features/harness/harness_screen.dart` | 1429 | Read-only log output | `InputBorder.none` | Dev harness; leave, annotate |
| `lib/features/harness/harness_screen.dart` | 1655 | `_StyledTextField` input | Explicit `OutlineInputBorder` with `_Colors.border` already | Already OK |
| `lib/features/data/presentation/widgets/search_overlay.dart` | 151 | Metrics search input | `BorderSide.none` on `border` + `enabledBorder` | Migrate to `ZSearchBar` |
| `lib/features/profile/presentation/emergency_card_edit_screen.dart` | 348 | Tag-entry inline input | `BorderSide.none` | Rewrite to visible outline |
| `lib/features/profile/presentation/emergency_card_edit_screen.dart` | 578 | `_ContactField` | `BorderSide.none` on `border` (no `enabledBorder`) | Rewrite to visible outline |
| `lib/features/profile/presentation/profile_screen.dart` | 366 | Name-edit inline input | `BorderSide.none` (no `enabledBorder`) | Rewrite to visible outline |
| `lib/features/nutrition/presentation/nutrition_rules_screen.dart` | 165 | Add-rule dialog textarea | `BorderSide.none` | Migrate to `ZTextArea` |
| `lib/features/onboarding/presentation/steps/name_step.dart` | 102 | Onboarding name step | No explicit border - relies on theme | Theme fix (Task 2) makes it correct automatically |
| `lib/features/progress/presentation/journal_diary_screen.dart` | 126 | Full-screen writing surface | `InputBorder.none` | Deliberate chromeless surface; annotate |
| `lib/features/progress/presentation/goal_create_edit_sheet.dart` | 519 / 552 / 575 | Title / Target / Unit | Go through `_inputDecoration` helper with `BorderSide.none` | Fix helper once - three fields benefit |
| `lib/features/integrations/presentation/widgets/integrations_search_bar.dart` | 51 | Integrations search | `BorderSide.none` | Migrate to `ZSearchBar` |

Total bare call sites: **13**. After this plan, the only ones that keep `InputBorder.none` are three deliberate exceptions (OTP invisible driver, read-only harness log, full-screen journal writing surface). Each exception is annotated in code.

---

## Pass 3 - Feature walkthrough audit

Walked every surface where the user types into an input and confirmed its path to an outline:

| Feature | Inputs encountered | Outline source after this plan |
|---------|--------------------|--------------------------------|
| Auth (Login, Register, Forgot, Reset) | `AppTextField` | Already explicit |
| Onboarding name step | Raw `TextFormField` | Theme default (Task 2) |
| Nutrition - Log meal popup - "Describe what you ate" | `ZTextArea` | Task 3 fix |
| Nutrition - Log meal popup - manual food fields | `ZLabeledTextField` + `ZLabeledNumberField` | Already explicit |
| Nutrition - Meal Review inline edit | `ZLabeledTextField` + `ZLabeledNumberField` | Already explicit |
| Nutrition - Meal Edit | `ZLabeledTextField` + `ZLabeledNumberField` | Already explicit |
| Nutrition - Walkthrough free-text questions | `ZTextArea` | Task 3 fix |
| Nutrition - Rules - Add rule dialog | Raw `TextField` | Migrated to `ZTextArea` (Task 6) |
| Today - Supplements / Run / Steps / Water / Wellness | `ZLabeledTextField` + `ZTextArea` | Already explicit / Task 3 |
| Today - Symptom, Sleep log notes | `ZTextArea` | Task 3 fix |
| Coach - chat input | Raw `TextField` with chat-bubble chrome | Outer container gains border (Task 8) |
| Settings - Account / Edit Profile | `AppTextField` | Already explicit |
| Profile - name edit | Raw `TextField` | Task 9 |
| Profile - Emergency card | Raw `TextField` x2 | Task 9 |
| Progress - Journal diary | Raw `TextField`, full-screen | Justified exception (Task 13) |
| Progress - Goal create/edit | `TextFormField` x3 via `_inputDecoration` | Task 10 |
| Data tab - search overlay | Raw `TextField` | Migrated to `ZSearchBar` (Task 11) |
| Integrations - search | Raw `TextField` | Migrated to `ZSearchBar` (Task 12) |
| Dev harness | `_StyledTextField` + log output | Already explicit / justified exception (Task 13) |

Zero surfaces remain without a visible outline path, except the three annotated exceptions.

---

## Task 1 - Capture current theme + widget state as ground truth

No code change - a verification step before touching anything. If the codebase has drifted since this plan was written, flag the drift.

- [ ] **Step 1.1** Open `lib/core/theme/app_theme.dart` and confirm `inputDecorationTheme` still sets `enabledBorder: isLight ? BorderSide(color: AppColors.borderLight) : BorderSide.none` (around lines 221-225). The `BorderSide.none` in dark mode is the root cause.

- [ ] **Step 1.2** Open `lib/shared/widgets/inputs/z_text_area.dart` and confirm lines 82 and 86 still pass `BorderSide.none`.

- [ ] **Step 1.3** Open `lib/shared/widgets/inputs/app_text_field.dart` and confirm the Plan 5 `unfocusedBorder` block (lines 126-129 and 151-152) is still in place.

- [ ] **Step 1.4** No commit. If any of the three assumptions above have changed, stop, update the plan, and re-plan.

**Verification:** If any assumption fails, halt and re-plan before executing.

---

## Task 2 - Fix the theme's `inputDecorationTheme` in both light and dark mode

**File:** `zuralog/lib/core/theme/app_theme.dart`

This is the foundation. Once this lands, every Material `TextField` / `TextFormField` that relies on theme defaults automatically picks up a visible outline. Two bugs today: dark mode's `enabledBorder` is `BorderSide.none`, and `errorBorder` / `focusedErrorBorder` lack parity. Fix both and add an explicit `disabledBorder`.

- [ ] **Step 2.1** Replace the `inputDecorationTheme: InputDecorationTheme(...)` block (currently lines 210-259) with a new block that sets every border state explicitly for both brightnesses:
  - `border` - `OutlineInputBorder` with `BorderRadius.circular(AppDimens.shapeSm)` (12 px) and `BorderSide(color: isLight ? AppColors.borderLight : AppColors.borderDark, width: 1)`.
  - `enabledBorder` - same outline as `border`. This is the critical line - in dark mode it must no longer be `BorderSide.none`.
  - `focusedBorder` - same radius, `BorderSide(color: isLight ? AppColors.primaryOnLight : AppColors.primary, width: 1.5)`.
  - `errorBorder` - same radius, `BorderSide(color: AppColors.error.withValues(alpha: 0.5), width: 1)`.
  - `focusedErrorBorder` - same radius, `BorderSide(color: AppColors.error, width: 1.5)`.
  - `disabledBorder` - same radius, `BorderSide(color: (isLight ? AppColors.borderLight : AppColors.borderDark).withValues(alpha: 0.5), width: 1)`.

- [ ] **Step 2.2** Keep `filled`, `fillColor`, `contentPadding`, `hintStyle`, and `labelStyle` unchanged.

- [ ] **Step 2.3** Add a block comment above the `inputDecorationTheme` assignment: "Every border state is set explicitly so no Material input anywhere in the app renders without a visible outline. Do not introduce BorderSide.none here - that was the dark-mode regression fixed by Phase 6 Plan 6."

- [ ] **Step 2.4** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 2.5** Commit: `fix(theme): give every Material input a visible outline in light and dark mode`

**Verification:** Hot-restart. The onboarding name step, which uses a bare `TextFormField` with no decoration of its own, now renders a visible 1 px border when empty in both modes. Tap it - the border thickens to the brand primary.

---

## Task 3 - Fix `ZTextArea` to render a visible outline

**File:** `zuralog/lib/shared/widgets/inputs/z_text_area.dart`

The widget behind the user's named complaint. Used by the log-meal popup ("Describe what you ate"), meal walkthrough free-text questions, supplements / run / sleep / symptom log notes - seven call sites fixed at once.

- [ ] **Step 3.1** In `build` (around lines 72-105), replace the two `OutlineInputBorder(..., borderSide: BorderSide.none)` blocks on `border` and `enabledBorder` with a single `unfocusedBorder` local matching `ZLabeledTextField`: `OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimens.shapeSm), borderSide: BorderSide(color: colors.border, width: 1))`. Pass `unfocusedBorder` to both `border` and `enabledBorder`.

- [ ] **Step 3.2** Keep `focusedBorder` as is - it already paints a primary-tinted outline on focus via `sageFocusBorder`.

- [ ] **Step 3.3** Add a one-line comment above the border assignments: `// Visible outline when empty - matches ZLabeledTextField. Do not set BorderSide.none here.`

- [ ] **Step 3.4** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 3.5** Commit: `fix(inputs): give ZTextArea a visible outline so "Describe what you ate" is no longer invisible`

**Verification:** Open Nutrition -> Log a meal -> Describe mode. The "Describe what you ate" box shows a clear grey outline when empty in both modes. Repeat on symptom / sleep / supplements logs.

---

## Task 4 - Re-verify `AppTextField` and lock the fix with a comment

**File:** `zuralog/lib/shared/widgets/inputs/app_text_field.dart`

Plan 5 added the explicit `unfocusedBorder` local. No functional change - make the intent undeletable by a future developer who thinks the explicit border is redundant.

- [ ] **Step 4.1** Above the `unfocusedBorder` local inside `build`, replace the existing comment with: `// EXPLICIT unfocused border - do not delete. The inputDecorationTheme would otherwise cover this, but having it here locally protects against any future theme change that forgets the dark-mode branch. Phase 6 Plan 6 locked this in.`

- [ ] **Step 4.2** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 4.3** Commit: `chore(inputs): lock AppTextField outline intent with an explanatory comment`

**Verification:** Pure comment - no runtime change.

---

## Task 5 - Audit the remaining shared input widgets

**Files:** `z_labeled_text_field.dart`, `z_labeled_number_field.dart`, `z_search_bar.dart`, `z_password_field.dart`, `z_otp_input.dart`

- [ ] **Step 5.1** `z_labeled_text_field.dart` - confirm `unfocusedBorder` / `focusedBorder` locals are present (lines 100-110). Add a one-line comment: `// Explicit outline - part of the Phase 6 Plan 6 guarantee.`

- [ ] **Step 5.2** `z_labeled_number_field.dart` - same check and same comment at lines 73-83.

- [ ] **Step 5.3** `z_search_bar.dart` - confirm lines 127-134 are still explicit. Add the same comment above the `InputDecoration` block.

- [ ] **Step 5.4** `z_password_field.dart` - add a one-line doc comment inside `build`: `// Inherits outline from AppTextField - see Phase 6 Plan 6.`

- [ ] **Step 5.5** `z_otp_input.dart` - the hidden driver `TextField` on line 193 uses `InputBorder.none` intentionally (wrapped in `Opacity(opacity: 0)` + `IgnorePointer`). Add a multi-line comment above the `InputDecoration`: `// Deliberate InputBorder.none - this TextField is invisible. The visible OTP chrome is the six _Slot boxes above. Phase 6 Plan 6 reviewed and kept this exception.`

- [ ] **Step 5.6** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 5.7** Commit: `chore(inputs): lock shared-input outline contract with comments and annotate OTP exception`

**Verification:** Pure comments - no runtime change. After this task, grep `BorderSide.none` inside `lib/shared/widgets/inputs/` shows only the annotated OTP lines.

---

## Task 6 - Migrate the nutrition rules Add-rule dialog to `ZTextArea`

**File:** `zuralog/lib/features/nutrition/presentation/nutrition_rules_screen.dart`

The dialog's inline `TextField` block (around lines 165-190) replicates what `ZTextArea` already provides - multi-line text, placeholder, character counter.

- [ ] **Step 6.1** Replace the `TextField(controller: controller, maxLength: 500, maxLines: 4, minLines: 2, ...)` block with `ZTextArea(controller: controller, placeholder: "e.g. I always use olive oil when cooking", maxLines: 4, minLines: 2, maxLength: 500)`.

- [ ] **Step 6.2** Remove the now-unused `InputDecoration`, `OutlineInputBorder`, `hintStyle`, `fillColor`, and `counterStyle` lines.

- [ ] **Step 6.3** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 6.4** Commit: `refactor(nutrition): add-rule dialog uses ZTextArea so it inherits the outline`

**Verification:** Nutrition -> Rules -> Add rule. The text area shows a visible outline when empty and a primary outline on focus, both modes.

---

## Task 7 - Named verification for "Describe what you ate"

**File:** `zuralog/lib/features/nutrition/presentation/log_meal_sheet.dart` (no code change - verification only)

The user explicitly named this field. It renders through `ZTextArea` at line 568. Task 3 fixes it. This task exists so the first surface the user opens after the plan lands is correct.

- [ ] **Step 7.1** Open `log_meal_sheet.dart` line 568 and confirm it still calls `ZTextArea(controller: _describeController, placeholder: "e.g. grilled chicken with rice and a side salad", minLines: 3, maxLines: 4)`. Do not change this.

- [ ] **Step 7.2** In the emulator, open Nutrition -> Log a meal. Confirm in both dark and light mode that the "Describe what you ate" box shows a visible grey outline when empty. Tap it - outline thickens to primary.

- [ ] **Step 7.3** No commit unless drift is found. If `log_meal_sheet.dart` no longer uses `ZTextArea` here, stop and re-plan.

**Verification:** The user's original complaint is resolved.

---

## Task 8 - Add a visible outline to the coach chat input

**File:** `zuralog/lib/shared/widgets/coach_input_bar.dart`

The chat input (around line 350) uses `TextField` with `InputBorder.none` because the visible chrome comes from the outer `Container`'s `BoxDecoration`. Today that decoration has no `border`, so the empty state blends into the canvas in dark mode.

- [ ] **Step 8.1** In the outer `Container` at lines 344-349, add `border: Border.all(color: colors.border, width: 1)` to the `BoxDecoration`. Keep `color: colors.inputBackground` and the existing radius.

- [ ] **Step 8.2** Keep `border: InputBorder.none` on the inner `TextField` - the outer container paints the chrome. Add a one-line comment: `// Outer Container paints the visible outline (see BoxDecoration above).`

- [ ] **Step 8.3** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 8.4** Commit: `fix(coach): give the chat input a visible outline on the outer pill`

**Verification:** Coach tab - empty message input shows a visible pill outline in both modes. Send / attach icons unchanged.

---

## Task 9 - Give profile and emergency-card inputs a visible outline

**Files:** `zuralog/lib/features/profile/presentation/profile_screen.dart`, `zuralog/lib/features/profile/presentation/emergency_card_edit_screen.dart`

Three hand-rolled `TextField`s set `BorderSide.none`. Swap for a visible outline.

- [ ] **Step 9.1** `profile_screen.dart` line 366 (`_NameEditRow`) - change `border: OutlineInputBorder(borderRadius: ..., borderSide: BorderSide.none)` to `borderSide: BorderSide(color: colors.border, width: 1)`. Add a matching `enabledBorder` block right after it with the same outline.

- [ ] **Step 9.2** `emergency_card_edit_screen.dart` line 369 (tag-entry input) - same change: swap `BorderSide.none` for `BorderSide(color: colors.border, width: 1)` on `border`, and add a matching `enabledBorder`.

- [ ] **Step 9.3** `emergency_card_edit_screen.dart` line 600 (`_ContactField`) - same pattern. Keep `focusedBorder` as is.

- [ ] **Step 9.4** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 9.5** Commit: `fix(profile): give profile name edit and emergency card inputs a visible outline`

**Verification:** Settings -> Profile -> tap name to edit - visible outline. Emergency Card edit screen - every tag input and contact field shows a visible outline when empty, both modes.

---

## Task 10 - Fix the goal-create sheet's private `_inputDecoration` helper

**File:** `zuralog/lib/features/progress/presentation/goal_create_edit_sheet.dart`

The helper at line 786-822 is used by three fields (Title, Target, Unit). It sets `BorderSide.none` on `border` and `enabledBorder`. Fix once - three fields benefit.

- [ ] **Step 10.1** In `_inputDecoration`, replace the `border: OutlineInputBorder(..., borderSide: BorderSide.none)` with `borderSide: BorderSide(color: colors.border, width: 1)`.

- [ ] **Step 10.2** Do the same on `enabledBorder`.

- [ ] **Step 10.3** Keep `focusedBorder`, `errorBorder`, `focusedErrorBorder` unchanged - they already have visible outlines.

- [ ] **Step 10.4** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 10.5** Commit: `fix(progress): goal-create sheet inputs render a visible outline`

**Verification:** Progress -> Goals -> Create new. Title, Target, Unit all show visible outlines when empty in both modes.

---

## Task 11 - Migrate the data-tab search overlay to `ZSearchBar`

**File:** `zuralog/lib/features/data/presentation/widgets/search_overlay.dart`

The inline `TextField` at line 151 duplicates `ZSearchBar`. Migrate for outline + code dedup.

- [ ] **Step 11.1** Replace the `TextField(...)` block with `ZSearchBar(controller: controller, placeholder: "Search metrics...", onChanged: the existing filter handler)`.

- [ ] **Step 11.2** Remove the inline `OutlineInputBorder` / `InputDecoration` / `suffixIcon` boilerplate.

- [ ] **Step 11.3** If the overlay needs `autofocus` and `ZSearchBar` does not support it today, add an optional `autofocus` parameter to `ZSearchBar` (forward to the inner `TextFormField`, default `false` so other call sites are unaffected).

- [ ] **Step 11.4** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 11.5** Commit: `refactor(data): data-tab search overlay uses ZSearchBar`

**Verification:** Data tab -> tap the search icon. Overlay input is the shared search bar with a visible outline in both modes.

---

## Task 12 - Migrate the integrations search bar to `ZSearchBar`

**File:** `zuralog/lib/features/integrations/presentation/widgets/integrations_search_bar.dart`

Same fix pattern as Task 11.

- [ ] **Step 12.1** Rewrite `build` to return a `Padding` wrapping `ZSearchBar(controller: _controller, placeholder: "Search integrations...", onChanged: widget.onChanged, onClear: _onClear)`.

- [ ] **Step 12.2** Remove the inline `InputDecoration`, manual `prefixIcon` / `suffixIcon` logic, and the direct `TextField`.

- [ ] **Step 12.3** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 12.4** Commit: `refactor(integrations): integrations search uses ZSearchBar`

**Verification:** Integrations hub - search input is the shared bar, visible outline in both modes, clear button behaves identically.

---

## Task 13 - Annotate the three deliberate chromeless exceptions

**Files:** `zuralog/lib/features/harness/harness_screen.dart`, `zuralog/lib/features/progress/presentation/journal_diary_screen.dart`

Two screens (plus the OTP widget already annotated in Task 5) keep `InputBorder.none` on purpose. Tag the intent so a future sweep does not "fix" them.

- [ ] **Step 13.1** `harness_screen.dart` line 1429 - read-only log output. Above the `TextField`, add: `// Dev harness log output - read-only, chrome comes from the outer Container's surface color. Outline intentionally omitted.`

- [ ] **Step 13.2** `harness_screen.dart` line 1655 - `_StyledTextField` already has a visible `OutlineInputBorder`. Leave unchanged.

- [ ] **Step 13.3** `journal_diary_screen.dart` line 126 - the full-screen writing surface. Above the `TextField`, add: `// Chromeless writing surface - the diary field fills the entire screen top to bottom; a visible outline here would be visual noise. Phase 6 Plan 6 reviewed and kept this exception.`

- [ ] **Step 13.4** Run: `cd c:/Projects/Zuralog/zuralog && flutter analyze`.

- [ ] **Step 13.5** Commit: `docs(inputs): annotate deliberate chromeless text inputs so they are not "fixed" later`

**Verification:** Comments only.

---

## Task 14 - Final verification sweep

- [ ] **Step 14.1** `cd c:/Projects/Zuralog/zuralog && flutter analyze` - zero errors, zero warnings.

- [ ] **Step 14.2** `cd c:/Projects/Zuralog/zuralog && flutter test` - passes.

- [ ] **Step 14.3** `cd c:/Projects/Zuralog/zuralog && flutter build apk --debug` - succeeds.

- [ ] **Step 14.4** Grep the codebase one last time:
  - `rg "BorderSide\.none" zuralog/lib` - every remaining hit must be one of (a) the OTP hidden driver, (b) the `z_otp_input.dart` slot-divider helper, (c) a `Chip` or other non-input widget, (d) an annotated exception. Zero new hits under `lib/shared/widgets/inputs/` besides the annotated OTP lines.
  - `rg "InputBorder\.none" zuralog/lib` - every hit is one of (a) `coach_input_bar.dart` (outer Container paints the outline), (b) `journal_diary_screen.dart` (annotated), (c) `harness_screen.dart` log output (annotated), (d) OTP hidden driver (annotated).

- [ ] **Step 14.5** Manual emulator sweep in dark mode across every Pass 3 surface (auth, onboarding name, all log screens, log-meal popup, rule dialog, goal create, profile edit, emergency card edit, data tab search, integrations search, coach chat). Every empty text input shows a visible grey outline; focus paints the brand primary. Repeat in light mode.

- [ ] **Step 14.6** Invoke the `docs` subagent to append under today's date in `docs/implementation-status.md`: "Phase 6 Plan 6 - global visible outline on every text input; theme + every shared input widget patched; all bare TextField / TextFormField usages outside the shared library audited." Then the `git` subagent commits the docs change.

---

## Definition of done

- [ ] `inputDecorationTheme` in `app_theme.dart` sets `border`, `enabledBorder`, `focusedBorder`, `errorBorder`, `focusedErrorBorder`, `disabledBorder` explicitly in both brightnesses.
- [ ] No `BorderSide.none` survives anywhere in `lib/shared/widgets/inputs/` except the annotated OTP hidden driver lines.
- [ ] `ZTextArea` has a visible outline on `border` and `enabledBorder` that matches `ZLabeledTextField`.
- [ ] `AppTextField`, `ZLabeledTextField`, `ZLabeledNumberField`, `ZSearchBar` each carry an explicit lock comment so the outline contract cannot be silently removed.
- [ ] `ZPasswordField` inherits cleanly from `AppTextField`; annotated accordingly.
- [ ] Coach chat input renders a visible outline via its outer `Container`'s `BoxDecoration.border`.
- [ ] Nutrition rules Add-rule dialog uses `ZTextArea` - no hand-rolled `TextField`.
- [ ] Data-tab search overlay uses `ZSearchBar`.
- [ ] Integrations search uses `ZSearchBar`.
- [ ] Goal create/edit sheet's `_inputDecoration` helper sets a visible outline on `border` and `enabledBorder`.
- [ ] Profile name-edit row and emergency-card text inputs render a visible outline.
- [ ] Journal diary full-screen writing surface, harness log output, and OTP hidden driver are each annotated as deliberate exceptions.
- [ ] The "Describe what you ate" box shows a visible outline in both light and dark mode.
- [ ] `flutter analyze`, `flutter test`, and `flutter build apk --debug` all pass clean.
- [ ] `docs/implementation-status.md` records the plan's completion.

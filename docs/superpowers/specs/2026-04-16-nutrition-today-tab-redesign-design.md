# Nutrition Feature + Today Tab Redesign

**Date:** 2026-04-16
**Updated:** 2026-04-17 (Phase 4: Meal Review dialog, time picker, edit flow, AI prompt improvements, mode persistence)
**Status:** Active — implementation in progress
**Author:** Hyowon + Claude
**Type:** Information architecture change + new feature
**Scope:** Mobile app (Flutter) + backend (FastAPI) + database (Supabase)

---

## What we are building

We are adding a **Nutrition** feature to ZuraLog and **redesigning the Today tab** around four health pillars: Sleep, Nutrition, Workouts, and Heart. At the same time, we are simplifying the bottom navigation bar from five tabs to three.

The Nutrition feature uses an **AI-first approach** — food data comes from AI estimation first, with results cached in our own database. We do not depend on a commercial food database vendor. Over time, the cache grows into ZuraLog's own proprietary food database built from real user queries.

This document covers everything needed to build this, broken into clear phases: what the user sees (frontend), what the server does (backend), and what the database stores.

---

## Decisions made

These decisions were reached through brainstorming and are final for this spec:

### Navigation and layout
1. **Tab name stays as "Today"** — it reminds users this is a daily snapshot, not a static home page
2. **Bottom nav goes from 5 tabs to 3** — Today, Data, Coach. No Profile tab.
3. **Progress and Trends move into Settings** — they are not deleted, just re-parented in the navigation. All existing code stays where it is on disk.
4. **Nutrition lives on the Today tab** as one of four pillar cards, plus its own set of screens
5. **Pillar cards are compact** — each card is roughly the same height as the Health Score + Streak row. Not large hero cards.
6. **Sleep, Workouts, Heart pillar cards are UI-only for now** — they display today's data but their dedicated home screens are future work. Tapping them goes to the existing Data tab as a placeholder.
7. **Achievements and Weekly Report move to Settings** alongside the rest of Progress
8. **Journal gets a shortcut on Today** — a small prompt card for daily writing
9. **Goals & Streaks stay on Today** — they already have a section there; no relocation needed
10. **Greeting row and Metrics Grid are removed** — the four pillar cards replace them
11. **Data Maturity Banner is removed** — each pillar card handles its own empty/building state internally

### Nutrition feature scope
12. **Nutrition Score is deferred** — meals are logged with foods, portions, calories, and macros, but no quality score for now
13. **Four logging methods** — Describe/Manual (text-based), Camera (photo/barcode/label), Search (database lookup), and Recents (one-tap re-log)
14. **History and Insights screens are deferred** — Nutrition launches with: Nutrition Home, LogMealSheet, and Meal Detail
15. **Glucose monitor integration is out of scope**

### AI-first food data strategy (resolved — was an open question)
16. **No commercial food database vendor** — we use AI estimation as the primary source of nutritional data, with results cached in the `food_cache` table. This is 20x cheaper than Nutritionix ($110/month vs $2,000+/month at 1M lookups) and handles international foods that no database covers.
17. **AI model for food parsing: Qwen 3.5 Flash via OpenRouter** — the cheaper/faster insight model, not the expensive coach model. Stateless one-shot calls.
18. **Vision model: Gemini** — for camera-based food recognition and nutrition label reading. Native multimodal capabilities.
19. **The food_cache table is the unifying data layer** — stores AI estimates, USDA-seeded foods, barcode lookups, and user-corrected values. Over time it becomes ZuraLog's own food database.
20. **USDA FoodData Central seeding** — one-time import of ~10,000 common foods from the USDA bulk download. Pre-populates the food cache so search works for new users from day one. No runtime API calls to USDA.
21. **Barcode scanning uses Open Food Facts** — free, 4M+ products, 150+ countries. Results cached in food_cache. If barcode not found, user is prompted to take a photo of the food or label instead.

### Smart logging features (AI-first advantages)
22. **Two logging modes: Quick and Guided** — a segmented control on the Log Meal screen lets the user switch per-meal. Quick mode: AI does everything silently. Guided mode (default): AI asks smart follow-up questions to improve accuracy.
23. **Interactive refinement in Guided mode** — the AI asks up to two follow-up questions per food item when they would meaningfully change the calorie count:
    - **Portion size**: XS / S / M / L / XL selector (the AI determines what each size means for that food)
    - **Cooking method**: horizontal chips with relevant options (e.g., Scrambled / Fried / Boiled / Poached for eggs). Only shown when cooking method changes calories significantly. Skipped for raw foods, bread, drinks, etc.
24. **Confidence scoring (internal only)** — the AI assigns a confidence score (0.0-1.0) to each parsed food item. This drives question selection in Guided mode (low confidence = more questions). Not shown to the user. Architecture is ready for future UI exposure if needed.
25. **Correction learning** — when users edit AI estimates before saving, the corrections feed into a weighted average over time. The cached value for that food gradually improves as more users provide corrections.
26. **Correction abuse protection** — two layers:
    - **Bounds checking**: corrections more than 3x or less than 0.3x the AI's original estimate are rejected from the learning system (the user's personal meal still saves with their number, but it doesn't affect the shared cache)
    - **Minimum threshold**: the cache value doesn't change until at least 5 different users have independently corrected the same food

### Nutrition Rules system
27. **Persistent user rules** — users can set rules that give the AI permanent context, eliminating repetitive Guided mode questions. Examples:
    - "I always use oil spray for cooking"
    - "I always use large eggs"
    - "My rice portions are always 1 cup cooked"
    - "I'm vegetarian"
28. **Rules injected into every AI prompt** — parse, vision, and guided question prompts all include the user's rules as context. The AI adapts its estimates and skips questions that rules already answer.
29. **When rules answer all Guided questions** — the AI auto-completes and shows a quick notification ("Your rules covered everything") instead of asking questions. Guided effectively becomes Quick when rules are comprehensive enough.
30. **Rules managed from Nutrition Home** — a "Rules" button/chip in the Nutrition Home header. Opens a simple list editor where users add, edit, or delete rules. Unlimited rules allowed.

### Deferred features (future work)
31. **Smart suggestions** (AI predicts "your usual breakfast?" based on time + history) — deferred, needs weeks of user data to be useful
32. **Meal templates** (one-tap recurring meals) — deferred, same reason
33. **Nutrition Score** — deferred
34. **Macro targets / goal-setting** — deferred to v2

---

## Today tab layout (top to bottom)

After the redesign, scrolling down the Today tab looks like this:

| Position | Section | What it shows |
|----------|---------|---------------|
| 1 | Health Score + Streak | Compact row — score ring on the left, streak flame on the right |
| 2 | Sleep card | Last night's duration, quality label, bed/wake times, deep sleep |
| 3 | Nutrition card (new) | Meals logged today as chips, calorie total, macros (P/C/F), "+" to log a meal |
| 4 | Workouts card | Today's activity — workout headline, steps, active minutes, calories burned |
| 5 | Heart card | Resting heart rate, HRV, sparkline trend, comparison to average |
| 6 | Daily Goals | Progress bars for active goals (existing widget, already on Today) |
| 7 | Journal Prompt (new) | Small tappable card — "How's your day going?" Opens journal entry screen |
| 8 | AI Briefing | Coach's daily summary, ties all four pillars together. "Talk to Coach" link. |

### What is removed from Today

- **Greeting row** — the pillar cards themselves tell the story of the day
- **My Metrics Grid** — redundant now that the four pillar cards show the same data, and the FAB handles quick logging
- **Data Maturity Banner** — each pillar card handles its own empty state internally (e.g. "No sleep data yet — connect a device")

### Pillar card design pattern

All four pillar cards follow the same compact layout using the `ZPillarCard` shared widget:

```
+------------------------------------------------------+
|  [Icon]  LABEL    context          Secondary stats   |
|          Headline number           stacked right      |
+------------------------------------------------------+
```

- **Left**: 44x44 icon with tinted background matching the pillar color
- **Middle**: Category label (uppercase, colored), then headline stat below
- **Right**: 2-3 secondary stats stacked vertically
- **Height**: ~80-90px, matching the Health Score row
- **Colors**: Sleep = `categorySleep` (#5E5CE6), Nutrition = `categoryNutrition` (#FF9F0A), Workouts = `categoryActivity` (#30D158), Heart = `categoryHeart` (#FF375F)
- **Card variant**: `ZuralogCard(variant: feature, category: categoryColor)` — includes brand pattern overlay
- **Icons**: Material Icons only (no emojis)

The Nutrition card is the only one that is slightly taller because it includes a meal chips row with a "+" button below the main stat row. The Nutrition card reads from live providers (`todayMealsProvider`, `nutritionDaySummaryProvider`) and handles the empty state ("Log a meal" prompt when no meals logged).

### Pillar card tap behavior

- **Sleep**: navigates to the Data tab (placeholder until Sleep Home is built)
- **Nutrition**: navigates to the new Nutrition Home screen
- **Workouts**: navigates to the Data tab (placeholder until Workouts Home is built)
- **Heart**: navigates to the Data tab (placeholder until Heart Home is built)

---

## Navigation changes

### Bottom bar

**Before:** Today - Data - Coach - Progress - Trends (5 tabs)
**After:** Today - Data - Coach (3 tabs)

The floating frosted-glass pill bar in `app_shell.dart` gets updated from five entries to three. The FAB (log sheet trigger) stays.

### Where Progress goes

Everything from the Progress tab moves into Settings as a new "Your Progress" section:

- Progress & Goals (goals, streaks, achievements, weekly report)
- Trends & Patterns (correlations, insights over time)

These screens are not moved on disk. The existing widgets under `features/progress/` and `features/trends/` are mounted from Settings routes instead of from bottom tabs.

### Where Journal goes

Journal keeps its existing location under `features/progress/` on disk. It gets two entry points:
1. The new Journal Prompt card on the Today tab (quick access)
2. Accessible through the Progress & Goals section in Settings

---

## The Nutrition feature

### Screen inventory

| Screen | Purpose | Reached from |
|--------|---------|-------------|
| Nutrition card (widget) | Compact summary on Today tab, reads from providers | Rendered inline on Today |
| Nutrition Home | Full daily view — all meals, macros, calorie total, log button, rules access | Tapping the Nutrition card |
| Log Meal sheet | Input screen: scan food, search, describe/manual, recents. Quick/Guided toggle persisted. | Tapping "Log meal" on Nutrition Home or "+" on the Nutrition card |
| Meal Review screen | Full-screen interactive review of AI-parsed foods with editing, refinement, meal type, time picker, save | Triggered by any AI action (describe parse, camera, barcode) |
| Meal Detail | Individual meal view — foods, portions, macros, inline edit, delete | Tapping a meal from Nutrition Home or after logging |
| Meal Edit dialog | Pre-filled manual edit of an existing meal's name, foods, macros, type, and time | "Edit" button on Meal Detail |
| Nutrition Rules | List editor for persistent AI context rules | "Rules" button on Nutrition Home header |

### Nutrition Home screen

The Nutrition Home screen opens when the user taps the Nutrition card on Today. It has four jobs: show what you ate today, show the daily calorie and macro totals, make it easy to log the next meal, and provide access to nutrition rules.

**Layout (top to bottom):**

1. **Header** — "Nutrition" title, today's date, "Rules" chip/icon button in the header
2. **Daily summary card** — total calories, protein, carbs, fat displayed as four inline stats inside a feature-variant card with nutrition amber pattern
3. **Today's meals** — list of meal cards, each showing meal name, meal type (breakfast/lunch/dinner/snack), time, calorie count. Tapping a meal opens Meal Detail.
4. **Log a meal button** — large, prominent CTA at the bottom. Opens the Log Meal sheet.

**Empty state:** When no meals are logged yet, the screen shows an inviting message ("No meals logged yet") with a prominent log button. No guilt, no pressure.

**Polish:** Loading skeletons (matching content shapes), pull-to-refresh, staggered entrance animations (ZFadeSlideIn).

### Log Meal sheet

A bottom sheet rendered above the bottom navigation bar (via `useRootNavigator: true`). This is the **input-only** screen — it collects what the user wants to log. All review, editing, and saving happens in the Meal Review screen.

The Quick/Guided mode preference is **persisted** across sessions so the user doesn't have to pick every time.

**Layout (top to bottom):**

1. **Quick / Guided toggle** — `ZSegmentedControl`. Preference saved to local storage.
2. **Meal type chips** — auto-suggested by time of day (before 10am = breakfast, 10-14 = lunch, 14-17 = snack, after 17 = dinner). Can be changed later in Meal Review.
3. **Scan food section** (primary) — three buttons: Camera, Photos, Barcode
   - Camera: opens device camera via `image_picker`, sends photo to backend vision endpoint → opens **Meal Review screen**
   - Photos: opens gallery picker, same flow
   - Barcode: opens `mobile_scanner` overlay, looks up Open Food Facts → opens **Meal Review screen**
4. **Search section** — `ZSearchBar` searching the food_cache (USDA + cached foods). Results shown below. Tapping a result adds it directly to the meal being built (no Meal Review — it's a known food with verified data).
5. **OR divider**
6. **Describe / Manual section** (secondary)
   - Describe: text area + "Parse with AI" button → opens **Meal Review screen**
   - Manual: toggle to enter food name + calories + macros directly. "Add food" adds to the meal being built.
   - Advanced manual toggle: expands to show additional fields (fiber, sodium, sugar, saturated fat)
7. **Recents row** — horizontal scroll of recent foods as one-tap chips. Tapping adds directly to the meal being built.
8. **Food list** — shows manually added and search-added foods (not AI-parsed — those go through Meal Review). Only visible when foods have been added via search/manual/recents.
9. **Save button** — only shown when food list has items AND no AI path was used. For AI paths, saving happens in the Meal Review screen.

### Meal Review screen (NEW)

A full-screen pushed route that opens whenever AI is involved in parsing food. This is the interactive review experience that replaces the old "results appear in a flat list" pattern.

**When it opens:**
- After "Parse with AI" returns results from the describe path
- After the camera/gallery vision model returns results
- After a barcode scan finds a product

**Three phases:**

**Phase 1 — Analyzing (loading)**
Not a spinner — an engaging branded loading state:
- Shows what the user submitted (their text description as a quote, or a thumbnail of their photo)
- Animated progress using the nutrition amber color and brand pattern
- Status text that updates: "Reading your description..." → "Identifying foods..." → "Estimating nutrition..."
- Takes 1-5 seconds depending on the input type

**Phase 2 — Results ("Here's what I found")**
Foods appear one by one with staggered `ZFadeSlideIn` animation:
- Each food gets its own card showing:
  - Food name (prominent)
  - Portion amount and unit
  - Compact macro display: calories / P / C / F
  - Confidence indicator (green dot = high confidence, amber = estimated)
  - Edit icon to tap and adjust values inline
- In **Guided mode**: refinement questions appear under each food card:
  - Portion size: XS / S / M / L / XL chips (multipliers: 0.5x, 0.75x, 1.0x, 1.5x, 2.0x)
  - Cooking method: relevant chips (only when confidence < 0.8 and food is cookable)
  - Items covered by rules: subtle "Covered by your rules" label instead of questions
  - If ALL items are high-confidence (rules covered everything): toast notification + skip refinement
- In **Quick mode**: no refinement questions, just results with edit icons
- **Total summary card** at the bottom — combined calories, protein, carbs, fat. Updates live as user adjusts.

**Phase 3 — Save ("Confirm your meal")**
Below the food list and total:
- **Meal type chips** — pre-filled from LogMealSheet selection, editable here
- **Time picker** — defaults to current time, shown as "3:21 PM" with an edit icon. Tapping opens a time picker dialog. This solves the "forgot to log earlier" use case.
- **"Save meal" button** — large CTA
- After saving: success animation, dialog dismisses, LogMealSheet also closes, providers invalidated, back to wherever the user came from

### Meal Detail screen (updated)

Shown after logging a meal or when tapping an existing meal from any list.

**Layout:**
1. **Meal header card** — meal name, meal type icon + label, time. Feature-variant card with nutrition pattern.
2. **Foods list** — each food item with its portion and calorie/macro breakdown in data-variant cards
3. **Totals card** — summed calories, protein, carbs, fat for the whole meal. Feature-variant card.
4. **Edit button** — opens a **Meal Edit dialog** (pre-filled with the meal's current data: name, foods with macros, meal type, time). User can change any field and save.
5. **Delete button** — confirmation dialog, then soft-delete

### Meal Edit dialog (NEW)

A full-screen pushed route for editing an existing meal. Pre-filled with the meal's current values.

**Layout:**
1. **Header** — "Edit meal" title
2. **Meal name** — editable text field, pre-filled
3. **Meal type chips** — pre-selected to current type
4. **Time picker** — showing current meal time, editable
5. **Foods list** — each food shown with editable name, calories, protein, carbs, fat fields. Delete button per food. "Add food" button at the bottom for manual additions.
6. **Save changes button** — calls `PUT /nutrition/meals/{id}`, invalidates providers, pops back to Meal Detail

### Nutrition Rules screen

Accessible from the "Rules" button on the Nutrition Home header. A simple list editor.

**Layout:**
1. **Header** — "Nutrition Rules" title, "Add rule" button
2. **Rules list** — each rule displayed as a text card with edit and delete actions
3. **Add/Edit rule** — simple text input dialog: "Describe your rule in plain language"
4. **Empty state** — "No rules yet. Rules help the AI understand your preferences so it asks fewer questions."

**Examples shown to the user:**
- "I always use oil spray for cooking"
- "I always use large eggs"
- "My rice portions are always 1 cup cooked"

Rules are stored per-user and injected into every AI prompt (parse, vision, guided).

### What we are explicitly not building in this version

- Nutrition Score (quality rating per meal)
- History screen (past days)
- Insights screen (AI patterns about eating habits)
- Recipe builder
- Meal plans
- Water tracking (already handled separately)
- Micronutrient deep-dive (basic manual mode covers calories + P/C/F; advanced mode adds fiber, sodium, sugar, saturated fat)
- Glucose monitor integration
- Calorie/macro targets or goal-setting for nutrition
- Smart suggestions (AI predicts your usual meals)
- Meal templates (one-tap recurring meals)

---

## AI-first food data architecture

### Why AI-first instead of a commercial food database

We researched all major food database vendors (Nutritionix, Edamam, FatSecret, USDA, Open Food Facts, Spoonacular, API Ninjas) and concluded that an AI-first approach best fits ZuraLog's philosophy and economics:

| Factor | Commercial database | AI-first + cache |
|--------|-------------------|------------------|
| Cost at 1M lookups/month | $300-2,000+/month | ~$110/month (dropping as cache fills) |
| International food coverage | Limited (US-focused except FatSecret) | Handles any food from any culture |
| Foods not in the database | Returns nothing | AI estimates it anyway |
| Consistency | Perfect (same food = same numbers) | Perfect after first lookup (cached) |
| Accuracy | Lab-verified for known foods | ~80% accurate (within 20% of lab values) |
| Dependency | Vendor lock-in, pricing changes | Self-owned, no vendor dependency |

### How food data flows

**Search path (database only):**
```
User types food name in search bar
  --> Query food_cache (GIN trigram fuzzy match)
  --> Found: return cached result instantly
  --> Not found: show "No results found"
```

**Describe path (AI-powered):**
```
User types meal description
  --> POST /meals/parse (AI estimates nutrition per food item)
  --> User reviews, edits, confirms
  --> Meal saved to database
```

**Camera path (vision-powered):**
```
User takes photo
  --> Auto-detect: food plate / barcode / nutrition label
  --> Food plate: Gemini vision estimates nutrition
  --> Barcode: Open Food Facts lookup, cache result
  --> Nutrition label: Gemini reads actual numbers
  --> User reviews, confirms
```

### USDA cache seeding

One-time bulk import of ~10,000 common foods from USDA FoodData Central (free, public domain, lab-analyzed). Downloaded as a file, imported via a script into the `food_cache` table with `external_id = "usda:{fdc_id}"` and `metadata = {"source": "usda"}`. This ensures search works for new users from day one without any AI calls.

### Correction learning flow

```
User edits AI estimate before saving (e.g., changes 150 kcal to 200 kcal)
  --> Bounds check: is 200 between 0.3x and 3x of 150? Yes (45-450 range)
  --> Store correction as a data point
  --> Check: do 5+ unique users have corrections for this food? If yes:
      --> Recompute weighted average of all corrections
      --> Update the food_cache entry with the improved value
  --> User's personal meal saves with their edited number regardless
```

### The food_cache table as the unifying layer

The `food_cache` table stores results from ALL sources. The `metadata` JSONB column tracks the source:

```json
{"source": "usda", "fdc_id": "171705"}
{"source": "ai_estimated", "model": "qwen/qwen3.5-flash", "confidence": 0.85}
{"source": "ai_vision", "model": "gemini-2.0-flash", "confidence": 0.72}
{"source": "openfoodfacts", "barcode": "5901234123457"}
{"source": "user_corrected", "correction_count": 7, "original_ai_estimate": 150}
```

---

## Privacy and safety

Food data is sensitive. People with eating disorders, body image issues, or restrictive diets can be harmed by careless nutrition UI. We take this seriously.

**What we will not do:**
- Show calorie totals as "deficit" or "surplus." No "you have 412 calories left today." That framing reinforces restriction.
- Tell users anything is "bad." A low-quality meal gets neutral language, never shame.
- Push notifications about unlogged meals. If the user forgets to log dinner, that is fine.
- Show before/after weight in the Nutrition feature. Weight stays in the Data tab, deliberately separate.

**What we will do:**
- A clear, one-tap path to delete any logged meal
- A clear path to delete all nutrition data under Settings -> Privacy
- Photo data belongs to the user. We do not use it for training. Deleted when the meal is deleted.
- Neutral, encouraging language everywhere. "Room for more vegetables" not "bad meal."
- Nutrition Rules are private per-user and never shared or used for training.

---

## Implementation Phases

### Phase 1 — Frontend (Flutter) -- COMPLETED

**1A. Navigation changes** -- DONE
**1B. Today tab redesign** -- DONE
**1C. Nutrition screens** -- DONE
**1D. Frontend polish** -- DONE

### Phase 2 — Backend (FastAPI) + Database (Supabase) -- COMPLETED

**2A. Database schema** -- DONE (5 tables: meals, meal_foods, food_cache, nutrition_daily_summaries, food_corrections)
**2B. Meal CRUD API** -- DONE (7 endpoints)
**2C. AI meal parsing** -- DONE (POST /meals/parse with Qwen 3.5 Flash)
**2D. AI-first food search + correction learning** -- DONE (search, corrections, confidence scoring)
**2E. Frontend wiring** -- DONE (real API repo, LogMealSheet with Quick/Guided, providers)

### Phase 3 — Enhanced Logging + Data Seeding -- COMPLETED

**3A. Quick fixes** -- DONE
- LogMealSheet renders above nav bar via useRootNavigator
- Food search endpoint is database-only (no AI fallback)
- Daily summary upsert constraint fix
- Rules screen crash fix

**3B. Manual entry + USDA cache seeding** -- DONE
- Manual food entry mode with proper ZButton toggle
- USDA FoodData Central import (249 foods) into food_cache
- Seed script as Celery task + standalone command

**3C. Camera logging** -- DONE
- Camera + gallery integration via image_picker
- Gemini vision model for food/label recognition via OpenRouter
- Barcode scanning via mobile_scanner + Open Food Facts
- Auto-detection (food vs barcode vs label)

**3D. Nutrition Rules** -- DONE
- nutrition_rules table with CRUD endpoints
- Rules editor screen accessible from Nutrition Home
- Rules injected into parse + vision AI prompts
- Auto-skip Guided refinement when rules cover everything

### Phase 4 — Meal Review Experience + UX Polish -- IN PROGRESS

**4A. Meal Review screen** -- PLANNED
- Full-screen interactive review dialog for AI-parsed foods
- Three phases: Analyzing (animated loading) → Results (food cards with editing) → Save (meal type + time + confirm)
- Guided mode refinement inline (portion, cooking method)
- Live-updating total summary
- Success animation on save

**4B. LogMealSheet simplification** -- PLANNED
- Remove food list and save button for AI paths (moved to Meal Review)
- Keep food list + save for non-AI paths (search, manual, recents)
- Persist Quick/Guided mode preference
- Section reorder: scan → search → describe/manual

**4C. Time picker + Edit meal flow** -- PLANNED
- Time picker on Meal Review screen and Meal Edit dialog
- Meal Edit dialog (pre-filled manual edit of existing meals)
- Update Meal Detail "Edit" button to open Meal Edit dialog

**4D. AI prompt improvements** -- PLANNED
- Tune parse prompt to not assume quantities not mentioned (e.g., "toast" = 1 slice, not 2)
- Better portion estimation guidance in system prompt
- Add explicit instruction: "Only use the quantities the user specified. Do not assume multiples."

---

## Open questions

1. **Macro targets** — do we eventually want users to set daily calorie/protein/carb/fat goals? Decision can wait for v2.

Previously open, now resolved:
- ~~Food database vendor~~ — Resolved: AI-first approach with food_cache, no commercial vendor
- ~~AI model for parsing~~ — Resolved: Qwen 3.5 Flash via OpenRouter (insight model)
- ~~AI model for vision~~ — Resolved: Gemini (native multimodal)

---

## What this spec does NOT cover

- Building dedicated home screens for Sleep, Workouts, or Heart pillars (future work)
- Nutrition Score or meal quality rating (deferred)
- History or Insights screens for nutrition (deferred)
- Glucose monitor integration (out of scope)
- Smart suggestions or meal templates (needs user history data)
- Moving any files on disk — all relocations are navigation-only
- Deleting any existing screens, providers, or tests

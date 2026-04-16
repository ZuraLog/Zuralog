# Nutrition Feature + Today Tab Redesign

**Date:** 2026-04-16
**Updated:** 2026-04-17 (Phase 3 scope: camera logging, manual entry, nutrition rules, USDA seeding, bug fixes)
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
| Log Meal sheet | Four logging paths: Describe/Manual, Camera, Search, Recents. Quick/Guided toggle. | Tapping "Log meal" on Nutrition Home or "+" on the Nutrition card |
| Meal Detail | Individual meal view — foods, portions, macros, edit/delete | Tapping a meal from Nutrition Home or after logging |
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

A bottom sheet rendered **above the bottom navigation bar** (not behind it). Has a **Quick / Guided** segmented control at the top.

**Four logging paths:**

**1. Describe / Manual (text-based)**
One section with two modes. Default is "Describe" — user types a natural sentence like "two scrambled eggs, a slice of sourdough toast with butter, and a coffee with oat milk." This is sent to the AI parse endpoint, which returns structured foods.

A "Enter nutrition manually" link toggles to Manual mode — a simple form with food name, calories, protein, carbs, fat fields. No AI involved. For users who know their numbers.

- **Quick mode**: Parsed/entered result appears as an editable list. No follow-up questions.
- **Guided mode**: AI presents follow-up questions for items where accuracy would improve (portion size, cooking method). User's Nutrition Rules are injected into the AI prompt, so questions already answered by rules are skipped. If rules cover everything, a toast notification says "Your rules covered everything — no questions needed."

**2. Camera (photo-based, three-in-one)**
Opens the device camera full-screen or the photo gallery. The system auto-detects what it's looking at:

- **Plate of food** — Gemini vision model identifies the food items and estimates nutrition. Same review/confirm flow as Describe.
- **Barcode** — detected on-device using a barcode scanner library (not the vision model). Looked up in Open Food Facts. If found, shows the product with nutrition data. If not found, prompts "Barcode not found — try taking a photo of the food or nutrition label instead."
- **Nutrition label** — Gemini reads the structured nutrition facts panel and extracts the actual numbers (calories, protein, carbs, fat). More accurate than estimation. User provides the food name.

Quick/Guided modes apply to camera results the same way as Describe results.

**3. Search (database only)**
User types a food name. Searches the `food_cache` table only (USDA-seeded data + previously cached foods + user history). No AI involved in search — this is a pure database lookup. If nothing matches, shows "No results found." User can add multiple foods to the meal before saving.

**4. Recents**
Horizontal scroll of the user's most recently logged unique foods as one-tap chips. Tapping adds that food to the current meal immediately.

**Meal type selection:** Before saving, the user picks a meal type (breakfast/lunch/dinner/snack) via chips. Auto-suggested based on time of day.

**Save flow:** Saves via `POST /nutrition/meals`. If user edited food values, corrections are submitted. Sheet dismisses, providers invalidated.

### Meal Detail screen

Shown after logging a meal or when tapping an existing meal from any list.

**Layout:**

1. **Meal header card** — meal name, meal type icon + label, time. Feature-variant card with nutrition pattern.
2. **Foods list** — each food item with its portion and calorie/macro breakdown in data-variant cards
3. **Totals card** — summed calories, protein, carbs, fat for the whole meal. Feature-variant card.
4. **Edit / Delete buttons** — edit navigates to the existing meal log screen (placeholder), delete shows confirmation dialog with soft-delete

**Polish:** Loading skeletons, staggered entrance animations.

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
- Micronutrient deep-dive
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

### Phase 3 — Enhanced Logging + Data Seeding -- IN PROGRESS

**3A. Quick fixes** -- PLANNED
- LogMealSheet renders above the bottom nav bar (padding fix)
- Remove AI fallback from food search endpoint (search = database only)

**3B. Manual entry + USDA cache seeding** -- PLANNED
- Manual food entry mode in the Describe section of LogMealSheet
- One-time USDA FoodData Central import (~10,000 foods) into food_cache
- Import script as a Celery task or management command

**3C. Camera logging** -- PLANNED
- Camera integration in LogMealSheet (take photo or upload from gallery)
- Gemini vision model for food recognition and nutrition estimation
- Barcode scanning with on-device detection + Open Food Facts lookup
- Nutrition label reading via Gemini
- Auto-detection (food vs barcode vs label)
- Quick/Guided modes apply to camera results

**3D. Nutrition Rules** -- PLANNED
- nutrition_rules table (per-user, text-based rules)
- Rules CRUD API endpoints
- Rules editor screen accessible from Nutrition Home
- Rules injected into all AI prompts (parse, vision, guided)
- Auto-skip Guided questions when rules provide the answer

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

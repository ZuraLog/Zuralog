# Health Sections Framework — AI Summary, Trends & All-Data
**Date:** 2026-04-20
**Status:** Approved for implementation planning
**Scope:** Sleep + Nutrition (immediate) · Heart + Fitness (future, same framework)

---

## 1. What We Are Building

A consistent three-screen framework applied to every major health section in ZuraLog (Heart, Sleep, Nutrition, Fitness). Each section gains three features:

1. **AI Summary** — a short, proactive, daily written insight on the section's detail screen
2. **Trends** — two metric-specific charts on the detail screen giving free users a meaningful at-a-glance history
3. **All-Data** — a separate deep-dive screen showing every metric for that section, with extended time ranges unlocked by Pro

The framework is designed once and applied to all four sections. Sleep and Nutrition are built first. Heart and Fitness follow the same template when those screens are built.

---

## 2. Navigation Structure

```
Today Tab
  └── [Tap section card]
        └── Detail Screen  ← free
              └── [Tap "View All Data →"]
                    └── All-Data Screen  ← Pro, with 7-day free preview
```

There are exactly three levels. All-Data is always a separate screen — never a tab within the detail screen and never a locked scroll section. This keeps the free detail screen clean and makes the Pro upgrade feel like a genuine expansion, not a blocked portion of something already visible.

---

## 3. The Detail Screen (Screen 2 — Free)

### 3.1 Template — applies to every section in this order

| Position | Block | Notes |
|---|---|---|
| 1 | **Hero card** | Today's key numbers at a glance. Section-specific content. |
| 2 | **Section-specific middle blocks** | Unique content only that section can show. 0–2 blocks. |
| 3 | **AI Summary card** | 1–3 sentences. See Section 5. |
| 4 | **Chart 1** | Most important metric. Bar or line depending on metric type. |
| 5 | **Chart 2** | Second most important metric. Bar or line depending on metric type. |
| 6 | **"View All Data →" button** | Full-width. Small Pro badge visible to free users. No hard wall here — the badge is informational, not blocking. |
| 7 | **Section-specific tail blocks** | Optional. Content that must appear below the charts (e.g. the Nutrition meal list and log CTA). |

### 3.2 Chart rules

- **Hard cap of 2 charts per section.** No exceptions. All other metrics live in All-Data.
- **Chart type is decided by the metric, not by the section:**
  - Bar chart — discrete daily values (calories consumed, sleep duration, steps, workout duration)
  - Line chart — continuous measurements (resting HR, HRV, SpO2, sleeping heart rate)
- **Time range toggle on each chart:** 7 days / 30 days. Both available to free users.
- **Each chart is independent** — they do not share a time range toggle state.
- **No metric switching on detail screen charts.** Each chart shows exactly one fixed metric. Metric switching is exclusively an All-Data feature.

### 3.3 Empty and sparse data states

- If today has no data at all: the hero card shows a "No data yet" empty state. Charts show their empty state ("No data for this period"). AI Summary shows "Log some data to get your first insight."
- If today has partial data: charts render what is available. Gaps in the chart are shown as empty bars or broken lines — never hidden, never zero-filled.
- The detail screen is always reachable regardless of data state. It never redirects or shows a hard error.

---

## 4. The All-Data Screen (Screen 3 — Pro, 7-day preview for free)

### 4.1 Purpose

All-Data answers a different question than the detail screen. The detail screen answers: *"How have I been doing lately?"* All-Data answers: *"How do I perform relative to myself, across every metric I track, over real time?"*

### 4.2 Structure — shared base, section-specific config

All-Data uses a single shared base screen (`AllDataScreen`) with a section config layer that specifies the tabs, chart types, and data endpoints for each section. This avoids duplicating the paywall logic, chart rendering, benchmark bands, and distribution breakdown across four separate screens while keeping each section's content simple and focused.

### 4.3 Screen layout

| Position | Block | Notes |
|---|---|---|
| 1 | **Metric tabs** | Horizontal scrollable tabs across the top. One tab per trackable metric for this section. |
| 2 | **Main chart** | Switches when a tab is tapped. Bar or line depending on the metric. |
| 3 | **Time range selector** | 7d · 30d · 3M · 6M · 1Y. See paywall rules below. |
| 4 | **Personal benchmark band** | Shaded zone overlaid on the chart. See Section 4.5. |
| 5 | **Distribution breakdown** | Below the chart. See Section 4.6. |

### 4.4 Paywall mechanics — time depth, not feature lock

Free users see everything on the All-Data screen. No feature is hidden or blurred. The only restriction is time depth:

- **Free:** 7 days of chart data visible. The 30d, 3M, 6M, 1Y range buttons are shown but tapping them triggers a soft upgrade prompt.
- **Pro:** All time ranges unlocked. 7d, 30d, 3M, 6M, 1Y.

The free 7-day preview means users fully experience the feature — they understand its value — before being asked to upgrade. This is a deliberate choice over a hard paywall.

The upgrade prompt appears inline below the time range selector when a Pro range is tapped. It does not replace the chart. It appears as a non-blocking card: "Unlock your full history with ZuraLog Pro."

### 4.5 Personal benchmark bands

A shaded band is overlaid on every chart showing the user's personal normal range. This is calculated from the user's own rolling 30-day history, not from population averages or fixed thresholds.

- Requires a minimum of 14 days of data before the band is shown. Below 14 days: "Building your baseline… keep logging to see your personal range."
- The band represents the user's personal normal zone (rolling mean ± standard deviation based on recent history).
- Health-guideline floors are applied to prevent the system from validating clinically poor patterns. Concrete example: if a user consistently sleeps 4 hours, their personal average is 4 hours — but the floor for sleep duration is 6 hours, so 4 hours is always classified as "Low" regardless of personal history. The floor values are defined per metric by the backend and are grounded in established health guidelines (e.g. sleep: 6h floor, resting HR: above 100 bpm is always "Low" for resting).
- The band updates as new data comes in. It is recalculated server-side daily.
- Both free and Pro users see the benchmark band. It is not a paywalled feature — it is part of the core chart experience.

### 4.6 Distribution breakdown

A horizontal segmented bar below the chart showing what percentage of the user's readings (within the selected time range) fell into each zone.

Zones: **Low · Normal · Good · Optimal**

- Zones are calculated from the user's personal history with health-guideline floors.
- The breakdown updates dynamically as the time range changes. Switching from 7d to 6M shows you whether your metric has genuinely improved or just felt like it.
- Free users see the breakdown for the 7-day window. Pro users see it for any selected range.
- Color coding: Low = muted red, Normal = muted amber, Good = section category color at 60% opacity, Optimal = section category color at full opacity.

### 4.7 Missing metric tabs

Every possible metric for a section has a tab in All-Data. If the user has no data for a metric (no wearable, no logging), the tab still appears. Tapping it shows an empty state: "Connect a source to see [metric name]" with a soft link to the Integrations screen.

Tabs never disappear. This is intentional — users see what they are missing and can choose to connect a source. It is a growth mechanic, not a broken state.

---

## 5. AI Summary

### 5.1 Content rules

- Length: 1–3 sentences. Never longer.
- Tone: observational with one gentle nudge. Never prescriptive or commanding.
- Language: "Your data suggests…" / "You tend to…" / "Last night was…" — never "You should…" / "You must…" / "You need to…"
- Medical disclaimer: the summary never gives clinical advice. It describes patterns in the user's own data.
- The nudge is always singular — one thing. Never a list of action items.

**Example (Sleep):** "You slept 6h 40m last night — about 45 minutes less than your usual. Your deep sleep was also below average. Your data suggests an earlier bedtime tonight might help you recover."

**Example (Nutrition):** "You hit your calorie target today and your protein was above your weekly average. Your data suggests your lunch timing is consistent, which tends to support more stable energy through the afternoon."

### 5.2 Generation and refresh

- The AI Summary is generated by the existing backend Celery pipeline and stored in the `insights` table.
- Insight types used: `sleep_analysis` (Sleep), `nutrition_summary` (Nutrition), and equivalent types for Heart and Fitness when those sections are built.
- One summary per section per day per user. It is generated after the day's data has been ingested, typically overnight or after a sync.
- The summary is surfaced via the section's API endpoint (not a separate AI call at read time). Zero latency at display time.
- If no summary exists for today: the card shows a skeleton loading state for the first load, then an empty state: "Your summary for today is being prepared."
- The `generated_at` timestamp is shown below the summary text so users know how fresh it is.

### 5.3 Summary card design

- Uses `ZuralogCard` with `ZCardVariant.feature` and the section's category color.
- Header row: sparkle icon + "AI Summary" label in the section's category color.
- Body: summary text in `AppTextStyles.bodyMedium`.
- Footer: "Generated [relative time]" in `AppTextStyles.bodySmall` using secondary text color.
- Skeleton loading state: three lines of animated skeleton text (widths: 100%, 85%, 70%).
- The card is always rendered on the detail screen, even while loading. It never causes layout shift.

---

## 6. Section-Specific Specs

### 6.1 Sleep

**Status:** Detail screen exists. AI Summary and trend charts are built. All-Data screen does not exist. "View All Data →" button does not exist.

**Work required:** Add "View All Data →" button to `SleepDetailScreen`. Build `SleepAllDataScreen` using the shared `AllDataScreen` base.

**Detail screen middle blocks (between hero and AI Summary):**
- Sleep stages breakdown (only shown when wearable data is available)
- Sleeping heart rate section (only shown when HR data is available)

**Detail screen charts:**
| Chart | Metric | Type | Notes |
|---|---|---|---|
| Chart 1 | Sleep Duration | Bar | Already implemented |
| Chart 2 | Sleeping Heart Rate | Line | Already implemented |

**All-Data metric tabs:**
| Tab | Metric | Chart Type |
|---|---|---|
| Duration | Total sleep time (minutes) | Bar |
| Quality | Sleep quality score (1–5) | Bar |
| Deep Sleep | Deep sleep minutes | Bar |
| REM | REM sleep minutes | Bar |
| Light Sleep | Light sleep minutes | Bar |
| Heart Rate | Sleeping heart rate (bpm) | Line |
| Efficiency | Sleep efficiency (%) | Line |

Tabs with no data (e.g. Deep Sleep if no wearable) show the "Connect a source" empty state.

**Backend:** The existing `GET /api/v1/sleep/trend` returns only duration and quality rating. All-Data requires all seven metrics (duration, quality, deep sleep, REM, light sleep, sleeping HR, efficiency). A new endpoint is required: `GET /api/v1/sleep/all-data?range=7d|30d|3m|6m|1y` that returns per-day rows with all seven metrics. The existing trend endpoint remains in place for the detail screen charts (it only needs 7d/30d and only two metrics). The new all-data endpoint needs to support all five range options.

---

### 6.2 Nutrition

**Status:** Home screen exists (meal logging, macro tracking, rules). AI Summary and trend charts are NOT built. All-Data screen does not exist.

**Work required:** Extend `/api/v1/nutrition/today` to include AI summary fields. Add `/api/v1/nutrition/trend` endpoint. Build `NutritionTrendSection` widget. Build `NutritionAiSummaryCard` widget. Add both to `NutritionHomeScreen`. Add "View All Data →" button. Build `NutritionAllDataScreen`.

**Detail screen structure (full order):**
1. Hero card — macro summary (calories, protein, carbs, fat for today)
2. *(No section-specific middle block needed — the hero card covers the macro summary)*
3. AI Summary card
4. Chart 1: Calories (bar, 7d/30d)
5. Chart 2: Protein (bar, 7d/30d)
6. "View All Data →" button
7. "Today's Meals" section header
8. Meal list (existing)
9. "Log a meal" CTA (existing)

The meal list stays on the Nutrition detail screen. It is the primary logging interface and must remain accessible from the main Nutrition screen.

**All-Data metric tabs:**
| Tab | Metric | Chart Type |
|---|---|---|
| Calories | Total daily calories (kcal) | Bar |
| Protein | Total daily protein (g) | Bar |
| Carbs | Total daily carbohydrates (g) | Bar |
| Fat | Total daily fat (g) | Bar |
| Meals | Number of meals logged | Bar |

**Backend changes required:**
1. `GET /api/v1/nutrition/today` — add `ai_summary: str | None` and `ai_generated_at: str | None` to the summary object. These come from the `insights` table where `type = 'nutrition_summary'` and `generation_date = today`.
2. `GET /api/v1/nutrition/trend?range=7d|30d|3m|6m|1y` — new endpoint. Queries `NutritionDailySummary` table for the requested range and returns per-day totals for all five metrics (calories, protein, carbs, fat, meal_count).

---

### 6.3 Heart (future)

Not built yet. When implemented, follows the same framework.

**Detail screen charts:** Resting Heart Rate (line) + HRV (line)
**All-Data tabs:** Resting HR · HRV · SpO2 · Active HR · Blood Pressure (if source available)
**Insight type:** `heart_summary` (to be added to `INSIGHT_TYPES` when Heart is built)

---

### 6.4 Fitness (future)

Not built yet. When implemented, follows the same framework.

**Detail screen charts:** Active Calories (bar) + Workout Duration (bar)
**All-Data tabs:** Steps · Active Calories · Workout Duration · Distance · Elevation
**Insight type:** `fitness_summary` (to be added to `INSIGHT_TYPES` when Fitness is built)

---

## 7. Flutter Architecture

### 7.1 AllDataScreen (shared base)

A single `AllDataScreen` widget accepts an `AllDataSectionConfig` and renders the full All-Data experience. The config specifies everything that varies per section:

```dart
class AllDataSectionConfig {
  final String sectionTitle;         // e.g. 'Sleep'
  final Color categoryColor;         // e.g. AppColors.categorySleep
  final List<AllDataMetricTab> tabs; // ordered list of metric tabs
  final Future<List<AllDataDay>> Function(String range) fetchData;
}

class AllDataMetricTab {
  final String id;                   // e.g. 'duration'
  final String label;                // e.g. 'Duration'
  final AllDataChartType chartType;  // bar | line
  final String unit;                 // e.g. 'h', 'kcal', 'bpm'
  final double? Function(AllDataDay) valueExtractor; // pulls this tab's value from a day row
  final String? emptyStateSource;    // shown when no data, e.g. 'Connect a wearable'
}

// One entry per day returned by the all-data endpoint.
// Each field is nullable — a day may have partial data.
class AllDataDay {
  final String date;                 // ISO date string 'YYYY-MM-DD'
  final bool isToday;
  final Map<String, double?> values; // keyed by AllDataMetricTab.id
}

enum AllDataChartType { bar, line }
```

The `AllDataScreen` handles: tab rendering, chart switching, time range selector, paywall gating, benchmark band overlay, and distribution breakdown.

### 7.2 Section configs

Each section provides a static config:

- `SleepAllDataConfig` — wired to the sleep trend endpoint
- `NutritionAllDataConfig` — wired to the nutrition trend endpoint
- `HeartAllDataConfig` (future)
- `FitnessAllDataConfig` (future)

### 7.3 New widgets (shared library)

These belong in `zuralog/lib/shared/widgets/` and must be added to `widgets.dart`:

None. The AI Summary card and trend section widgets are feature-specific (they use section-specific data models and providers). They live in each feature's `presentation/widgets/` folder.

The `AllDataScreen` and related config types live in a new shared location: `zuralog/lib/shared/all_data/`.

### 7.4 Feature-specific widgets

| Feature | Widget | Location |
|---|---|---|
| Nutrition | `NutritionAiSummaryCard` | `features/nutrition/presentation/widgets/` |
| Nutrition | `NutritionTrendSection` | `features/nutrition/presentation/widgets/` |
| Sleep | `SleepAiSummaryCard` | `features/sleep/presentation/widgets/` — already exists |
| Sleep | `SleepTrendSection` | `features/sleep/presentation/widgets/` — already exists |

### 7.5 New providers

**Nutrition:**
- `nutritionTrendProvider` — `FutureProvider.family<List<NutritionTrendDay>, String>` keyed by range string
- `nutritionAllDataProvider` — `FutureProvider.family<List<NutritionTrendDay>, String>` keyed by range string (same model, separate provider for the All-Data screen)

**Sleep:**
- `sleepTrendProvider` already exists and is keyed by range — detail screen charts continue using it as-is
- `sleepAllDataProvider` — new `FutureProvider.family<List<SleepAllDataDay>, String>` for the All-Data screen, keyed by range string

### 7.6 New models

**Nutrition:**
- `NutritionTrendDay` — `{ date: String, totalCalories: double, totalProteinG: double, totalCarbsG: double, totalFatG: double, mealCount: int, isToday: bool }` — used by detail screen charts
- `NutritionDaySummary` extended — add `aiSummary: String?` and `aiGeneratedAt: DateTime?`
- `NutritionRepositoryInterface` — add `getTrend(String range)` returning `Future<List<NutritionTrendDay>>`
- `ApiNutritionRepository` — implement `getTrend()` calling `GET /api/v1/nutrition/trend`
- `MockNutritionRepository` — implement `getTrend()` with hardcoded fixture data

**Sleep:**
- `SleepAllDataDay` — `{ date: String, isToday: bool, values: Map<String, double?> }` — used by `AllDataScreen` via the generic `AllDataDay` model. The sleep all-data provider maps the backend response into `AllDataDay` entries keyed by metric id (e.g. `'duration'`, `'deep_sleep'`, `'rem'`, etc.)
- `SleepRepositoryInterface` — add `getSleepAllData(String range)` returning `Future<List<AllDataDay>>`

---

## 8. What Is Explicitly Out of Scope

The following are NOT part of this spec and must not be built as part of this effort:

- **Raw data tables** — scrollable lists of individual readings. Not included.
- **Cross-metric correlations** — "your sleep affected your recovery." That is the Trends tab's job.
- **Data export** — a separate feature.
- **User-adjustable zone thresholds** — zones are calculated automatically. Users cannot manually set Low/Normal/Good/Optimal bounds.
- **Comparison overlays** — overlaying two time periods on the same chart. A future enhancement.
- **AI-generated coaching within All-Data** — the Coach tab handles deep Q&A. All-Data is visual only.
- **Heart and Fitness implementation** — designed here, built later.

---

## 9. How This Differs From Bevel

| Dimension | Bevel | ZuraLog |
|---|---|---|
| Paywall mechanism | Feature lock (AI is Pro only) | Time depth (features visible to all, history is Pro) |
| Metric ranges | Fixed population thresholds (e.g. "Optimal >85%") | Personal benchmarks calculated from user's own history |
| Score system | Proprietary composite scores (Sleep Score, Recovery Score) | Raw real numbers (hours, kcal, bpm) — no invented scores |
| AI delivery | Chatbot — user asks questions | Proactive — written daily without user prompting |
| Missing data | Metric disappears if no source | Metric tab shows empty state with source nudge |
| Platform | iOS-first | Android + iOS from day one |
| Aggregation | Apple Health + limited partners | Multi-source aggregator (Strava, Fitbit, Oura, Apple Health, Health Connect, Polar, Withings) |

The concept of "metric tabs + chart + time range selector" is a common UI pattern and is not ownable. ZuraLog's differentiation is in the paywall approach, the personalization of ranges, the absence of proprietary scores, and the proactive AI delivery model.

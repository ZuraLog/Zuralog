# AI Insights Engine — Design Specification

**Date:** 2026-03-18
**Status:** Approved — Ready for Implementation Planning
**Author:** Brainstorming session (Claude Code + product owner)
**Related docs:** `docs/PRD.md` § Feature D, `docs/architecture.md`, `docs/mvp-features.md` § Feature D & H

---

## 1. Problem Statement

The existing insight system is broken in two distinct ways:

**The display layer is completely broken.** Four concrete bugs prevent any real insight from ever appearing on screen — even when the backend has generated cards and stored them in the database. Every user today sees the "Your insights are on the way" empty state, always.

**The generation layer is shallow.** Even if the display bugs were fixed, the content would be nearly useless. The generator always produces the same generic fallback sentence ("Consistency is key. Keep tracking and the insights will come.") because goal and trend data is never actually passed into it. The system only produces 3–4 card types, ignores most of the data we have, never detects cross-domain patterns, and makes no use of the user's stated goals or dashboard layout.

This spec defines a complete replacement of the insight engine — fixing all display bugs and building a comprehensive, LLM-powered insight pipeline that uses all available health data.

---

## 2. Goals

1. Fix all four display bugs so existing and new insights actually reach the screen.
2. Replace the shallow rule-based generator with a two-layer pipeline: Python analytics + focused LLM call.
3. Surface 8 categories of health signals covering every data source we have.
4. Detect cross-domain patterns that no single health app can find.
5. Personalise cards to the user's inferred focus (goals + dashboard layout).
6. Generate insights once per day on a schedule — locked in, not re-triggerable by users.
7. Use a cheap, fast model for insight generation (not Kimi K2.5, which is reserved for the Coach tab).
8. Fix the field name mismatches between the backend API and the Flutter app.
9. Add the missing `GET /api/v1/insights/:id` endpoint.

---

## 3. Non-Goals

- Real-time insight generation (insights are a daily digest, not a live feed).
- Manual refresh by users (locked for the day — no refresh endpoint or UI).
- Replacing the Coach tab AI (Kimi K2.5 stays for chat).
- Weekly or monthly reports (separate feature, separate spec).

---

## 4. Architecture Overview

```
Celery Beat (6 AM per user's local time)
  ↓
Step 1 — HealthBriefBuilder        (Python, free — fetches all user data)
  ↓
Step 2 — InsightSignalDetector     (Python, free — runs all analytics)
  ↓
Step 3 — SignalPrioritizer         (Python, free — ranks and selects signals)
  ↓
Step 4 — InsightCardWriter         (LLM call — writes cards in user's voice)
  ↓
Step 5 — Persist to insights table (upsert with date-lock)
  ↓
Step 6 — App fetches and displays  (Flutter, after bug fixes)
```

The critical design principle: **the LLM never does analytics.** All statistics, trend detection, correlation computation, anomaly detection, and goal progress calculation happen in Python first. The LLM receives a compact, pre-processed brief and its only job is to turn structured facts into natural-language cards in the right persona voice. This keeps costs low, keeps the analytics testable, and makes the output predictable.

---

## 5. Daily Generation Schedule

Insights are generated once per day per user using Celery Beat.

**Trigger:** A scheduled Celery task runs at 6:00 AM in the user's local timezone. The user's timezone is derived from their last known device timezone offset (stored in `user_preferences` — add `timezone` field if not present, default UTC).

**Date-lock:** The `insights` table has a unique constraint on `(user_id, type, date)`. "Today's date" is the calendar date in the user's local timezone. Any attempt to re-run generation for a user who already has insights for today is a no-op (the upsert constraint prevents duplicates and the task exits early if today's cards already exist and are not dismissed).

**No manual refresh:** There is no endpoint, button, or background trigger that allows a user to regenerate today's insights. The only way cards change during the day is if an anomaly is detected by the separate `check_anomalies_for_user` task — anomaly cards can be inserted at any time, but are a separate code path.

**On first run (new user):** If a user has fewer than 7 days of data (`MIN_DATA_DAYS_FOR_MATURITY`), a `welcome` card is generated instead of full insight cards. The welcome card counts down how many more days until full insights unlock. No LLM call is made for welcome cards.

---

## 6. Step 1 — HealthBriefBuilder

A new `HealthBriefBuilder` class (`cloud-brain/app/analytics/health_brief_builder.py`) fetches all user data in parallel using `asyncio.gather`. All queries target the date range appropriate for the analysis window — no query fetches more than 90 days.

### Data fetched and why

| Source | Window | Fields | Purpose |
|--------|--------|--------|---------|
| `daily_health_metrics` | 30 days | steps, active_calories, distance_meters, flights_climbed, resting_heart_rate, hrv_ms, heart_rate_avg, vo2_max, respiratory_rate, oxygen_saturation, body_fat_percentage | All activity, cardiovascular, and vitals metrics |
| `sleep_records` | 30 days | hours, quality_score | Sleep duration and quality trends, anomaly baseline |
| `unified_activities` | 30 days | activity_type, duration_seconds, distance_meters, calories, start_time | Workout frequency, type distribution, training load |
| `nutrition_entries` | 30 days | calories, protein_grams, carbs_grams, fat_grams | Calorie balance, macro trends, deficit/surplus analysis |
| `weight_measurements` | 90 days | weight_kg, date | Rate of weight change, direction vs goal, plateau detection |
| `quick_logs` | 14 days | metric_type, value, text_value, data, logged_at | Mood, energy, stress, water, supplements, symptoms, manual sleep |
| `user_goals` | all active | metric, target_value, period, current_value, is_active, deadline | Goal progress, pacing, near-miss detection |
| `user_streaks` | current | streak_type, current_count, longest_count, last_activity_date | Streak at-risk, milestones, personal bests |
| `health_scores` | 14 days | score, score_date, commentary | Health score trend |
| `user_preferences` | current | goals, dashboard_layout, coach_persona, fitness_level, units_system | Focus inference, LLM persona, unit formatting |
| `integrations` | current | provider, is_active, last_synced_at | Data source confidence, stale integration detection |

### Data quality rules

- If a source hasn't synced in 24+ hours, its data is flagged as potentially stale and is not used for "today's" values (only historical context).
- When multiple sources exist for the same metric on the same day (e.g., Apple Health steps + Fitbit steps), use the highest-quality source in order: Oura > Fitbit > Polar > Withings > Apple Health > Health Connect > manual.
- If a metric has fewer than 7 values in the window, it is excluded from trend analysis (not enough data). It can still be used for anomaly detection if ≥ 14 historical points exist.

### Output: `HealthBrief` dataclass

```python
@dataclass
class HealthBrief:
    user_id: str
    generated_at: datetime
    daily_metrics: list[DailyMetricsRow]     # 30 days, date-sorted
    sleep_records: list[SleepRow]            # 30 days
    activities: list[ActivityRow]            # 30 days
    nutrition: list[NutritionRow]            # 30 days
    weight: list[WeightRow]                  # 90 days
    quick_logs: list[QuickLogRow]            # 14 days
    goals: list[GoalRow]                     # active only
    streaks: list[StreakRow]
    health_scores: list[HealthScoreRow]      # 14 days
    preferences: UserPreferencesSnapshot
    integrations: list[IntegrationStatus]
    data_maturity_days: int                  # distinct days with any data
```

---

## 7. Step 2 — InsightSignalDetector

A new `InsightSignalDetector` class (`cloud-brain/app/analytics/insight_signal_detector.py`) receives the `HealthBrief` and produces a list of `InsightSignal` objects.

### Signal dataclass

```python
@dataclass
class InsightSignal:
    signal_type: str           # See categories below
    category: str              # A through H
    metrics: list[str]         # Which metrics this signal involves
    values: dict[str, Any]     # The actual numbers (for LLM context and card data field)
    severity: int              # 1 (low) to 5 (critical)
    actionable: bool           # Can the user do something about this today?
    focus_relevant: bool       # Is this signal related to the user's inferred focus?
    title_hint: str            # Suggested card title (LLM may deviate)
    data_payload: dict         # Stored in the insight.data JSON field for chart rendering
```

### Category A — Single-metric trends

Uses `TrendDetector` (7-day window comparison, 10% sensitivity threshold). Requires ≥ 14 values in the 30-day window.

**Metrics covered:**
- `steps` — daily step count
- `active_calories` — active energy burned
- `distance_meters` — total walking/running distance
- `resting_heart_rate` — cardiovascular baseline
- `hrv_ms` — recovery quality
- `sleep_hours` — from sleep_records
- `sleep_quality` — from sleep_records quality_score
- `weight_kg` — from weight_measurements
- `calories` — daily intake from nutrition_entries
- `protein_grams` — protein intake
- `vo2_max` — aerobic fitness
- `mood` — from quick_logs, averaged per day
- `energy` — from quick_logs, averaged per day
- `stress` — from quick_logs, averaged per day
- `water_ml` — total water per day from quick_logs

**Signal types produced:**
- `trend_decline` — metric trending down > 10% vs prior 7-day window
- `trend_improvement` — metric trending up > 10% vs prior 7-day window

**Severity rules:**
- Base severity: 2
- +1 if the metric is in the user's `focus_metrics` (see Step 3, Focus Inference)
- +1 if decline > 20%
- +1 if the metric is a health-critical one (hrv_ms, resting_heart_rate, sleep_hours)

**Example signals:**
- HRV down 14%: `{signal_type: trend_decline, metrics: ["hrv_ms"], values: {recent_avg: 31.2, previous_avg: 36.3, pct_change: -14.1}, severity: 4}`
- Sleep hours up 11%: `{signal_type: trend_improvement, metrics: ["sleep_hours"], values: {recent_avg: 7.4, previous_avg: 6.6, pct_change: 12.1}, severity: 2}`

---

### Category B — Goal progress and pacing

Uses `GoalTracker.check_progress()` on every active `UserGoal`.

**Signal types produced:**

| Signal | Condition | Severity |
|--------|-----------|----------|
| `goal_near_miss` | 80–99% complete, goal not yet met, period resets today | 4 |
| `goal_met_today` | Goal reached 100%+ for today | 2 |
| `goal_all_met` | Every active daily goal is met | 3 |
| `goal_behind_pace` | Weekly goal: current rate projects to < 80% completion by week end | 3 |
| `goal_at_risk` | Long-term goal: current trend line projects to miss the deadline | 4 |
| `goal_streak` | Same goal met N consecutive days: N ∈ {3, 5, 7, 14, 30} | 2 |
| `goal_zero_progress` | Daily goal at 0% progress and current time is past 12:00 PM local | 3 |
| `goal_no_activity_today` | No workout logged yet and user has a weekly workout-frequency goal | 3 |

**Pacing logic for weekly goals:**
- Days elapsed in week: D (1–7)
- Current progress: C
- Target: T
- Required daily rate: T / 7
- Projected completion: C / D × 7
- Behind pace if projected < T × 0.8

**Example signals:**
- Steps goal 10,000, current 8,200 at 6pm: `{signal_type: goal_near_miss, metrics: ["steps"], values: {current: 8200, target: 10000, pct: 82, remaining: 1800}, severity: 4, actionable: true}`
- Weight goal 75kg by March 1st, current trend projects 77kg: `{signal_type: goal_at_risk, metrics: ["weight_kg"], values: {current_weight: 78.2, target: 75.0, projected_by_deadline: 77.1, deadline: "2026-03-01"}, severity: 4}`

---

### Category C — Anomaly detection

Extends the existing `AnomalyDetector`. Uses 30-day lookback, 14-point minimum, population standard deviation.

**Metrics covered (expanded from current 6 to 12):**

Current: `resting_heart_rate`, `hrv_ms`, `steps`, `active_calories`, `sleep_hours`, `sleep_quality`

Added: `weight_kg` (sudden jump ≥ 2kg in one day), `calories` (daily intake), `mood`, `energy`, `vo2_max`, `respiratory_rate`, `oxygen_saturation`

**Severity mapping:**
- Elevated (2.0–3.0 stddev): severity 3
- Critical (≥ 3.0 stddev): severity 5 (always surfaced regardless of focus relevance)

**Direction labels:**
- `high` — current value above baseline (bad for: RHR, stress; good for: steps, HRV)
- `low` — current value below baseline (bad for: HRV, sleep, mood; good for: RHR, weight if goal is loss)

The `data_payload` for anomaly signals always includes: `{current_value, baseline_mean, baseline_stddev, deviation_magnitude, direction, severity}` so the card can render a comparison visualisation.

**Example signals:**
- RHR 78 vs baseline 63: `{signal_type: anomaly, metrics: ["resting_heart_rate"], values: {current: 78, mean: 63, stddev: 3.2, deviation: 4.69, direction: "high"}, severity: 5, actionable: false}`
- Mood crashed from usual 7.2 to 3.0: `{signal_type: anomaly, metrics: ["mood"], values: {current: 3.0, mean: 7.2, stddev: 1.1, deviation: 3.8, direction: "low"}, severity: 4}`

---

### Category D — Cross-metric correlations

Uses `CorrelationAnalyzer.calculate_correlation()` with lag support. Requires ≥ 14 paired data points. Only surfaces correlations with `abs(Pearson r) > 0.4`. Correlation signals are computed from the 30-day history and represent discovered patterns, not single-day observations.

**All correlation pairs checked:**

*Sleep & Next-Day Activity (lag = 1 day)*
- Sleep hours → next-day step count
- Sleep hours → next-day active calories
- Sleep quality → next-day workout duration (when workout occurred)

*Sleep & Recovery (lag = 0)*
- Sleep hours → same-day HRV
- Sleep quality → same-day HRV

*Recovery & Performance (lag = 1 day)*
- HRV → next-day workout duration
- HRV → next-day step count
- Resting heart rate → next-day energy level (quick log)

*Nutrition & Body Weight (lag = 2 days)*
- Daily calorie intake → weight change 2 days later
- Calorie deficit vs maintenance → weekly weight delta

*Nutrition & Recovery (lag = 0)*
- Daily calorie intake → same-day HRV
- Protein intake → workout days (do higher-protein days correlate with more exercise?)

*Stress & Health (lag = 0 and lag = 1)*
- Stress level → same-night sleep hours
- Stress level → next-day HRV (lag 1)
- Stress level → next-day mood (lag 1)
- Stress level → next-day step count (lag 1)

*Activity & Recovery (lag = 1)*
- Active calories (workout intensity) → next-day RHR
- Consecutive workout days → HRV (overtraining proxy)

*Hydration & Wellbeing (lag = 0 and lag = 1)*
- Water intake → same-day energy level
- Water intake → same-night sleep quality
- Water intake → next-day energy (lag 1)

*Activity & Body Composition*
- Weekly workout frequency → weight trend direction

**Signal types produced:**
- `correlation_positive` — r > 0.4: two metrics move together
- `correlation_negative` — r < -0.4: two metrics move in opposite directions

**Severity:**
- `abs(r)` 0.4–0.6: severity 2
- `abs(r)` 0.6–0.8: severity 3
- `abs(r)` > 0.8: severity 4

**The `data_payload` includes:** `{metric_a, metric_b, pearson_r, lag_days, data_points, direction_label, example_stat}` where `example_stat` is a concrete quantification ("On nights with 7+ hours sleep, next-day steps are 28% higher on average") computed from the actual data.

**Example signal:**
```python
{
  signal_type: "correlation_negative",
  metrics: ["stress", "sleep_hours"],
  values: {r: -0.61, lag: 0, data_points: 21},
  data_payload: {
    example_stat: "On high-stress days you average 1.2 fewer hours of sleep",
    metric_a: "stress",
    metric_b: "sleep_hours",
    pearson_r: -0.61,
  },
  severity: 3,
  actionable: True,
  title_hint: "Stress is cutting into your sleep"
}
```

---

### Category E — Cross-domain compound patterns

These are the most valuable signals. They require combining 2+ data sources and cannot be detected by any single health app. Each pattern is implemented as a dedicated detector method.

**Pattern: Weight plateau**
- Condition: Weight hasn't changed by more than ±0.3kg over the last 14 days
- Sub-condition A (calorie data available): compute average daily intake vs estimated TDEE (estimated from weight + activity data). Classify as surplus / deficit / maintenance.
- Sub-condition B (workout data available): check if workout frequency has dropped in the same window.
- Signal: `compound_weight_plateau`
- Severity: 4 if user has weight_loss or body_recomposition goal; 2 otherwise
- Example payload: `{weight_change_14d: 0.1, avg_calories: 2100, est_tdee: 1950, status: "slight_surplus", workout_freq_change: -33}`

**Pattern: Overtraining warning**
- Condition: 5+ consecutive workout days AND HRV trend is down AND RHR trend is up over the same period
- All three conditions must be true simultaneously
- Signal: `compound_overtraining_risk`
- Severity: 4
- Example payload: `{consecutive_workout_days: 6, hrv_change_pct: -18, rhr_change_pct: +8}`

**Pattern: Sleep debt accumulation**
- Condition: Average sleep this week is ≥ 1 hour below the user's 4-week rolling average
- Sub-condition: Energy or mood ratings (from quick logs) are also declining over the same period
- Signal: `compound_sleep_debt`
- Severity: 3 base; +1 if mood/energy ratings also declining
- Example payload: `{avg_sleep_this_week: 5.8, avg_sleep_4wk: 7.1, sleep_deficit_hours: 1.3, energy_rating_change: -2.1}`

**Pattern: Unsustainable calorie deficit**
- Condition: User has weight_loss goal AND calorie intake < (estimated TDEE × 0.75) for 5+ consecutive days
- A deficit deeper than 25% of maintenance calories is a red flag for muscle loss and recovery damage
- Signal: `compound_deficit_too_deep`
- Severity: 3
- Example payload: `{avg_deficit_pct: 32, consecutive_days: 6, avg_intake: 1280, est_tdee: 1900}`

**Pattern: Workout consistency collapse**
- Condition: User averaged 3+ workouts/week for the past 4 weeks AND this week has ≤ 1 workout with ≥ 2 days remaining in the week
- Signal: `compound_workout_collapse`
- Severity: 3
- Example payload: `{prev_4wk_avg_per_week: 3.5, this_week_count: 1, days_remaining: 3}`

**Pattern: Recovery window (positive)**
- Condition: HRV above the 30-day mean AND RHR at or below baseline AND this has been true for 3+ consecutive days
- Signal: `compound_recovery_peak`
- Severity: 2 (positive signal — good timing for a hard effort)
- Example payload: `{hrv_vs_baseline_pct: +12, rhr_vs_baseline_pct: -5, consecutive_good_days: 4}`

**Pattern: Stress-driven health cascade**
- Condition: Stress ratings (quick log) ≥ 6 for 3+ consecutive days AND sleep declining AND HRV declining
- All three conditions must be true
- Signal: `compound_stress_cascade`
- Severity: 4
- Example payload: `{avg_stress_3d: 7.3, sleep_decline_hours: 1.4, hrv_decline_pct: -12, consecutive_high_stress_days: 4}`

**Pattern: Dehydration pattern**
- Condition: Average water intake ≤ 4 glasses/day for 5+ consecutive days where water was logged AND energy ratings below average over same period
- Signal: `compound_dehydration_pattern`
- Severity: 3
- Example payload: `{avg_water_glasses: 2.8, target: 8, consecutive_low_days: 5, energy_rating_vs_avg: -1.8}`

**Pattern: Weekend vs weekday activity gap**
- Condition: Average steps on weekends vs weekdays differ by ≥ 40%, computed over the last 30 days (requires ≥ 8 weekend days and ≥ 8 weekdays with data)
- Signal: `compound_weekend_activity_gap`
- Severity: 2
- Example payload: `{weekday_avg_steps: 9200, weekend_avg_steps: 4400, gap_pct: -52, direction: "lower_weekends"}`

**Pattern: Pre-event training trajectory**
- Condition: User has a long-term goal with a deadline ≤ 30 days away AND primary training metric (e.g. distance for a run goal) is trending in the right direction (up by ≥ 10%)
- Signal: `compound_event_on_track`
- Severity: 2 (positive — affirming)
- Example payload: `{days_until_deadline: 18, training_metric: "distance_meters", trend_pct: +15, goal_title: "5K race"}`

---

### Category F — User focus inference

This is not a signal category — it is a preprocessing step that runs before all other categories and produces a `UserFocusProfile` that every other category uses to adjust signal severity.

**Step 1 — Read `user_preferences.goals` (stated intent):**

| Goal key | Focus label | Priority metrics |
|----------|-------------|-----------------|
| `weight_loss` | cutting | weight_kg, calories, active_calories, body_fat_percentage, protein_grams |
| `sleep` | recovery | sleep_hours, sleep_quality, hrv_ms, stress, resting_heart_rate |
| `fitness` | performance | steps, active_calories, distance_meters, vo2_max, workout_frequency |
| `stress` | stress_management | stress, mood, hrv_ms, sleep_hours, resting_heart_rate |
| `nutrition` | nutrition | calories, protein_grams, carbs_grams, fat_grams, water_ml |
| `longevity` | longevity | hrv_ms, resting_heart_rate, vo2_max, sleep_hours, weight_kg |
| `build_muscle` | body_recomposition | weight_kg, protein_grams, workout_frequency, active_calories |

**Step 2 — Read `user_preferences.dashboard_layout` (revealed preference):**

The `dashboard_layout` JSON contains the list of visible card keys on the user's Today tab. Map card keys to inferred focus:

| Card combination | Inferred sub-focus |
|-----------------|-------------------|
| `calories` + `weight` + `running`/`cardio` | `cutting` |
| `sleep` + `hrv` + `stress` | `recovery` |
| `sleep` + `hrv` + `water` | `sleep_optimisation` |
| `steps` + `active_calories` + `distance` | `activity_volume` |
| `protein` + `calories` + `weight` + `workouts` | `body_recomposition` |
| `hrv` + `resting_heart_rate` + `sleep` + `water` | `longevity` |
| `calories` + `protein` + `carbs` + `fat` | `nutrition_tracking` |

**Step 3 — Combine into `UserFocusProfile`:**

```python
@dataclass
class UserFocusProfile:
    stated_goals: list[str]           # from user_preferences.goals
    inferred_focus: str               # most specific combined label
    focus_metrics: list[str]          # metrics that get severity boost
    deprioritised_metrics: list[str]  # still shown if anomaly, lower priority otherwise
    coach_persona: str                # tough_love | balanced | gentle
    fitness_level: str                # beginner | active | athletic
    units_system: str                 # metric | imperial
```

**Severity adjustment rule:** Any signal whose primary metric is in `focus_metrics` gets `severity += 1` (capped at 5). This ensures the insight set stays relevant to what the user actually cares about.

---

### Category G — Streak and consistency signals

Uses `UserStreak` rows directly.

| Signal | Condition | Severity |
|--------|-----------|----------|
| `streak_at_risk` | Streak will break today unless activity happens (last_activity_date = yesterday) and it's past 6pm | 3 |
| `streak_milestone_tomorrow` | Current streak is exactly (milestone − 1): milestones at 7, 14, 30, 60, 90, 180, 365 | 2 |
| `streak_personal_best` | current_count == longest_count and current_count > 0 (at the all-time high right now) | 3 |
| `streak_broken_recovery` | Streak broke yesterday or today (current_count reset to 0), current_count < 3 | 2 |
| `consistency_perfect_week` | All 7 days this week have health data logged | 2 |

---

### Category H — Data quality and integration signals

Low priority (severity 1–2), but shown when there's nothing else to show or when data quality is so poor that other signals may be unreliable.

| Signal | Condition | Severity |
|--------|-----------|----------|
| `integration_stale` | Any connected integration hasn't synced in 24+ hours | 2 |
| `data_gap_sleep` | Sleep tracker connected but no sleep data for 2+ nights | 2 |
| `data_gap_activity` | Activity tracker connected but no activity data for 2+ days | 2 |
| `new_integration` | An integration connected in the last 48 hours | 1 |
| `first_week` | data_maturity_days < 7 — welcome card only, no other signals | — |

---

## 8. Step 3 — Signal Prioritizer

A new `SignalPrioritizer` class (`cloud-brain/app/analytics/signal_prioritizer.py`) receives the full list of `InsightSignal` objects and returns the final ordered subset for the LLM.

### Sorting rules (applied in sequence)

1. **Critical anomalies always go first.** Any `category: C` signal with `severity == 5` is pinned to the top 1–2 positions regardless of focus relevance. These are health alerts.

2. **Sort remaining signals by composite score:**
   ```
   score = (severity × 3) + (focus_relevant × 2) + (actionable × 1)
   ```
   Higher score = earlier position.

3. **Recency tie-breaking.** Within the same composite score, signals based on today's or yesterday's data rank above historical pattern signals. Correlation discoveries are explicitly treated as lower-recency even if the data is current.

### Deduplication rules

Before sorting, merge signals that are about the same underlying metric:

- If a metric has both a `trend_decline` and a `goal_near_miss`, merge them into one signal with the higher severity and both data payloads. The LLM receives both facts and writes one richer card.
- If a metric has both a `trend_decline` and an `anomaly`, keep both — they are different in nature (trend = gradual change; anomaly = single-day spike).

### Diversity enforcement

After sorting, enforce variety:
- Maximum 2 signals from any single category (A through H) in the final set.
- At least 2 different categories must be represented unless fewer than 4 signals exist total.
- Exception: anomaly signals (category C) are exempt from the 2-card cap — if you have 3 critical anomalies, show all 3.

### Dynamic count

- Minimum: 2 cards
- Maximum: 10 cards
- Typical: 4–6 for a user on a normal day
- The count is dynamic — the prioritizer takes as many as pass the diversity rules up to the cap.

### Output

The prioritizer returns an ordered `list[InsightSignal]` — this is the brief that goes to the LLM.

---

## 9. Step 4 — InsightCardWriter (LLM)

### Model

A dedicated cheap, fast model via OpenRouter. The model ID is stored in a new config variable `OPENROUTER_INSIGHT_MODEL` (separate from `OPENROUTER_MODEL` which is used for the Coach). Default to be decided at implementation time — a placeholder is acceptable in the initial implementation. Candidates: Gemini Flash 2.5, GPT-4o mini. The architecture supports swapping models by changing one env var.

### One request per user per day

The entire set of signals is sent in a single API call. The LLM returns a JSON array of cards. This minimises latency and cost.

### Prompt structure

**System prompt:**
```
You are a health insight writer for Zuralog. Your job is to turn structured health data signals into clear, personal, and actionable insight cards.

User context:
- Coach persona: {persona}            (tough_love | balanced | gentle)
- Fitness level: {fitness_level}      (beginner | active | athletic)
- Primary goals: {stated_goals}
- Inferred focus: {inferred_focus}
- Units: {units_system}

Persona writing style:
- tough_love: Direct, honest, no sugarcoating. Holds the user accountable. Example: "You only hit your step goal twice this week. That's not effort — that's a pattern."
- balanced: Supportive but honest. Acknowledges effort and gaps equally. Example: "You had a strong Monday and Tuesday, but the back half of the week dropped off. Let's look at what changed."
- gentle: Encouraging, kind, never negative. Frames everything as an opportunity. Example: "Your sleep has been a little shorter this week. Even 30 extra minutes could make a noticeable difference."

Output rules:
1. Return a JSON array only. No prose outside the array.
2. Each element must have: type, title, body, priority (1–10, lower = more urgent), reasoning.
3. title: 3–7 words. Punchy headline.
4. body: 1–3 sentences. Specific numbers from the signal data. No generic advice.
5. reasoning: 1 sentence explaining why this signal was surfaced today.
6. Never invent numbers. Only use values from the signal data provided.
7. Never repeat the same insight. Each card must cover a different point.
8. Write in second person ("you", "your").
9. Do not use emoji.
```

**User message:**
```
Today is {date}. Here are the health signals detected for this user. Write one insight card per signal.

Signals:
{json.dumps(signals_for_llm, indent=2)}
```

Where `signals_for_llm` is a list of dicts containing `signal_type`, `metrics`, `values`, `actionable`, `title_hint` for each signal. The `data_payload` is also included so the LLM has the concrete numbers.

### LLM response parsing

Parse the JSON array response. If parsing fails (malformed JSON), fall back to the existing rule-based `InsightGenerator` for each signal individually. This ensures the feature never fully breaks even if the LLM call fails.

### Fallback chain

1. LLM call succeeds and returns valid JSON → use LLM cards
2. LLM call succeeds but JSON is malformed → run rule-based fallback per signal
3. LLM call fails (API error after 3 retries) → run rule-based fallback per signal
4. Rule-based fallback also fails → log error, generate a minimal "we're working on it" card, never show an empty feed to the user

---

## 10. Step 5 — Persistence

### Unique constraint change

The existing unique constraint `(user_id, type, date)` must be updated. With the new system, a user can have multiple cards of the same `type` on the same day (e.g., two different correlation discoveries). The new constraint is `(user_id, type, date, metrics_key)` where `metrics_key` is a stable hash of the signal's metric list.

Alternatively: remove the unique constraint on `type` and instead use a new `generation_date` column (ISO date string, the calendar date in the user's local timezone) with a constraint on `(user_id, generation_date)` at the batch level — the entire batch is treated as an atomic daily generation. If today's batch already exists, skip generation.

**Recommended approach:** Add a `generation_date` column to `insights`. The task checks at the start: if any non-dismissed insight exists for this user with today's `generation_date`, exit immediately (date-lock). This is simpler than per-type constraints and correctly handles the "one generation per day" requirement.

### New fields on `Insight` model

- `generation_date: str` — ISO date (YYYY-MM-DD, user's local timezone) of the batch that created this card. Used for the date-lock check.
- `signal_type: str` — the `InsightSignal.signal_type` value (e.g. `trend_decline`, `compound_overtraining_risk`) for analytics and debugging.

---

## 11. Bug Fixes (Display Layer)

Four bugs currently prevent any insight from reaching the screen. All must be fixed as part of this implementation.

### Bug 1: Wrong API response key in Flutter

**File:** `zuralog/lib/features/today/data/today_repository.dart:250`
**Current:** `response.data['items']`
**Fix:** `response.data['insights']`

The backend returns `{"insights": [...], "total": N, "has_more": false}`. The Flutter app reads `items` which doesn't exist, falls back to `[]`, and shows the empty state.

### Bug 2: Field name mismatch — `summary` vs `body`

**File:** `zuralog/lib/features/today/domain/today_models.dart` — `InsightCard.fromJson()`
**Current:** reads `json['summary']`
**Fix:** reads `json['body']`

The backend sends `body`. Flutter reads `summary`. Card body text is always null/empty.

### Bug 3: Field name mismatch — `is_read` vs `read_at`

**File:** `zuralog/lib/features/today/domain/today_models.dart` — `InsightCard.fromJson()`
**Current:** `json['is_read'] as bool`
**Fix:** `json['read_at'] != null` — the backend sends a timestamp, not a boolean. Treat non-null `read_at` as `is_read = true`.

### Bug 4: Missing `GET /api/v1/insights/:id` endpoint

**File:** `cloud-brain/app/api/v1/insight_routes.py`
**Current:** Only `GET /api/v1/insights` (list) and `PATCH /api/v1/insights/:id` exist.
**Fix:** Add `GET /api/v1/insights/{insight_id}` endpoint that returns a single `InsightResponse`. Tapping a card to open the detail screen currently 404s.

### Bug 5: PATCH body field mismatch — `status` vs `action`

**File:** `zuralog/lib/features/today/data/today_repository.dart:269,276`
**Current:** Flutter sends `{'status': 'read'}` and `{'status': 'dismissed'}` (note: `dismissed` with a `d`)
**Fix:** Flutter must send `{'action': 'read'}` and `{'action': 'dismiss'}` — matching the backend's `InsightActionRequest` schema exactly. Note both the key name (`status` → `action`) and the value for dismiss (`'dismissed'` → `'dismiss'`) change.

**Also:** `InsightDetail.fromJson` in `today_models.dart` reads `json['summary']` (same as Bug 2) — fix both `InsightCard.fromJson` and `InsightDetail.fromJson` in the same pass.

---

## 12. Celery Beat Schedule

Add the daily insight generation task to the Celery Beat schedule. Because users are in different timezones, use one of two approaches:

**Approach: Hourly fan-out (Option B).** This is the correct design for a global product.

A new Celery Beat task `fan_out_daily_insights` runs at the top of every UTC hour (cron: `0 * * * *`). It:
1. Queries `user_preferences` for all users whose `timezone` field maps to a current local hour of 6 (i.e., `datetime.now(ZoneInfo(tz)).hour == 6`).
2. For each matching user, enqueues `generate_insights_for_user.delay(user_id)`.
3. The individual task starts with the date-lock check — if today's insights already exist, it exits immediately.

The fan-out task must handle timezone lookup failures gracefully: if a `timezone` value is invalid or missing, treat as UTC.

At 1M users spread across ~24 timezones, approximately 40,000 users hit 6 AM each hour — well within Celery's throughput capacity.

---

## 13. API Changes Summary

| Change | Type | File |
|--------|------|------|
| Fix `GET /api/v1/insights` response key (`insights` not `items`) | Bug fix (already correct on backend, Flutter reads wrong key) | `today_repository.dart` |
| Add `GET /api/v1/insights/{id}` endpoint | New endpoint | `insight_routes.py` |
| Add `generation_date` field to `Insight` model | Schema change | `insight.py`, new migration |
| Add `signal_type` field to `Insight` model | Schema change | `insight.py`, new migration |
| Add `OPENROUTER_INSIGHT_MODEL` env var | Config | `config.py`, `.env.example` |

---

## 14. New Files

| File | Purpose |
|------|---------|
| `cloud-brain/app/analytics/health_brief_builder.py` | Fetches all user data and builds `HealthBrief` |
| `cloud-brain/app/analytics/insight_signal_detector.py` | Runs all 8 signal categories, returns `list[InsightSignal]` |
| `cloud-brain/app/analytics/signal_prioritizer.py` | Ranks, deduplicates, and selects the final signal set |
| `cloud-brain/app/analytics/insight_card_writer.py` | LLM call + fallback logic, returns card dicts |
| `cloud-brain/app/analytics/user_focus_profile.py` | `UserFocusProfile` dataclass + inference logic |

---

## 15. Modified Files

| File | Change |
|------|--------|
| `cloud-brain/app/tasks/insight_tasks.py` | Replace current generator with new pipeline |
| `cloud-brain/app/worker.py` | Add hourly fan-out task to Beat schedule |
| `cloud-brain/app/models/insight.py` | Add `generation_date` and `signal_type` columns |
| `cloud-brain/app/api/v1/insight_routes.py` | Add `GET /{id}` endpoint |
| `cloud-brain/app/config.py` | Add `OPENROUTER_INSIGHT_MODEL` setting |
| `cloud-brain/alembic/versions/` | New migration for `generation_date`, `signal_type` |
| `zuralog/lib/features/today/data/today_repository.dart` | Fix `items` → `insights`, fix PATCH body |
| `zuralog/lib/features/today/domain/today_models.dart` | Fix `summary` → `body`, fix `is_read` → `read_at != null` |

---

## 16. Testing Requirements

### Backend unit tests

- `TestHealthBriefBuilder` — mock DB, verify all queries fire, verify data quality rules (stale source exclusion, multi-source preference order)
- `TestInsightSignalDetector` — one test per signal type, covering: signal fires when condition met, signal does not fire when condition not met, severity adjustments from focus profile
- `TestSignalPrioritizer` — verify anomaly pinning, verify diversity cap, verify deduplication, verify dynamic count
- `TestUserFocusProfile` — verify goal → metric mapping, verify dashboard layout inference, verify combined profile
- `TestInsightCardWriter` — mock OpenRouter, verify fallback fires on error, verify JSON parse failure triggers fallback
- `TestInsightDateLock` — verify second run for same user + same date is a no-op

### Backend integration tests

- End-to-end: given a seeded user with 30 days of data, run `generate_insights_for_user` and verify insights appear in `GET /api/v1/insights`
- Verify `GET /api/v1/insights/{id}` returns the correct card
- Verify `PATCH /api/v1/insights/{id}` with `action=read` and `action=dismiss` work correctly

### Flutter tests

- Verify `_fetchInsights` correctly reads `response.data['insights']`
- Verify `InsightCard.fromJson` correctly maps `body` and derives `is_read` from `read_at`
- Verify `markInsightRead` sends `{'action': 'read'}`

---

## 17. Data Requirements for Signals

This table documents how much data each signal category needs before it can fire. Used by the `InsightSignalDetector` to skip categories when data is insufficient — never show a signal you can't back up with real numbers.

| Category | Minimum data required |
|---------|-----------------------|
| A (trends) | ≥ 14 data points in 30-day window for the metric |
| B (goals) | At least 1 active goal |
| C (anomalies) | ≥ 14 historical points for the metric (existing requirement) |
| D (correlations) | ≥ 14 paired data points for both metrics |
| E (compound patterns) | Varies per pattern — documented in each pattern's condition above |
| F (focus inference) | Always runs — falls back to default if no preferences exist |
| G (streaks) | At least 1 streak row with current_count > 0 |
| H (data quality) | Always runs |

---

## 18. Signal Type vs DB Insight Type — Mapping

The `InsightSignalDetector` produces signals identified by `signal_type` strings (the analytics vocabulary). The `Insight` database row stores a `type` value (the display vocabulary). These are not always 1:1.

**Mapping rules:**

| Signal types (from detector) | DB `type` value | Rationale |
|------------------------------|-----------------|-----------|
| `trend_decline`, `trend_improvement` | `trend_decline` / `trend_improvement` | One-to-one, stored separately |
| `goal_near_miss`, `goal_behind_pace`, `goal_at_risk`, `goal_zero_progress`, `goal_no_activity_today` | `goal_nudge` | All are motivational goal prompts; use the existing DB type |
| `goal_met_today`, `goal_all_met`, `goal_streak` | `goal_nudge` | Same — positive goal signals use the same DB type |
| `anomaly` | `anomaly_alert` | Existing type |
| `correlation_positive`, `correlation_negative` | `correlation_discovery` | Existing type |
| `compound_*` (all compound patterns) | Their own type string (e.g. `compound_weight_plateau`) | New DB types — require INSIGHT_TYPES expansion |
| `streak_at_risk`, `streak_milestone_tomorrow`, `streak_personal_best`, `streak_broken_recovery`, `consistency_perfect_week` | `streak_milestone` | Existing type |
| `integration_stale`, `data_gap_sleep`, `data_gap_activity`, `new_integration` | `data_quality` | New DB type |
| `first_week` | `welcome` | Existing type |

The `signal_type` raw value is also stored in the new `signal_type` column on `Insight` for analytics and debugging.

---

## 19. Insight Type Taxonomy (Extended)

The `INSIGHT_TYPES` constant in `insight.py` must be expanded:

```python
INSIGHT_TYPES: tuple[str, ...] = (
    # Existing
    "sleep_analysis",
    "activity_progress",
    "nutrition_summary",
    "anomaly_alert",
    "goal_nudge",
    "correlation_discovery",
    "streak_milestone",
    "welcome",
    # New
    "trend_decline",
    "trend_improvement",
    "goal_at_risk",
    "goal_streak",
    "compound_weight_plateau",
    "compound_overtraining_risk",
    "compound_sleep_debt",
    "compound_deficit_too_deep",
    "compound_workout_collapse",
    "compound_recovery_peak",
    "compound_stress_cascade",
    "compound_dehydration_pattern",
    "compound_weekend_gap",
    "compound_event_on_track",
    "data_quality",
)
```

---

## 20. Cost Model

**Per user per day:**
- Python analytics: $0 (compute only)
- LLM call (insight writer): ~500 tokens in (brief + signals) + ~400 tokens out (5–8 card JSON)
- At typical cheap model pricing (~$0.15/M input, ~$0.60/M output): ~$0.00008 per user per day = ~$0.024 per user per month

**At 1M users:** ~$24,000/month for the insight writer — well within budget and far cheaper than using Kimi K2.5 for this task.

**Comparison:** Running Kimi K2.5 for insights would cost ~$2.50+ per user per month just for the insight generation (much larger context window needed). The cheap model approach saves ~99% on this specific feature.

---

## 21. Resolved Decisions and Open Questions

### Resolved

**TDEE estimation (was Open Question #2):**
Use the Harris-Benedict formula with the following inputs:
- **BMR inputs:** weight in kg (from latest `weight_measurements`), height (not stored — use population average of 170cm as fallback if not provided), age (derive from `user.birthday` if available), sex (derive from `user.gender` if available).
- **Activity multiplier:** derive from average `active_calories` over the last 14 days. Map to standard multipliers: < 200 kcal/day active → sedentary (×1.2), 200–400 → lightly active (×1.375), 400–600 → moderately active (×1.55), > 600 → very active (×1.725).
- If weight is unavailable, skip all TDEE-dependent compound patterns for this user rather than guessing.
- Store the computed TDEE estimate in `HealthBrief` for use by all compound pattern detectors.

**DB unique constraint approach (was Open Question #4):**
Use the `generation_date` column approach (Option B from §10). Add a `generation_date: str` column (ISO date, user's local timezone). The date-lock check at task start queries: "does any non-dismissed insight row exist for this user where `generation_date = today`?" If yes, exit immediately. The old `uq_insights_user_type_day` constraint should be **dropped** in the migration — it is replaced by the application-level date-lock. A database-level `(user_id, signal_type, generation_date)` unique constraint is added so duplicate signals within the same batch are prevented at the DB layer.

### Open (must resolve before implementation begins)

1. **Timezone field:** `user_preferences` does not currently store a timezone string. Add a `timezone: str` column (IANA timezone name, e.g. `"America/New_York"`) with default `"UTC"`. The mobile app should send the device timezone on every API request (add to the existing request headers or to the preferences update endpoint). The hourly Celery fan-out queries `user_preferences` for all users whose local hour (derived from `timezone`) is 6.

2. **Dashboard layout schema:** Confirm the exact card key names in `user_preferences.dashboard_layout` before implementing focus inference. The `UserFocusProfile` inference mapping in §7 Category F must use exact key names as stored in the DB. Read the Flutter `dashboard_layout` serialisation code to confirm the keys before hard-coding them in the detector.

3. **Insight model LLM model:** `OPENROUTER_INSIGHT_MODEL` must be set to a real model before the feature is merged. Confirm the chosen cheap model (candidates: `google/gemini-flash-2.5`, `openai/gpt-4o-mini`) and add it to `.env.example` and Railway environment variables.

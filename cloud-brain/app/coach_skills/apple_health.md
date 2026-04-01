# Apple Health — Coaching Guide

## When to use this skill
Use this skill when an iOS user asks about their health data, activity, sleep, heart health, fitness scores, weight, or nutrition tracked by their Apple devices.

## Quick Reference

| User asks about | Call this | Time range |
|---|---|---|
| General health / "how am I doing?" | `apple_health_read_metrics(data_type="daily_summary", ...)` | 7 days |
| Tiredness / low energy | `apple_health_read_metrics(data_type="daily_summary", ...)` | 5 days |
| Heart health | `apple_health_read_metrics(data_type="daily_summary", ...)` | 14 days |
| A specific workout | `apple_health_read_metrics(data_type="workouts", ...)` | Date range of session |
| HRV trend / meaning | `apple_health_read_metrics(data_type="hrv", ...)` | 14–30 days |

Always call the tool before speaking. If records come back empty, say so — do not guess.

## What this tool returns

**Tool name:** `apple_health_read_metrics`
**Required parameters:** `data_type`
**Optional parameters:** `start_date` (YYYY-MM-DD), `end_date` (YYYY-MM-DD)

Data comes from Apple HealthKit — aggregated from Apple Watch, iPhone sensors, and connected apps (Strava, MyFitnessPal, CalAI). As current as the user's last sync.

| data_type | Key fields |
|---|---|
| `daily_summary` | steps, active_calories, resting_heart_rate_bpm, hrv_ms, vo2_max_ml_kg_min, distance_meters, flights_climbed, body_fat_percentage, respiratory_rate_bpm, oxygen_saturation_pct, heart_rate_avg_bpm |
| `steps` | steps, total_steps |
| `calories` | active_calories, total_active_calories |
| `workouts` | activity_type, duration_seconds, distance_meters, calories, start_time |
| `sleep` | hours, quality_score (0–100, nullable) |
| `weight` | weight_kg |
| `nutrition` | calories, protein_grams, carbs_grams, fat_grams (all nullable) |
| `resting_heart_rate` | resting_heart_rate_bpm |
| `hrv` | hrv_ms |
| `vo2_max` | vo2_max_ml_kg_min |
| `body_fat` | body_fat_percentage |
| `respiratory_rate` | respiratory_rate_bpm |
| `oxygen_saturation` | oxygen_saturation_pct |
| `heart_rate` | heart_rate_avg_bpm |
| `distance` | distance_meters, total_distance_meters |
| `flights_climbed` | flights_climbed, total_flights |

`activity_type` values: `run`, `cycle`, `walk`, `swim`, `strength`, `unknown`.

**What requires Apple Watch vs iPhone alone:**
- Apple Watch required: hrv_ms, vo2_max_ml_kg_min, sleep stages, reliable resting HR
- iPhone alone: steps, distance, flights_climbed, nutrition (if logged), weight (if entered)
- `sleep quality_score`: null unless a third-party app writes a score to HealthKit — never assume it has a value

Any field in `daily_summary` can be null — this is normal.

## Core Pattern

Use `daily_summary` for any general "how am I doing?" question — it returns all scalar metrics in one call. Only switch to a specific `data_type` when you need workout details (`workouts`) or nightly sleep records (`sleep`).

## Scenarios

### "How am I doing this week?" / "Give me a health summary"
**Call:** `apple_health_read_metrics(data_type="daily_summary", start_date=today-7, end_date=today)`
**Look for:** Step trend (days above 7,000?), HRV stability (rising / stable / declining?), sleep hours (7–9 consistently?), resting HR (near baseline or elevated?)
**Frame it as:** Lead with the most interesting finding. One insight + supporting numbers + a next step. Example: "Your steps were strong Mon–Thu but dropped Fri–Sun. HRV improved mid-week — your body responded well to the activity load."

### "Why am I tired?" / "Why is my energy low?"
**Call:** `apple_health_read_metrics(data_type="daily_summary", start_date=today-5, end_date=today)`
**Look for:** (1) Sleep hours under 7 — most common cause; (2) HRV declining across period — incomplete recovery; (3) active calories very high + low HRV — overtraining signal; (4) resting HR elevated 5+ bpm above typical — illness or stress
**Frame it as:** Connect the dots between what the numbers show. Example: "Your sleep averaged 5.8 hours over 4 nights. Your HRV dropped from 48ms to 31ms across the same period. The tiredness is direct feedback — your body hasn't had enough time to recover."

### "How's my heart health?"
**Call:** `apple_health_read_metrics(data_type="daily_summary", start_date=today-14, end_date=today)`
**Look for:** Resting HR trend (stable or drifting up?), HRV this week vs prior-week 7-day average, flag if 5+ consecutive days more than 7 bpm above personal baseline
**Frame it as:** Use trend language, not alarm language. Example: "Your resting HR has averaged 62 bpm — stable and healthy. HRV held around 44ms this week, consistent with prior week. No red flags."

### "How was my workout?" / "Did I train hard enough?"
**Call:** `apple_health_read_metrics(data_type="workouts", start_date=session_date, end_date=session_date)`
**Look for:** duration_seconds (convert to minutes), distance_meters (convert to km or miles per user preference), calories (active), activity_type (confirm it's the right session)
**Frame it as:** Numbers need context. Example: "You ran 5.2km in 28 minutes — a 5:23/km pace. 380 active calories. Want me to compare that to your runs this month?"

### "What does my HRV mean?"
**Call:** `apple_health_read_metrics(data_type="daily_summary", start_date=today-14, end_date=today)`. Use `data_type="hrv"` if you need a longer 30-day window.
**Look for:** 7-day rolling average vs prior 7-day average; days more than 20% below rolling average (acute stress); multi-week downward trend (cumulative stress or overtraining)
**Frame it as:** Personalise to the user's own history. Important Apple Watch context to share: Apple Watch measures SDNN (not RMSSD like Oura/WHOOP/Fitbit) — numbers are not comparable across devices. Readings are taken opportunistically during the day, not overnight, making them more variable than overnight trackers. A single reading means almost nothing — trend is the signal. Example: "Your HRV ranged 42–48ms this week — above average for Apple Watch users and stable. No signs of cumulative recovery debt."

## Thresholds to cite consistently

| Metric | Range | What it means |
|---|---|---|
| Steps | Under 4,000 | Sedentary — high health risk |
| Steps | 5,000–6,999 | Below optimal |
| Steps | 7,000–9,000 | Where most meaningful health benefits begin — the real target |
| Steps | 10,000+ | Very active — diminishing returns above 9,000 |
| Sleep | 7–9 hours | Healthy target |
| Sleep | Under 7 hours | Meaningful recovery impairment |
| Resting HR | 40–55 bpm | Athletic range |
| Resting HR | 60–80 bpm | Normal |
| Resting HR | 80–99 bpm | High-normal |
| Resting HR | 100+ bpm | Clinically elevated |
| HRV (Apple SDNN) | ~36ms | Average Apple Watch user |
| HRV (Apple SDNN) | ~18ms | Bottom 10% |
| HRV (Apple SDNN) | ~76ms | Top 10% |
| HRV (Apple SDNN) | Any value | Compare only to the user's own history — not other people |
| VO2 Max | Under 30 | Low |
| VO2 Max | 30–38 | Fair |
| VO2 Max | 38–46 | Good |
| VO2 Max | 46–55 | Excellent |
| VO2 Max | 55+ | Superior (women run ~8–10 mL/kg/min lower than men at the same level) |

## Common Mistakes

1. **Reacting to a single low HRV reading** — day-to-day swings of 20% are normal; always look at the 7-day trend first before saying anything.
2. **Comparing this user's HRV to another person's number** — HRV baselines are entirely personal; only compare the user to their own history.
3. **Saying "I can't see your data" without trying the tool** — always call the tool first. If records come back empty, say: "Your Apple Health data is empty for this period — make sure the Zuralog app has synced recently."
4. **Reporting a number without context** — "You got 8,421 steps" is not coaching. "You hit 8,421 steps — that's above the 7,000 level where most health benefits kick in" is coaching.
5. **Never diagnose.** If a metric is persistently outside normal range (e.g. resting HR elevated for 2+ weeks), suggest the user see a doctor. Never speculate on what condition it might indicate.

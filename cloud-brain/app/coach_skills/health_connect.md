# Health Connect — Coaching Guide

## When to use this skill
Use this skill when an Android user asks about their health data, activity, sleep, heart health, fitness scores, weight, or nutrition tracked through Google Health Connect.

## Quick Reference

| User asks about | Call this | Time range |
|---|---|---|
| General health / "how am I doing?" | `health_connect_read_metrics(data_type="daily_summary", ...)` | 7 days |
| Tiredness / low energy | `health_connect_read_metrics(data_type="daily_summary", ...)` | 5 days |
| Heart health | `health_connect_read_metrics(data_type="daily_summary", ...)` | 14 days |
| A specific workout | `health_connect_read_metrics(data_type="workouts", ...)` | Date range of session |
| HRV trend | `health_connect_read_metrics(data_type="hrv", ...)` | 14–30 days |

Always call the tool before speaking. If records come back empty, say so — do not guess.

## What this tool returns

**Tool name:** `health_connect_read_metrics`
**Required parameters:** `data_type`
**Optional parameters:** `start_date` (YYYY-MM-DD), `end_date` (YYYY-MM-DD)

Data comes from Google Health Connect — a privacy-first, on-device data hub that aggregates from any apps the user has connected: Samsung Health, Fitbit, Garmin Connect, MyFitnessPal, and others. As current as the user's last sync.

**Critical platform note:** On iOS, Apple Watch is a consistent, dominant data source. On Android, there is no single standard wearable. A Samsung Galaxy Watch user will have very different data completeness than a Garmin user or a phone-only user. Always check which fields actually have data before coaching from them.

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

`activity_type` values: `run`, `cycle`, `walk`, `swim`, `strength`, `unknown`. Any field can be null — especially on Android where availability varies by wearable.

**Data availability by wearable:**

| Source | Steps | Sleep stages | HRV | VO2 Max | Heart Rate |
|---|---|---|---|---|---|
| Samsung Galaxy Watch | ✓ | ✓ | Inconsistent | Via Samsung Health | ✓ |
| Garmin (via Connect) | ✓ | ✓ (basic) | ✗ not shared | ✗ not shared | ✓ |
| Fitbit / Pixel Watch | ✓ | ✓ | Partial | Partial | ✓ |
| Phone only, no wearable | ✓ | ✗ no stages | ✗ | ✗ | ✗ |

Key caveats:
- Garmin explicitly does NOT share HRV through Health Connect — treat `hrv_ms` as likely null for Garmin users
- VO2 max: no native Health Connect data type — only present if a connected app writes it; expect null for most users
- `sleep quality_score`: almost always null on Android — do not reference unless it has a value
- HRV measurement: unlike Apple (consistent SDNN), Android HRV depends on source app algorithm (RMSSD, SDNN, or custom); never compare Android `hrv_ms` numbers to Apple `hrv_ms` numbers

## Core Pattern

Use `daily_summary` first, but expect more null fields than on Apple Health. Before coaching from any metric, verify it has a non-null value. If a metric is null, tell the user what their setup doesn't share rather than saying their data is "incomplete."

## Scenarios

### "How am I doing this week?"
**Call:** `health_connect_read_metrics(data_type="daily_summary", start_date=today-7, end_date=today)`
**Look for:** Which fields have data vs null — build the response around what's available. Step trend (days above 7,000?), sleep hours (7–9?), any heart rate data.
**Frame it as:** Lead with what you have; be honest about gaps without making it sound like the user's fault. Example: "Your steps were strong all week — averaging 9,200 a day. Sleep looks solid at 7.4 hours. Your wearable doesn't share HRV with Health Connect, so I can't give a recovery score — but from what I can see, you're in a good place."

### "Why am I tired?"
**Call:** `health_connect_read_metrics(data_type="daily_summary", start_date=today-5, end_date=today)`
**Look for:** (1) Sleep hours under 7 — most reliably available across all setups; (2) active calories very high + short sleep — overtraining signal; (3) HRV declining — only if non-null; (4) resting HR elevated — only if available
**Frame it as:** Work with what you have, honest about gaps. Example: "Your sleep has averaged 5.6 hours over 4 nights — that's almost certainly the cause. I don't have HRV data from your setup, but the sleep shortage alone explains the fatigue."

### "How's my heart health?"
**Call:** `health_connect_read_metrics(data_type="daily_summary", start_date=today-14, end_date=today)`
**Android note:** Heart rate availability varies. Samsung Galaxy Watch and Fitbit provide reliable resting HR. Garmin does too. Phone-only users have no heart rate data.
**Look for:** Resting HR trend if available; workout data as a cardiovascular proxy
**Frame it as:** Clear about what you can and can't see. Example: "Your resting HR is averaging 68 bpm — healthy range. I don't have HRV data from your setup, which would give a fuller recovery picture."

### "How was my workout?"
**Call:** `health_connect_read_metrics(data_type="workouts", start_date=session_date, end_date=session_date)`
**Android note:** Workout data syncs reliably from Garmin, Samsung, and Fitbit.
**Look for:** duration_seconds (convert to minutes), distance_meters (convert to km/miles), calories (active), activity_type
**Frame it as:** Numbers in context. Example: "You ran 5.2km in 28 minutes — a 5:23/km pace. 380 active calories. Want me to compare that to your runs this month?"

### User has no sleep stage data or HRV is null
**Signs:** Sleep records have hours but no stages; `hrv_ms` is consistently null
**What to say:** "I can see you slept 7 hours but your current setup doesn't share sleep stages with Health Connect. A Samsung Galaxy Watch or Fitbit would give you deep sleep and REM tracking." / "Your wearable doesn't share HRV through Health Connect — this is common with Garmin devices. A Samsung Galaxy Watch would give you that."
**What NOT to do:** Don't say "your deep sleep was low" without stage data. Don't say "your HRV is 0" when it's null.

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
| HRV (Android — if available) | Any value | Measurement method varies by source (RMSSD, SDNN, or custom) — compare only to the user's own history on the same device; do NOT compare to Apple Watch numbers |
| VO2 Max | Under 30 | Low |
| VO2 Max | 30–38 | Fair |
| VO2 Max | 38–46 | Good |
| VO2 Max | 46–55 | Excellent |
| VO2 Max | 55+ | Superior (women run ~8–10 mL/kg/min lower than men at the same level) |

## Common Mistakes

1. **Assuming HRV is available** — check for nulls first; if `hrv_ms` is consistently null, do not reference HRV at all.
2. **Comparing Android HRV to Apple Watch HRV numbers** — different devices use different measurement methods; the numbers are not comparable.
3. **Saying "your data looks incomplete"** — say "your current setup doesn't share [X] — here's what I can work with" instead.
4. **Reporting a null field as zero** — null `hrv_ms` means the data doesn't exist, not that HRV is 0.
5. **Refusing to help because some fields are null** — coach from what you have; Android data gaps are normal and expected.
6. **Never diagnose.** If a metric is persistently outside normal range (e.g. resting HR elevated for 2+ weeks), suggest the user see a doctor. Never speculate on what condition it might indicate.

# Tool Orchestration & Platform Awareness — Design Spec
**Date:** 2026-04-04
**Status:** Approved

## Problem

Zura's tool-use behavior has two structural gaps:

1. **No platform awareness.** Zura doesn't know whether the user is on iPhone or Android at the start of a conversation. It can call the wrong health data source or waste a turn guessing.

2. **Hardcoded, narrow rules.** The one rule governing multi-tool behavior (`_CAPABILITIES_BLOCK` Rule #1) only covers the check-in case. Every other multi-source scenario — workouts, journal + health cross-reference, external integrations — has no guidance. The AI may stop after a single empty result and give an incomplete response.

The fix is not more hardcoded rules. It's a single always-visible orchestration block in the system prompt that teaches Zura how to reason about all four data sources, for any question.

---

## The Four Data Sources

Zura has access to four distinct data sources. Every orchestration decision flows from understanding which source to use, in what order, and why.

### Source 1 — ZuraLog Database (native data)
Goals, streaks, achievements, journal entries, supplements, and AI-generated insight cards. Stored directly in our PostgreSQL database. Always available, always fast. No device required, no external service call.

**Tools:** `get_goals`, `get_streaks`, `get_achievements`, `get_journal_entries`, `get_supplements`, `get_insights`, `query_memory`

### Source 2 — Device health data (synced into our database)
Steps, sleep, heart rate, HRV, VO2 max, workouts, weight, nutrition. Originates from Apple Health (iOS) or Google Health Connect (Android), but is synced into our PostgreSQL database at ingest time. The MCP tools query our database — not the device directly. If records are empty, it means no recent sync occurred; the user needs to open the app and sync.

**Tools:** `apple_health_read_metrics`, `health_connect_read_metrics`

**Platform note:** Apple Health is the default for iOS users; Health Connect is the default for Android users. This is a starting point, not a restriction. If the user asks to query a specific source regardless of their registered platform, always honor that request.

### Source 3 — Direct integrations (live external API calls)
Strava, Fitbit, Garmin, Oura, Withings, Polar. These make live HTTP calls to external services on every tool invocation. They are slower than database queries, subject to rate limits, and can fail. Use them when the user asks something specific to those services, or when our database doesn't have what's needed.

**Tools:** `strava_get_activities`, `strava_create_activity`, `fitbit_*`, `garmin_*`, `oura_*`, `withings_*`, `polar_*`

### Source 4 — Indirect integrations (already in our database)
Apps like MyFitnessPal, Garmin Connect, or any third-party app that writes data into Apple Health or Google Health Connect. That data flows through our sync pipeline at ingest time and lands in our database tagged with its source. Zura doesn't need to do anything special — it's queryable through the same Source 2 health tools.

---

## Design

### Change 1 — Platform injected into the system prompt

**What:** Add a `platform` field to the `UserProfile` dataclass and surface it in the `## About This User` section of every conversation's system prompt.

**Value:** `"ios"`, `"android"`, or `None` (omitted when unknown).

**Where it comes from:** The `user_device` table already stores `platform` per registered device. The profile loader queries the user's most recently active device and reads its `platform` column.

**How it appears in the prompt:**
```
## About This User
- Name: Alex
- Platform: iOS
- Goals: weight_loss, sleep
- Units: metric
- Timezone: America/New_York
```

**Files changed:**
- `cloud-brain/app/agent/prompts/system.py` — add `platform: str | None` to `UserProfile`; update `_build_profile_block()` to emit the platform line when present
- `cloud-brain/app/api/v1/chat.py` — update `_load_user_profile()` to query `user_device` for the most recent device and pass `platform` into `UserProfile`

---

### Change 2 — New `_TOOL_ORCHESTRATION_BLOCK` in the system prompt

A new constant added to `system.py` and appended to all three persona prompts (Tough Love, Balanced, Gentle) alongside `_SAFETY_BLOCK` and `_CAPABILITIES_BLOCK`.

The block contains four rules:

#### Rule 1: Query our database first
Sources 1 and 2 both live in our PostgreSQL database. They are fast and reliable. Always start there before reaching for a live external integration (Source 3). Only call a direct integration tool when the user asks about something specific to that service, or when the database has no relevant data.

#### Rule 2: Platform routing is a smart default, not a strict rule
Use the platform from "About This User" to choose the starting health data tool. iOS → try `apple_health_read_metrics` first. Android → try `health_connect_read_metrics` first. If the user explicitly asks to query a different source — or if the default returns empty and the other platform source might have data — query it. Never refuse a user's request to check a specific source just because their registered platform doesn't match.

#### Rule 3: Gather from all relevant sources before responding
Before responding to any question about the user's health, progress, or status — think about which of the four sources could add useful context. Do not answer from a single source when more context exists elsewhere. A question about how the user is doing may involve goals (Source 1), step and sleep data (Source 2), and a recent Strava run (Source 3). Gather what's relevant, then respond. The pattern library is intentionally not prescribed here — Zura reasons from the principle: "What sources could help me answer this better?"

#### Rule 4: Always be transparent about what was searched; never stop on empty
Every response where tools were used must include a plain statement of exactly which sources were checked. This applies even when data was found.

Examples:
- "I checked your ZuraLog goals, Apple Health activity data, and step history for the past 7 days."
- "I checked your ZuraLog database and Apple Health — both came back empty for this period. If your data is in Strava or Fitbit, just say so and I'll check there."

If one source returns empty, continue querying the other relevant sources before responding. Never give a one-liner response because a single source returned nothing. The search statement at the end of the response tells the user exactly where Zura looked — giving them the ability to redirect in the next message (e.g. "actually, check Strava").

**Anti-patterns (explicitly named):**
- **Single-source stop** — calling one tool and responding before checking all relevant sources
- **Empty-and-out** — stopping the entire response because one source returned no records
- **Silent search** — responding without telling the user which sources were checked
- **Repeat call** — calling the same tool twice with identical parameters in the same turn
- **Fabrication** — estimating or inventing numbers when a tool returned nothing

---

### Change 3 — Remove hardcoded Rule #1 from `_CAPABILITIES_BLOCK`

The existing Rule #1 in `_CAPABILITIES_BLOCK` reads:

> "For overall check-in questions ('How am I doing?', 'How was my day?', 'Give me a summary'), always call BOTH `apple_health_read_metrics` (data_type=daily_summary) AND `get_goals` before responding — even if health data comes back empty."

This is replaced entirely by the broader Rule 3 in `_TOOL_ORCHESTRATION_BLOCK`. Remove it. The remaining six rules in `_CAPABILITIES_BLOCK` stay unchanged.

---

### Change 4 — Fix iOS-only language in `_CAPABILITIES_BLOCK`

The data freshness note for the health tool currently reads:

> "Data freshness: populated by the user's iOS device after Apple Health authorization."

This excludes Android users. Replace with:

> "Data freshness: populated by the user's device after health authorization."

---

### Change 5 — Fix "Zuralog" → "ZuraLog" throughout `system.py`

Every instance of "Zuralog" in `system.py` is corrected to "ZuraLog." This includes the opening lines of all three persona prompts, the safety block identity rule, and any other occurrences. When a user asks what app they're using, Zura will respond with the correctly capitalized name.

---

## Files Changed

| File | What changes |
|---|---|
| `cloud-brain/app/agent/prompts/system.py` | Add `platform` to `UserProfile`; update `_build_profile_block()`; add `_TOOL_ORCHESTRATION_BLOCK`; append it to all three persona prompts; remove Rule #1 from `_CAPABILITIES_BLOCK`; fix iOS-only language; fix "Zuralog" → "ZuraLog" throughout |
| `cloud-brain/app/api/v1/chat.py` | Update `_load_user_profile()` to query `user_device` and populate `platform` |

No new files. No database migrations. No API changes. No Flutter changes.

---

## Out of Scope

- The `apple_health.md` and `health_connect.md` coach skill documents are not changed. They remain focused on data interpretation, not orchestration.
- No changes to the MCP servers themselves.
- No changes to the tool filtering or registry logic.
- Dynamic pattern library (intentionally not built — principles replace it).

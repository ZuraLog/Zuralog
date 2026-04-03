# Tool Orchestration and Platform Awareness -- Implementation Plan
**Date:** 2026-04-04  
**Branch:** `feat/tool-orchestration-prompt`  
**Spec:** `docs/superpowers/specs/2026-04-04-tool-orchestration-design.md`

---

## Files touched

| # | File | What changes |
|---|---|---|
| 1 | `cloud-brain/app/agent/prompts/system.py` | Dataclass field, profile builder, new constant, persona wiring, text fixes |
| 2 | `cloud-brain/app/api/v1/chat.py` | Device query, platform passed to UserProfile |
| 3 | `cloud-brain/tests/agent/test_prompts.py` | Verify tests still pass; add coverage for new block |

---

## Task list

### Task 1 -- Add `platform` field to `UserProfile` dataclass
**File:** `cloud-brain/app/agent/prompts/system.py`  
**Dependencies:** None

On the `UserProfile` dataclass (line 29), add a new field after `height_cm`:

```python
platform: str | None
```

Update the class docstring: `platform: Device platform -- ios, android, or None when unknown.`

### Task 2 -- Update `_build_profile_block()` to emit the platform line
**File:** `cloud-brain/app/agent/prompts/system.py`  
**Dependencies:** Task 1

Inside `_build_profile_block()` (starts at line 55), add a conditional block **after the Name line (line 69) and before the birthday block (line 70)**. This placement matches the spec example output which shows Platform right after Name.

```python
if profile.platform is not None:
    label = 'iOS' if profile.platform == 'ios' else 'Android'
    lines.append(f'- Platform: {label}')
```

Note: the spec shows iOS and Android as display labels, not the raw ios/android strings from the database. Map them.

### Task 3 -- Write the `_TOOL_ORCHESTRATION_BLOCK` constant
**File:** `cloud-brain/app/agent/prompts/system.py`  
**Dependencies:** None

Create a new string constant named `_TOOL_ORCHESTRATION_BLOCK` placed between `_CAPABILITIES_BLOCK` (ends around line 165) and `_SAFETY_BLOCK` (starts around line 171). The constant is a triple-quoted string containing:

**Section header:** `## Tool Orchestration`

**Rule 1 -- Query our database first.**
Explain that Sources 1 (ZuraLog native data) and 2 (device health data synced into our database) are fast local queries. Source 3 (Strava, Fitbit, Garmin, Oura, Withings, Polar) makes live external API calls that are slower and can fail. Always start with database tools. Only call a direct integration tool when the user asks about that specific service, or when the database has no relevant data.

**Rule 2 -- Platform routing is a smart default, not a strict rule.**
Use the platform from About This User to pick the starting health data tool. iOS means try `apple_health_read_metrics` first; Android means try `health_connect_read_metrics` first. If the user explicitly asks for a different source, honor it. If the default returns empty and the other platform source might have data, try it. Never refuse a request just because the registered platform does not match.

**Rule 3 -- Gather from all relevant sources before responding.**
Before answering any question about health, progress, or status, think about which sources could add useful context. Do not answer from a single source when more context exists elsewhere. A check-in question may involve goals (Source 1), step and sleep data (Source 2), and a recent Strava run (Source 3). Gather what is relevant, then respond. There is no static pattern table -- reason from the principle: What sources could help me answer this better?

**Rule 4 -- Always be transparent about what was searched; never stop on empty.**
Every response where tools were used must include a plain statement of which sources were checked -- even when data was found. Provide two examples:
- I checked your ZuraLog goals, Apple Health activity data, and step history for the past 7 days.
- I checked your ZuraLog database and Apple Health -- both came back empty for this period. If your data is in Strava or Fitbit, just say so and I will check there.

If one source returns empty, continue querying other relevant sources before responding. Never give a one-liner because a single source returned nothing. The source statement tells the user exactly where Zura looked so they can redirect in the next message.

Name the five anti-patterns explicitly as a bullet list:
- **Single-source stop** -- calling one tool and responding before checking all relevant sources
- **Empty-and-out** -- stopping the entire response because one source returned no records
- **Silent search** -- responding without telling the user which sources were checked
- **Repeat call** -- calling the same tool twice with identical parameters in the same turn
- **Fabrication** -- estimating or inventing numbers when a tool returned nothing

### Task 4 -- Append `_TOOL_ORCHESTRATION_BLOCK` to all three persona prompt constants
**File:** `cloud-brain/app/agent/prompts/system.py`  
**Dependencies:** Task 3

Each persona constant (TOUGH_LOVE_PROMPT, BALANCED_PROMPT, GENTLE_PROMPT) currently ends with `+ _CAPABILITIES_BLOCK`. Add `+ _TOOL_ORCHESTRATION_BLOCK` after it in all three. The orchestration block goes **after** `_CAPABILITIES_BLOCK`.

### Task 5 -- Remove hardcoded Rule #1 from `_CAPABILITIES_BLOCK`
**File:** `cloud-brain/app/agent/prompts/system.py`  
**Dependencies:** Task 3 (the replacement block must exist before removing the old rule)

In the Rules of Engagement section inside `_CAPABILITIES_BLOCK`, the current Rule 1 spans lines 136-140 and prescribes calling BOTH apple_health_read_metrics AND get_goals for check-in questions.

Replace it with a shorter, general version:

> 1. **Check Data First:** If a user asks about their status, DO NOT guess. Use your tools to fetch their actual stats before responding.

This keeps the rule number (1) and the spirit (check data first) but removes the hardcoded two-call pattern, which is now covered by Rule 3 in the orchestration block.

### Task 6 -- Fix iOS-only language in `_CAPABILITIES_BLOCK`
**File:** `cloud-brain/app/agent/prompts/system.py`  
**Dependencies:** None

On line 107, change the data freshness note from iOS-specific to platform-neutral:

Before: Data freshness populated by the user iOS device after Apple Health authorization. If records are empty mention that the user should sync their Apple Health data.

After: Data freshness populated by the user device after health authorization. If records are empty mention that the user should sync their health data.

Two changes: (a) remove iOS before device, (b) remove Apple Health before authorization and data, replacing with just health.

### Task 7 -- Fix Zuralog to ZuraLog throughout the file
**File:** `cloud-brain/app/agent/prompts/system.py`  
**Dependencies:** None

There are exactly 4 occurrences of Zuralog in this file:

1. **Line 2** (module docstring): Zuralog Cloud Brain becomes ZuraLog Cloud Brain
2. **Line 200** (TOUGH_LOVE_PROMPT opening): You are Zuralog becomes You are ZuraLog
3. **Line 234** (BALANCED_PROMPT opening): You are Zuralog becomes You are ZuraLog
4. **Line 268** (GENTLE_PROMPT opening): You are Zuralog becomes You are ZuraLog

Do NOT change occurrences of Zura (without log) -- those are the AI short name and are correct as-is.

### Task 8 -- Update `_load_user_profile()` to query for platform
**File:** `cloud-brain/app/api/v1/chat.py`  
**Dependencies:** Task 1 (the `platform` field must exist on `UserProfile`)

In `_load_user_profile()` (starts at line 293), add a **separate query** after the existing user+preferences JOIN query. This keeps the existing query clean and avoids complicating the LEFT JOIN.

Steps:

1. Add an import for `UserDevice` at the top of the file (around line 62, near other model imports):

```python
from app.models.user_device import UserDevice
```

2. After `row = result.first()` succeeds and user/prefs are extracted (around line 330), add a second query:

```python
device_result = await db.execute(
    select(UserDevice.platform)
    .where(UserDevice.user_id == user_id)
    .order_by(UserDevice.last_seen_at.desc().nulls_last())
    .limit(1)
)
platform = device_result.scalar_one_or_none()
```

3. Pass `platform=platform` into the `UserProfile(...)` constructor on line 332.

4. Also add `platform=None` to the `_default_profile` on line 310 (the fallback when no user row exists).

**Important:** The `order_by` uses `.desc().nulls_last()` so that the most recently seen device wins, and devices that have never been seen (null `last_seen_at`) fall to the bottom. The table name is `user_devices` (plural) per the model `__tablename__`.

### Task 9 -- Run tests and fix any breakage
**File:** `cloud-brain/tests/agent/test_prompts.py` (and any other test files that break)  
**Dependencies:** Tasks 1-8

Run the existing test suite:

```bash
cd cloud-brain && python -m pytest tests/agent/test_prompts.py -v
```

Expected breakage and fixes:

1. **Any test that constructs `UserProfile` directly** will fail because the new `platform` field has no default. Search the entire test suite for `UserProfile(` and add `platform=None` to every constructor call that is missing it.

2. **`test_safety_block_present_in_all_personas`** (line 291) should still pass -- it checks for strings inside the safety block which is unchanged.

3. **The orchestration block is new content** -- add at least one test to verify it is present in all personas:

```python
def test_tool_orchestration_block_present_in_all_personas():
    for persona in ('tough_love', 'balanced', 'gentle'):
        prompt = build_system_prompt(persona=persona)
        assert 'Tool Orchestration' in prompt
        assert 'Single-source stop' in prompt
        assert 'Empty-and-out' in prompt
        assert 'Fabrication' in prompt
```

4. Run the full test suite (not just prompt tests) to catch any import errors or integration test breakage:

```bash
cd cloud-brain && python -m pytest --tb=short -q
```

### Task 10 -- Git: create branch and commit
**Dependencies:** Task 9 (all tests pass)

Use the `git` subagent for all operations:

1. Create branch `feat/tool-orchestration-prompt` from `main`
2. Stage the changed files:
   - `cloud-brain/app/agent/prompts/system.py`
   - `cloud-brain/app/api/v1/chat.py`
   - `cloud-brain/tests/agent/test_prompts.py`
3. Commit with message: `feat(prompts): add tool orchestration block and platform awareness`
4. Push the branch

---

## Execution order summary

Tasks 1, 3, 6, 7 have no dependencies and can be done in any order (or in parallel).  
Task 2 depends on Task 1.  
Task 4 depends on Task 3.  
Task 5 depends on Task 3.  
Task 8 depends on Task 1.  
Task 9 depends on all of Tasks 1-8.  
Task 10 depends on Task 9.

```
Independent:  1, 3, 6, 7
Then:         2 (needs 1), 4 (needs 3), 5 (needs 3), 8 (needs 1)
Then:         9 (needs all above)
Finally:      10 (needs 9)
```

---

## Risks and notes

- **No migration needed.** The `user_devices` table and its `platform` column already exist. We are only reading from it.
- **No API contract change.** The `platform` value is injected into the system prompt only -- it never surfaces in any API response.
- **Null safety.** When a user has no registered device, `platform` is `None` and the profile block simply omits the Platform line. The orchestration block still works -- it just cannot provide a smart default, so the AI picks a source based on context.
- **Test scope.** The `_load_user_profile` function is async and hits the database, so it is not unit-tested in `test_prompts.py`. The prompt assembly tests in that file cover the `system.py` changes. If integration tests exist for `chat.py`, they will exercise the device query path.

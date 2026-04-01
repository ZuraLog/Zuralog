# [Tool Name] — Coaching Guide

## When to use this skill
One sentence. Starts with "Use this skill when..." — this line is extracted as the index entry the AI sees in every conversation.

## Quick Reference

| User asks about | Call this | Time range |
|---|---|---|
| General health / "how am I doing?" | `tool_name(data_type="daily_summary", ...)` | 7 days |
| [Specific topic] | `tool_name(data_type="X", ...)` | 1–7 days |
| [Another topic] | `tool_name(data_type="Y", ...)` | 14–30 days |

Always call the tool before speaking. If records come back empty, say so — do not guess.

## What this tool returns

**Tool name:** `tool_name_here`
**Required parameters:** `param1`, `param2`, `param3`

Brief note on where the data comes from and any freshness caveat (e.g. "as current as the user's last sync").

| data_type | Key fields |
|---|---|
| `daily_summary` | field1, field2, field3 (any can be null) |
| `specific_type` | field_a, field_b |

Note any fields that are nullable, platform-specific, or require a wearable.

## Core Pattern

**The one rule that governs everything else in this skill.**

For example: "Use `daily_summary` for general questions — it returns all scalar metrics in one call. Only use specific data_types when you need deeper detail (e.g. per-workout breakdown)."

## Scenarios

### "[Most common user question]"
**Call:** `tool_name(data_type="...", start_date=today-7, end_date=today)`
**Look for:** what to check in the response, what pattern means what
**Frame it as:** lead with [X], not [Y] — one insight + supporting numbers + a next step

### "[Second common question]"
**Call:** ...
**Look for:** ...
**Frame it as:** ...

### "[Third common question]"
**Call:** ...
**Look for:** ...
**Frame it as:** ...

(3–5 scenarios. Pick questions real users actually ask, not hypotheticals.)

## Thresholds to cite consistently

| Metric | Range | What it means |
|---|---|---|
| [Metric name] | [value range] | [plain-language interpretation] |
| [Metric name] | [value range] | [plain-language interpretation] |

## Common Mistakes

1. **[Mistake]** — [what to do instead]
2. **[Mistake]** — [what to do instead]
3. **Never diagnose.** If a metric is persistently outside normal range, suggest the user see a doctor. Never speculate on what condition it might indicate.

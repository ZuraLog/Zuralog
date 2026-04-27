# Supplements & Meds — Complete UI Overhaul Design

**Date:** 2026-04-27  
**Status:** Approved  
**Branch:** `feat/supplements-log-overhaul`

---

## Problem Statement

The current supplements feature is a dead-end form. You open it, manually tick boxes, hit Save, and close it. There is no insight, no offline resilience, no way to understand what your stack is doing for you, and no AI — just a list and a save button. This overhaul replaces it entirely with a gesture-first, AI-first, offline-first system that makes supplements feel as effortless as logging water.

---

## What We Are Replacing

The existing `SupplementsLogScreen` — a full-screen route with a `ListView` of checkboxes, an inline add form, a notes field, and a bottom Save button — is **deleted in full**. Nothing from it is carried forward. The route, the widget, and the associated navigation entry are all removed.

---

## Architecture: Two Components

The new feature is split into two distinct areas, each with a clear job:

### 1. Daily Check-off Panel (`ZSupplementsLogPanel`)

This replaces the old full-screen route. It appears inline inside the existing `ZLogGridSheet`, just like Water and Weight already work — the FAB on Today opens a bottom sheet, the supplements tile now shows an inline panel instead of navigating away.

**What it does:**
- Shows the user's stack grouped by timing window (Morning / Evening / Anytime)
- Each supplement row auto-saves the moment it is tapped — no Save button required
- A 4-second undo toast appears immediately after a **check-in tap** (marking something as taken) so accidental taps can be reversed without a dialog. The toast does not appear for uncheck taps — those go through the confirmation dialog instead.
- Offline writes are queued locally first; the panel works identically with no internet connection
- A tiny inline cloud icon next to the count (e.g. "2 of 5 taken today ☁↑") shows sync state — upload icon at 35% opacity when pending, done icon in body-blue (`#64D2FF`) at 55% opacity when synced. No banners. No badges on individual rows. Exactly the same pattern used by Water and Weight.
- A "+ Log something extra today" link at the bottom lets the user log a one-off supplement (name + dose + unit) for today only without adding it to their permanent stack
- A "Manage my stack →" link at the bottom navigates to the Stack Management screen
- An "Open Coach →" card lets the user deep-link to the Coach tab if they want personalised advice from Zura

**Unchecking a taken item:**  
Tapping a taken row shows a modal confirmation dialog before anything is deleted:

> **Remove log entry?**  
> This will delete your **[Supplement Name]** record for today. This action cannot be undone.  
> [Remove entry] (red, destructive) [Cancel]

The entry is only removed after the user taps "Remove entry". Tapping Cancel or dismissing the dialog leaves the log untouched. This is non-negotiable UX — there must always be a way to undo a logged entry.

**Empty state:**  
First-time users who have no stack yet see an empty state with a prompt and a single primary button: "Set up my stack". This navigates to the Stack Management screen with the Add form pre-opened.

---

### 2. Stack Management Screen (`SupplementsStackScreen`)

A dedicated full-screen route for managing the permanent supplement routine. Reached from:
- The gear icon in the panel header
- The "Manage my stack →" link in the panel footer
- The "Set up my stack" empty state button

**What it does:**
- Lists all supplements with name, dose, unit, form, and timing
- Swipe-to-delete or long-press to reorder
- "Add supplement or med" button opens the Add form (below)
- Supplements can be toggled inactive without being deleted (so you can pause something temporarily without losing it)

**Add / Edit form fields:**
- Name (required, free text)
- Amount (numeric) + Unit (option grid — mg / mcg / IU / g / ml / other)
- Form (option grid — Tablet / Capsule / Softgel / Powder / Liquid / Other)
- Timing (option grid — Morning / With lunch / Evening / With meal / Anytime)

**Option grid layout:** 2-column grid. If the option count is odd, the last item spans both columns (full-width). No chip selectors anywhere in this feature.

**Scan the Label:**  
The Add form includes a "Scan label" button that opens the same three-tile entry point used by the nutrition log (Camera · Photos · Barcode). The scanned result pre-fills Name, Amount, Unit, and Form. The user reviews the pre-filled card and confirms before the supplement is added to their stack. No custom camera UI is built — this reuses the existing nutrition scan infrastructure (`log_meal_sheet.dart` / `MealReviewScreen` pattern) with supplement-specific field mapping.

---

## Offline Capability

Supplements must work identically offline as online, matching the Water and Weight implementation.

**How it works:**
1. When the user taps a row, the log entry is written to the local database immediately. The UI updates instantly.
2. A background sync service picks up pending entries and posts them to the server when a connection is available.
3. The sync state is tracked per session with a three-value enum: `none` / `pending` / `synced`.
4. The panel subtitle shows the sync state via the inline cloud icon — no other visual changes.

**Conflict handling:** If the same supplement is tapped while offline on two devices, the server deduplicates by supplement ID + calendar day. Duplicate `supplement_taken` ingest events on the same day are ignored (idempotent by design).

---

## AI Features (Phase 1 — Built with This Overhaul)

Six AI capabilities are included in this overhaul:

| # | Feature | Where it appears |
|---|---------|-----------------|
| 1 | **Build my stack via Zura** | Empty state + Coach deep-link card in panel |
| 2 | **Conflict & overlap warnings** | Add form — inline warning card when overlap detected (e.g. "Your multivitamin already contains 1000 IU Vitamin D") with "Adjust dose" and "Add anyway" options |
| 3 | **Timing suggestions from your data** | Add form — inline tip card below the timing grid using the user's own meal timing patterns |
| 4 | **Correlation insights** | New "Supplement Insights" view accessible from the gear icon — connects supplement consistency to sleep, energy, HRV, stress from Health Connect / HealthKit |
| 5 | **Scan the bottle** | Add form scan entry point (Camera / Photos / Barcode), pre-fills fields from label |
| 6 | **Talk to Zura to log** | "Open Coach →" deep-link card at the bottom of the daily panel |

**Not included:** Streak tracking. Streaks will be built once, app-wide, in a future milestone — not per-feature.

---

## Data Model Changes

### `SupplementEntry` (Flutter model)

Current fields: `id`, `name`, `dose` (String?), `timing` (String?)

New fields added:
- `dose_amount` (double?) — the numeric part of the dose (e.g. `5000`)
- `dose_unit` (String?) — the unit (e.g. `IU`, `mg`, `mcg`)
- `form` (String?) — the physical form (e.g. `capsule`, `softgel`, `tablet`)

The old `dose` string field is kept for backwards compatibility during migration but is not shown in the new UI.

### `user_supplements` table (Supabase / Postgres)

Three new nullable columns — **db subagent must be consulted before any migration is written:**
- `dose_amount` — `NUMERIC(8,2)` nullable
- `dose_unit` — `VARCHAR(20)` nullable
- `form` — `VARCHAR(20)` nullable

No columns are dropped. The old `dose` column (free text) stays for backwards read compatibility.

---

## API Changes

### Existing endpoints (unchanged)

- `GET /api/v1/supplements` — returns the user's stack list (rate limit: 60/min)
- `POST /api/v1/supplements` — atomic replace of the full stack (rate limit: 30/min, max 50 items)

### New endpoint

**`GET /api/v1/supplements/today-log`**

Returns which supplement IDs have already been logged today. This is needed to correctly show "taken" state on panel open — without it, the panel cannot distinguish between "not yet taken" and "taken before this session".

Response:
```json
{
  "entries": [
    { "supplement_id": "abc123", "log_id": "qlog-uuid-1" },
    { "supplement_id": "def456", "log_id": "qlog-uuid-2" }
  ]
}
```

Each entry includes both the supplement stack ID (so the panel knows which row to mark taken) and the `quick_logs` row ID (so the client can call DELETE if the user removes the entry). Implemented by querying `quick_logs WHERE metric_type = 'supplement_taken' AND recorded_at >= today_start_utc`.

Rate limit: 60/min. No writes. Read-only.

### Ingest (unchanged)

Each tap on the panel calls `submitIngest()` with:
- `metric_type: supplement_taken`
- `value: 1.0`
- `unit: dose`
- `metadata: { supplement_id: "<id>" }`

Removing a log entry calls a new `DELETE /api/v1/supplements/log/{log_entry_id}` endpoint (one log entry, one delete). The `log_entry_id` is the UUID of the specific `quick_logs` row — **not** the supplement's stack ID. The client receives this row ID from the `GET /api/v1/supplements/today-log` response (each entry includes its own `log_id` alongside the `supplement_id`).

---

## Navigation Changes

| Before | After |
|--------|-------|
| FAB → Log Grid Sheet → Supplements tile → **pushes `SupplementsLogScreen` (full-screen)** | FAB → Log Grid Sheet → Supplements tile → **opens inline `ZSupplementsLogPanel`** |
| No management screen | Panel gear icon / footer link → **`SupplementsStackScreen`** |
| No scan flow for supplements | Add form → Scan label button → **reused nutrition scan entry** |
| No Coach link | Panel footer → **deep-link to Coach tab** |

The `behaviour` on the supplements tile in `ZLogGridSheet` changes from `_TileBehaviour.fullScreen` to the inline panel behaviour. The `RouteNames.supplementsLog` route is removed.

---

## State Management

New providers:
- `supplementsTodayLogProvider` — streams today's taken IDs from the local DB, refreshed on app foreground and after every tap
- `supplementsSyncStatusProvider` — exposes the three-value sync enum for the cloud icon

Existing providers that continue to be invalidated after a successful log:
- `todayLogSummaryProvider`
- `progressHomeProvider`
- `goalsProvider`
- `supplementsListProvider`

---

## Out of Scope

The following were explicitly discussed and ruled out for this overhaul:

- **Streak tracking** — will be built once, app-wide, in a future milestone
- **Custom camera UI** — the existing nutrition scan infrastructure is reused as-is
- **New "Ask Zura" screen** — the Coach tab already exists; a deep-link button is sufficient
- **Notes field** — the free-text notes field from the old screen is not carried forward

---

## Success Criteria

1. A user with a saved stack can log their entire morning routine in under 10 seconds — just taps, no Save button.
2. The panel works identically with no internet connection. Logs sync silently in the background when online.
3. Accidentally tapping a supplement can be reversed — either via the 4-second undo toast or the Remove entry confirmation dialog.
4. A new user with no stack sees a guided path to set one up, including the Zura AI option.
5. Scanning a supplement bottle pre-fills the add form without any manual typing.

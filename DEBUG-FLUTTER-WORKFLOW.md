# Flutter Visual QA Workflow for AI Agents

A structured, context-rot-resistant workflow for visually testing a Flutter app.
Read `DEBUG-FLUTTER.md` first — this document governs **when and how** to use those techniques.

---

## The Core Discipline

There are exactly **two modes**. You may only be in one at a time:

| Mode | What you do | What you never do |
|------|-------------|-------------------|
| **Reconnaissance** | Observe, navigate, screenshot, log | Fix anything |
| **Execution** | Implement the plan | Open new bugs |

Switching from Reconnaissance to fixing mid-session is the root cause of context rot.
**Do not do it.**

---

## Phase 1 — Reconnaissance

### Step 1: List All Features to Test

Before launching the emulator, write out every feature you will test. Do this from:
- `docs/screens.md` — full screen inventory
- `docs/mvp-features.md` — MVP feature list
- The task description / PR description

Format:

```
FEATURES TO TEST
----------------
[ ] Welcome screen — animation, logo
[ ] Onboarding — page transitions, copy
[ ] Login — email/password, Google Sign-In
[ ] Register — validation, error states
[ ] Today tab — AI insights feed, health score, quick actions
[ ] Dashboard tab — activity rings, metrics, populated vs empty states
[ ] Coach Chat tab — WebSocket connection, message send/receive
[ ] Integrations tab — connected state, disconnected state, OAuth flow
[ ] Settings — theme toggle, logout
[ ] Dark mode — all tabs
[ ] Empty states — demo-empty account
```

> **Rule:** The list is fixed before Reconnaissance begins. Do not add features mid-session.

---

### Step 2: Set Up the Environment

Follow `DEBUG-FLUTTER.md` exactly. Open separate terminals for each blocking process:

```
Terminal A → make dev          (Cloud Brain backend)
Terminal B → emulator launch   (Android emulator)
Terminal C → make run          (Flutter app)
Agent terminal → ADB commands, screenshots only
```

Health check before proceeding:

```bash
curl http://localhost:8001/health
# Must return: {"status":"healthy"}

flutter devices
# Must show emulator-5554 as "device"
```

Do not begin testing until both checks pass.

---

### Step 3: Test Each Feature — Observe Only

Work through the feature list in order. For each feature:

1. Navigate to it (ADB tap / swipe).
2. Take a screenshot → `.agent/screenshots/<feature-name>.png`.
3. Read the screenshot.
4. Check logcat for errors: `"$ADB" -s $DEVICE logcat -d flutter:D *:S | tail -30`
5. Record result as **PASS** or **BUG**.

**If it passes** — mark it done. Move to the next feature immediately.

**If it has a bug** — log it (see format below). **Do not fix it. Do not investigate further. Move on.**

> The temptation to fix a bug the moment you see it is the enemy. Every minute spent
> debugging feature 2 is a minute feature 7 goes untested.

---

### Step 4: Bug Log Format

Log every bug with enough detail to act on later. Append to a running list:

```
BUGS FOUND
----------
BUG-001  [Screen: Dashboard]
  Symptom:  Activity rings do not animate on first load.
  Steps:    Log in as demo-full → tap Dashboard tab → observe rings.
  Expected: Rings animate from 0 to current value.
  Actual:   Rings appear static at final value immediately.
  Evidence: .agent/screenshots/dashboard-rings.png

BUG-002  [Screen: Coach Chat]
  Symptom:  WebSocket disconnects after ~10 seconds of inactivity.
  Steps:    Open Chat tab → wait 15s without typing → send a message.
  Expected: Message sends successfully.
  Actual:   "Connection lost" toast appears; message not sent.
  Evidence: .agent/screenshots/chat-disconnect.png
  Logcat:   WS close frame received, code=1006
```

Keep it factual. No theories about causes at this stage — just what you saw.

---

### Step 5: Complete the Full Feature Pass

Continue until every feature on the list has a **PASS** or **BUG** entry.
Do not stop early. Do not loop back to fix anything.

At the end you will have:

```
RECONNAISSANCE SUMMARY
----------------------
PASS  Welcome screen
PASS  Onboarding
PASS  Login — email/password
BUG   Login — Google Sign-In (BUG-001)
PASS  Register
PASS  Today tab
BUG   Dashboard — rings not animating (BUG-002)
PASS  Coach Chat — message send/receive
BUG   Coach Chat — WebSocket drops after inactivity (BUG-003)
PASS  Integrations tab — disconnected state
...
```

---

## Phase 2 — Report

Before moving to planning, print the full summary in the conversation:

```
=== VISUAL QA REPORT ===

Tested: <date>
Account used: demo-full@zuralog.dev / demo-empty@zuralog.dev
Build: debug / make run / local backend

PASSED (N features)
  - Feature list...

BUGS FOUND (N issues)
  - BUG-001: ...
  - BUG-002: ...

SCREENSHOTS: .agent/screenshots/
```

This report is the single source of truth for the Execution phase.

---

## Phase 3 — Implementation Plan

### Decide: Conversation or File?

| Condition | Where to write the plan |
|-----------|------------------------|
| 3 or fewer bugs, straightforward fixes | Write it inline in the conversation |
| 4+ bugs, or any bug that touches multiple files | Write it to `.agent/plans/<date>-qa-fixes.md` |

The threshold is about context capacity. A long plan written only in the conversation
will be forgotten by a subagent that doesn't see the full conversation history.
Write it to `.agent/` when there's any doubt.

### Plan Format

```markdown
# QA Fix Plan — <date>

## Bug Fixes

### BUG-001: Google Sign-In silently fails
**Root cause hypothesis:** `GOOGLE_WEB_CLIENT_ID` not injected — bare `flutter run` used.
**Files to change:** `Makefile`, verify `make run` usage in CI
**Acceptance:** Log in via Google Sign-In on emulator without null token error.

### BUG-002: Dashboard rings not animating
**Root cause hypothesis:** `AnimationController` not disposed/re-initialized on tab reselect.
**Files to change:** `zuralog/lib/features/dashboard/presentation/dashboard_screen.dart`
**Acceptance:** Navigate away from Dashboard and back — rings animate from 0 each time.

### BUG-003: WebSocket drops after 10s inactivity
**Root cause hypothesis:** Missing client-side ping/keepalive.
**Files to change:** `zuralog/lib/features/chat/data/websocket_client.dart`
**Acceptance:** Chat connection stays alive after 30s of inactivity.

## Subagent Task Breakdown

Each bug should be assigned to a subagent as an independent task:

| Task | Files | Depends on |
|------|-------|------------|
| Fix BUG-001 | Makefile | — |
| Fix BUG-002 | dashboard_screen.dart | — |
| Fix BUG-003 | websocket_client.dart | — |

Tasks with no dependencies can run in parallel.
```

### Subagent Execution Rules

- Each subagent receives: the plan entry for its bug + the relevant file paths + `DEBUG-FLUTTER.md` for context.
- Each subagent works on its own branch: `fix/bug-001-google-signin`, etc.
- Each subagent runs `flutter analyze` before declaring done — zero warnings required.
- Each subagent does **not** run visual QA — that is reserved for Phase 4.

---

## Phase 4 — Verify and Repeat

After all subagents have merged their fixes:

1. Pull the latest `main`.
2. Return to **Phase 1** — run the full feature pass again.
3. Verify every previously-logged bug is now **PASS**.
4. Look for regressions in previously-passing features.
5. Any new bugs found go through the same cycle.

The loop continues until the full feature list is **PASS** with no bugs.

---

## Cleanup (Before Every Merge to Main)

```bash
# Remove all screenshots
rm -f .agent/screenshots/*.png

# Remove any plan files that are now fully executed
# (keep them if the cycle is still in progress)

# Verify nothing extra is staged
git status
```

---

## Quick Checklists

### Start of Reconnaissance
- [ ] Feature list written out in full
- [ ] Backend health check passes (`curl http://localhost:8001/health`)
- [ ] Emulator online (`flutter devices`)
- [ ] App running (`make run` in its own terminal)
- [ ] Screenshots directory ready (`mkdir -p .agent/screenshots`)

### End of Reconnaissance
- [ ] Every feature has PASS or BUG status
- [ ] Every bug has screenshot evidence in `.agent/screenshots/`
- [ ] QA report printed in conversation

### Before Writing the Plan
- [ ] Root cause hypothesis written for each bug
- [ ] Files to change identified for each bug
- [ ] Acceptance criteria defined for each bug
- [ ] Decision made: plan in conversation vs `.agent/plans/`

### Before Merging Fixes
- [ ] `flutter analyze` — zero warnings
- [ ] Full Phase 1 pass completed — all previously-failing features now PASS
- [ ] No regressions in previously-passing features
- [ ] Screenshots deleted from `.agent/screenshots/`
- [ ] Plan file deleted from `.agent/plans/` (if fully executed)

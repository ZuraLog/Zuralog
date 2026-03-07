# Flutter Visual QA Workflow — AI Agent Reference

Read `DEBUG-FLUTTER.md` before starting. This document governs **when and how** to use those techniques.

---

## Two Modes — Never Mix Them

| Mode | Do | Never |
|------|----|-------|
| **Reconnaissance** | Observe, screenshot, log bugs | Fix anything |
| **Execution** | Implement the plan | Open new bugs |

Switching modes mid-session causes context rot. **Complete the full feature pass before touching code.**

---

## Phase 1 — Reconnaissance

### Step 1: Write the Feature List

Before launching anything, list every feature to test. Sources: `docs/screens.md`, `docs/mvp-features.md`, task description.

```
FEATURES TO TEST
[ ] Welcome — animation, logo
[ ] Onboarding — transitions, copy
[ ] Login — email/password, Google Sign-In
[ ] Register — validation, errors
[ ] Today tab — insights feed, health score, quick actions
[ ] Dashboard — activity rings, metrics, populated + empty
[ ] Coach Chat — WebSocket send/receive
[ ] Integrations — connected, disconnected, OAuth flow
[ ] Settings — theme toggle, logout
[ ] Dark mode — all tabs
[ ] Empty states — demo-empty account
```

The list is **fixed** before Reconnaissance begins. Do not add to it mid-session.

---

### Step 2: Environment Setup

Follow `DEBUG-FLUTTER.md` §2–4. Each blocking process gets its own terminal:

```
Terminal A → cd cloud-brain && docker compose up -d && make dev
Terminal B → emulator launch
Terminal C → make run   (from project root)
Agent terminal → ADB only
```

Proceed only when both pass:
```bash
curl http://localhost:8001/health   # → {"status":"healthy"}
flutter devices                     # → emulator-5554   device
```

---

### Step 3: Test Each Feature — Observe Only

For each feature:
1. Navigate (ADB tap/swipe)
2. Screenshot → `.agent/screenshots/<feature>.png`
3. Read screenshot
4. Check logcat: `"$ADB" -s $DEVICE logcat -d flutter:D *:S | tail -30`
5. Mark **PASS** or **BUG**

**PASS** → move on immediately.
**BUG** → log it (format below), then move on immediately. Do not fix. Do not investigate.

---

### Step 4: Bug Log Format

```
BUGS FOUND
BUG-001  [Dashboard] Activity rings static on first load.
  Steps:    demo-full → Dashboard tab
  Expected: Rings animate 0 → value
  Actual:   Rings appear at final value immediately
  Evidence: .agent/screenshots/dashboard-rings.png

BUG-002  [Coach Chat] WebSocket drops after ~10s inactivity.
  Steps:    Chat tab → wait 15s → send message
  Expected: Message sends
  Actual:   "Connection lost" toast; message not sent
  Logcat:   WS close frame code=1006
```

Facts only — no cause theories at this stage.

---

### Step 5: Complete the Full Pass

Every feature gets PASS or BUG before stopping. No exceptions.

```
RECONNAISSANCE SUMMARY
PASS  Welcome
PASS  Onboarding
BUG   Login — Google Sign-In (BUG-001)
PASS  Register
BUG   Dashboard — rings (BUG-002)
BUG   Coach Chat — WS drop (BUG-003)
PASS  Integrations
...
```

---

## Phase 2 — Report

Print in conversation before writing any code:

```
=== VISUAL QA REPORT ===
Date:     <date>
Accounts: demo-full / demo-empty
Build:    make run / debug / local backend

PASSED  (N): <list>
BUGS    (N): BUG-001 ... BUG-002 ... BUG-003 ...
Screenshots: .agent/screenshots/
```

---

## Phase 3 — Implementation Plan

### Conversation or File?

| Condition | Location |
|-----------|----------|
| ≤3 bugs, single-file fixes | Inline in conversation |
| 4+ bugs, or any multi-file fix | `.agent/plans/<date>-qa-fixes.md` |

When in doubt, write to file — subagents won't have conversation history.

### Plan Format

```markdown
# QA Fix Plan — <date>

### BUG-001: Google Sign-In silently fails
Hypothesis: GOOGLE_WEB_CLIENT_ID not injected (bare flutter run used)
Files:      Makefile
Acceptance: Google Sign-In completes without null token

### BUG-002: Dashboard rings not animating
Hypothesis: AnimationController not re-initialized on tab reselect
Files:      zuralog/lib/features/dashboard/presentation/dashboard_screen.dart
Acceptance: Navigate away and back — rings animate from 0 each time

### BUG-003: WebSocket drops after 10s
Hypothesis: Missing client-side ping/keepalive
Files:      zuralog/lib/features/chat/data/websocket_client.dart
Acceptance: Connection stays alive after 30s inactivity

## Subagent Breakdown
| Task     | Files                  | Parallel? |
|----------|------------------------|-----------|
| BUG-001  | Makefile               | yes       |
| BUG-002  | dashboard_screen.dart  | yes       |
| BUG-003  | websocket_client.dart  | yes       |
```

### Subagent Rules
- Each subagent gets: its plan entry + file paths + `DEBUG-FLUTTER.md`
- Branch per bug: `fix/bug-001-google-signin`
- `flutter analyze` must pass (zero warnings) before declaring done
- No visual QA — that is Phase 4

---

## Phase 4 — Verify and Repeat

1. Pull latest `main`
2. Run full Phase 1 pass
3. Confirm every BUG is now PASS
4. Check for regressions in previously-passing features
5. New bugs found → new cycle from Phase 1

---

## Cleanup (Before Every Merge)

```bash
rm -f .agent/screenshots/*.png
# delete .agent/plans/<file> only if cycle is complete
git status
```

---

## Checklists

**Before Reconnaissance**
- [ ] Feature list written
- [ ] `curl http://localhost:8001/health` → healthy
- [ ] `flutter devices` → emulator online
- [ ] `make run` running in its own terminal
- [ ] `mkdir -p .agent/screenshots`

**After Reconnaissance**
- [ ] Every feature: PASS or BUG
- [ ] Every bug: screenshot in `.agent/screenshots/`
- [ ] QA report printed in conversation

**Before Merging**
- [ ] `flutter analyze` → zero warnings
- [ ] All prior BUGs now PASS
- [ ] No regressions
- [ ] `rm -f .agent/screenshots/*.png`
- [ ] `.agent/plans/` file deleted (if cycle complete)

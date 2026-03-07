# Flutter Visual QA Workflow — AI Agent Reference

Read `DEBUG-FLUTTER.md` before starting. This document governs **when and how** to use those techniques.

Apply this workflow to any scope — a single screen, a set of related features, or a full release pass. The scope is defined by the task, not by this document.

---

## Two Modes — Never Mix Them

| Mode | Do | Never |
|------|----|-------|
| **Reconnaissance** | Observe, screenshot, log bugs | Fix anything |
| **Execution** | Implement the plan | Open new bugs |

Switching modes mid-session causes context rot. **Complete your full defined scope before touching code.**

---

## Phase 1 — Reconnaissance

### Step 1: Define the Scope

Before launching anything, write out what you will test. Derive the list from:
- The task description or PR
- `docs/screens.md` and `docs/mvp-features.md` (for broad passes)
- A specific screen or flow (for targeted fixes)

The scope can be one item or fifty. Size it to the task.

```
SCOPE
[ ] <screen or feature>
[ ] <screen or feature>
[ ] ...
```

The list is **fixed** before Reconnaissance begins. Do not add to it mid-session.

---

### Step 2: Environment Setup

Follow `DEBUG-FLUTTER.md` §2–4. Each blocking process gets its own terminal:

```
Terminal A → cd cloud-brain && docker compose up -d && make dev
Terminal B → emulator launch
Terminal C → make run   (from project root)
Agent terminal → mobile-mcp tools + ADB (logcat/toggles only)
```

Proceed only when both pass:
```bash
curl http://localhost:8001/health   # → {"status":"healthy"}
```
```
mobile_list_available_devices()     # → emulator-5554 state: online
```

---

### Step 3: Test Each Item — Observe Only

For each item in scope:
1. Navigate: `mobile_click_on_screen_at_coordinates` / `mobile_swipe_on_screen`
2. Screenshot: `mobile_take_screenshot` (inline) or `mobile_save_screenshot` (evidence)
3. Read screenshot
4. Check logcat: `"$ADB" -s $DEVICE logcat -d flutter:D *:S | tail -30`
5. Mark **PASS** or **BUG**

**PASS** → move on immediately.
**BUG** → log it (format below), then move on immediately. Do not fix. Do not investigate.

---

### Step 4: Bug Log Format

```
BUGS FOUND
BUG-001  [<Screen/Feature>] <One-line symptom>
  Steps:    <Minimal reproduction steps>
  Expected: <What should happen>
  Actual:   <What actually happened>
  Evidence: .agent/screenshots/<label>.png
  Logcat:   <Relevant log line if any>
```

Facts only — no cause theories at this stage.

---

### Step 5: Complete the Scope

Every item in scope gets PASS or BUG before stopping. No exceptions.

```
RECONNAISSANCE SUMMARY
PASS  <item>
PASS  <item>
BUG   <item> (BUG-001)
PASS  <item>
BUG   <item> (BUG-002)
...
```

---

## Phase 2 — Report

Print in conversation before writing any code:

```
=== VISUAL QA REPORT ===
Date:     <date>
Scope:    <description of what was tested>
Account:  <test account used>
Build:    <make target / mode / backend>

PASSED  (N): <list>
BUGS    (N): BUG-001 ... BUG-002 ...
Screenshots: .agent/screenshots/
```

---

## STOP — Human Review Required

**Do not proceed to Phase 3 until the human has reviewed the report and explicitly approved execution.**

After printing the report, say:

> "Reconnaissance complete. I found N bug(s). Please review the report above.
> When you're ready to proceed, switch to a capable model (e.g. claude-sonnet or opus)
> and tell me to continue. I will not write any code until you confirm."

Wait for explicit approval. Do not plan, do not hypothesize fixes, do not touch files.

**Why:** Bug fixes require a smarter model than QA observation. The human needs to review findings, reprioritize if needed, and confirm the right model is active before execution begins.

---

## Phase 3 — Implementation Plan

### Conversation or File?

| Condition | Location |
|-----------|----------|
| ≤3 bugs, single-file fixes | Inline in conversation |
| 4+ bugs, or any multi-file fix | `.agent/plans/<date>-<label>.md` |

When in doubt, write to file — subagents won't have conversation history.

### Plan Format

```markdown
# Fix Plan — <date> — <scope label>

### BUG-001: <title>
Hypothesis: <root cause theory>
Files:      <file paths>
Acceptance: <how to verify it's fixed>

### BUG-002: <title>
Hypothesis: <root cause theory>
Files:      <file paths>
Acceptance: <how to verify it's fixed>

## Subagent Breakdown
| Task    | Files       | Parallel? |
|---------|-------------|-----------|
| BUG-001 | <files>     | yes/no    |
| BUG-002 | <files>     | yes/no    |
```

### Subagent Rules
- Each subagent gets: its plan entry + file paths + `DEBUG-FLUTTER.md`
- Branch per bug: `fix/bug-001-<slug>`
- `flutter analyze` must pass (zero warnings) before declaring done
- No visual QA — that is Phase 4

---

## Phase 4 — Verify and Repeat

1. Pull latest `main`
2. Re-run Reconnaissance over the same scope
3. Confirm every BUG is now PASS
4. Check for regressions in previously-passing items
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
- [ ] Scope list written
- [ ] `curl http://localhost:8001/health` → healthy
- [ ] `flutter devices` → emulator online
- [ ] App running in its own terminal
- [ ] `mkdir -p .agent/screenshots`

**After Reconnaissance**
- [ ] Every scoped item: PASS or BUG
- [ ] Every bug: screenshot in `.agent/screenshots/`
- [ ] QA report printed in conversation
- [ ] **Human has reviewed the report and explicitly approved proceeding**
- [ ] **Capable model is active (e.g. claude-sonnet or opus) before writing any fix**

**Before Merging**
- [ ] `flutter analyze` → zero warnings
- [ ] All prior BUGs now PASS
- [ ] No regressions
- [ ] `rm -f .agent/screenshots/*.png`
- [ ] `.agent/plans/` file deleted (if cycle complete)

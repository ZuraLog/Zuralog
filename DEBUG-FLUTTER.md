# Programmatic Flutter Debugging Guide for AI Agents

How to visually verify and interact with a running Flutter app on an Android emulator
using only shell commands and the Read tool — no Playwright, no human needed.

---

## How It Works

```
Flutter App (on emulator)
        ↓
  ADB screencap  →  PNG file  →  Read tool  →  Agent sees the UI
  ADB input tap  ←  Agent calculates coordinates from screenshot
```

The Read tool can render image files inline. Combined with ADB's ability to
capture frames and inject touch events, an agent can see the UI and drive it
like a human finger.

---

## CRITICAL: Always Open a New Terminal

**Never run `flutter run`, `make run`, `make dev`, or any long-running server command in the same terminal session where the agent is working.**

If you do, the agent's terminal will block indefinitely waiting for the process to exit — it will appear to hang and never complete. This applies to:

- `flutter run` / `make run` / `make run-ios` (Flutter app)
- `make dev` / `uvicorn ...` (Cloud Brain backend)
- `docker compose up` (without `-d`)
- Any process that streams output and does not return a prompt

**How to open a new terminal:**

The approach depends on your tool. For `opencode` (and most agent environments), use the shell's background operator or instruct the user to open a separate terminal tab:

```bash
# Option A — background the process (output still goes to the terminal log)
make run &

# Option B — ask the user to run it in a new terminal tab (preferred for interactive processes)
# "Please open a new terminal, cd to zuralog/, and run: make run"
```

> **Rule of thumb:** If a command doesn't return a shell prompt by itself, it must run in its own terminal or be backgrounded with `&`. The agent's working terminal must always remain free.

---

## Screenshots — Storage and Cleanup

All screenshots taken during visual QA **must** be saved to `.agent/screenshots/` at the project root:

```bash
# Always use this directory for screenshots
"$ADB" -s emulator-5554 exec-out screencap -p > .agent/screenshots/screen1.png
```

This directory is **gitignored** (added to `.gitignore`). Screenshots will never be committed accidentally.

**Before merging to `main`:** Delete all screenshots and verify the directory is empty:

```bash
rm -f .agent/screenshots/*.png
# Verify nothing is staged
git status
```

> **Why a dedicated folder?** Saving screenshots to `/tmp`, the project root, or ad-hoc paths makes cleanup error-prone. A single gitignored directory makes the cleanup step unambiguous.

---

## 1. Prerequisites

### Find ADB

ADB is bundled with Android Studio. It is usually **not on PATH** by default.

```bash
# Windows — find the executable
find /c/Users -name "adb.exe" 2>/dev/null | head -5

# Common locations
/c/Users/<user>/AppData/Local/Android/Sdk/platform-tools/adb.exe

# Store in a variable for the session
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
```

### Verify Flutter is installed

```bash
flutter --version
flutter devices   # lists connected physical + emulated devices
```

---

## 2. Start the Backend (Cloud Brain)

The Flutter app connects to the Cloud Brain backend. **Start the backend before launching the app**, or auth, AI chat, and all data flows will fail.

**Open a new terminal (separate from the agent's terminal)** and run:

```bash
# Terminal 1 — from cloud-brain/
docker compose up -d          # start Postgres + Redis (detached — OK to run here)
make dev                      # starts uvicorn; blocks this terminal — that's expected
```

Health check (run from the agent's terminal once the server is up):

```bash
curl http://localhost:8001/health
# Expected: {"status":"healthy"}
```

> **Why `make dev` instead of bare `uvicorn`?** `make dev` reads `cloud-brain/.env` and injects all environment variables automatically.

---

## 3. Start an Emulator

### List available emulators

```bash
flutter emulators
```

### Launch one

**Open a new terminal** and run the emulator directly (more reliable than `flutter emulators --launch` on Windows):

```bash
# Windows (Git Bash)
"$LOCALAPPDATA/Android/Sdk/emulator/emulator.exe" -avd <AVD_NAME> -no-snapshot-load &

# macOS
~/Library/Android/sdk/emulator/emulator -avd <AVD_NAME> -no-snapshot-load &

# Linux
~/Android/Sdk/emulator/emulator -avd <AVD_NAME> -no-snapshot-load &
```

### Wait for it to come online

```bash
# Poll until the emulator is no longer "offline"
flutter devices   # emulator-5554 should show "device" status
```

Typical boot time: **60–120 seconds**. Add `sleep 30` before the first `flutter devices` check.

> **`flutter emulators --launch` vs direct launch:** `flutter emulators --launch` exits immediately after spawning the process. On Windows this can race with AVD lock files and silently fail. Use the direct `emulator.exe` command above.

---

## 4. Run the Flutter App

**Open a new terminal (separate from the agent's terminal)** and run:

```bash
# From the project root (Zuralog/)
make run          # Android emulator — debug, local backend (RECOMMENDED)
make run-ios      # iOS Simulator — debug, local backend
make run-prod     # Android emulator — release, api.zuralog.com
```

**Do not use bare `flutter run`** — `make run` injects required build-time variables (`GOOGLE_WEB_CLIENT_ID`, `SENTRY_DSN`) from `cloud-brain/.env`. Without them, Google Sign-In will silently return a null token and Sentry will be disabled.

Wait for the app to fully launch before taking screenshots:

```bash
sleep 60   # cold build takes ~60s; hot restart is faster
```

### Hot reload vs hot restart

While `flutter run` / `make run` is running in its own terminal, you can trigger these from the agent's terminal using ADB or by sending a keystroke to the flutter process. More commonly, the distinction matters for understanding lag:

| Command | What resets | Use when |
|---------|-------------|----------|
| `r` (hot reload) | UI only — state is preserved | Tweaking widgets, colors, layout |
| `R` (hot restart) | Full app state | Changing providers, data models, auth state |

---

## 5. Demo Accounts — Skip Auth During QA

Two pre-seeded test accounts exist. Use them to log in immediately without going through registration:

| Account | Email | Password | Purpose |
|---------|-------|----------|---------|
| `demo-full` | `demo-full@zuralog.dev` | `ZuraDemo2026!` | 30 days of realistic health data |
| `demo-empty` | `demo-empty@zuralog.dev` | `ZuraDemo2026!` | Brand new account — exercises empty states |

> Use `demo-full` for most visual QA. Use `demo-empty` to verify skeleton/empty UI states.

---

## 6. Take a Screenshot

```bash
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
SCREENSHOTS=".agent/screenshots"
mkdir -p "$SCREENSHOTS"

# Capture to the designated screenshots folder
"$ADB" -s emulator-5554 exec-out screencap -p > "$SCREENSHOTS/screen1.png"
```

Then use the **Read tool** on `.agent/screenshots/screen1.png` — it renders the image so you can
see the current state of the UI.

> **Do not use** `adb shell screencap /sdcard/screen.png` + `adb pull` on API 36+
> emulators — it errors. The `exec-out screencap -p` pipe is the reliable path.

---

## 7. Coordinate Scaling — CRITICAL

The screenshot PNG is **downscaled** relative to the actual device pixel dimensions.
You must convert coordinates before tapping.

### Get the actual screen size

```bash
"$ADB" -s emulator-5554 shell wm size
# Example output: Physical size: 1080x2400
```

### Measure the screenshot dimensions

Read the PNG — the Read tool shows the image. Estimate element positions in the
**rendered** image (e.g. 720×1600 rendered pixels for a 1080×2400 device).

### Convert rendered → actual coordinates

```
actual_x = (rendered_x / rendered_width)  * actual_width
actual_y = (rendered_y / rendered_height) * actual_height
```

**Example:** Element at rendered (360, 890) on a 720×1600 screenshot, device is 1080×2400:

```
actual_x = (360 / 720) * 1080 = 540
actual_y = (890 / 1600) * 2400 = 1335
```

Always do this math — do **not** use rendered pixel values directly as ADB coordinates.

---

## 8. Interact with the UI

All interactions go through `adb shell input`.

### Tap

```bash
"$ADB" -s emulator-5554 shell input tap <actual_x> <actual_y>
sleep 1   # wait for animation/navigation
```

### Type text

```bash
# Tap the text field first, then type
"$ADB" -s emulator-5554 shell input tap 540 349
sleep 0.5
"$ADB" -s emulator-5554 shell input text "search query"
sleep 1
```

> **Caveat:** `input text` does not handle spaces well. For multi-word input,
> use `input text` with URL-encoded spaces (`%s`) or send words separately.

### Scroll / Swipe

```bash
# swipe from (x1,y1) to (x2,y2) over <duration_ms>
"$ADB" -s emulator-5554 shell input swipe 540 1200 540 400 500   # scroll up
"$ADB" -s emulator-5554 shell input swipe 540 400 540 1200 500   # scroll down
```

### Key events

```bash
"$ADB" -s emulator-5554 shell input keyevent KEYCODE_BACK
"$ADB" -s emulator-5554 shell input keyevent KEYCODE_HOME
"$ADB" -s emulator-5554 shell input keyevent KEYCODE_ENTER
```

---

## 9. Common System Toggles

### Dark mode

```bash
# Enable
"$ADB" -s emulator-5554 shell "cmd uimode night yes"

# Disable
"$ADB" -s emulator-5554 shell "cmd uimode night no"
```

### Font scale

```bash
"$ADB" -s emulator-5554 shell settings put system font_scale 1.5
```

### Rotate screen

```bash
# Disable auto-rotate first
"$ADB" -s emulator-5554 shell settings put system accelerometer_rotation 0
# Set landscape (1) or portrait (0)
"$ADB" -s emulator-5554 shell settings put system user_rotation 1
```

---

## 10. Read Flutter Logs

```bash
# Stream logcat filtered to Flutter
"$ADB" -s emulator-5554 logcat -s flutter

# One-shot dump of recent logs
"$ADB" -s emulator-5554 logcat -d -s flutter | tail -50
```

For `debugPrint()` output from Dart, use tag `flutter`:

```bash
"$ADB" -s emulator-5554 logcat -d flutter:D *:S | tail -50
```

> **Check logs after every navigation step** during QA — a blank screen or missing widget is often a Dart exception that only appears in logcat, not on screen.

---

## 11. Run Static Analysis Before Visual QA

Before launching the emulator, catch obvious code errors first:

```bash
# From zuralog/
flutter analyze
```

The project enforces a **zero-warning policy** — all warnings are treated as errors. Fix any issues reported before proceeding to visual QA.

---

## 12. Typical Visual QA Workflow

```bash
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
DEVICE="emulator-5554"
SCREENSHOTS=".agent/screenshots"
mkdir -p "$SCREENSHOTS"

# --- SETUP (each step in its own terminal or backgrounded) ---

# Terminal A: start backend
#   cd cloud-brain && docker compose up -d && make dev

# Terminal B: start emulator
#   "$LOCALAPPDATA/Android/Sdk/emulator/emulator.exe" -avd Pixel_6 -no-snapshot-load &

# Terminal C: run the app
#   make run   (from project root)

# Agent's terminal: wait for everything to be up
sleep 90   # emulator + app cold start

# --- VISUAL QA ---

# 1. Capture initial state
"$ADB" -s $DEVICE exec-out screencap -p > "$SCREENSHOTS/screen1.png"
# → Read .agent/screenshots/screen1.png in Read tool

# 2. Check for crashes or errors
"$ADB" -s $DEVICE logcat -d flutter:D *:S | tail -50

# 3. Navigate (example: tap the third bottom-nav tab at rendered ~(588, 1460))
# Device is 1080x2400, screenshot is 720x1600
# actual_x = (588/720)*1080 = 882
# actual_y = (1460/1600)*2400 = 2190
"$ADB" -s $DEVICE shell input tap 882 2190
sleep 2

# 4. Capture new state
"$ADB" -s $DEVICE exec-out screencap -p > "$SCREENSHOTS/screen2.png"
# → Read .agent/screenshots/screen2.png in Read tool

# 5. Test dark mode
"$ADB" -s $DEVICE shell "cmd uimode night yes"
sleep 2
"$ADB" -s $DEVICE exec-out screencap -p > "$SCREENSHOTS/screen_dark.png"
# → Read .agent/screenshots/screen_dark.png in Read tool

# 6. Restore
"$ADB" -s $DEVICE shell "cmd uimode night no"

# --- CLEANUP (before merging) ---
rm -f .agent/screenshots/*.png
```

---

## 13. Gotchas and Tips

| Situation | Solution |
|-----------|----------|
| Agent terminal hangs after `make run` or `make dev` | You ran a blocking process in the agent's terminal — always use a separate terminal or `&` |
| `adb: command not found` | Use the full path to `adb.exe` — it is rarely on PATH |
| `screencap: usage` error | Use `exec-out screencap -p >` not `shell screencap -p /path` |
| Tap does nothing | Recalculate coordinates using the scaling formula in §7 |
| "System UI isn't responding" ANR dialog | Tap "Wait" using scaled actual coordinates (~y=1335 for the dialog's bottom option on 2400px tall device) |
| Text input appends to existing text | Tap the field's clear button first, or use `KEYCODE_CTRL_A` + `KEYCODE_DEL` to select-all and delete |
| Flutter app not visible | `make run` may still be compiling — wait longer before taking screenshots |
| Screenshot is all black | Emulator may not have fully booted — add more sleep time |
| Emulator shows as "offline" | Wait 10–15 more seconds; cold boot takes time |
| Need to scroll to find element | Use swipe commands to scroll, then re-screenshot to check |
| Google Sign-In returns null token | You used bare `flutter run` — use `make run` instead |
| Auth / AI features return errors | Backend not running — start `make dev` in `cloud-brain/` first |
| Screenshot files committed to git | They weren't in `.agent/screenshots/` — move them there and clean up |

---

## 14. Cleanup

```bash
# Kill the background flutter run job
kill %1   # or: kill $(jobs -p)

# Stop the emulator
"$ADB" -s emulator-5554 emu kill

# Remove all screenshots (required before merging)
rm -f .agent/screenshots/*.png

# Verify nothing extra is staged
git status
```

---

## Quick Reference Card

```bash
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
D="emulator-5554"
SS=".agent/screenshots"
mkdir -p "$SS"

# Screenshot (always use .agent/screenshots/)
"$ADB" -s $D exec-out screencap -p > "$SS/screen.png"

# Tap (use scaled coords!)
"$ADB" -s $D shell input tap <x> <y>

# Type
"$ADB" -s $D shell input text "hello"

# Scroll up
"$ADB" -s $D shell input swipe 540 1200 540 400 500

# Back button
"$ADB" -s $D shell input keyevent KEYCODE_BACK

# Dark mode on/off
"$ADB" -s $D shell "cmd uimode night yes"
"$ADB" -s $D shell "cmd uimode night no"

# Flutter logs
"$ADB" -s $D logcat -d -s flutter | tail -50

# Screen size (for coordinate scaling)
"$ADB" -s $D shell wm size

# Cleanup screenshots before merge
rm -f .agent/screenshots/*.png
```

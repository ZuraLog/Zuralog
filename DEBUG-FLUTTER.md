# Flutter Programmatic Debugging — AI Agent Reference

ADB screencap → PNG → Read tool → agent sees UI. ADB input → agent drives UI.

---

## CRITICAL: New Terminal Required

**Never run blocking processes in the agent's terminal** — it will hang indefinitely.

Blocking commands (always run in a separate terminal or with `&`):
- `make run` / `make run-ios` / `flutter run`
- `make dev` / `uvicorn ...`
- `docker compose up` (without `-d`)

```bash
# Background it, or ask the user to open a new terminal tab
make run &
```

---

## Screenshots — Storage and Cleanup

All screenshots **must** go to `.agent/screenshots/` (gitignored).

```bash
mkdir -p .agent/screenshots
"$ADB" -s emulator-5554 exec-out screencap -p > .agent/screenshots/screen1.png
```

Before merging: `rm -f .agent/screenshots/*.png && git status`

---

## 1. Prerequisites

```bash
# Find ADB (not on PATH by default)
# Windows: /c/Users/<user>/AppData/Local/Android/Sdk/platform-tools/adb.exe
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"

flutter --version
flutter devices
```

---

## 2. Start the Backend

**In a new terminal** (`cloud-brain/`):

```bash
docker compose up -d
make dev   # blocks — expected
```

Health check from agent terminal: `curl http://localhost:8001/health` → `{"status":"healthy"}`

> Use `make dev`, not bare `uvicorn` — it injects all env vars from `cloud-brain/.env`.

---

## 3. Start an Emulator

**In a new terminal:**

```bash
# Windows
"$LOCALAPPDATA/Android/Sdk/emulator/emulator.exe" -avd <AVD_NAME> -no-snapshot-load &
# macOS
~/Library/Android/sdk/emulator/emulator -avd <AVD_NAME> -no-snapshot-load &
# Linux
~/Android/Sdk/emulator/emulator -avd <AVD_NAME> -no-snapshot-load &
```

Boot time: **60–120s**. Poll with `flutter devices` until `emulator-5554` shows `device`.

> `flutter emulators --launch` can silently fail on Windows — use the direct binary above.

---

## 4. Run the Flutter App

**In a new terminal** (project root):

```bash
make run        # Android — debug, local backend (RECOMMENDED)
make run-ios    # iOS — debug, local backend
make run-prod   # Android — release, api.zuralog.com
```

**Never use bare `flutter run`** — `make run` injects `GOOGLE_WEB_CLIENT_ID` and `SENTRY_DSN` from `cloud-brain/.env`. Without them, Google Sign-In silently fails.

`sleep 60` after launching — cold build takes ~60s.

| Keystroke | Resets | Use when |
|-----------|--------|----------|
| `r` | UI only (state preserved) | Widget/layout tweaks |
| `R` | Full app state | Provider, model, or auth changes |

---

## 5. Demo Accounts

| Email | Password | Use for |
|-------|----------|---------|
| `demo-full@zuralog.dev` | `ZuraDemo2026!` | Populated data — most QA |
| `demo-empty@zuralog.dev` | `ZuraDemo2026!` | Empty states |

---

## 6. Take a Screenshot

```bash
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
"$ADB" -s emulator-5554 exec-out screencap -p > .agent/screenshots/screen1.png
# Then: Read tool on .agent/screenshots/screen1.png
```

> Do **not** use `adb shell screencap /sdcard/...` + `adb pull` — fails on API 36+.

---

## 7. Coordinate Scaling — CRITICAL

Screenshot is downscaled. **Always convert before tapping.**

```bash
"$ADB" -s emulator-5554 shell wm size   # e.g. Physical size: 1080x2400
```

```
actual_x = (rendered_x / rendered_width)  * actual_width
actual_y = (rendered_y / rendered_height) * actual_height

# Example: rendered (360,890) on 720x1600 PNG, device 1080x2400
# actual_x = (360/720)*1080 = 540
# actual_y = (890/1600)*2400 = 1335
```

---

## 8. Interact with the UI

```bash
# Tap
"$ADB" -s emulator-5554 shell input tap <x> <y>
sleep 1

# Type (tap field first; spaces unreliable — use %s or split words)
"$ADB" -s emulator-5554 shell input tap 540 349 && sleep 0.5
"$ADB" -s emulator-5554 shell input text "hello"

# Swipe (scroll up / scroll down)
"$ADB" -s emulator-5554 shell input swipe 540 1200 540 400 500
"$ADB" -s emulator-5554 shell input swipe 540 400 540 1200 500

# Key events
"$ADB" -s emulator-5554 shell input keyevent KEYCODE_BACK
"$ADB" -s emulator-5554 shell input keyevent KEYCODE_HOME
"$ADB" -s emulator-5554 shell input keyevent KEYCODE_ENTER
```

---

## 9. System Toggles

```bash
# Dark mode
"$ADB" -s emulator-5554 shell "cmd uimode night yes"
"$ADB" -s emulator-5554 shell "cmd uimode night no"

# Font scale
"$ADB" -s emulator-5554 shell settings put system font_scale 1.5

# Rotation (disable auto-rotate first)
"$ADB" -s emulator-5554 shell settings put system accelerometer_rotation 0
"$ADB" -s emulator-5554 shell settings put system user_rotation 1   # 1=landscape, 0=portrait
```

---

## 10. Flutter Logs

```bash
"$ADB" -s emulator-5554 logcat -d -s flutter | tail -50
"$ADB" -s emulator-5554 logcat -d flutter:D *:S | tail -50   # debugPrint output
```

> Check logcat after every navigation — blank screens are usually silent Dart exceptions.

---

## 11. Static Analysis (Before QA)

```bash
# From zuralog/
flutter analyze   # must report zero warnings — project enforces zero-warning policy
```

---

## 12. Session Skeleton

```bash
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
D="emulator-5554"
SS=".agent/screenshots"
mkdir -p "$SS"

# Terminals A/B/C running: make dev | emulator | make run
sleep 90   # wait for cold start

"$ADB" -s $D exec-out screencap -p > "$SS/screen1.png"   # Read tool
"$ADB" -s $D logcat -d flutter:D *:S | tail -50

"$ADB" -s $D shell input tap <x> <y> && sleep 2
"$ADB" -s $D exec-out screencap -p > "$SS/screen2.png"   # Read tool

"$ADB" -s $D shell "cmd uimode night yes" && sleep 2
"$ADB" -s $D exec-out screencap -p > "$SS/screen_dark.png"   # Read tool
"$ADB" -s $D shell "cmd uimode night no"

# Cleanup
rm -f "$SS"/*.png
```

---

## 13. Gotchas

| Symptom | Fix |
|---------|-----|
| Agent terminal hangs | Blocking process in agent terminal — use new terminal or `&` |
| `adb: not found` | Use full path to `adb.exe` |
| `screencap: usage` error | Use `exec-out screencap -p >`, not `shell screencap` |
| Tap does nothing | Recalculate with scaling formula (§7) |
| ANR "System UI not responding" | Tap "Wait" at scaled coords (~y=1335 on 2400px device) |
| Text appends to existing | `KEYCODE_CTRL_A` + `KEYCODE_DEL` to clear first |
| App not visible | Still compiling — wait longer |
| Black screenshot | Emulator still booting — add sleep |
| Emulator offline | Wait 10–15s more |
| Google Sign-In null token | Used bare `flutter run` — use `make run` |
| Auth/AI errors | Backend not running — `make dev` in `cloud-brain/` |
| Screenshot committed to git | Wasn't in `.agent/screenshots/` — move and clean up |

---

## 14. Cleanup

```bash
kill %1                              # stop flutter run background job
"$ADB" -s emulator-5554 emu kill    # stop emulator
rm -f .agent/screenshots/*.png       # required before merge
git status                           # verify clean
```

---

## Quick Reference

```bash
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
D="emulator-5554"

"$ADB" -s $D exec-out screencap -p > .agent/screenshots/screen.png   # screenshot
"$ADB" -s $D shell wm size                                             # device dimensions
"$ADB" -s $D shell input tap <x> <y>                                  # tap (scaled coords)
"$ADB" -s $D shell input swipe 540 1200 540 400 500                   # scroll up
"$ADB" -s $D shell input keyevent KEYCODE_BACK                        # back
"$ADB" -s $D shell "cmd uimode night yes"                             # dark mode on
"$ADB" -s $D logcat -d -s flutter | tail -50                          # logs
rm -f .agent/screenshots/*.png                                         # cleanup
```

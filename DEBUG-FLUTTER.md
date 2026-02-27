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

## 2. Start an Emulator

### List available emulators

```bash
flutter emulators
```

### Launch one

```bash
flutter emulators --launch Pixel_6
# or
flutter emulators --launch Medium_Phone_API_36.1
```

### Wait for it to come online

```bash
# Poll until the emulator is no longer "offline"
flutter devices   # emulator-5554 should show "device" status
```

Typical boot time: **20–40 seconds**. Add `sleep 20` before the first `flutter devices` check.

---

## 3. Run the Flutter App

```bash
# Run on the emulator (blocks the terminal — use & or a separate process)
cd zuralog
flutter run -d emulator-5554 &

# Wait for the app to fully launch before taking screenshots
sleep 60   # cold build takes ~60s; hot restart is faster
```

> **Tip:** On subsequent runs use `flutter run --hot` or press `r` in the flutter
> process to hot-reload without a full restart.

---

## 4. Take a Screenshot

```bash
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"

# Capture to a local PNG file
"$ADB" -s emulator-5554 exec-out screencap -p > screen.png
```

Then use the **Read tool** on `screen.png` — it renders the image so you can
see the current state of the UI.

> **Do not use** `adb shell screencap /sdcard/screen.png` + `adb pull` on API 36+
> emulators — it errors. The `exec-out screencap -p` pipe is the reliable path.

---

## 5. Coordinate Scaling — CRITICAL

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

## 6. Interact with the UI

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

## 7. Common System Toggles

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

## 8. Read Flutter Logs

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

---

## 9. Typical Visual QA Workflow

```bash
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
DEVICE="emulator-5554"

# 1. Launch emulator and wait
flutter emulators --launch Pixel_6
sleep 30
flutter devices   # confirm device is online

# 2. Run app
cd zuralog && flutter run -d $DEVICE &
sleep 60

# 3. Capture initial state
"$ADB" -s $DEVICE exec-out screencap -p > /tmp/screen1.png
# → Read /tmp/screen1.png in Read tool

# 4. Navigate (example: tap the third bottom-nav tab at rendered ~(588, 1460))
# Device is 1080x2400, screenshot is 720x1600
# actual_x = (588/720)*1080 = 882
# actual_y = (1460/1600)*2400 = 2190
"$ADB" -s $DEVICE shell input tap 882 2190
sleep 2

# 5. Capture new state
"$ADB" -s $DEVICE exec-out screencap -p > /tmp/screen2.png
# → Read /tmp/screen2.png in Read tool

# 6. Test dark mode
"$ADB" -s $DEVICE shell "cmd uimode night yes"
sleep 2
"$ADB" -s $DEVICE exec-out screencap -p > /tmp/screen_dark.png
# → Read /tmp/screen_dark.png in Read tool

# 7. Restore
"$ADB" -s $DEVICE shell "cmd uimode night no"
```

---

## 10. Gotchas and Tips

| Situation | Solution |
|-----------|----------|
| `adb: command not found` | Use the full path to `adb.exe` — it is rarely on PATH |
| `screencap: usage` error | Use `exec-out screencap -p >` not `shell screencap -p /path` |
| Tap does nothing | Recalculate coordinates using the scaling formula in §5 |
| "System UI isn't responding" ANR dialog | Tap "Wait" using scaled actual coordinates (~y=1335 for the dialog's bottom option on 2400px tall device) |
| Text input appends to existing text | Tap the field's clear button first, or use `KEYCODE_CTRL_A` + `KEYCODE_DEL` to select-all and delete |
| Flutter app not visible | `flutter run` may still be compiling — wait longer before taking screenshots |
| Screenshot is all black | Emulator may not have fully booted — add more sleep time |
| Emulator shows as "offline" | Wait 10–15 more seconds; cold boot takes time |
| Need to scroll to find element | Use swipe commands to scroll, then re-screenshot to check |

---

## 11. Cleanup

```bash
# Kill the flutter run process
kill $(lsof -ti :8080)   # if using a port
# or just kill the background job
kill %1

# Stop the emulator
"$ADB" -s emulator-5554 emu kill
```

---

## Quick Reference Card

```bash
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
D="emulator-5554"

# Screenshot
"$ADB" -s $D exec-out screencap -p > screen.png

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
```

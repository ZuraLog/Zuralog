# Flutter Programmatic Debugging — AI Agent Reference

**Primary method: `mobile-mcp`** — use its tools for all device interaction.
**Fallback: ADB** — only for logcat, system toggles, and anything mobile-mcp doesn't cover.

---

## CRITICAL: Check mobile-mcp First

Before doing anything, verify the `mobile-mcp` MCP server is enabled:

```
mobile_list_available_devices()
```

If the tool is unavailable or errors, **stop and ask the user to enable the `mobile-mcp` MCP server** before proceeding. Do not fall back to raw ADB for device interaction — use ADB only for the specific gaps listed in §10.

To enable (opencode config example):
```json
{
  "mcp": {
    "mobile-mcp": {
      "type": "local",
      "command": ["npx", "@mobilenext/mobile-mcp@latest"],
      "enabled": true
    }
  }
}
```

---

## CRITICAL: New Terminal Required

**Never run blocking processes in the agent's terminal** — it will hang indefinitely.

Blocking commands (always run in a separate terminal or with `&`):
- `make run` / `make run-ios` / `flutter run`
- `make dev` / `uvicorn ...`
- `docker compose up` (without `-d`)

---

## Screenshots — Storage, Resizing, and Cleanup

### Inline viewing (most common)
`mobile_take_screenshot` renders directly in context — no file, no resizing needed.

### Persistent evidence (bug logs, before/after)
Save to file **then resize before reading**. Anthropic's API rejects images where any dimension exceeds 2000px in multi-image requests. Emulator screens are typically 1080×2400 — height alone exceeds the limit.

```bash
# Save
mobile_save_screenshot(device, ".agent/screenshots/<label>.png")

# Resize to max 1600px on longest side (keeps aspect ratio)
magick .agent/screenshots/<label>.png -resize 1600x1600\> .agent/screenshots/<label>.png

# If ImageMagick is not available, use ffmpeg:
ffmpeg -i .agent/screenshots/<label>.png -vf scale="'if(gt(iw,ih),1600,-1)':'if(gt(iw,ih),-1,1600)'" .agent/screenshots/<label>.png -y
```

**Always resize before using the Read tool on a saved screenshot.** Skipping this causes the `image dimensions exceed max allowed size` API error.

Before merging: `rm -f .agent/screenshots/*.png && git status`

---

## 1. Prerequisites

```bash
# Backend must be running — see §2
# Emulator must be booted — see §3
# App must be running — see §4

# ADB path (only needed for logcat / system toggles)
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
```

---

## 2. Start the Backend

**In a new terminal** (`cloud-brain/`):

```bash
docker compose up -d
make dev   # blocks — expected
```

Health check: `curl http://localhost:8001/health` → `{"status":"healthy"}`

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

Boot time: **60–120s**. Then verify with mobile-mcp:

```
mobile_list_available_devices()
# → emulator-5554 should appear with state "online"
```

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

Wait ~60s for cold build. Then confirm the app is on screen:

```
mobile_take_screenshot(device)
```

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

```
# Inline — renders immediately in context (preferred)
mobile_take_screenshot(device)

# Persistent — saves to file for bug evidence
mobile_save_screenshot(device, ".agent/screenshots/<label>.png")
```

---

## 7. Find Elements and Coordinates

**Prefer this over manual coordinate math.** Returns element labels, bounds, and tap coordinates directly:

```
mobile_list_elements_on_screen(device)
```

Use the returned coordinates directly with `mobile_click_on_screen_at_coordinates`. No scaling math needed.

### Manual Coordinate Scaling (fallback only)

If you must tap an unlabelled area without element data:

```
mobile_get_screen_size(device)   # returns actual pixel dimensions
```

```
actual_x = (rendered_x / rendered_width)  * actual_width
actual_y = (rendered_y / rendered_height) * actual_height

# Example: rendered (360,890) on 720x1600 screenshot, device 1080x2400
# actual_x = (360/720)*1080 = 540
# actual_y = (890/1600)*2400 = 1335
```

---

## 8. Interact with the UI

All interaction goes through mobile-mcp tools — no ADB input commands needed.

```
# Tap
mobile_click_on_screen_at_coordinates(device, x, y)

# Double tap
mobile_double_tap_on_screen(device, x, y)

# Long press
mobile_long_press_on_screen_at_coordinates(device, x, y)

# Type text (tap the field first to focus it)
mobile_type_keys(device, "hello world", submit=false)
mobile_type_keys(device, "hello", submit=true)   # submits with Enter

# Swipe / scroll
mobile_swipe_on_screen(device, direction="up")    # scroll up
mobile_swipe_on_screen(device, direction="down")  # scroll down
mobile_swipe_on_screen(device, direction="left")
mobile_swipe_on_screen(device, direction="right")

# Device buttons
mobile_press_button(device, "BACK")
mobile_press_button(device, "HOME")
mobile_press_button(device, "ENTER")
mobile_press_button(device, "VOLUME_UP")
mobile_press_button(device, "VOLUME_DOWN")
```

---

## 9. App Management

```
# List installed apps
mobile_list_apps(device)

# Launch by package name
mobile_launch_app(device, "com.zuralog.zuralog")

# Terminate
mobile_terminate_app(device, "com.zuralog.zuralog")

# Open a URL
mobile_open_url(device, "https://example.com")
```

---

## 10. ADB — Gaps Not Covered by mobile-mcp

Use ADB **only** for these:

```bash
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
D="emulator-5554"

# Flutter logs / crash detection (always check after navigation)
"$ADB" -s $D logcat -d -s flutter | tail -50
"$ADB" -s $D logcat -d flutter:D *:S | tail -50   # debugPrint output

# Dark mode toggle
"$ADB" -s $D shell "cmd uimode night yes"
"$ADB" -s $D shell "cmd uimode night no"

# Font scale
"$ADB" -s $D shell settings put system font_scale 1.5

# Screen rotation (prefer mobile_set_orientation when available)
"$ADB" -s $D shell settings put system accelerometer_rotation 0
"$ADB" -s $D shell settings put system user_rotation 1   # 1=landscape, 0=portrait
```

---

## 11. Static Analysis (Before QA)

```bash
# From zuralog/
flutter analyze   # must report zero warnings — project enforces zero-warning policy
```

---

## 12. Session Skeleton

```
# 1. Verify mobile-mcp is active
mobile_list_available_devices()

# 2. Confirm app is on screen
mobile_take_screenshot(device)

# 3. Check for silent errors
"$ADB" -s $D logcat -d flutter:D *:S | tail -50

# 4. Find elements and interact
mobile_list_elements_on_screen(device)
mobile_click_on_screen_at_coordinates(device, x, y)

# 5. Screenshot after interaction
mobile_take_screenshot(device)

# 6. Save evidence for bugs — always resize before reading
mobile_save_screenshot(device, ".agent/screenshots/<label>.png")
magick .agent/screenshots/<label>.png -resize 1600x1600\> .agent/screenshots/<label>.png

# 7. Dark mode
"$ADB" -s $D shell "cmd uimode night yes"
mobile_take_screenshot(device)
"$ADB" -s $D shell "cmd uimode night no"

# 8. Cleanup
rm -f .agent/screenshots/*.png
```

---

## 13. Gotchas

| Symptom | Fix |
|---------|-----|
| `mobile-mcp` tools unavailable | Not enabled — ask user to enable `mobile-mcp` MCP server |
| Agent terminal hangs | Blocking process in agent terminal — use new terminal or `&` |
| Tap does nothing | Use `mobile_list_elements_on_screen` to get accurate coordinates |
| Can't find element | Scroll with `mobile_swipe_on_screen`, re-check elements |
| ANR "System UI not responding" | Tap "Wait" via `mobile_list_elements_on_screen` coordinates |
| Text appends to existing | Terminate and relaunch app, or long-press field → select all → retype |
| App not visible after `make run` | Still compiling — wait longer, retry `mobile_take_screenshot` |
| Black screenshot | Emulator still booting — wait and retry |
| Google Sign-In null token | Used bare `flutter run` — use `make run` |
| Auth/AI errors | Backend not running — `make dev` in `cloud-brain/` |
| Screenshot committed to git | Wasn't in `.agent/screenshots/` — move and clean up |
| `image dimensions exceed max allowed size` | Saved screenshot not resized — run `magick <file> -resize 1600x1600\> <file>` before Read tool |

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

```
# mobile-mcp (primary)
mobile_list_available_devices()
mobile_take_screenshot(device)
mobile_save_screenshot(device, ".agent/screenshots/<label>.png")
magick .agent/screenshots/<label>.png -resize 1600x1600\> .agent/screenshots/<label>.png   # resize before Read tool
mobile_list_elements_on_screen(device)
mobile_click_on_screen_at_coordinates(device, x, y)
mobile_swipe_on_screen(device, direction="up")
mobile_type_keys(device, "text", submit=false)
mobile_press_button(device, "BACK")
mobile_get_screen_size(device)
mobile_set_orientation(device, "landscape")
mobile_launch_app(device, "com.zuralog.zuralog")
mobile_terminate_app(device, "com.zuralog.zuralog")

# ADB (gaps only)
ADB="/c/Users/hyoar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
"$ADB" -s emulator-5554 logcat -d -s flutter | tail -50
"$ADB" -s emulator-5554 shell "cmd uimode night yes"
"$ADB" -s emulator-5554 shell "cmd uimode night no"
rm -f .agent/screenshots/*.png
```

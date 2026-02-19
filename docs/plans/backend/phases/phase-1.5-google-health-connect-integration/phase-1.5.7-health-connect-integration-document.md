# Phase 1.5.7: Health Connect Integration Document

**Parent Goal:** Phase 1.5 Google Health Connect Integration
**Checklist:**
- [x] 1.5.1 Health Connect Permissions (Android)
- [x] 1.5.2 Kotlin Health Connect Bridge
- [x] 1.5.3 Flutter Platform Channel (Android)
- [x] 1.5.4 Health Connect MCP Server
- [x] 1.5.5 Background Sync (Android WorkManager)
- [x] 1.5.6 Unified Health Store Abstraction
- [ ] 1.5.7 Health Connect Integration Document

---

## What
Create a comprehensive reference document for the Google Health Connect integration, similar to the Apple Health one.

## Why
Health Connect is relatively new and has specific quirks (e.g., it's a separate app on older Android versions, built-in on Android 14). Documentation is vital for maintenance.

## How
Create `google-health-connect-integration.md` in the integrations folder.

## Features
- **Setup Guide:** How to install the Health Connect app on emulators.
- **Permission Flow:** Explains the "Rationale" -> "System Dialog" flow.

## Files
- Create: `docs/plans/backend/integrations/google-health-connect-integration.md`

## Steps

1. **Create integration reference document**

`docs/plans/backend/integrations/google-health-connect-integration.md` content:

```markdown
# Google Health Connect Integration Reference

## Overview
We use Google Health Connect (Android 14+ built-in, Android 9+ via APK) to store and retrieve health data.

## Architecture
- **Kotlin Bridge:** Uses `androidx.health.connect:connect-client`.
- **Method Channel:** `com.lifelogger/health`.
- **Background:** `WorkManager` (Periodic 15m).

## Data Types
| Metric | Record Class | Read/Write |
|--------|--------------|------------|
| Steps | `StepsRecord` | Read/Write |
| Calories | `ActiveCaloriesBurnedRecord` | Read/Write |
| Workout | `ExerciseSessionRecord` | Read/Write |
| Weight | `WeightRecord` | Read/Write |

## Permission Handling
Android requires declaring `<uses-permission>` in Manifest.
At runtime, we launch an intent. The user sees a system sheet to toggle category access.

## Testing on Emulator
1. Use an image with Play Store (API 34+ recommended).
2. Install "Health Connect" app if not present.
3. Open Health Connect -> Data and Access -> Life Logger -> Allow All.
```

## Exit Criteria
- `google-health-connect-integration.md` exists in the `integrations` folder.

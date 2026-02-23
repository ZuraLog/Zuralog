# Phase 1.10.7: Harness: Background Sync Test

**Parent Goal:** Phase 1.10 Background Services & Sync Engine
**Checklist:**
- [x] 1.10.1 Cloud-to-Device Write Flow
- [x] 1.10.2 Background Sync Scheduler
- [x] 1.10.3 Edge Agent Background Handler
- [x] 1.10.4 Data Normalization
- [x] 1.10.5 Source-of-Truth Hierarchy
- [x] 1.10.6 Sync Status Tracking
- [x] 1.10.7 Harness: Background Sync Test

---

## What
Add controls to the Developer Harness to manually trigger the "Background Sync" (Cloud-to-Device write) flow for testing.

## Why
We need to verify the complex FCM -> Background Handler -> HealthKit Write chain without waiting for an actual AI agent decision.

## How
Button on Harness Screen: "Simulate AI Write".

## Features
- **Visual Feedback:** Shows if the API accepted the request.
- **Log Monitor:** We will need to check client logs to see if the background handler fired.

## Files
- Modify: `zuralog/lib/features/harness/harness_screen.dart`

## Steps

1. **Add sync controls (`zuralog/lib/features/harness/harness_screen.dart`)**

```dart
// In build()
ElevatedButton(
  onPressed: () async {
    // Call backend endpoint that simulates an AI write request
    try {
      final response = await ref.read(apiClientProvider).post(
        '/dev/trigger-write', 
        data: {
           'data_type': 'steps',
           'value': {'count': 500, 'date': DateTime.now().toIso8601String()}
        }
      );
      _log("Write Triggered: ${response.data}");
    } catch(e) {
      _log("Error: $e");
    }
  },
  child: const Text('Simulate AI Write (FCM)'),
),
```

## Exit Criteria
- Button calls backend.
- Backend sends FCM.
- Device receives FCM (verify via log).

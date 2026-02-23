# Phase 1.4.7: Harness Test: HealthKit Integration

**Parent Goal:** Phase 1.4 Apple HealthKit Integration
**Checklist:**
- [x] 1.4.1 HealthKit Entitlements & Permissions (iOS)
- [x] 1.4.2 Swift HealthKit Bridge
- [x] 1.4.3 Flutter Platform Channel
- [x] 1.4.4 HealthKit MCP Server (Cloud Brain)
- [x] 1.4.5 Edge Agent Health Repository
- [x] 1.4.6 Background Observation
- [ ] 1.4.7 Harness Test: HealthKit Integration
- [ ] 1.4.8 Apple Health Integration Document

---

## What
Update the Developer UI Harness to include buttons that trigger HealthKit permissions, read steps, and read workouts.

## Why
We need to verify that our `PlatformChannel` -> `Swift Bridge` -> `HealthKit` chain works on a real device/simulator before building the actual "Integrations" screen.

## How
Add three buttons to `HarnessScreen` that call methods on `HealthRepository` and display results in the output text field.

## Features
- **Permission Trigger:** Forces the iOS "Allow Access" sheet to appear.
- **Data Verification:** Confirms we can actually read data written by the Apple Health app.

## Files
- Modify: `zuralog/lib/features/harness/harness_screen.dart`

## Steps

1. **Add HealthKit buttons to harness (`zuralog/lib/features/harness/harness_screen.dart`)**

```dart
// ... inside the Wrap widget ...

ElevatedButton(
  onPressed: () async {
    final healthRepo = ref.read(healthRepositoryProvider);
    final authorized = await healthRepo.requestAuthorization();
    setState(() {
         _outputController.text = authorized 
        ? 'HealthKit AUTHORIZED' 
        : 'HealthKit DENIED/UNAVAILABLE';
    });
  },
  child: const Text('Request HealthKit'),
),

ElevatedButton(
  onPressed: () async {
    final healthRepo = ref.read(healthRepositoryProvider);
    final steps = await healthRepo.getSteps(DateTime.now());
    setState(() {
        _outputController.text = 'Steps today: $steps';
    });
  },
  child: const Text('Read Steps'),
),

ElevatedButton(
  onPressed: () async {
    final healthRepo = ref.read(healthRepositoryProvider);
    final workouts = await healthRepo.getWorkouts(
      DateTime.now().subtract(const Duration(days: 7)),
      DateTime.now(),
    );
    setState(() {
        _outputController.text = 'Workouts (Last 7 Days): ${workouts.length}\n$workouts';
    });
  },
  child: const Text('Read Workouts'),
),
```

## Exit Criteria
- Can request permission (Apple Health dialog appears).
- Can read steps (matches Health app simulator data).
- Can read workouts.

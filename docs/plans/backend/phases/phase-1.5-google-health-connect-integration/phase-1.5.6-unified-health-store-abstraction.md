# Phase 1.5.6: Unified Health Store Abstraction

**Parent Goal:** Phase 1.5 Google Health Connect Integration
**Checklist:**
- [x] 1.5.1 Health Connect Permissions (Android)
- [x] 1.5.2 Kotlin Health Connect Bridge
- [x] 1.5.3 Flutter Platform Channel (Android)
- [x] 1.5.4 Health Connect MCP Server
- [x] 1.5.5 Background Sync (Android WorkManager)
- [ ] 1.5.6 Unified Health Store Abstraction
- [ ] 1.5.7 Health Connect Integration Document

---

## What
Refactor `HealthRepository` and create a `HealthObserver` class that hides the platform-specific implementation details (HealthKit vs Health Connect) from the rest of the Flutter app.

## Why
The UI (Dashboard) just wants to know "how many steps today?". It shouldn't care if it's on iOS or Android.

## How
Use `Platform.isAndroid` and `Platform.isIOS` checks within the repository layer to delegate calls to the appropriate native bridge methods (which we've already unified under `HealthBridge` class in Dart).

## Features
- **Polymorphism:** Swap implementations based on runtime OS.
- **Fail-safe:** If on Web or Desktop, returns empty data instead of crashing.

## Files
- Create: `life_logger/lib/core/health/health_observer.dart`
- Modify: `life_logger/lib/features/health/data/health_repository.dart`

## Steps

1. **Create unified health observer (`life_logger/lib/core/health/health_observer.dart`)**

```dart
import 'dart:io';
// import 'package:flutter_riverpod/flutter_riverpod.dart'; // If needed

class HealthObserver {
  final bool isAndroid;
  final bool isIOS;
  
  HealthObserver() 
      : isAndroid = Platform.isAndroid,
        isIOS = Platform.isIOS;
  
  Future<void> startObserving({
    required Function(String dataType) onDataChanged,
  }) async {
    if (isIOS) {
       // Call HealthBridge.startBackgroundObservers() (implemented in 1.4)
    } else if (isAndroid) {
       // Android relies on WorkManager (scheduled in native), 
       // but we might want to register a foreground listener if the app is open.
    }
  }
  
  Future<void> stopObserving() async {
    // Teardown logic
  }
}
```

2. **Update HealthRepository (`life_logger/lib/features/health/data/health_repository.dart`)**

```dart
// Ensure methods handle platform specifics if they diverge.
// Currently HealthBridge handles the channel, which is unified. 
// Just ensure error handling covers "Health Connect Not Installed" on Android.

Future<bool> requestAuthorization() async {
  // On Android, this might redirect to Play Store if Health Connect is missing.
  // Add check:
  if (Platform.isAndroid) {
    // Check if package installed
  }
  return await HealthBridge.requestAuthorization();
}
```

## Exit Criteria
- `HealthObserver` class created.
- `HealthRepository` robustly handles platform differences.

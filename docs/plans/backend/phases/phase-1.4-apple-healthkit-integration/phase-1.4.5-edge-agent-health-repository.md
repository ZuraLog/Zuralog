# Phase 1.4.5: Edge Agent Health Repository

**Parent Goal:** Phase 1.4 Apple HealthKit Integration
**Checklist:**
- [x] 1.4.1 HealthKit Entitlements & Permissions (iOS)
- [x] 1.4.2 Swift HealthKit Bridge
- [x] 1.4.3 Flutter Platform Channel
- [x] 1.4.4 HealthKit MCP Server (Cloud Brain)
- [ ] 1.4.5 Edge Agent Health Repository
- [ ] 1.4.6 Background Observation
- [ ] 1.4.7 Harness Test: HealthKit Integration
- [ ] 1.4.8 Apple Health Integration Document

---

## What
Create a Repository class in Dart that abstracts the low-level Platform Channel calls (`HealthBridge`) into a clean, type-safe API for the rest of the Flutter app to use.

## Why
Directly calling static platform channel methods from UI code is brittle and hard to test. A Repository pattern allows us to inject dependencies, manage authorization state centrally, and swap implementations for testing.

## How
The `HealthRepository` will wrap `HealthBridge` calls. It will be provided via `Riverpod` to the rest of the app.

## Features
- **Authorization Management:** Encapsulates the logic for checking and requesting permissions.
- **Data Transformation:** Converts raw Maps from the platform channel into strongly typed Dart objects (if needed in future).

## Files
- Create: `zuralog/lib/features/health/data/health_repository.dart`

## Steps

1. **Create health repository (`zuralog/lib/features/health/data/health_repository.dart`)**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/health/health_bridge.dart';

class HealthRepository {
  
  /// Request permissions from the user to access HealthKit data.
  Future<bool> requestAuthorization() async {
    return await HealthBridge.requestAuthorization();
  }
  
  /// Check if HealthKit is available on this device.
  Future<bool> get isAvailable async {
    return await HealthBridge.isAvailable();
  }
  
  /// Fetch total steps for a specific day.
  Future<double> getSteps(DateTime date) async {
    return await HealthBridge.getSteps(date);
  }
  
  /// Fetch workouts within a date range.
  Future<List<Map<String, dynamic>>> getWorkouts(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await HealthBridge.getWorkouts(startDate, endDate);
  }
  
  /// Write a workout to HealthKit.
  Future<bool> writeWorkout({
    required String activityType,
    required DateTime startDate,
    required DateTime endDate,
    required double energyBurned,
  }) async {
    return await HealthBridge.writeWorkout(
      activityType: activityType,
      startDate: startDate,
      endDate: endDate,
      energyBurned: energyBurned,
    );
  }
  
  /// Write nutrition data (calories) to HealthKit.
  Future<bool> writeNutrition({
    required double calories,
    required DateTime date,
  }) async {
    return await HealthBridge.writeNutrition(
      calories: calories,
      date: date,
    );
  }
}

// Riverpod Provider
final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository();
});
```

## Exit Criteria
- Repository compiles.
- Provides clean API for UI and background services.

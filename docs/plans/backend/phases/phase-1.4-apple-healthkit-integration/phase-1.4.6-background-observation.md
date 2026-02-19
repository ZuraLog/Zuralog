# Phase 1.4.6: Background Observation (HKObserverQuery)

**Parent Goal:** Phase 1.4 Apple HealthKit Integration
**Checklist:**
- [x] 1.4.1 HealthKit Entitlements & Permissions (iOS)
- [x] 1.4.2 Swift HealthKit Bridge
- [x] 1.4.3 Flutter Platform Channel
- [x] 1.4.4 HealthKit MCP Server (Cloud Brain)
- [x] 1.4.5 Edge Agent Health Repository
- [ ] 1.4.6 Background Observation
- [ ] 1.4.7 Harness Test: HealthKit Integration
- [ ] 1.4.8 Apple Health Integration Document

---

## What
Implement `HKObserverQuery` in Swift to detect when HealthKit data changes (e.g., a new workout is logged by an Apple Watch) even when the Life Logger app is not running.

## Why
This is critical for "Passive Tracking." We want the Cloud Brain to know about your morning run automatically, without you having to open the app and press "Sync".

## How
We register a long-running query in `HealthKitBridge.swift` and enable "Background Delivery". When iOS wakes our app up with new data, we (in later phases) trigger a background synchronization task.

## Features
- **Passive Sync:** Zero-touch data ingestion.
- **Battery Efficient:** Uses OS-level batching instead of polling.

## Files
- Modify: `life_logger/ios/Runner/HealthKitBridge.swift`

## Steps

1. **Add observer query for background updates (`life_logger/ios/Runner/HealthKitBridge.swift`)**

```swift
// Add this method to HealthKitBridge class
func startBackgroundObservers(completion: @escaping (Bool) -> Void) {
    guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
          let workoutType = HKObjectType.workoutType() else {
        completion(false)
        return
    }
    
    // Observer for Steps
    let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
        if error == nil {
            // Data changed - notify Flutter logic
            self?.notifyFlutterOfChange(type: "steps")
        }
        // Important: Call completion handler to let iOS know we finished processing
        completionHandler()
    }
    
    // Observer for Workouts
    let workoutQuery = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
        if error == nil {
            self?.notifyFlutterOfChange(type: "workouts")
        }
        completionHandler()
    }
    
    healthStore.execute(query)
    healthStore.execute(workoutQuery)
    
    // Enable background delivery (frequency: .immediate usually means "when convenient for iOS", often deferred)
    healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in }
    healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
    
    completion(true)
}

private func notifyFlutterOfChange(type: String) {
    // In Phase 1.10 (Background Services), we will implement the actual 
    // "Headless JS" or "WorkManager" logic here to wake up Dart code.
    // For now, we just print/log.
    print("background_observer_triggered: \(type)")
}
```

## Exit Criteria
- Observers start without error.
- Changes in Health app trigger the callback (visible in logs when debugging).

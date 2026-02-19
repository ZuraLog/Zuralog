# Apple HealthKit Integration

> **Status:** Reference document for Phase 1.4 implementation  
> **Priority:** P0 (MVP)

---

## Overview

This document provides deep-dive technical details for integrating Apple HealthKit into Life Logger.

---

## API Overview

### Data Types

#### Read Permissions
- Steps: `HKQuantityType.quantityType(forIdentifier: .stepCount)`
- Active Energy: `HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)`
- Dietary Energy: `HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)`
- Body Mass: `HKQuantityType.quantityType(forIdentifier: .bodyMass)`
- Workouts: `HKObjectType.workoutType()`
- Sleep: `HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)`

#### Write Permissions
- Dietary Energy (nutrition logging)
- Body Mass (weight logging)
- Workouts (workout logging)

---

## Permission Requirements

### Required Entitlements
- `com.apple.developer.healthkit`
- `com.apple.developer.healthkit.background-delivery`

### Info.plist Keys
```xml
<key>NSHealthShareUsageDescription</key>
<string>Life Logger needs access to your health data to provide personalized AI coaching.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Life Logger needs to write health data based on your requests.</string>
```

---

## Background Delivery

### HKObserverQuery Setup
```swift
healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
    // Handle result
}
```

### Observer Query
```swift
let query = HKObserverQuery(sampleType: stepType, predicate: nil) { _, completionHandler, error in
    // Handle new data
    completionHandler()
}
healthStore.execute(query)
```

---

## Code Examples

### Reading Steps
```swift
func fetchSteps(date: Date, completion: @escaping (Double?, Error?) -> Void) {
    guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
    let startOfDay = Calendar.current.startOfDay(for: date)
    let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: date, options: .strictStartDate)
    
    let query = HKStatisticsQuery(
        quantityType: stepType,
        quantitySamplePredicate: predicate,
        options: .cumulativeSum
    ) { _, result, error in
        guard let result = result, let sum = result.sumQuantity() else {
            completion(nil, error)
            return
        }
        let steps = sum.doubleValue(for: HKUnit.count())
        completion(steps, nil)
    }
    healthStore.execute(query)
}
```

### Writing Workout
```swift
func writeWorkout(activityType: String, startDate: Date, endDate: Date, energyBurned: Double, completion: @escaping (Bool, Error?) -> Void) {
    let workout = HKWorkout(
        activityType: .running,
        start: startDate,
        end: endDate,
        duration: endDate.timeIntervalSince(startDate),
        totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: energyBurned),
        totalDistance: nil,
        metadata: nil
    )
    healthStore.save(workout) { success, error in
        completion(success, error)
    }
}
```

---

## Testing Checklist

- [ ] HealthKit authorization request
- [ ] Read steps for today
- [ ] Read workouts for date range
- [ ] Write nutrition entry
- [ ] Write workout entry
- [ ] Background observer fires on new data
- [ ] Data syncs to Cloud Brain

---

## Rate Limits

No rate limits for local HealthKit access. Background delivery is immediate.

---

## References

- [Apple HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [HealthKit Entitlements](https://developer.apple.com/documentation/healthkit/supported_healthkit_entitlements)

# Phase 1.4.2: Swift HealthKit Bridge

**Parent Goal:** Phase 1.4 Apple HealthKit Integration
**Checklist:**
- [x] 1.4.1 HealthKit Entitlements & Permissions (iOS)
- [ ] 1.4.2 Swift HealthKit Bridge
- [ ] 1.4.3 Flutter Platform Channel
- [ ] 1.4.4 HealthKit MCP Server (Cloud Brain)
- [ ] 1.4.5 Edge Agent Health Repository
- [ ] 1.4.6 Background Observation
- [ ] 1.4.7 Harness Test: HealthKit Integration
- [ ] 1.4.8 Apple Health Integration Document

---

## What
Implement the native Swift code layer that directly interacts with the `HealthKit` framework. This class (`HealthKitBridge`) will handle permissions, querying data (steps, workouts), and writing data (nutrition, weight).

## Why
Flutter cannot access Apple Health APIs directly. We must write native Swift code to interface with `HKHealthStore` and then expose those functions to Dart via a Platform Channel.

## How
We will create a `HealthKitBridge` class that:
1. Initializes `HKHealthStore`.
2. Defines `HKObjectType` sets for reading and writing.
3. Implements methods like `fetchSteps`, `fetchWorkouts`, `writeNutrition`.

## Features
- **Granular Data Access:** Reads Steps, Active Energy, Dietary Energy, Body Mass, Workouts, and Sleep.
- **Bi-directional:** Can both read analytics and write entries created by the AI.

## Files
- Create: `zuralog/ios/Runner/HealthKitBridge.swift`

## Steps

1. **Create HealthKit bridge**

```swift
import Foundation
import HealthKit

class HealthKitBridge: NSObject {
    private let healthStore = HKHealthStore()
    
    // Data types we need to read/write
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.workoutType(),
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
    ]
    
    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.workoutType(),
    ]
    
    func isAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            completion(success, error)
        }
    }
    
    // MARK: - Read Methods
    
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
    
    func fetchWorkouts(startDate: Date, endDate: Date, completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        guard let workoutType = HKObjectType.workoutType() else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            guard let workouts = samples as? [HKWorkout] else {
                completion(nil, error)
                return
            }
            
            let workoutData = workouts.map { workout in
                [
                    "id": workout.uuid.uuidString,
                    "activityType": workout.workoutActivityType.name,
                    "duration": workout.duration,
                    "startDate": workout.startDate.timeIntervalSince1970,
                    "endDate": workout.endDate.timeIntervalSince1970,
                    "energyBurned": workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                ]
            }
            
            completion(workoutData, nil)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Write Methods
    
    func writeWorkout(
        activityType: String,
        startDate: Date,
        endDate: Date,
        energyBurned: Double,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let workoutType: HKWorkoutActivityType
        switch activityType.lowercased() {
        case "run", "running": workoutType = .running
        case "walk", "walking": workoutType = .walking
        case "cycle", "cycling": workoutType = .cycling
        default: workoutType = .traditionalStrengthTraining
        }
        
        let workout = HKWorkout(
            activityType: workoutType,
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
    
    func writeNutrition(calories: Double, date: Date, completion: @escaping (Bool, Error?) -> Void) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            completion(false, nil)
            return
        }
        
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
        let sample = HKQuantitySample(
            type: energyType,
            quantity: quantity,
            start: date,
            end: date
        )
        
        healthStore.save(sample) { success, error in
            completion(success, error)
        }
    }
}
```

## Exit Criteria
- Swift bridge class compiles.
- Methods cover all required read/write operations.

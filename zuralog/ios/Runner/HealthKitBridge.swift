/// HealthKitBridge -- Native Swift interface to Apple HealthKit.
///
/// Handles all direct HKHealthStore interactions: authorization,
/// reading metrics (steps, workouts, sleep, calories, weight),
/// and writing entries (nutrition, workouts).
///
/// This class is consumed by AppDelegate via FlutterMethodChannel.
/// It does NOT interact with Flutter directly -- the channel handler
/// marshals arguments and results.

import Foundation
import HealthKit

class HealthKitBridge: NSObject {

    // MARK: - Properties

    private let healthStore = HKHealthStore()

    /// All data types we request read access for.
    private let readTypes: Set<HKObjectType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.dietaryEnergyConsumed),
        HKQuantityType(.bodyMass),
        HKCategoryType(.sleepAnalysis),
        HKWorkoutType.workoutType(),
    ]

    /// Data types we request write access for.
    private let writeTypes: Set<HKSampleType> = [
        HKQuantityType(.dietaryEnergyConsumed),
        HKQuantityType(.bodyMass),
        HKWorkoutType.workoutType(),
    ]

    // MARK: - Availability & Authorization

    /// Checks if HealthKit is available on this device.
    ///
    /// - Returns: `true` if HealthKit is supported (iOS devices, not iPad-only).
    func isAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    /// Requests read/write authorization from the user.
    ///
    /// Displays the iOS system permission sheet. The user can grant
    /// or deny access per data type. HealthKit does NOT reveal which
    /// specific types were denied -- `success` only means the dialog
    /// was presented without error.
    ///
    /// - Parameter completion: Called with `(true, nil)` on success,
    ///   `(false, error)` if HealthKit is unavailable or request failed.
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }

        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    // MARK: - Read: Steps

    /// Fetches cumulative step count for a specific day.
    ///
    /// - Parameters:
    ///   - date: The day to query (uses start-of-day to end-of-day range).
    ///   - completion: Called with total step count or nil on failure.
    func fetchSteps(date: Date, completion: @escaping (Double?, Error?) -> Void) {
        let stepType = HKQuantityType(.stepCount)
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }
            let steps = sum.doubleValue(for: HKUnit.count())
            DispatchQueue.main.async { completion(steps, nil) }
        }

        healthStore.execute(query)
    }

    // MARK: - Read: Workouts

    /// Fetches workouts within a date range.
    ///
    /// - Parameters:
    ///   - startDate: Range start (inclusive).
    ///   - endDate: Range end (exclusive).
    ///   - completion: Called with array of workout dictionaries or nil.
    func fetchWorkouts(startDate: Date, endDate: Date, completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let query = HKSampleQuery(
            sampleType: HKWorkoutType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            guard let workouts = samples as? [HKWorkout] else {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }

            let workoutData: [[String: Any]] = workouts.map { workout in
                [
                    "id": workout.uuid.uuidString,
                    "activityType": workout.workoutActivityType.name,
                    "duration": workout.duration,
                    "startDate": workout.startDate.timeIntervalSince1970 * 1000,
                    "endDate": workout.endDate.timeIntervalSince1970 * 1000,
                    "energyBurned": workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0,
                ]
            }

            DispatchQueue.main.async { completion(workoutData, nil) }
        }

        healthStore.execute(query)
    }

    // MARK: - Read: Sleep

    /// Fetches sleep analysis samples within a date range.
    ///
    /// - Parameters:
    ///   - startDate: Range start (inclusive).
    ///   - endDate: Range end (exclusive).
    ///   - completion: Called with array of sleep segment dictionaries.
    func fetchSleep(startDate: Date, endDate: Date, completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        let sleepType = HKCategoryType(.sleepAnalysis)

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            guard let sleepSamples = samples as? [HKCategorySample] else {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }

            let sleepData: [[String: Any]] = sleepSamples.map { sample in
                [
                    "value": sample.value,
                    "startDate": sample.startDate.timeIntervalSince1970 * 1000,
                    "endDate": sample.endDate.timeIntervalSince1970 * 1000,
                    "source": sample.sourceRevision.source.name,
                ]
            }

            DispatchQueue.main.async { completion(sleepData, nil) }
        }

        healthStore.execute(query)
    }

    // MARK: - Read: Weight

    /// Fetches the most recent body mass sample.
    ///
    /// - Parameter completion: Called with weight in kg, or nil.
    func fetchWeight(completion: @escaping (Double?, Error?) -> Void) {
        let weightType = HKQuantityType(.bodyMass)

        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }
            let kg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            DispatchQueue.main.async { completion(kg, nil) }
        }

        healthStore.execute(query)
    }

    // MARK: - Write: Workout

    /// Writes a workout entry to HealthKit.
    ///
    /// - Parameters:
    ///   - activityType: String key (e.g., "running", "cycling", "walking").
    ///   - startDate: Workout start time.
    ///   - endDate: Workout end time.
    ///   - energyBurned: Calories burned (kcal).
    ///   - completion: Called with success/failure.
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
        case "swim", "swimming": workoutType = .swimming
        case "hike", "hiking": workoutType = .hiking
        case "strength", "strength_training": workoutType = .traditionalStrengthTraining
        case "yoga": workoutType = .yoga
        case "dance": workoutType = .dance
        default:
            // Use .other for unrecognized types rather than silently misclassifying.
            workoutType = .other
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
            DispatchQueue.main.async { completion(success, error) }
        }
    }

    // MARK: - Write: Nutrition

    /// Writes a dietary energy (calorie) entry to HealthKit.
    ///
    /// - Parameters:
    ///   - calories: Kilocalories consumed.
    ///   - date: The date/time of the meal.
    ///   - completion: Called with success/failure.
    func writeNutrition(calories: Double, date: Date, completion: @escaping (Bool, Error?) -> Void) {
        let energyType = HKQuantityType(.dietaryEnergyConsumed)
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
        let sample = HKQuantitySample(
            type: energyType,
            quantity: quantity,
            start: date,
            end: date
        )

        healthStore.save(sample) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }

    // MARK: - Write: Weight

    /// Writes a body mass entry to HealthKit.
    ///
    /// - Parameters:
    ///   - weightKg: Weight in kilograms.
    ///   - date: The date of the measurement.
    ///   - completion: Called with success/failure.
    func writeWeight(weightKg: Double, date: Date, completion: @escaping (Bool, Error?) -> Void) {
        let weightType = HKQuantityType(.bodyMass)
        let quantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(
            type: weightType,
            quantity: quantity,
            start: date,
            end: date
        )

        healthStore.save(sample) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }

    // MARK: - Background Observation

    /// Starts long-running HKObserverQuery instances for steps, workouts, and sleep.
    ///
    /// When iOS detects new data in HealthKit (e.g., from Apple Watch
    /// or a third-party app), it wakes our process and fires the
    /// observer callback. In Phase 1.10 (Background Services), the
    /// callback will trigger a Dart background isolate via headless
    /// FlutterEngine. For now, it logs the event.
    ///
    /// Also enables background delivery so observers fire even when
    /// the app is terminated.
    ///
    /// - Parameter completion: Called with `true` if observers started.
    func startBackgroundObservers(completion: @escaping (Bool) -> Void) {
        let stepType = HKQuantityType(.stepCount)
        let workoutType = HKWorkoutType.workoutType()
        let sleepType = HKCategoryType(.sleepAnalysis)

        let typesToObserve: [(HKSampleType, String)] = [
            (stepType, "steps"),
            (workoutType, "workouts"),
            (sleepType, "sleep"),
        ]

        // Track whether all background delivery registrations succeed.
        let group = DispatchGroup()
        var allSucceeded = true

        for (sampleType, label) in typesToObserve {
            let query = HKObserverQuery(
                sampleType: sampleType,
                predicate: nil
            ) { [weak self] _, completionHandler, error in
                if error == nil {
                    self?.notifyOfChange(type: label)
                }
                // Must call completion handler to tell iOS we're done processing.
                completionHandler()
            }

            healthStore.execute(query)

            // Enable background delivery (frequency: .immediate means
            // "as soon as practical" -- iOS may batch for battery).
            group.enter()
            healthStore.enableBackgroundDelivery(
                for: sampleType,
                frequency: .immediate
            ) { success, error in
                if !success {
                    allSucceeded = false
                }
                if let error = error {
                    print("HealthKit background delivery error for \(label): \(error.localizedDescription)")
                }
                group.leave()
            }
        }

        // Report success only after all background delivery registrations complete.
        group.notify(queue: .main) {
            completion(allSucceeded)
        }
    }

    /// Called when an HKObserverQuery fires due to new data.
    ///
    /// In Phase 1.10 (Background Services), this will:
    /// 1. Start a headless FlutterEngine
    /// 2. Send the change type via method channel
    /// 3. Dart code syncs data to Cloud Brain via REST
    ///
    /// For now, logs the event for debugging.
    ///
    /// - Parameter type: The data type that changed (e.g., "steps", "workouts").
    private func notifyOfChange(type: String) {
        print("[HealthKitBridge] background_observer_triggered: \(type)")
        // TODO(phase-1.10): Trigger background sync to Cloud Brain
    }
}

// MARK: - HKWorkoutActivityType Extension

extension HKWorkoutActivityType {
    /// Human-readable name for serialization to Dart.
    var name: String {
        switch self {
        case .running: return "running"
        case .walking: return "walking"
        case .cycling: return "cycling"
        case .swimming: return "swimming"
        case .hiking: return "hiking"
        case .traditionalStrengthTraining: return "strength_training"
        case .yoga: return "yoga"
        case .dance: return "dance"
        default: return "other"
        }
    }
}

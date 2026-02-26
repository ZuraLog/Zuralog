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
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.vo2Max),
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

    /// Passively checks if HealthKit permissions were previously granted.
    ///
    /// Uses write authorization status for body mass (weight) as a proxy —
    /// HealthKit only reliably reports write authorization, unlike read
    /// authorization which is hidden for privacy.
    ///
    /// This method does NOT show any permission dialog.
    ///
    /// - Parameter completion: Called with `true` if write authorization is
    ///   `.sharingAuthorized`, `false` if `.sharingDenied` or `.notDetermined`
    ///   (never asked). Both non-authorized states return `false`.
    func checkPermissionsGranted(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        // bodyMass is in our writeTypes set — write auth is reliably reported.
        let weightType = HKQuantityType(.bodyMass)
        let status = healthStore.authorizationStatus(for: weightType)
        completion(status == .sharingAuthorized)
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

    // MARK: - Read: Active Calories Burned

    /// Fetches cumulative active energy burned for a specific day.
    ///
    /// Queries `HKQuantityType(.activeEnergyBurned)` using a cumulative-sum
    /// statistics query scoped to midnight-to-midnight for [date].
    ///
    /// - Parameters:
    ///   - date: The day to query.
    ///   - completion: Called with total kcal burned or nil on failure.
    func fetchActiveCaloriesBurned(date: Date, completion: @escaping (Double?, Error?) -> Void) {
        let energyType = HKQuantityType(.activeEnergyBurned)
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }
            let kcal = sum.doubleValue(for: HKUnit.kilocalorie())
            DispatchQueue.main.async { completion(kcal, nil) }
        }

        healthStore.execute(query)
    }

    // MARK: - Read: Nutrition Calories Consumed

    /// Fetches cumulative dietary energy consumed for a specific day.
    ///
    /// Queries `HKQuantityType(.dietaryEnergyConsumed)` using a cumulative-sum
    /// statistics query scoped to midnight-to-midnight for [date].
    ///
    /// - Parameters:
    ///   - date: The day to query.
    ///   - completion: Called with total kcal consumed or nil on failure.
    func fetchNutritionCalories(date: Date, completion: @escaping (Double?, Error?) -> Void) {
        let nutritionType = HKQuantityType(.dietaryEnergyConsumed)
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: nutritionType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }
            let kcal = sum.doubleValue(for: HKUnit.kilocalorie())
            DispatchQueue.main.async { completion(kcal, nil) }
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

    // MARK: - Read: Resting Heart Rate

    /// Fetches the most recent resting heart rate sample.
    ///
    /// Apple Watch measures resting HR nightly and writes it to HealthKit.
    /// Returns the most recent sample regardless of date.
    ///
    /// - Parameter completion: Called with resting HR in beats-per-minute, or nil.
    func fetchRestingHeartRate(completion: @escaping (Double?, Error?) -> Void) {
        let rhrType = HKQuantityType(.restingHeartRate)

        let query = HKSampleQuery(
            sampleType: rhrType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }
            let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            DispatchQueue.main.async { completion(bpm, nil) }
        }

        healthStore.execute(query)
    }

    // MARK: - Read: HRV

    /// Fetches the most recent heart rate variability (SDNN) sample.
    ///
    /// Apple Watch writes HRV samples during overnight breathing sessions.
    /// Returns the most recent sample regardless of date.
    ///
    /// - Parameter completion: Called with HRV in milliseconds, or nil.
    func fetchHRV(completion: @escaping (Double?, Error?) -> Void) {
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)

        let query = HKSampleQuery(
            sampleType: hrvType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }
            // HealthKit stores HRV in seconds; convert to milliseconds.
            let ms = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            DispatchQueue.main.async { completion(ms, nil) }
        }

        healthStore.execute(query)
    }

    // MARK: - Read: Cardio Fitness (VO2 Max)

    /// Fetches the most recent VO2 max (cardio fitness) sample.
    ///
    /// Apple Watch estimates VO2 max during outdoor walks/runs (Series 3+)
    /// and writes it to HealthKit as mL/kg/min.
    ///
    /// - Parameter completion: Called with VO2 max in mL/kg/min, or nil.
    func fetchCardioFitness(completion: @escaping (Double?, Error?) -> Void) {
        let vo2Type = HKQuantityType(.vo2Max)

        let query = HKSampleQuery(
            sampleType: vo2Type,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }
            // VO2 max unit: mL/kg/min
            let mlPerKgMin = sample.quantity.doubleValue(
                for: HKUnit(from: "ml/kg/min")
            )
            DispatchQueue.main.async { completion(mlPerKgMin, nil) }
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
        let calorieType = HKQuantityType(.activeEnergyBurned)
        let nutritionType = HKQuantityType(.dietaryEnergyConsumed)
        let weightType = HKQuantityType(.bodyMass)
        let rhrType = HKQuantityType(.restingHeartRate)
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let vo2Type = HKQuantityType(.vo2Max)

        let typesToObserve: [(HKSampleType, String)] = [
            (stepType, "steps"),
            (workoutType, "workouts"),
            (sleepType, "sleep"),
            (calorieType, "calories"),
            (nutritionType, "nutrition"),
            (weightType, "weight"),
            (rhrType, "resting_heart_rate"),
            (hrvType, "hrv"),
            (vo2Type, "vo2_max"),
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

    /// Manually triggers a native background sync for a specific type.
    /// Used by the platform channel to satisfy FCM 'read_health' requests.
    func triggerSync(type: String) {
        notifyOfChange(type: type)
    }

    /// Called when an HKObserverQuery fires due to new data.
    ///
    /// Reads the Keychain for stored auth credentials and, if present,
    /// reads the latest data for the changed type and POSTs it directly
    /// to the Cloud Brain's `/api/v1/health/ingest` endpoint via URLSession.
    ///
    /// This runs entirely natively — no Flutter engine required — so it
    /// works reliably in the background when the app is suspended or terminated.
    ///
    /// - Parameter type: The data type that changed (e.g., "steps", "workouts").
    private func notifyOfChange(type: String) {
        print("[HealthKitBridge] background_observer_triggered: \(type)")

        guard let token = KeychainHelper.shared.read(key: "auth_token"),
              let baseURL = KeychainHelper.shared.read(key: "api_base_url") else {
            print("[HealthKitBridge] No auth credentials in Keychain — skipping background sync")
            return
        }

        let now = Date()
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now

        switch type {
        case "steps":
            fetchSteps(date: now) { steps, _ in
                guard let steps = steps, steps > 0 else { return }
                let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: now)).prefix(10)
                let payload: [String: Any] = [
                    "source": "apple_health",
                    "daily_metrics": [["date": String(today), "steps": Int(steps)]],
                ]
                self.postToIngest(payload: payload, token: token, baseURL: baseURL)
            }
        case "workouts":
            fetchWorkouts(startDate: oneDayAgo, endDate: now) { workouts, _ in
                guard let workouts = workouts, !workouts.isEmpty else { return }
                let entries: [[String: Any]] = workouts.map { w in
                    [
                        "original_id": (w["id"] as? String) ?? UUID().uuidString,
                        "activity_type": (w["activityType"] as? String) ?? "other",
                        "duration_seconds": (w["duration"] as? Double).map { Int($0) } ?? 0,
                        "calories": (w["energyBurned"] as? Double).map { Int($0) } ?? 0,
                        "start_time": ISO8601DateFormatter().string(
                            from: Date(timeIntervalSince1970: ((w["startDate"] as? Double) ?? 0) / 1000.0)
                        ),
                    ]
                }
                let payload: [String: Any] = ["source": "apple_health", "workouts": entries]
                self.postToIngest(payload: payload, token: token, baseURL: baseURL)
            }
        case "sleep":
            fetchSleep(startDate: oneDayAgo, endDate: now) { segments, _ in
                guard let segments = segments, !segments.isEmpty else { return }
                var totalSeconds: Double = 0
                for seg in segments {
                    let startMs = (seg["startDate"] as? Double) ?? 0
                    let endMs = (seg["endDate"] as? Double) ?? 0
                    totalSeconds += (endMs - startMs) / 1000.0
                }
                let hours = totalSeconds / 3600.0
                guard hours > 0 else { return }
                let today = String(ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: now)).prefix(10))
                let payload: [String: Any] = [
                    "source": "apple_health",
                    "sleep": [["date": today, "hours": round(hours * 100) / 100]],
                ]
                self.postToIngest(payload: payload, token: token, baseURL: baseURL)
            }
        default:
            // For other types (calories, nutrition, weight, RHR, HRV, VO2)
            // read today's daily metrics and post as daily_metrics entry
            readAndPostDailyMetrics(date: now, token: token, baseURL: baseURL)
        }
    }

    /// Reads key daily metrics and posts them to the ingest endpoint.
    ///
    /// Used as a fallback for observer types that don't warrant individual
    /// fetch functions (calories, RHR, HRV, VO2, nutrition).
    ///
    /// - Parameters:
    ///   - date: The date to read metrics for.
    ///   - token: JWT bearer token.
    ///   - baseURL: Cloud Brain API base URL.
    private func readAndPostDailyMetrics(date: Date, token: String, baseURL: String) {
        let group = DispatchGroup()
        var steps: Double = 0
        var calories: Double = 0
        var rhr: Double? = nil
        var hrv: Double? = nil
        var vo2: Double? = nil

        group.enter()
        fetchSteps(date: date) { s, _ in steps = s ?? 0; group.leave() }

        group.enter()
        fetchActiveCaloriesBurned(date: date) { c, _ in calories = c ?? 0; group.leave() }

        group.enter()
        fetchRestingHeartRate { r, _ in rhr = r; group.leave() }

        group.enter()
        fetchHRV { h, _ in hrv = h; group.leave() }

        group.enter()
        fetchCardioFitness { v, _ in vo2 = v; group.leave() }

        group.notify(queue: .global(qos: .background)) {
            let today = String(ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: date)).prefix(10))
            var entry: [String: Any] = ["date": today]
            if steps > 0 { entry["steps"] = Int(steps) }
            if calories > 0 { entry["active_calories"] = Int(calories) }
            if let rhr = rhr, rhr > 0 { entry["resting_heart_rate"] = rhr }
            if let hrv = hrv, hrv > 0 { entry["hrv_ms"] = hrv }
            if let vo2 = vo2, vo2 > 0 { entry["vo2_max"] = vo2 }
            let payload: [String: Any] = ["source": "apple_health", "daily_metrics": [entry]]
            self.postToIngest(payload: payload, token: token, baseURL: baseURL)
        }
    }

    /// Posts a health data payload to the Cloud Brain ingest endpoint via URLSession.
    ///
    /// Fire-and-forget — errors are logged but not propagated.
    ///
    /// - Parameters:
    ///   - payload: The JSON-encodable dictionary to POST.
    ///   - token: JWT bearer token for Authorization header.
    ///   - baseURL: Cloud Brain API base URL (e.g., https://api.zuralog.com).
    private func postToIngest(payload: [String: Any], token: String, baseURL: String) {
        guard let url = URL(string: "\(baseURL)/api/v1/health/ingest"),
              let body = try? JSONSerialization.data(withJSONObject: payload) else {
            print("[HealthKitBridge] Invalid ingest URL or payload")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        request.timeoutInterval = 30.0

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("[HealthKitBridge] Ingest POST failed: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("[HealthKitBridge] Ingest POST returned HTTP \(http.statusCode)")
            } else {
                print("[HealthKitBridge] Ingest POST succeeded for \(payload["source"] ?? "?")")
            }
        }.resume()
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

/// Zuralog Android — Kotlin bridge for Google Health Connect.
///
/// Provides suspend functions to read and write health data via the
/// `androidx.health.connect:connect-client` SDK. All public methods
/// are coroutine-safe and must be called from a coroutine scope
/// (never `runBlocking` on the main thread).
///
/// This class mirrors the Swift `HealthKitBridge` so that the Flutter
/// platform channel handler in `MainActivity` can route identical
/// method names to either native implementation.
package com.zuralog.zuralog

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.NutritionRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.Vo2MaxRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Mass
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/// Kotlin bridge for Google Health Connect data access.
///
/// Each public method corresponds to a Flutter platform channel method.
/// Methods are `suspend` to avoid blocking the UI thread.
class HealthConnectBridge(private val context: Context) {

    companion object {
        private const val TAG = "HealthConnectBridge"

        /**
         * The set of Health Connect permissions Zuralog requires.
         * Must match the <uses-permission> tags in AndroidManifest.xml.
         * Used by MainActivity to launch the permission request contract.
         */
        val REQUIRED_PERMISSIONS: Set<String> = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getWritePermission(StepsRecord::class),
            HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
            HealthPermission.getWritePermission(ActiveCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
            HealthPermission.getWritePermission(TotalCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(SleepSessionRecord::class),
            HealthPermission.getWritePermission(SleepSessionRecord::class),
            HealthPermission.getReadPermission(WeightRecord::class),
            HealthPermission.getWritePermission(WeightRecord::class),
            HealthPermission.getReadPermission(ExerciseSessionRecord::class),
            HealthPermission.getWritePermission(ExerciseSessionRecord::class),
            HealthPermission.getReadPermission(NutritionRecord::class),
            HealthPermission.getWritePermission(NutritionRecord::class),
            HealthPermission.getReadPermission(RestingHeartRateRecord::class),
            HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
            HealthPermission.getReadPermission(Vo2MaxRecord::class),
        )

        /**
         * The minimum set of read permissions that must be granted for a
         * successful connection. Write permissions and less common data types
         * are not required — HC may not surface all REQUIRED_PERMISSIONS in the
         * dialog depending on device and HC version, so checking containsAll()
         * on the full set causes false negatives.
         */
        val CORE_READ_PERMISSIONS: Set<String> = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(SleepSessionRecord::class),
            HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        )
    }

    /// Lazily initialized Health Connect client.
    /// Returns `null` if Health Connect is not available on this device.
    private val client: HealthConnectClient? by lazy {
        try {
            if (isAvailable()) HealthConnectClient.getOrCreate(context) else null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create HealthConnectClient", e)
            null
        }
    }

    // ------------------------------------------------------------------
    // Availability & Permissions
    // ------------------------------------------------------------------

    /// Checks whether Health Connect is installed and available.
    ///
    /// Returns `true` if the SDK status is `SDK_AVAILABLE`.
    fun isAvailable(): Boolean {
        val status = HealthConnectClient.getSdkStatus(context)
        return status == HealthConnectClient.SDK_AVAILABLE
    }

    /// Checks which permissions have been granted.
    ///
    /// Returns `true` if ALL required permissions are granted.
    suspend fun hasAllPermissions(): Boolean {
        val hcClient = client ?: return false
        val granted = hcClient.permissionController.getGrantedPermissions()
        // Use CORE_READ_PERMISSIONS instead of REQUIRED_PERMISSIONS — HC may not
        // surface all write permissions in the dialog on all devices/versions.
        return granted.containsAll(CORE_READ_PERMISSIONS)
    }

    // ------------------------------------------------------------------
    // Read Methods
    // ------------------------------------------------------------------

    /// Reads total step count for a given date (midnight to midnight).
    ///
    /// Parameters:
    ///   - dateMillis: Milliseconds since epoch representing the target date.
    ///
    /// Returns: Total step count as Int, or 0 if no data.
    suspend fun readSteps(dateMillis: Long): Int {
        val hcClient = client ?: return 0
        return try {
            val date = Instant.ofEpochMilli(dateMillis)
                .atZone(ZoneId.systemDefault())
                .toLocalDate()
            val startOfDay = date.atStartOfDay(ZoneId.systemDefault()).toInstant()
            val endOfDay = date.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant()

            val response = hcClient.readRecords(
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(startOfDay, endOfDay)
                )
            )
            response.records.sumOf { it.count.toInt() }
        } catch (e: Exception) {
            Log.e(TAG, "readSteps failed", e)
            0
        }
    }

    /// Reads exercise session records within a time range.
    ///
    /// Parameters:
    ///   - startTimeMillis: Start of range (epoch millis).
    ///   - endTimeMillis: End of range (epoch millis).
    ///
    /// Returns: List of workout maps with keys: title, startTime, endTime, duration.
    suspend fun readWorkouts(startTimeMillis: Long, endTimeMillis: Long): List<Map<String, Any>> {
        val hcClient = client ?: return emptyList()
        return try {
            val response = hcClient.readRecords(
                ReadRecordsRequest(
                    recordType = ExerciseSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        Instant.ofEpochMilli(startTimeMillis),
                        Instant.ofEpochMilli(endTimeMillis)
                    )
                )
            )
            response.records.map { session ->
                mapOf(
                    "title" to (session.title ?: "Workout"),
                    "activityType" to session.exerciseType.toString(),
                    "startTime" to session.startTime.toEpochMilli(),
                    "endTime" to session.endTime.toEpochMilli(),
                    "duration" to (session.endTime.toEpochMilli() - session.startTime.toEpochMilli()),
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "readWorkouts failed", e)
            emptyList()
        }
    }

    /// Reads sleep session records within a time range.
    ///
    /// Parameters:
    ///   - startTimeMillis: Start of range (epoch millis).
    ///   - endTimeMillis: End of range (epoch millis).
    ///
    /// Returns: List of sleep maps with keys: startTime, endTime, duration.
    suspend fun readSleep(startTimeMillis: Long, endTimeMillis: Long): List<Map<String, Any>> {
        val hcClient = client ?: return emptyList()
        return try {
            val response = hcClient.readRecords(
                ReadRecordsRequest(
                    recordType = SleepSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        Instant.ofEpochMilli(startTimeMillis),
                        Instant.ofEpochMilli(endTimeMillis)
                    )
                )
            )
            response.records.map { session ->
                mapOf(
                    "startTime" to session.startTime.toEpochMilli(),
                    "endTime" to session.endTime.toEpochMilli(),
                    "duration" to (session.endTime.toEpochMilli() - session.startTime.toEpochMilli()),
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "readSleep failed", e)
            emptyList()
        }
    }

    /// Reads the most recent body weight record.
    ///
    /// Returns: Weight in kilograms, or null if no data.
    suspend fun readWeight(): Double? {
        val hcClient = client ?: return null
        return try {
            val now = Instant.now()
            val oneYearAgo = now.minusSeconds(365L * 24 * 3600)

            val response = hcClient.readRecords(
                ReadRecordsRequest(
                    recordType = WeightRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(oneYearAgo, now)
                )
            )
            response.records.maxByOrNull { it.time }?.weight?.inKilograms
        } catch (e: Exception) {
            Log.e(TAG, "readWeight failed", e)
            null
        }
    }

    /// Reads total active calories burned for a given date (midnight to midnight).
    ///
    /// Sums all `ActiveCaloriesBurnedRecord` entries within the day window.
    ///
    /// Parameters:
    ///   - dateMillis: Milliseconds since epoch representing the target date.
    ///
    /// Returns: Total active calories burned in kcal, or null if no data.
    suspend fun readActiveCaloriesBurned(dateMillis: Long): Double? {
        val hcClient = client ?: return null
        return try {
            val date = Instant.ofEpochMilli(dateMillis)
                .atZone(ZoneId.systemDefault())
                .toLocalDate()
            val startOfDay = date.atStartOfDay(ZoneId.systemDefault()).toInstant()
            val endOfDay = date.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant()

            val response = hcClient.readRecords(
                ReadRecordsRequest(
                    recordType = ActiveCaloriesBurnedRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(startOfDay, endOfDay)
                )
            )
            val total = response.records.sumOf { it.energy.inKilocalories }
            if (total == 0.0) null else total
        } catch (e: Exception) {
            Log.e(TAG, "readActiveCaloriesBurned failed", e)
            null
        }
    }

    /// Reads total dietary energy (calories consumed) for a given date (midnight to midnight).
    ///
    /// Sums all `NutritionRecord` energy entries within the day window.
    ///
    /// Parameters:
    ///   - dateMillis: Milliseconds since epoch representing the target date.
    ///
    /// Returns: Total dietary calories in kcal, or null if no data.
    suspend fun readNutritionCalories(dateMillis: Long): Double? {
        val hcClient = client ?: return null
        return try {
            val date = Instant.ofEpochMilli(dateMillis)
                .atZone(ZoneId.systemDefault())
                .toLocalDate()
            val startOfDay = date.atStartOfDay(ZoneId.systemDefault()).toInstant()
            val endOfDay = date.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant()

            val response = hcClient.readRecords(
                ReadRecordsRequest(
                    recordType = NutritionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(startOfDay, endOfDay)
                )
            )
            // energy field is nullable on NutritionRecord; sum only non-null entries.
            val total = response.records.mapNotNull { it.energy?.inKilocalories }.sum()
            if (total == 0.0) null else total
        } catch (e: Exception) {
            Log.e(TAG, "readNutritionCalories failed", e)
            null
        }
    }

    /// Reads the most recent resting heart rate record.
    ///
    /// Health Connect receives RestingHeartRateRecord from wearables
    /// (e.g. Galaxy Watch, Pixel Watch) and compatible fitness apps.
    ///
    /// Returns: Resting HR in beats-per-minute, or null if no data.
    suspend fun readRestingHeartRate(): Double? {
        val hcClient = client ?: return null
        return try {
            val now = Instant.now()
            val thirtyDaysAgo = now.minusSeconds(30L * 24 * 3600)

            val response = hcClient.readRecords(
                ReadRecordsRequest(
                    recordType = RestingHeartRateRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(thirtyDaysAgo, now)
                )
            )
            response.records.maxByOrNull { it.time }?.beatsPerMinute?.toDouble()
        } catch (e: Exception) {
            Log.e(TAG, "readRestingHeartRate failed", e)
            null
        }
    }

    /// Reads the most recent heart rate variability (RMSSD) record.
    ///
    /// HRV RMSSD is written by wearables after overnight sleep tracking.
    ///
    /// Returns: HRV in milliseconds, or null if no data.
    suspend fun readHRV(): Double? {
        val hcClient = client ?: return null
        return try {
            val now = Instant.now()
            val thirtyDaysAgo = now.minusSeconds(30L * 24 * 3600)

            val response = hcClient.readRecords(
                ReadRecordsRequest(
                    recordType = HeartRateVariabilityRmssdRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(thirtyDaysAgo, now)
                )
            )
            response.records.maxByOrNull { it.time }?.heartRateVariabilityMillis
        } catch (e: Exception) {
            Log.e(TAG, "readHRV failed", e)
            null
        }
    }

    /// Reads the most recent VO2 max (cardio fitness) record.
    ///
    /// Vo2MaxRecord is written by wearables and fitness apps that
    /// estimate maximal oxygen uptake in mL/kg/min.
    ///
    /// Returns: VO2 max in mL/kg/min, or null if no data.
    suspend fun readCardioFitness(): Double? {
        val hcClient = client ?: return null
        return try {
            val now = Instant.now()
            val ninetyDaysAgo = now.minusSeconds(90L * 24 * 3600)

            val response = hcClient.readRecords(
                ReadRecordsRequest(
                    recordType = Vo2MaxRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(ninetyDaysAgo, now)
                )
            )
            response.records.maxByOrNull { it.time }?.vo2MillilitersPerMinuteKilogram
        } catch (e: Exception) {
            Log.e(TAG, "readCardioFitness failed", e)
            null
        }
    }

    // ------------------------------------------------------------------
    // Write Methods
    // ------------------------------------------------------------------

    /// Writes a workout (exercise session) record to Health Connect.
    ///
    /// Parameters:
    ///   - activityType: Human-readable type (e.g., "running").
    ///   - startTimeMillis: Start time (epoch millis).
    ///   - endTimeMillis: End time (epoch millis).
    ///   - energyBurned: Calories burned (kcal).
    ///
    /// Returns: true on success, false on failure.
    suspend fun writeWorkout(
        activityType: String,
        startTimeMillis: Long,
        endTimeMillis: Long,
        energyBurned: Double
    ): Boolean {
        val hcClient = client ?: return false
        return try {
            val exerciseType = mapActivityType(activityType)
            val record = ExerciseSessionRecord(
                startTime = Instant.ofEpochMilli(startTimeMillis),
                startZoneOffset = null,
                endTime = Instant.ofEpochMilli(endTimeMillis),
                endZoneOffset = null,
                exerciseType = exerciseType,
                title = activityType.replaceFirstChar { it.uppercase() },
                metadata = Metadata.manualEntry()
            )
            hcClient.insertRecords(listOf(record))
            true
        } catch (e: Exception) {
            Log.e(TAG, "writeWorkout failed", e)
            false
        }
    }

    /// Writes a nutrition (calorie) record to Health Connect.
    ///
    /// Parameters:
    ///   - calories: Kilocalories consumed.
    ///   - dateMillis: Date of the meal (epoch millis).
    ///
    /// Returns: true on success, false on failure.
    suspend fun writeNutrition(calories: Double, dateMillis: Long): Boolean {
        val hcClient = client ?: return false
        return try {
            val instant = Instant.ofEpochMilli(dateMillis)
            val record = NutritionRecord(
                startTime = instant,
                startZoneOffset = null,
                endTime = instant.plusSeconds(1),
                endZoneOffset = null,
                energy = Energy.kilocalories(calories), // kcal -> kcal
                metadata = Metadata.manualEntry()
            )
            hcClient.insertRecords(listOf(record))
            true
        } catch (e: Exception) {
            Log.e(TAG, "writeNutrition failed", e)
            false
        }
    }

    /// Writes a body weight record to Health Connect.
    ///
    /// Parameters:
    ///   - weightKg: Weight in kilograms.
    ///   - dateMillis: Date of the measurement (epoch millis).
    ///
    /// Returns: true on success, false on failure.
    suspend fun writeWeight(weightKg: Double, dateMillis: Long): Boolean {
        val hcClient = client ?: return false
        return try {
            val record = WeightRecord(
                time = Instant.ofEpochMilli(dateMillis),
                zoneOffset = null,
                weight = Mass.kilograms(weightKg),
                metadata = Metadata.manualEntry()
            )
            hcClient.insertRecords(listOf(record))
            true
        } catch (e: Exception) {
            Log.e(TAG, "writeWeight failed", e)
            false
        }
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    /// Maps a human-readable activity type string to the Health Connect
    /// `ExerciseSessionRecord.EXERCISE_TYPE_*` constant.
    private fun mapActivityType(type: String): Int {
        return when (type.lowercase()) {
            "running" -> ExerciseSessionRecord.EXERCISE_TYPE_RUNNING
            "cycling" -> ExerciseSessionRecord.EXERCISE_TYPE_BIKING
            "walking" -> ExerciseSessionRecord.EXERCISE_TYPE_WALKING
            "swimming" -> ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL
            "hiking" -> ExerciseSessionRecord.EXERCISE_TYPE_HIKING
            "yoga" -> ExerciseSessionRecord.EXERCISE_TYPE_YOGA
            "strength" -> ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING
            else -> ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT
        }
    }
}

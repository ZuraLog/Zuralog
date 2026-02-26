/// Zuralog Android — WorkManager worker for periodic Health Connect sync.
///
/// Scheduled every 15 minutes (WorkManager minimum interval) when
/// the device has network connectivity and battery is not low.
///
/// **Full implementation:**
/// Reads all 16 Health Connect data types and POSTs the aggregated
/// payload to POST /api/v1/health/ingest on the Cloud Brain.
///
/// Credentials (userId + apiToken) are stored in EncryptedSharedPreferences
/// via [storeCredentials] and read securely here before each sync run.
package com.zuralog.zuralog

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.time.ZoneId
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

/// Periodic background worker that syncs all Health Connect data types
/// to the Zuralog Cloud Brain via POST /api/v1/health/ingest.
class HealthSyncWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "HealthSyncWorker"
        private const val WORK_NAME = "zuralog_health_sync"

        /// EncryptedSharedPreferences file name (never plain-text).
        private const val PREFS_FILE = "zuralog_sync_credentials"

        /// Keys within the encrypted prefs file.
        private const val KEY_API_TOKEN = "api_token"

        /// Cloud Brain ingest endpoint.  Matches the iOS Swift constant.
        private const val INGEST_URL = "https://api.zuralog.com/api/v1/health/ingest"

        // ------------------------------------------------------------------
        // Scheduling
        // ------------------------------------------------------------------

        /// Schedules the periodic sync worker.
        ///
        /// Parameters:
        ///   - context: Application or Activity context.
        ///
        /// The worker runs every 15 minutes (minimum interval) with
        /// constraints: network connected + battery not low.
        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(true)
                .build()

            val request = PeriodicWorkRequestBuilder<HealthSyncWorker>(
                15, TimeUnit.MINUTES,
            )
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request,
            )

            Log.i(TAG, "Health sync worker scheduled (15 min interval)")
        }

        // ------------------------------------------------------------------
        // Credential storage
        // ------------------------------------------------------------------

        /// Persists the JWT api token in EncryptedSharedPreferences.
        ///
        /// Called from [MainActivity.configureBackgroundSync] immediately
        /// after the user grants Health Connect permissions.
        ///
        /// The server extracts user_id from the JWT, so we only need to
        /// store the token itself.
        ///
        /// Parameters:
        ///   - context:  Application or Activity context.
        ///   - apiToken: The user's JWT bearer token for POST /health/ingest.
        fun storeCredentials(context: Context, apiToken: String) {
            val prefs = buildEncryptedPrefs(context)
            prefs.edit()
                .putString(KEY_API_TOKEN, apiToken)
                .apply()
        }

        /// Returns the EncryptedSharedPreferences instance.
        ///
        /// Uses AES256_SIV for key encryption and AES256_GCM for values,
        /// with a master key backed by the Android Keystore.
        private fun buildEncryptedPrefs(context: Context): android.content.SharedPreferences {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            return EncryptedSharedPreferences.create(
                context,
                PREFS_FILE,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        }
    }

    // ------------------------------------------------------------------
    // Worker entry point
    // ------------------------------------------------------------------

    /// Executes the background sync task.
    ///
    /// Returns:
    ///   - Result.success() if sync completed (even with no data).
    ///   - Result.retry()   if a transient error occurred (network, HC unavailable).
    ///   - Result.failure() if Health Connect is not installed or credentials missing.
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        Log.i(TAG, "HealthSyncWorker starting...")

        // 1. Guard: Health Connect must be available.
        val sdkStatus = HealthConnectClient.getSdkStatus(applicationContext)
        if (sdkStatus != HealthConnectClient.SDK_AVAILABLE) {
            Log.w(TAG, "Health Connect not available (status=$sdkStatus) — skipping sync")
            return@withContext Result.failure()
        }

        // 2. Load credentials from EncryptedSharedPreferences.
        val prefs = buildEncryptedPrefs(applicationContext)
        val apiToken = prefs.getString(KEY_API_TOKEN, null)

        if (apiToken.isNullOrBlank()) {
            Log.w(TAG, "No credentials stored — Health Connect not yet connected. Skipping.")
            return@withContext Result.failure()
        }

        return@withContext try {
            val bridge = HealthConnectBridge(applicationContext)
            val payload = buildPayload(bridge)

            // POST to Cloud Brain.
            val httpStatus = postPayload(payload, apiToken)

            if (httpStatus in 200..299) {
                Log.i(TAG, "HealthSyncWorker: ingest succeeded (HTTP $httpStatus)")
                // Update last-sync timestamp for Flutter UI.
                applicationContext
                    .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    .edit()
                    .putLong("flutter.last_sync_timestamp", System.currentTimeMillis())
                    .putBoolean("flutter.sync_in_progress", false)
                    .apply()
                Result.success()
            } else {
                Log.w(TAG, "HealthSyncWorker: ingest returned HTTP $httpStatus — will retry")
                Result.retry()
            }
        } catch (e: Exception) {
            Log.e(TAG, "HealthSyncWorker failed", e)
            Result.retry()
        }
    }

    // ------------------------------------------------------------------
    // Payload builder
    // ------------------------------------------------------------------

    /// Reads all supported Health Connect data types and assembles
    /// the JSON payload expected by POST /api/v1/health/ingest.
    ///
    /// The server extracts user_id from the JWT bearer token in the
    /// Authorization header, so user_id is not included in the body.
    ///
    /// Parameters:
    ///   - bridge: Initialised [HealthConnectBridge] for data access.
    ///
    /// Returns: Populated [JSONObject] ready for serialisation.
    private suspend fun buildPayload(bridge: HealthConnectBridge): JSONObject {
        val now = Instant.now()
        val todayMillis = now.atZone(ZoneId.systemDefault())
            .toLocalDate()
            .atStartOfDay(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()

        // Date range for ranged queries: last 7 days.
        val sevenDaysAgo = now.minusSeconds(7L * 24 * 3600).toEpochMilli()

        // -- Scalar daily metrics --
        val steps = bridge.readSteps(todayMillis)
        val calories = bridge.readActiveCaloriesBurned(todayMillis)
        val nutritionKcal = bridge.readNutritionCalories(todayMillis)
        val restingHr = bridge.readRestingHeartRate()
        val hrv = bridge.readHRV()
        val vo2Max = bridge.readCardioFitness()
        val weight = bridge.readWeight()
        val distance = bridge.readDistance(todayMillis)
        val floors = bridge.readFloors(todayMillis)
        val bodyFat = bridge.readBodyFat()
        val respiratoryRate = bridge.readRespiratoryRate()
        val oxygenSaturation = bridge.readOxygenSaturation()
        val heartRateAvg = bridge.readHeartRate(todayMillis)
        val bloodPressure = bridge.readBloodPressure()

        // -- Ranged list metrics --
        val workouts = bridge.readWorkouts(sevenDaysAgo, now.toEpochMilli())
        val sleep = bridge.readSleep(sevenDaysAgo, now.toEpochMilli())

        // Assemble top-level payload.
        // Note: user_id is intentionally omitted — the ingest endpoint
        // extracts it from the JWT bearer token in the Authorization header.
        val payload = JSONObject().apply {
            put("source", "health_connect")
            put("timestamp", now.toString())

            // Daily metrics object.
            val daily = JSONObject().apply {
                put("date", java.time.LocalDate.now().toString())
                put("steps", steps)
                calories?.let { put("active_calories", it) }
                nutritionKcal?.let { put("nutrition_calories", it) }
                restingHr?.let { put("resting_heart_rate", it) }
                hrv?.let { put("hrv_ms", it) }
                vo2Max?.let { put("vo2_max", it) }
                weight?.let { put("weight_kg", it) }
                distance?.let { put("distance_meters", it) }
                floors?.let { put("flights_climbed", it) }
                bodyFat?.let { put("body_fat_percentage", it) }
                respiratoryRate?.let { put("respiratory_rate", it) }
                oxygenSaturation?.let { put("oxygen_saturation", it) }
                heartRateAvg?.let { put("heart_rate_avg", it) }
                bloodPressure?.let { bp ->
                    put("blood_pressure_systolic", bp["systolic"])
                    put("blood_pressure_diastolic", bp["diastolic"])
                }
            }
            put("daily_metrics", daily)

            // Workouts array.
            val workoutsArr = JSONArray()
            workouts.forEach { w ->
                workoutsArr.put(JSONObject(w))
            }
            put("workouts", workoutsArr)

            // Sleep array.
            val sleepArr = JSONArray()
            sleep.forEach { s ->
                sleepArr.put(JSONObject(s))
            }
            put("sleep", sleepArr)
        }

        return payload
    }

    // ------------------------------------------------------------------
    // HTTP transport
    // ------------------------------------------------------------------

    /// Posts the assembled payload to the Cloud Brain ingest endpoint.
    ///
    /// Uses java.net.HttpURLConnection (no external HTTP library needed).
    ///
    /// Parameters:
    ///   - payload:  The JSON body to send.
    ///   - apiToken: Bearer token for Authorization header.
    ///
    /// Returns: HTTP response status code (e.g. 200, 400, 500).
    ///
    /// Throws: IOException on network failure.
    private fun postPayload(payload: JSONObject, apiToken: String): Int {
        val url = URL(INGEST_URL)
        val conn = url.openConnection() as HttpURLConnection
        return try {
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $apiToken")
            conn.doOutput = true
            conn.connectTimeout = 15_000
            conn.readTimeout = 15_000

            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(payload.toString())
                writer.flush()
            }

            conn.responseCode
        } finally {
            conn.disconnect()
        }
    }
}

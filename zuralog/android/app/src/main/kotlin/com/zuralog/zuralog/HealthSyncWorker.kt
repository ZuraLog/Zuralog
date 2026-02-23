/// Zuralog Android — WorkManager worker for periodic Health Connect sync.
///
/// Scheduled every 15 minutes (WorkManager minimum interval) when
/// the device has network connectivity and battery is not low.
///
/// **MVP scope:** Reads recent steps from Health Connect and logs
/// the result to Android logcat. Full sync to Cloud Brain API
/// is deferred to Phase 1.10 (Background Services).
package com.zuralog.zuralog

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.time.Instant
import java.time.ZoneId
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/// Periodic background worker that syncs Health Connect data.
///
/// In the MVP, this just reads recent steps and logs them.
/// Phase 1.10 will add:
/// - HTTP client to push data to Cloud Brain.
/// - FlutterBackgroundExecutor for headless Dart execution.
/// - Delta sync (only new records since last sync).
class HealthSyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "HealthSyncWorker"
        private const val WORK_NAME = "zuralog_health_sync"

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
                15, TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request
            )

            Log.i(TAG, "Health sync worker scheduled (15min interval)")
        }
    }

    /// Executes the background sync task.
    ///
    /// Returns:
    ///   - Result.success() if sync completed (even with no data).
    ///   - Result.retry() if Health Connect is temporarily unavailable.
    ///   - Result.failure() if Health Connect is not installed.
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        Log.i(TAG, "HealthSyncWorker starting...")

        // Check if Health Connect is available.
        val sdkStatus = HealthConnectClient.getSdkStatus(applicationContext)
        if (sdkStatus != HealthConnectClient.SDK_AVAILABLE) {
            Log.w(TAG, "Health Connect not available (status=$sdkStatus)")
            return@withContext Result.failure()
        }

        try {
            val bridge = HealthConnectBridge(applicationContext)

            // Read today's step count as a proof-of-life metric.
            val now = Instant.now()
            val todayStart = now.atZone(ZoneId.systemDefault())
                .toLocalDate()
                .atStartOfDay(ZoneId.systemDefault())
                .toInstant()

            val steps = bridge.readSteps(todayStart.toEpochMilli())
            Log.i(TAG, "Background sync: today's steps = $steps")

            // TODO(Phase 1.10): Send data to Cloud Brain API.
            // val apiClient = HttpClient(...)
            // apiClient.post("/api/v1/health/sync", body = ...)

            // Save last-sync timestamp for Flutter's SyncStatusStore.
            // Flutter shared_preferences uses "FlutterSharedPreferences" with
            // a "flutter." key prefix on Android.
            val prefs = applicationContext.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE,
            )
            prefs.edit()
                .putLong("flutter.last_sync_timestamp", System.currentTimeMillis())
                .putBoolean("flutter.sync_in_progress", false)
                .apply()

            return@withContext Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "HealthSyncWorker failed", e)
            return@withContext Result.retry()
        }
    }
}

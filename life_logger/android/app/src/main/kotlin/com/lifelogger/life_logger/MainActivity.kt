/// Life Logger Android — MainActivity with Health Connect platform channel.
///
/// Routes Flutter `MethodChannel("com.lifelogger/health")` calls to the
/// native `HealthConnectBridge`. Uses `lifecycleScope` with
/// `Dispatchers.IO` for all suspend bridge calls to avoid blocking
/// the UI thread.
///
/// The method names match the iOS AppDelegate handler exactly so that
/// `HealthBridge.dart` works identically on both platforms.
package com.lifelogger.life_logger

import android.os.Bundle
import android.util.Log
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/// Main activity that bootstraps the Flutter engine and sets up the
/// Health Connect method channel.
class MainActivity : FlutterFragmentActivity() {

    companion object {
        /// Channel name shared with `HealthBridge.dart`.
        private const val HEALTH_CHANNEL = "com.lifelogger/health"
        private const val TAG = "MainActivity"
    }

    private lateinit var healthConnectBridge: HealthConnectBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        healthConnectBridge = HealthConnectBridge(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HEALTH_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    result.success(healthConnectBridge.isAvailable())
                }

                "requestAuthorization" -> {
                    // Health Connect permissions are requested via an ActivityResult
                    // contract. For MVP, we check if permissions are already granted.
                    // Full interactive permission request uses registerForActivityResult
                    // which requires the Dart side to handle the deferred response.
                    lifecycleScope.launch {
                        try {
                            val hasAll = withContext(Dispatchers.IO) {
                                healthConnectBridge.hasAllPermissions()
                            }
                            result.success(hasAll)
                        } catch (e: Exception) {
                            Log.e(TAG, "requestAuthorization failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getSteps" -> {
                    val dateMillis = call.argument<Long>("date")
                        ?: call.argument<Number>("date")?.toLong()
                        ?: System.currentTimeMillis()

                    lifecycleScope.launch {
                        try {
                            val steps = withContext(Dispatchers.IO) {
                                healthConnectBridge.readSteps(dateMillis)
                            }
                            result.success(steps.toDouble())
                        } catch (e: Exception) {
                            Log.e(TAG, "getSteps failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getWorkouts" -> {
                    val startDate = call.argument<Long>("startDate")
                        ?: call.argument<Number>("startDate")?.toLong()
                        ?: 0L
                    val endDate = call.argument<Long>("endDate")
                        ?: call.argument<Number>("endDate")?.toLong()
                        ?: System.currentTimeMillis()

                    lifecycleScope.launch {
                        try {
                            val workouts = withContext(Dispatchers.IO) {
                                healthConnectBridge.readWorkouts(startDate, endDate)
                            }
                            result.success(workouts)
                        } catch (e: Exception) {
                            Log.e(TAG, "getWorkouts failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getSleep" -> {
                    val startDate = call.argument<Long>("startDate")
                        ?: call.argument<Number>("startDate")?.toLong()
                        ?: 0L
                    val endDate = call.argument<Long>("endDate")
                        ?: call.argument<Number>("endDate")?.toLong()
                        ?: System.currentTimeMillis()

                    lifecycleScope.launch {
                        try {
                            val sleep = withContext(Dispatchers.IO) {
                                healthConnectBridge.readSleep(startDate, endDate)
                            }
                            result.success(sleep)
                        } catch (e: Exception) {
                            Log.e(TAG, "getSleep failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getWeight" -> {
                    lifecycleScope.launch {
                        try {
                            val weight = withContext(Dispatchers.IO) {
                                healthConnectBridge.readWeight()
                            }
                            result.success(weight)
                        } catch (e: Exception) {
                            Log.e(TAG, "getWeight failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "writeWorkout" -> {
                    val activityType = call.argument<String>("activityType") ?: "other"
                    val startDate = call.argument<Long>("startDate")
                        ?: call.argument<Number>("startDate")?.toLong()
                        ?: 0L
                    val endDate = call.argument<Long>("endDate")
                        ?: call.argument<Number>("endDate")?.toLong()
                        ?: System.currentTimeMillis()
                    val energyBurned = call.argument<Double>("energyBurned")
                        ?: call.argument<Number>("energyBurned")?.toDouble()
                        ?: 0.0

                    lifecycleScope.launch {
                        try {
                            val ok = withContext(Dispatchers.IO) {
                                healthConnectBridge.writeWorkout(
                                    activityType, startDate, endDate, energyBurned
                                )
                            }
                            result.success(ok)
                        } catch (e: Exception) {
                            Log.e(TAG, "writeWorkout failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "writeNutrition" -> {
                    val calories = call.argument<Double>("calories")
                        ?: call.argument<Number>("calories")?.toDouble()
                        ?: 0.0
                    val dateMillis = call.argument<Long>("date")
                        ?: call.argument<Number>("date")?.toLong()
                        ?: System.currentTimeMillis()

                    lifecycleScope.launch {
                        try {
                            val ok = withContext(Dispatchers.IO) {
                                healthConnectBridge.writeNutrition(calories, dateMillis)
                            }
                            result.success(ok)
                        } catch (e: Exception) {
                            Log.e(TAG, "writeNutrition failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "writeWeight" -> {
                    val weightKg = call.argument<Double>("weightKg")
                        ?: call.argument<Number>("weightKg")?.toDouble()
                        ?: 0.0
                    val dateMillis = call.argument<Long>("date")
                        ?: call.argument<Number>("date")?.toLong()
                        ?: System.currentTimeMillis()

                    lifecycleScope.launch {
                        try {
                            val ok = withContext(Dispatchers.IO) {
                                healthConnectBridge.writeWeight(weightKg, dateMillis)
                            }
                            result.success(ok)
                        } catch (e: Exception) {
                            Log.e(TAG, "writeWeight failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "startBackgroundObservers" -> {
                    // On Android, background sync is handled by WorkManager
                    // (Phase 1.5.5), not observer queries like iOS.
                    // Schedule the worker and return true.
                    try {
                        HealthSyncWorker.schedule(this@MainActivity)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "startBackgroundObservers failed", e)
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}

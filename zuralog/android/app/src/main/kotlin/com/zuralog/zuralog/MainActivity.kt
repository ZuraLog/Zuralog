/// Zuralog Android — MainActivity with Health Connect platform channel.
///
/// Routes Flutter `MethodChannel("com.zuralog/health")` calls to the
/// native `HealthConnectBridge`. Uses `lifecycleScope` with
/// `Dispatchers.IO` for all suspend bridge calls to avoid blocking
/// the UI thread.
///
/// The method names match the iOS AppDelegate handler exactly so that
/// `HealthBridge.dart` works identically on both platforms.
package com.zuralog.zuralog

import android.os.Bundle
import android.util.Log
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.PermissionController
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
        private const val HEALTH_CHANNEL = "com.zuralog/health"
        private const val TAG = "MainActivity"
    }

    private lateinit var healthConnectBridge: HealthConnectBridge
    private var pendingPermissionResult: MethodChannel.Result? = null
    private lateinit var requestPermissions: ActivityResultLauncher<Set<String>>

    /// Initialises the Activity and registers the Health Connect permission launcher.
    ///
    /// The [ActivityResultLauncher] for Health Connect permissions MUST be registered
    /// here, before [super.onCreate], to satisfy Android's lifecycle contract.
    /// Registering it inside [configureFlutterEngine] or a method channel handler
    /// causes an [IllegalStateException] because the Fragment registry is already locked.
    ///
    /// - Parameters:
    ///   - savedInstanceState: Bundle from the previous instance, or null on first launch.
    override fun onCreate(savedInstanceState: Bundle?) {
        // Register the ActivityResult launcher BEFORE super.onCreate().
        // Health Connect permission requests require this to be registered
        // during the activity creation lifecycle, not inside configureFlutterEngine.
        requestPermissions = registerForActivityResult(
            PermissionController.createRequestPermissionResultContract()
        ) { granted ->
            // Callback fires on the main thread when the Health Connect dialog closes
            // (whether the user grants, denies, or presses back).
            // - [granted]: the set of permissions the system actually granted (may be empty).
            // - [pendingPermissionResult] is captured atomically into [pending] and cleared
            //   to prevent a second callback from replying to a stale result.
            val pending = pendingPermissionResult
            pendingPermissionResult = null
            // Consider it a successful grant if the user granted at least the
            // core read permissions. containsAll() is too strict — HC may not
            // surface every write permission in the dialog depending on device
            // and HC version, causing containsAll() to return false even when
            // the user tapped "Allow all".
            val coreReadPermissions = HealthConnectBridge.CORE_READ_PERMISSIONS
            val success = granted.containsAll(coreReadPermissions)
            pending?.success(success)
        }
        super.onCreate(savedInstanceState)
    }

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

                "checkPermissions" -> {
                    // Passive permission check — no UI shown. Returns false on any failure
                    // so the Dart caller always receives a Bool (never an exception).
                    lifecycleScope.launch {
                        try {
                            val hasAll = withContext(Dispatchers.IO) {
                                healthConnectBridge.hasAllPermissions()
                            }
                            result.success(hasAll)
                        } catch (e: Exception) {
                            Log.e(TAG, "checkPermissions failed", e)
                            // Intentionally returns success(false) rather than result.error(...)
                            // so the Flutter caller receives a Bool in all cases (simpler API contract).
                            result.success(false)
                        }
                    }
                }

                "requestAuthorization" -> {
                    // Guard: reject concurrent permission requests to prevent result leaking.
                    if (pendingPermissionResult != null) {
                        result.error(
                            "ALREADY_PENDING",
                            "A Health Connect permission request is already in progress.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    // Requests Health Connect permissions interactively.
                    // 1. Check if all required permissions are already granted (fast path).
                    // 2. If granted → reply true immediately.
                    // 3. If not → store [result] as [pendingPermissionResult] and launch the
                    //    Health Connect permission dialog. The ActivityResultLauncher callback
                    //    (registered in [onCreate]) will reply when the dialog closes.
                    // Exceptions clear [pendingPermissionResult] to avoid dangling result references.
                    lifecycleScope.launch {
                        try {
                            val hasAll = withContext(Dispatchers.IO) {
                                healthConnectBridge.hasAllPermissions()
                            }
                            if (hasAll) {
                                // All permissions already granted — return immediately.
                                result.success(true)
                            } else {
                                // Permissions not yet granted: launch the Health Connect
                                // system permission dialog. The result will be delivered
                                // to the ActivityResultLauncher callback registered in onCreate,
                                // which will call pending?.success(allGranted).
                                pendingPermissionResult = result
                                requestPermissions.launch(HealthConnectBridge.REQUIRED_PERMISSIONS)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "requestAuthorization failed", e)
                            // Clear pending result to avoid a dangling reference.
                            pendingPermissionResult = null
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

                "getCaloriesBurned" -> {
                    val dateMillis = call.argument<Long>("date")
                        ?: call.argument<Number>("date")?.toLong()
                        ?: System.currentTimeMillis()

                    lifecycleScope.launch {
                        try {
                            val kcal = withContext(Dispatchers.IO) {
                                healthConnectBridge.readActiveCaloriesBurned(dateMillis)
                            }
                            result.success(kcal)
                        } catch (e: Exception) {
                            Log.e(TAG, "getCaloriesBurned failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getNutrition" -> {
                    val dateMillis = call.argument<Long>("date")
                        ?: call.argument<Number>("date")?.toLong()
                        ?: System.currentTimeMillis()

                    lifecycleScope.launch {
                        try {
                            val kcal = withContext(Dispatchers.IO) {
                                healthConnectBridge.readNutritionCalories(dateMillis)
                            }
                            result.success(kcal)
                        } catch (e: Exception) {
                            Log.e(TAG, "getNutrition failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getRestingHeartRate" -> {
                    lifecycleScope.launch {
                        try {
                            val bpm = withContext(Dispatchers.IO) {
                                healthConnectBridge.readRestingHeartRate()
                            }
                            result.success(bpm)
                        } catch (e: Exception) {
                            Log.e(TAG, "getRestingHeartRate failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getHRV" -> {
                    lifecycleScope.launch {
                        try {
                            val ms = withContext(Dispatchers.IO) {
                                healthConnectBridge.readHRV()
                            }
                            result.success(ms)
                        } catch (e: Exception) {
                            Log.e(TAG, "getHRV failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getCardioFitness" -> {
                    lifecycleScope.launch {
                        try {
                            val vo2 = withContext(Dispatchers.IO) {
                                healthConnectBridge.readCardioFitness()
                            }
                            result.success(vo2)
                        } catch (e: Exception) {
                            Log.e(TAG, "getCardioFitness failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getDistance" -> {
                    val dateMillis = call.argument<Long>("date")
                        ?: call.argument<Number>("date")?.toLong()
                        ?: System.currentTimeMillis()

                    lifecycleScope.launch {
                        try {
                            val meters = withContext(Dispatchers.IO) {
                                healthConnectBridge.readDistance(dateMillis)
                            }
                            result.success(meters)
                        } catch (e: Exception) {
                            Log.e(TAG, "getDistance failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getFloors" -> {
                    val dateMillis = call.argument<Long>("date")
                        ?: call.argument<Number>("date")?.toLong()
                        ?: System.currentTimeMillis()

                    lifecycleScope.launch {
                        try {
                            val floors = withContext(Dispatchers.IO) {
                                healthConnectBridge.readFloors(dateMillis)
                            }
                            result.success(floors)
                        } catch (e: Exception) {
                            Log.e(TAG, "getFloors failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getBodyFat" -> {
                    lifecycleScope.launch {
                        try {
                            val pct = withContext(Dispatchers.IO) {
                                healthConnectBridge.readBodyFat()
                            }
                            result.success(pct)
                        } catch (e: Exception) {
                            Log.e(TAG, "getBodyFat failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getRespiratoryRate" -> {
                    lifecycleScope.launch {
                        try {
                            val rate = withContext(Dispatchers.IO) {
                                healthConnectBridge.readRespiratoryRate()
                            }
                            result.success(rate)
                        } catch (e: Exception) {
                            Log.e(TAG, "getRespiratoryRate failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getOxygenSaturation" -> {
                    lifecycleScope.launch {
                        try {
                            val pct = withContext(Dispatchers.IO) {
                                healthConnectBridge.readOxygenSaturation()
                            }
                            result.success(pct)
                        } catch (e: Exception) {
                            Log.e(TAG, "getOxygenSaturation failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getHeartRate" -> {
                    val dateMillis = call.argument<Long>("date")
                        ?: call.argument<Number>("date")?.toLong()
                        ?: System.currentTimeMillis()

                    lifecycleScope.launch {
                        try {
                            val bpm = withContext(Dispatchers.IO) {
                                healthConnectBridge.readHeartRate(dateMillis)
                            }
                            result.success(bpm)
                        } catch (e: Exception) {
                            Log.e(TAG, "getHeartRate failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "getBloodPressure" -> {
                    lifecycleScope.launch {
                        try {
                            val bp = withContext(Dispatchers.IO) {
                                healthConnectBridge.readBloodPressure()
                            }
                            result.success(bp)
                        } catch (e: Exception) {
                            Log.e(TAG, "getBloodPressure failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                "configureBackgroundSync" -> {
                    // Called after the user grants Health Connect permissions in the
                    // connect flow. Stores the Cloud Brain credentials in
                    // EncryptedSharedPreferences so HealthSyncWorker can reach the
                    // correct server in the background, then schedules the periodic
                    // WorkManager task.
                    //
                    // Keys match what HealthBridge.dart sends via invokeMethod:
                    //   auth_token    — the user's JWT bearer token
                    //   api_base_url  — the Cloud Brain base URL (e.g. http://192.168.1.5:8001
                    //                   for local dev, https://api.zuralog.com for production).
                    //                   Stored and used by HealthSyncWorker to build the
                    //                   full ingest URL dynamically — not hardcoded.
                    val apiToken = call.argument<String>("auth_token") ?: ""
                    val apiBaseUrl = call.argument<String>("api_base_url") ?: ""

                    try {
                        // Persist both JWT token and base URL for HealthSyncWorker.
                        HealthSyncWorker.storeCredentials(
                            context = this@MainActivity,
                            apiToken = apiToken,
                            apiBaseUrl = apiBaseUrl,
                        )
                        // Schedule the periodic background worker.
                        HealthSyncWorker.schedule(this@MainActivity)
                        Log.i(TAG, "configureBackgroundSync: credentials stored + worker scheduled (baseUrl=$apiBaseUrl)")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "configureBackgroundSync failed", e)
                        result.error("HEALTH_CONNECT_ERROR", e.message, null)
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

                "backgroundWrite" -> {
                    // Handles FCM-initiated write commands dispatched by the Cloud Brain
                    // AI agent (via DeviceWriteService → FCM → FCMService.dart).
                    //
                    // Matches the iOS AppDelegate contract exactly:
                    //   data_type — "nutrition" | "workout" | "weight"  (snake_case)
                    //   value     — JSON string encoding the write payload
                    //               e.g. '{"calories":500,"date":"2026-02-27T..."}'
                    val dataType = call.argument<String>("data_type") ?: ""
                    val valueJson = call.argument<String>("value") ?: "{}"

                    // Parse the JSON value string into a key→Any map.
                    val valueMap: Map<String, Any?> = try {
                        val jsonObj = org.json.JSONObject(valueJson)
                        jsonObj.keys().asSequence().associateWith { jsonObj.get(it) }
                    } catch (e: Exception) {
                        Log.w(TAG, "backgroundWrite: could not parse value JSON: $valueJson")
                        emptyMap()
                    }

                    val dateMillis = try {
                        val dateStr = valueMap["date"] as? String ?: ""
                        java.time.Instant.parse(dateStr).toEpochMilli()
                    } catch (e: Exception) {
                        System.currentTimeMillis()
                    }

                    lifecycleScope.launch {
                        try {
                            val ok = withContext(Dispatchers.IO) {
                                when (dataType) {
                                    "nutrition" -> {
                                        val calories = (valueMap["calories"] as? Number)?.toDouble() ?: 0.0
                                        healthConnectBridge.writeNutrition(calories, dateMillis)
                                    }
                                    "weight" -> {
                                        val weightKg = (valueMap["weight_kg"] as? Number)?.toDouble() ?: 0.0
                                        healthConnectBridge.writeWeight(weightKg, dateMillis)
                                    }
                                    "workout" -> {
                                        val calories = (valueMap["calories"] as? Number)?.toDouble() ?: 0.0
                                        val activityType = valueMap["activity_type"] as? String ?: "other"
                                        val durationSeconds = (valueMap["duration_seconds"] as? Number)?.toLong() ?: 1800L
                                        healthConnectBridge.writeWorkout(
                                            activityType = activityType,
                                            startTimeMillis = dateMillis,
                                            endTimeMillis = dateMillis + durationSeconds * 1000L,
                                            energyBurned = calories,
                                        )
                                    }
                                    else -> {
                                        Log.w(TAG, "backgroundWrite: unsupported data_type=$dataType")
                                        false
                                    }
                                }
                            }
                            result.success(ok)
                        } catch (e: Exception) {
                            Log.e(TAG, "backgroundWrite failed", e)
                            result.error("HEALTH_CONNECT_ERROR", e.message, null)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}

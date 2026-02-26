# Google Health Connect Integration — Execution Record

**Branch:** `feat/google-health-connect-full-integration`
**Status:** Complete — merged to `main`
**Last updated:** 2026-02-27

---

## What Was Built

### Full Google Health Connect Integration (Phases 1–9)

The goal was to graduate Health Connect from a partial stub (3 data types, no real
sync, MCP server returning `pending_device_sync`) to a production-quality integration
that reads **17 health data types** on Android, syncs them to the Cloud Brain via
WorkManager, and allows the AI agent to both read and write Health Connect data.

---

## Architecture

```
Android Edge Agent              Cloud Brain               AI Agent
─────────────────               ───────────               ────────
HealthConnectBridge.kt  ──→  POST /health/ingest  ──→  PostgreSQL
HealthSyncWorker.kt             (JWT auth)          ──→  HealthConnectServer MCP
  (WorkManager periodic)                            ──→  health_connect_read_metrics

Orchestrator  ──→  health_connect_write_entry  ──→  DeviceWriteService
                                                 ──→  FCM push to Android
                                                 ──→  backgroundWrite channel handler
                                                 ──→  HealthConnectBridge.write*
```

---

## Completed Work

### Phase 1 — `HealthDataServerBase` extracted

**New file:** `cloud-brain/app/mcp_servers/health_data_server_base.py`

~550-line shared abstract base class containing all shared DB query logic across
both Apple Health and Health Connect MCP servers. Eliminates ~400 lines of
duplication that previously existed between the two server implementations.

Key design: 6 abstract properties (`name`, `description`, `source_name`, `platform`,
`_read_tool_name`, `_write_tool_name`) distinguish the two concrete subclasses.
All DB logic — 16 data type query handlers + FCM write dispatch — lives here.

### Phase 2 — `AppleHealthServer` refactored + `HealthConnectServer` rewritten

**Rewritten:** `cloud-brain/app/mcp_servers/apple_health_server.py`
- Was 600+ lines of duplicated logic; now ~70-line thin subclass

**Rewritten:** `cloud-brain/app/mcp_servers/health_connect_server.py`
- Was 180-line stub returning `pending_device_sync` for every call
- Now ~75-line real implementation backed by `HealthDataServerBase`

**Fixed:** `cloud-brain/app/main.py`
- `HealthConnectServer()` now wired with `db_factory=async_session` and
  `device_write_service=device_write_svc` (was constructed with no arguments)

### Phase 3 — `HealthConnectBridge.kt` extended (7 new read methods)

**Modified:** `zuralog/android/app/src/main/kotlin/com/zuralog/zuralog/HealthConnectBridge.kt`

Added imports and 7 new suspend read methods:
- `readDistance` → `DistanceRecord`
- `readFloors` → `FloorsClimbedRecord`
- `readBodyFat` → `BodyFatRecord`
- `readRespiratoryRate` → `RespiratoryRateRecord`
- `readOxygenSaturation` → `OxygenSaturationRecord`
- `readHeartRate` → `HeartRateRecord` (time-series, returns avg/min/max)
- `readBloodPressure` → `BloodPressureRecord` (returns systolic/diastolic avg)

All 7 new permissions added to `REQUIRED_PERMISSIONS`.

### Phase 4 — `MainActivity.kt` extended (9 new channel handlers)

**Modified:** `zuralog/android/app/src/main/kotlin/com/zuralog/zuralog/MainActivity.kt`

9 new `MethodChannel` handlers added:
- `getDistance`, `getFloors`, `getBodyFat`, `getRespiratoryRate`,
  `getOxygenSaturation`, `getHeartRate`, `getBloodPressure`
- `configureBackgroundSync` — receives `auth_token` + `api_base_url` from Dart,
  stores credentials via `HealthSyncWorker.storeCredentials()`, schedules WorkManager
- `backgroundWrite` — receives `data_type` + `value` (JSON string) from FCM handler,
  parses JSON, dispatches to the correct `HealthConnectBridge.write*` method

**Modified:** `zuralog/android/app/build.gradle.kts`
- Added `androidx.security:security-crypto:1.1.0-alpha06` dependency

### Phase 5 — `HealthSyncWorker.kt` full rewrite

**Rewritten:** `zuralog/android/app/src/main/kotlin/com/zuralog/zuralog/HealthSyncWorker.kt`

Previously a stub returning `Result.success()` without doing any real work.
Now a production-quality WorkManager worker that:
- Reads ALL 16 data types via `HealthConnectBridge` (30-day lookback window)
- Securely stores the API bearer token using `EncryptedSharedPreferences`
  (AES256_GCM + AES256_SIV via Android Keystore — no plaintext secrets on disk)
- POSTs assembled payload to `POST /api/v1/health/ingest` via
  `java.net.HttpURLConnection` with `Authorization: Bearer {token}` header
- Returns `Result.success()` on HTTP 2xx, `Result.retry()` on network error or
  non-2xx response (WorkManager handles exponential back-off automatically)
- `storeCredentials(context, apiToken)` static method called from MainActivity

### Phase 6 — FCM `backgroundWrite` handler

Implemented as part of Phase 4. The handler correctly matches the iOS AppDelegate
contract so Dart code can use the same FCM payload structure on both platforms:
- `data_type` (snake_case string, e.g. `"nutrition"`, `"weight"`)
- `value` (JSON string, e.g. `'{"calories":500,"protein":40,"date":"..."}'`)

### Phase 7 — Android manifest permissions

**Modified:** `zuralog/android/app/src/main/AndroidManifest.xml`

Added 7 missing `uses-permission` entries for Health Connect:
`READ_DISTANCE`, `READ_FLOORS_CLIMBED`, `READ_BODY_FAT`, `READ_RESPIRATORY_RATE`,
`READ_OXYGEN_SATURATION`, `READ_HEART_RATE`, `READ_BLOOD_PRESSURE`

### Phase 8 — Dart-side fixes

**Fixed:** `zuralog/lib/features/health/data/health_sync_service.dart`
- Added `dart:io` import for `Platform`
- Changed hardcoded `source: 'apple_health'` to
  `source: Platform.isAndroid ? 'health_connect' : 'apple_health'`

**Fixed:** `zuralog/lib/features/integrations/domain/integrations_provider.dart`
- Google Health Connect connect flow now includes the full three-step sequence
  that matches the Apple Health flow:
  1. `configureBackgroundSync` (sends credentials to Android WorkManager)
  2. `startBackgroundObservers` (enables real-time observation)
  3. Initial 30-day full sync

### Phase 9 — Tests updated + full suite passing

**Rewritten:** `cloud-brain/tests/mcp/test_health_connect_server.py`
- Dropped stale assertions expecting `pending_device_sync` (old stub behavior)
- Restructured to match `test_apple_health_server.py` pattern:
  - `TestHealthConnectServerExecutionNoDb` — 6 tests verifying graceful degradation
    without `db_factory` (all expect `success is False`)
  - `TestHealthConnectServerExecutionWithDb` — 5 tests with mock `db_factory`
    verifying real DB query path (steps, nutrition, workouts, sleep, invalid type)
- Final result: **102/102 tests pass**

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| `HealthDataServerBase` abstract base | Avoids ~400 lines of duplication between Apple Health and Health Connect MCP servers; future integrations (Garmin, Fitbit) can subclass with ~70 lines |
| `DailyHealthMetrics` NOT filtered by `source_name` | The daily metrics table is user-level, not source-level — it aggregates across all sources |
| JWT auth for WorkManager sync | Android `HealthSyncWorker` extracts user identity from `Authorization: Bearer` header server-side — no `user_id` in POST body needed |
| `EncryptedSharedPreferences` for API token | AES256_GCM/SIV via Android Keystore — no plaintext token ever touches disk |
| FCM write payload: `value` as JSON string | Matches iOS AppDelegate contract; Dart code is platform-agnostic |
| Dart key names: `auth_token` / `api_base_url` | Android handler uses same snake_case keys; avoids silent mismatch bugs |

---

## What This Means for Users

Android users running Zuralog can now:

1. **Tap "Connect" on Google Health Connect** in the Integrations Hub — permissions
   are requested, background sync is configured, and a 30-day historical sync runs immediately.

2. **See all their Android health data in AI chat** — the AI agent can answer questions
   like "How many steps did I take this week?" or "What was my average heart rate on Monday?"
   using data read from Health Connect.

3. **Have the AI write data back** — the orchestrator can push nutrition logs, weight
   entries, and workout records back to Health Connect via FCM, keeping Android health
   data in sync with AI-driven entries.

4. **Get ongoing automatic sync** — WorkManager runs a periodic background sync
   (default interval inherits from the existing schedule) without requiring the app
   to be open.

---

## Data Types Supported

| Category | Data Types |
|---|---|
| Activity | steps, active calories, distance, floors climbed, workouts |
| Cardiovascular | heart rate (time-series avg/min/max), resting heart rate, blood pressure |
| Body composition | body weight, body fat percentage |
| Respiratory | respiratory rate, SpO2 (oxygen saturation) |
| Advanced fitness | HRV, VO2 max |
| Sleep | sleep sessions |
| Nutrition | nutrition logs (calories, macros) |
| Daily summary | all scalar metrics for a date range in one call |

---

## Deviations from Original Plan

- **`HealthDataServerBase` was not in the original plan** — discovered during Phase 2
  that extracting a shared base eliminated ~400 lines of duplication. Worth the
  additional complexity.
- **`HealthSyncWorker` was a more significant rewrite than expected** — the stub was
  more incomplete than the plan indicated; a full `HttpURLConnection`-based HTTP
  client had to be written from scratch (no OkHttp to avoid adding a new dependency).
- **Tests required restructuring, not just updating** — the old 3 failing tests assumed
  the stub's `pending_device_sync` behavior; they were replaced with a `NoDb`/`WithDb`
  split matching the Apple Health server test pattern.

---

## What Remains for the Future

- **Real-device E2E test** — verify the WorkManager sync fires on a physical Android
  device with Health Connect installed and that data appears in the Cloud Brain DB.
- **Granular sync window** — currently syncs 30-day lookback on every run; a
  `last_synced_at` cursor would avoid re-processing old records.
- **Blood pressure write** — read is implemented; write (systolic + diastolic pair)
  requires a more complex FCM payload and is not yet wired.
- **VO2 max + HRV write** — read works; Health Connect does not expose write APIs
  for these types yet (Google limitation as of early 2026).
- **Conflict resolution** — if both Apple Health (via iCloud) and Health Connect
  report the same metric for the same date, the ingest endpoint currently stores
  both rows; a deduplication layer would improve accuracy.
- **Permission re-request flow** — if the user revokes a Health Connect permission
  mid-session, the bridge currently returns an empty list without surfacing the
  revocation to the UI; a permission-check screen would improve UX.

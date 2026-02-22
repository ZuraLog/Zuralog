# Executed Phase 1.10: Background Services & Sync Engine

> **Branch:** `feat/phase-1.10`
> **Date:** 2026-02-22
> **Status:** Complete (pending merge to main)

---

## Summary

Implemented the full Background Services & Sync Engine spanning both the Cloud Brain (Python/FastAPI + Celery) and Edge Agent (Flutter/Dart). This phase establishes background data sync infrastructure, cloud-to-device write flow via FCM, cross-source data normalization, activity deduplication, and sync status tracking.

## What Was Built

### Cloud Brain (Backend)

- **Data Normalizer** (`app/analytics/normalizer.py`) — Stateless `DataNormalizer` class that transforms Strava, Apple HealthKit, and Google Health Connect activity data into a unified internal schema. Handles field name mapping, unit conversion (HC milliseconds to seconds), and activity type classification via `ActivityType` enum (RUN, CYCLE, WALK, SWIM, STRENGTH, UNKNOWN).

- **Deduplication Engine** (`app/analytics/deduplication.py`) — `SourceOfTruth` class with time-based overlap detection (>50% threshold on shorter activity) and source-priority conflict resolution. Priority hierarchy: Apple Health/Health Connect (10) > Strava (8) > Manual (5). Proper ISO 8601 datetime parsing replaces the original plan's placeholder.

- **Sync Status Tracking** — `SyncStatus` enum (IDLE, SYNCING, ERROR) and two new columns (`sync_status`, `sync_error`) added to the `Integration` model for debugging sync failures.

- **Device Write Service** (`app/services/device_write_service.py`) — Bridges AI write decisions to on-device health writes via FCM silent data messages. Constructs FCM payloads with `action: write_health`, data type, and JSON-encoded value.

- **Push Service Enhancement** — Added `send_data_message()` to `PushService` for silent data-only FCM pushes (no visible notification).

- **User Device Model** (`app/models/user_device.py`) — `UserDevice` ORM model for FCM token storage per user device. In-memory storage for MVP; DB persistence ready for Phase 2.

- **Device Registration Endpoint** (`POST /api/v1/devices/register`) — Edge Agent calls this after FCM initialization to register its token.

- **Celery Worker** (`app/worker.py`) — Celery app with Redis broker, Beat schedule (sync every 15min, token refresh every 1h), JSON serialization.

- **Sync Scheduler** (`app/services/sync_scheduler.py`) — `SyncService` class orchestrating per-user data sync from cloud integrations (Strava). Per-provider error capture without aborting the full sync. Celery tasks: `sync_all_users_task` (master) and `refresh_tokens_task`.

- **Dev Trigger Endpoint** (`POST /api/v1/dev/trigger-write`) — Simulates AI-initiated health writes for harness testing. Disabled in production.

- **28 new unit tests** across 5 test files, all passing.

### Edge Agent (Flutter)

- **FCM Background Handler** — Implemented `firebaseMessagingBackgroundHandler` body (was empty scaffold from Phase 1.9). Handles `write_health` actions via direct `MethodChannel('com.lifelogger/health')` in the headless isolate. Granular exception handling: `PlatformException`, `MissingPluginException`.

- **Firebase Initialization** — `main.dart` now calls `Firebase.initializeApp()` and registers the background handler before `runApp()`. Wrapped in try-catch for environments without Firebase config.

- **Harness Background Sync Section** — New section in the developer harness with buttons for simulating AI writes (Steps, Nutrition) and a sync status placeholder.

### Infrastructure

- **Docker Compose** — Added `celery-worker` (concurrency=2) and `celery-beat` services alongside existing PostgreSQL and Redis.

- **Dependencies** — Added `celery[redis]>=5.4.0` to `pyproject.toml`.

---

## Deviations from Original Plan

| # | Original Plan | What We Did | Reason |
|---|---|---|---|
| 1 | `handle_write_request()` inside `Orchestrator` | Created separate `DeviceWriteService` | Clean separation of concerns — Orchestrator handles LLM loop, not FCM |
| 2 | Execution order: 1.10.1 → 1.10.7 | Reordered: pure logic first (1.10.4, 1.10.5, 1.10.6), then infra (1.10.1, 1.10.2, 1.10.3, 1.10.7) | Pure logic is TDD-friendly and has no infrastructure dependencies |
| 3 | No device token storage | Added `UserDevice` model + `/devices/register` endpoint | Required for FCM delivery — original plan assumed `db.get_user_device()` exists |
| 4 | `_is_overlap()` returned `False` (placeholder) | Proper datetime parsing with time-interval intersection | Original was non-functional |
| 5 | Only `send_notification()` in PushService | Added `send_data_message()` for silent data-only pushes | Notification payloads show visible alerts; data-only wakes app silently |
| 6 | No `/dev/trigger-write` endpoint | Created dev-only endpoint gated behind `app_env != production` | Required for harness button to work |

---

## Verification Results

| Check | Result |
|-------|--------|
| Backend tests (new) | 28/28 passed |
| Backend tests (existing) | 96/96 sync tests pass; 60 pre-existing async failures (pytest-asyncio config) |
| Ruff lint | 0 new issues (3 pre-existing in alembic/) |
| Flutter analyze | 0 new issues (3 pre-existing in unrelated files) |
| Branch | `feat/phase-1.10` — 7 atomic commits |

---

## Files Created (11)

| File | Purpose |
|------|---------|
| `cloud-brain/app/analytics/normalizer.py` | Cross-source activity normalization |
| `cloud-brain/app/analytics/deduplication.py` | Overlap detection + priority resolution |
| `cloud-brain/app/services/device_write_service.py` | Cloud-to-device write via FCM |
| `cloud-brain/app/services/sync_scheduler.py` | Celery sync tasks |
| `cloud-brain/app/worker.py` | Celery app configuration |
| `cloud-brain/app/models/user_device.py` | FCM token storage model |
| `cloud-brain/app/api/v1/devices.py` | Device registration endpoint |
| `cloud-brain/app/api/v1/dev.py` | Dev-only trigger endpoint |
| `cloud-brain/tests/test_normalizer.py` | 8 normalizer tests |
| `cloud-brain/tests/test_deduplication.py` | 8 deduplication tests |
| `cloud-brain/tests/test_sync_status.py` | 4 sync status tests |
| `cloud-brain/tests/test_device_write_service.py` | 4 write service tests |
| `cloud-brain/tests/test_sync_scheduler.py` | 4 sync scheduler tests |
| `life_logger/test/core/network/fcm_service_test.dart` | FCM handler compilation test |

## Files Modified (9)

| File | Change |
|------|--------|
| `cloud-brain/app/models/integration.py` | Added SyncStatus enum + sync_status/sync_error columns |
| `cloud-brain/app/services/push_service.py` | Added send_data_message() |
| `cloud-brain/app/models/__init__.py` | Re-exported UserDevice |
| `cloud-brain/app/main.py` | Registered devices + dev routers, init PushService + DeviceWriteService |
| `cloud-brain/pyproject.toml` | Added celery[redis] dependency |
| `cloud-brain/docker-compose.yml` | Added celery-worker + celery-beat services |
| `life_logger/lib/core/network/fcm_service.dart` | Implemented background handler body |
| `life_logger/lib/main.dart` | Firebase init + FCM handler registration |
| `life_logger/lib/features/harness/harness_screen.dart` | Added Background Sync section |

---

## Next Steps

- **Phase 1.11 (Analytics):** Can now consume normalized/deduplicated data from the normalizer and deduplication engine
- **Actual Strava sync:** `SyncService._sync_strava()` has a TODO for real API calls using httpx
- **DB persistence for device tokens:** Replace in-memory `app.state.device_tokens` with `UserDevice` table queries
- **Alembic migration:** Run `alembic revision --autogenerate -m "add_sync_status_and_user_devices"` when DB is available
- **Token refresh:** `refresh_tokens_task` needs actual provider-specific refresh implementation
- **Native `backgroundWrite`:** iOS Swift and Android Kotlin bridges need to handle the `backgroundWrite` MethodChannel call

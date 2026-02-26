# Strava Integration — Execution Record

**Branch:** `feat/strava-rate-limiter`
**Status:** Complete — ready to merge to `main`
**Last updated:** 2026-02-26

---

## What Was Built

### Phase 1.6 — Production-Ready Strava Integration

The goal was to upgrade the MVP Strava integration from in-memory token storage to a
production-quality system that survives server restarts, handles token expiry automatically,
and syncs data in real time.

---

### Completed Work (13 commits)

#### Token Lifecycle — `StravaTokenService`

New file: `cloud-brain/app/services/strava_token_service.py`

- `save_tokens()` — persists access token, refresh token, expiry, and athlete metadata to the `integrations` table
- `get_access_token()` — returns a valid token; auto-refreshes using the Strava token endpoint if within 5 minutes of expiry
- `refresh_access_token()` — calls `https://www.strava.com/oauth/token` with `grant_type=refresh_token`; writes new tokens to DB
- `get_integration()` — fetches the raw `Integration` row for a user
- `disconnect()` — marks `is_active=False` and clears tokens

#### MCP Server Wiring — `StravaServer`

Modified: `cloud-brain/app/mcp_servers/strava_server.py`

- Constructor accepts `token_service`, `db_factory`, and `rate_limiter`
- `execute_tool` resolves tokens via `StravaTokenService` when DB path is active; falls back to in-memory dict for backwards compatibility
- Rate limiter checked before every outbound API call

#### OAuth Exchange & Connection Endpoints

Modified: `cloud-brain/app/api/v1/integrations.py`

- `POST /integrations/strava/exchange` — persists tokens to DB on OAuth callback; returns `athlete_id`
- `GET /integrations/strava/status` — returns connection status, athlete ID, and last sync time
- `DELETE /integrations/strava/disconnect` — deactivates the integration and clears stored tokens
- OAuth scopes expanded to `activity:read_all,profile:read_all,read`

#### Real Activity Sync — `SyncService._sync_strava`

Modified: `cloud-brain/app/services/sync_scheduler.py`

- Calls `GET /api/v3/athlete/activities` with pagination (`per_page=200`, Strava's maximum)
- Loops pages until an empty page is returned (full historical backfill on first connect)
- Early-exit optimisation: stops pagination the moment a duplicate activity is found — makes incremental syncs fast
- `after_timestamp` parameter: when supplied, uses Strava's `after=` filter; `sync_user_data` derives this from `integration.last_synced_at`
- Maps Strava activity types to canonical `ActivityType` enum; uses `start_date` (genuine UTC) not `start_date_local`
- Upserts rows into `UnifiedActivity`; commits per page

#### Proactive Token Refresh — `refresh_tokens_task`

Modified: `cloud-brain/app/services/sync_scheduler.py`

- `SyncService._refresh_expiring_tokens()` queries for active Strava integrations expiring within 30 minutes and refreshes them
- Wired to `refresh_tokens_task` Celery task, scheduled hourly via Celery Beat

#### Webhook Real-Time Sync

New file: `cloud-brain/app/api/v1/strava_webhooks.py`
New task: `sync_strava_activity_task` in `cloud-brain/app/services/sync_scheduler.py`

- `GET /api/v1/webhooks/strava` — Strava subscription validation challenge (echoes `hub.challenge`); returns 503 if `STRAVA_WEBHOOK_VERIFY_TOKEN` is not configured
- `POST /api/v1/webhooks/strava` — receives activity events from Strava; dispatches `sync_strava_activity_task.delay()` immediately and returns 200 within Strava's 2-second timeout
- `sync_strava_activity_task` — resolves the user by matching `provider_metadata.athlete_id` to `owner_id`, fetches the specific activity from `GET /activities/{id}`, and upserts or deletes the `UnifiedActivity` row
- Athlete deauthorisation events (`object_type="athlete"`) are acknowledged but no task is dispatched

#### `strava_get_athlete_stats` MCP Tool

Modified: `cloud-brain/app/mcp_servers/strava_server.py`

- Calls `GET /athletes/{athlete_id}/stats`; returns recent, all-time, and year-to-date totals for runs, rides, and swims
- `athlete_id` is now **optional** in the tool schema — `execute_tool` auto-resolves it from `provider_metadata.athlete_id` when the DB token path is active
- Falls back to a clear error message telling the user to reconnect if the ID cannot be resolved

#### Redis Rate Limiter — `StravaRateLimiter`

New file: `cloud-brain/app/services/strava_rate_limiter.py`

- Tracks requests against Strava's limits: 100 requests / 15 minutes and 1000 requests / day
- Redis-backed sliding window counters (fail-open: if Redis is unavailable, requests are allowed)
- Wired into `StravaServer` via `main.py` using `settings.redis_url`

#### Application Wiring — `main.py`

- `StravaTokenService` and `StravaRateLimiter` instantiated at startup and injected into `StravaServer`
- `app.state.strava_token_service` set for use by API routes
- `strava_webhook_router` mounted at `/api/v1`

---

### Code Review Fixes (post-implementation)

Five issues found and resolved before merge:

| Issue | Fix |
|---|---|
| Webhook `hub.verify_token` bypass when env var is empty | Added 503 guard + `hub.mode != "subscribe"` check |
| `_sync_strava` had no httpx timeout | Added `timeout=30.0` |
| `db=None` silently passed to `_sync_strava` | Added explicit guard with error message |
| `start_date_local` (wall-clock) used for timestamps | Switched to `start_date` (genuine UTC) |
| `StravaRateLimiter` built but never wired | Wired in `main.py` with `settings.redis_url` |

---

### Test Coverage

- **Total passing:** 349 (35 net new tests added across this phase)
- **Files:** `tests/test_strava_token_service.py`, `tests/test_strava_rate_limiter.py`, `tests/test_strava_webhooks.py`, `tests/test_sync_scheduler.py`, `tests/mcp/test_strava_server.py`, `tests/test_integrations.py`
- **Pre-existing failures:** 4 in `tests/test_transcribe.py` — unrelated (require OpenAI key not set in test env)
- **Linting:** `ruff check app/ tests/` → 0 errors

---

### Known Limitations Accepted at This Phase

| Limitation | Notes |
|---|---|
| `db.add()` on `AsyncMock` produces `RuntimeWarning: coroutine never awaited` | Cosmetic. SQLAlchemy's `session.add()` is synchronous; `AsyncMock` makes it async in tests. Fix: `mock_db.add = MagicMock()`. |
| Webhook subscription not yet registered with Strava | Requires a public HTTPS URL and `STRAVA_WEBHOOK_VERIFY_TOKEN` set. Must be done manually or via a setup script. |
| `sync_all_users_task` is still a stub | Returns `{"users_processed": 0}`. Full implementation is Phase 1.10. |

---

## What Still Needs to Be Done

### High Priority

#### 1. Register Webhook Subscription with Strava

Before real-time sync fires, Strava must be told about our webhook endpoint. This is a one-time
operation that calls Strava's subscription API with our endpoint URL and verify token.

**What to build:**
- A management script or admin endpoint that calls `POST https://www.strava.com/api/v3/push_subscriptions`
- Required env vars: `STRAVA_WEBHOOK_VERIFY_TOKEN`, `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`
- The endpoint must be publicly reachable (HTTPS). In local dev, use `ngrok` or similar.
- Store the returned `subscription_id` in config or DB for deregistration later.

**Without this:** The webhook POST handler and `sync_strava_activity_task` are fully implemented
but will never receive events from Strava.

---

#### 2. Implement `sync_all_users_task` (Phase 1.10)

The master Celery Beat task (`sync_all_users_task`) is currently a stub that returns
`{"users_processed": 0}`. It needs to:

1. Query the DB for all users with an active, non-error Strava integration
2. For each user, call `StravaTokenService.get_access_token()` to get a fresh token
3. Dispatch `SyncService.sync_user_data()` (or a per-user Celery sub-task)
4. Update `last_synced_at` and `sync_status` on each `Integration` row after sync

**Impact:** Without this, the 15-minute periodic poll never runs. Real-time webhook sync
works independently, but missed events (e.g. server downtime) are never backfilled.

---

#### 3. Cross-Source Deduplication (before Apple Health / Health Connect goes live)

Strava syncs its activities to both Apple Health and Google Health Connect by default.
When the Edge Agent begins pushing data from those platforms, the same run will appear
multiple times in `UnifiedActivity` with different `source` and `original_id` values.

**What to build:**
- Overlap detection on ingestion: before inserting a new activity from Apple Health or
  Health Connect, check if a `UnifiedActivity` row already exists with the same `user_id`,
  `activity_type`, and `start_time` within ±60 seconds, and similar `duration_seconds`
  within ±5%. If yes, skip the insert.
- Source priority hierarchy: Strava data is richer (distance, pace, GPS). When a conflict
  is detected, keep the Strava record.
- Optional: add a `canonical_source` column to `UnifiedActivity` to mark which source
  "owns" the authoritative record for display.
- Edge Agent (Swift/Kotlin) should query Zuralog before pushing a workout to check for
  prior existence.

---

### Medium Priority

#### 4. Activity Write Operations — "Log My Run"

To support user requests like *"I forgot to log my run, I ran 5km an hour ago"*, the
following must be added:

**New OAuth scope required:** `activity:write`
(Requires Strava API agreement review for apps writing data on behalf of users.)

**What to build:**
- Add `activity:write` to the OAuth scope string in `integrations.py`
- Re-auth flow for existing users who connected before this scope was added
- `strava_create_activity` tool in `StravaServer` already has the implementation skeleton
  and `POST /api/v3/activities` wired — it just needs the write scope to succeed
- Validate that the AI's proposed `start_date_local` and `elapsed_time` are reasonable
  before sending to Strava (e.g. not in the future, not longer than 24 hours)

**Note:** Strava cannot physically start GPS tracking from an API call. "Start a run"
means creating a manual activity record with no GPS data.

---

#### 5. Per-Activity Detail Sync (Heart Rate, Pace, Elevation)

Currently only summary fields are stored (`duration_seconds`, `distance_meters`,
`calories`, `activity_type`, `start_time`). Strava exposes richer data per activity.

**What to build:**
- After upserting a `UnifiedActivity` row, optionally call `GET /activities/{id}` and
  `GET /activities/{id}/streams?keys=heartrate,cadence,watts,altitude,velocity_smooth`
- Store detailed stream data in a new `activity_streams` table or as JSONB on
  `UnifiedActivity`
- Expose a new MCP tool `strava_get_activity_detail` that returns lap data, HR zones,
  and pace breakdown for a specific activity ID

**Scope already held:** `activity:read_all` covers private activities and stream data.

---

#### 6. Flutter UI — Strava Activity Screen

The data is in the DB but there is no Flutter screen displaying it.

**What to build:**
- A Strava / Activities screen in the Flutter app that lists `UnifiedActivity` rows
  sourced from Strava
- Filter by activity type (Run, Ride, Swim)
- Summary card showing distance, duration, calories, and date
- Deep-link to the activity on Strava (using `original_id` to construct
  `https://www.strava.com/activities/{id}`)

---

### Low Priority

#### 7. Gear & Route Data

- `GET /gear/{id}` — shoe or bike attached to a run or ride
- GPS polyline — already in the activity summary payload as `map.summary_polyline`;
  decode and store for map display

#### 8. Encrypt Tokens at Rest (Phase 2)

Access tokens and refresh tokens are stored in plaintext in the `integrations` table.
Supabase Vault (or `pgcrypto`) should be used to encrypt these columns at rest.

#### 9. Strava Deauthorisation Handling

When a user revokes Zuralog's access from Strava's settings, Strava sends an `athlete`
deauth webhook event. The current handler logs it but does not call `disconnect()`.
This should be wired up so the `Integration` row is cleanly deactivated.

---

## File Reference

### New Files (this phase)
| File | Purpose |
|---|---|
| `cloud-brain/app/services/strava_token_service.py` | DB-backed token lifecycle |
| `cloud-brain/app/services/strava_rate_limiter.py` | Redis sliding-window rate limiter |
| `cloud-brain/app/api/v1/strava_webhooks.py` | Webhook validation + event handler |
| `cloud-brain/tests/test_strava_token_service.py` | Token service unit tests |
| `cloud-brain/tests/test_strava_rate_limiter.py` | Rate limiter unit tests |
| `cloud-brain/tests/test_strava_webhooks.py` | Webhook endpoint tests |

### Modified Files (this phase)
| File | Change |
|---|---|
| `cloud-brain/app/mcp_servers/strava_server.py` | DB token path, rate limiter, `strava_get_athlete_stats`, auto-resolve `athlete_id` |
| `cloud-brain/app/main.py` | Inject services, mount webhook router |
| `cloud-brain/app/api/v1/integrations.py` | DB token persistence, status/disconnect endpoints, expanded scopes |
| `cloud-brain/app/services/sync_scheduler.py` | Real sync impl, pagination, incremental sync, `sync_strava_activity_task`, token refresh task |
| `cloud-brain/app/config.py` | `strava_webhook_verify_token` setting |
| `cloud-brain/.env.example` | Document `STRAVA_WEBHOOK_VERIFY_TOKEN` |
| `cloud-brain/tests/test_sync_scheduler.py` | Pagination tests, incremental sync tests |
| `cloud-brain/tests/mcp/test_strava_server.py` | DB token path tests |
| `cloud-brain/tests/test_integrations.py` | Exchange persist, status, disconnect tests |

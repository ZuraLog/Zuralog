# Withings Integration

**Status:** Code complete — credentials pending (see Railway setup below)  
**Type:** Direct REST API (OAuth 2.0 + HMAC-SHA256 signed requests)  
**Scopes:** `user.metrics,user.activity`  
**Rate limit:** 120 requests/minute (app-level, shared across all users)

---

## API Reference

| Property | Value |
|---|---|
| Auth URL | `https://account.withings.com/oauth2_user/authorize2` |
| Token endpoint | `POST https://wbsapi.withings.net/v2/oauth2` |
| Signature endpoint | `POST https://wbsapi.withings.net/v2/signature` |
| Base API URL | `https://wbsapi.withings.net` |
| API style | All POST with `action` parameter |
| Access token lifetime | 3 hours |
| Refresh token lifetime | 1 year |
| Auth code validity | 30 seconds |
| PKCE | No |
| Request signing | Required on all data API calls (HMAC-SHA256) |

---

## OAuth Flow

Withings uses a **server-side callback** (not a deep-link scheme). This is required because Withings validates that the registered redirect URI is a reachable HTTP(S) URL at app registration time — `zuralog://` custom schemes are rejected.

### Flow

```
App → GET /api/v1/integrations/withings/authorize
    ← { auth_url, state }

Browser → account.withings.com/oauth2_user/authorize2
    ← GET https://api.zuralog.com/api/v1/integrations/withings/callback?code=...&state=...

Backend:
  1. validate state (Redis getdel → user_id)
  2. exchange code within 30 seconds (getnonce → sign → POST /v2/oauth2)
  3. save tokens to DB
  4. trigger Celery: backfill (30 days) + webhook subscriptions
  5. redirect browser → zuralog://oauth/withings?success=true

App deeplink handler:
  reads ?success=true/false, refreshes integration status
```

### State Management

Unlike other integrations where `store_state` stores `"1"`, Withings stores `user_id` as the Redis value:

```
withings:state:{state} → user_id   (TTL: 600s)
```

This is necessary because the `/callback` endpoint receives a browser redirect with no JWT, so the user must be resolved from the state token.

---

## Request Signing (HMAC-SHA256)

Every Withings data API call requires a fresh nonce and HMAC-SHA256 signature. This is unique among ZuraLog integrations.

### Per-call flow

1. `POST /v2/signature` with `action=getnonce`, `client_id`, `timestamp`, `signature`
   - Nonce signature: `HMAC-SHA256(client_secret, "getnonce,{client_id},{timestamp}")`
2. Receive `nonce` from response
3. Compute API call signature: `HMAC-SHA256(client_secret, "{action},{client_id},{nonce}")`
4. Include `action`, `client_id`, `nonce`, `signature` in every API request body

### Service class

`WithingsSignatureService` handles this pipeline:
- `compute_signature(action, client_id, timestamp|nonce)` → hex digest
- `get_nonce()` → fresh nonce from Withings
- `prepare_signed_params(action, extra_params)` → full signed dict ready for POST

**Note:** Webhook subscription calls (`notify/subscribe`) use Bearer token auth only — no signing required.

---

## Webhook Notifications

Withings sends **form-encoded POST** (not JSON) to the registered callback URL.

### Webhook endpoint

```
POST https://api.zuralog.com/api/v1/webhooks/withings
```

### Payload fields

| Field | Description |
|---|---|
| `userid` | Withings user ID |
| `appli` | Notification category code |
| `startdate` | Unix timestamp range start |
| `enddate` | Unix timestamp range end |
| `date` | YYYY-MM-DD |

### Appli codes → data fetch mapping

| Appli | Trigger | Fetch |
|---|---|---|
| 1 | Weight/body composition | `getmeas` (meastypes 1,5,6,8,76,77,88,91) |
| 2 | Temperature | `getmeas` (meastypes 12,71,73) |
| 4 | Blood pressure/SpO2 | `getmeas` (meastypes 9,10,11,54) |
| 16 | Activity | `getactivity` + `getworkouts` |
| 44 | Sleep | `sleep v2 getsummary` |
| 54 | ECG | `heart v2 list` |
| 62 | HRV | `getmeas` (meastype 135) |

### Retry behavior

Withings retries webhooks up to 10 times with exponential backoff. Subscriptions auto-cancel after 20 consecutive days of failure.

### Subscription management

Subscriptions are per-user (unlike Oura which is per-app). Created in the `create_withings_webhook_subscriptions_task` Celery task on user connect, subscribing to all 7 appli codes.

---

## Measurement Type Codes

```python
1  = weight_kg
5  = fat_free_mass_kg
6  = fat_ratio_pct
8  = fat_mass_kg
9  = diastolic_bp_mmhg
10 = systolic_bp_mmhg
11 = heart_pulse_bpm
12 = temperature_c
54 = spo2_pct
71 = body_temperature_c
73 = skin_temperature_c
76 = muscle_mass_kg
77 = hydration_kg
88 = bone_mass_kg
91 = pulse_wave_velocity_ms
135 = hrv_ms
```

---

## MCP Tools (10)

| Tool | Endpoint | Action | Data |
|---|---|---|---|
| `withings_get_measurements` | `/measure` | `getmeas` | Weight, fat, muscle, bone, hydration, pulse wave velocity |
| `withings_get_blood_pressure` | `/measure` | `getmeas` | Systolic, diastolic, heart rate |
| `withings_get_temperature` | `/measure` | `getmeas` | Body temperature, skin temperature |
| `withings_get_spo2` | `/measure` | `getmeas` | Blood oxygen saturation |
| `withings_get_hrv` | `/measure` | `getmeas` | Heart rate variability |
| `withings_get_activity` | `/v2/measure` | `getactivity` | Steps, distance, calories, active minutes |
| `withings_get_workouts` | `/v2/measure` | `getworkouts` | Workout sessions |
| `withings_get_sleep` | `/v2/sleep` | `get` | Detailed sleep with HR curves |
| `withings_get_sleep_summary` | `/v2/sleep` | `getsummary` | Sleep score, stages, efficiency |
| `withings_get_heart_list` | `/v2/heart` | `list` | ECG recordings, AFib detection |

---

## Database Models

| Model | Table | Notes |
|---|---|---|
| `Integration` | `integrations` | Shared; `provider="withings"`, `provider_metadata.withings_user_id` |
| `BloodPressureRecord` | `blood_pressure_records` | New model added for this integration; `source` field supports future providers |

### BloodPressureRecord columns

```sql
id              TEXT PRIMARY KEY
user_id         TEXT NOT NULL
source          TEXT NOT NULL          -- "withings"
date            TEXT NOT NULL          -- YYYY-MM-DD
measured_at     TIMESTAMPTZ NOT NULL
systolic_mmhg   DOUBLE PRECISION NOT NULL
diastolic_mmhg  DOUBLE PRECISION NOT NULL
heart_rate_bpm  DOUBLE PRECISION
original_id     TEXT
created_at      TIMESTAMPTZ DEFAULT NOW()
UNIQUE (user_id, source, measured_at)
```

---

## Celery Tasks

| Task name | Trigger | Description |
|---|---|---|
| `withings.sync_notification` | Webhook | Fetch data by appli code for the notified user |
| `withings.sync_periodic` | Beat every 15 min | Sync today + yesterday for all active Withings users |
| `withings.refresh_tokens` | Beat every 1 hr | Proactively refresh tokens expiring within 30 min |
| `withings.backfill` | On connect | 30-day historical sync for new user |
| `withings.create_webhooks` | On connect | Subscribe to all 7 appli codes for new user |

---

## Railway Setup

### Required environment variables

| Variable | Value | Services |
|---|---|---|
| `WITHINGS_CLIENT_ID` | From BitWarden | Zuralog, Celery_Worker, Celery_Beat |
| `WITHINGS_CLIENT_SECRET` | From BitWarden | Zuralog, Celery_Worker, Celery_Beat |
| `WITHINGS_REDIRECT_URI` | `https://api.zuralog.com/api/v1/integrations/withings/callback` | Zuralog, Celery_Worker, Celery_Beat |

**Status:** `WITHINGS_REDIRECT_URI` is already set on the Zuralog service. `WITHINGS_CLIENT_ID` and `WITHINGS_CLIENT_SECRET` must be retrieved from BitWarden and set on all three services.

### Registered URLs (in Withings Developer app)

| URL type | Value |
|---|---|
| Callback URL | `https://api.zuralog.com/api/v1/integrations/withings/callback` |
| Webhook URL | `https://api.zuralog.com/api/v1/webhooks/withings` |

---

## Testing

### Unit tests (38, fast — no TestClient)

```bash
cd cloud-brain
python -m pytest tests/test_withings_signature_service.py tests/test_withings_token_service.py tests/test_withings_rate_limiter.py -v
```

### Integration tests (33, TestClient-based)

```bash
cd cloud-brain
python -m pytest tests/test_withings_routes.py tests/test_withings_webhooks.py tests/test_withings_server.py -v
```

> **Note:** TestClient-based tests make real network calls to PostHog/Sentry on teardown and run slowly on Windows (this is a pre-existing issue across all integration route tests, not Withings-specific). These run at full speed in CI (Linux).

### Demo mode E2E test

Append `&mode=demo` to the auth URL to use Withings' built-in demo user (no real Withings account needed):

```
https://account.withings.com/oauth2_user/authorize2?...&mode=demo
```

---

## Key Implementation Notes

- **30-second code window:** The authorization code expires in 30 seconds. The server-side callback exchanges it immediately upon receipt — no user action or delay possible.
- **Token refresh buffer:** 30 minutes before expiry (tokens last 3 hours; most aggressive of all integrations).
- **Refresh token rotation:** Withings issues a new refresh token on every refresh. The old one remains valid for 8 hours. If refresh fails, the user must re-authenticate (1-year refresh token expiry).
- **`hmac.new()` is the correct Python call** (not `hmac.HMAC()`).
- **All API requests are POST** — Withings has no GET endpoints; `action` parameter selects the operation.

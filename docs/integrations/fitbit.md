# Integration: Fitbit

**Status:** ✅ Production  
**Priority:** P1  
**Type:** Direct API (REST)  
**Auth:** OAuth 2.0 (Authorization Code + PKCE — RFC 7636)

---

## API Details

| Property | Value |
|----------|-------|
| Base URL | `https://api.fitbit.com` |
| Auth URL | `https://www.fitbit.com/oauth2/authorize` |
| Token URL | `https://api.fitbit.com/oauth2/token` |
| Rate Limit | **150 requests/hour per user** |
| Rate Limit Headers | `Fitbit-Rate-Limit-Remaining`, `Fitbit-Rate-Limit-Reset` |
| Access Token | 8 hours (28,800 seconds) |
| Refresh Token | Never expires — **single-use** (critical: losing it requires re-auth) |
| Webhooks | Yes — `activities`, `body`, `foods`, `sleep`, `userRevokedAccess` |
| Read/Write | Both (write weight, water, activities) |
| Pricing | Free |

## Why Direct Integration (Not Just Health Connect)

Fitbit's direct API provides ~18 exclusive data types that Health Connect cannot relay:
- ECG waveform data + AFib classification
- HRV (RMSSD 5-min intervals during sleep)
- Intraday heart rate (1-second resolution)
- Intraday SpO2 (minute-level during sleep)
- Breathing rate (derived sleep metric)
- Skin temperature (deviation from baseline)
- Active Zone Minutes (Fitbit-proprietary)
- Sleep score (composite)
- Blood glucose (manual logs)
- Historical data beyond 30 days
- iOS support (Health Connect is Android-only)
- Real-time webhooks (Health Connect is pull-only)

## Scopes Requested

```
activity heartrate sleep oxygen_saturation respiratory_rate
temperature cardio_fitness electrocardiogram weight nutrition
profile settings
```

## MCP Tools (12)

| Tool | Endpoint |
|------|----------|
| `fitbit_get_daily_activity` | `GET /1/user/-/activities/date/{date}.json` |
| `fitbit_get_activity_timeseries` | `GET /1/user/-/activities/{resource}/date/{start}/{end}.json` |
| `fitbit_get_heart_rate` | `GET /1/user/-/activities/heart/date/{date}/{period}.json` |
| `fitbit_get_heart_rate_intraday` | `GET /1/user/-/activities/heart/date/{date}/1d/{detail}.json` |
| `fitbit_get_hrv` | `GET /1/user/-/hrv/date/{date}.json` |
| `fitbit_get_sleep` | `GET /1.2/user/-/sleep/date/{date}.json` |
| `fitbit_get_spo2` | `GET /1/user/-/spo2/date/{date}.json` |
| `fitbit_get_breathing_rate` | `GET /1/user/-/br/date/{date}.json` |
| `fitbit_get_temperature` | `GET /1/user/-/temp/skin/date/{date}.json` |
| `fitbit_get_vo2max` | `GET /1/user/-/cardioscore/date/{date}.json` |
| `fitbit_get_weight` | `GET /1/user/-/body/log/weight/date/{date}.json` |
| `fitbit_get_nutrition` | `GET /1/user/-/foods/log/date/{date}.json` |

## Implementation Details

**Files:**
- `cloud-brain/app/services/fitbit_token_service.py` — OAuth + PKCE, single-use refresh handling
- `cloud-brain/app/services/fitbit_rate_limiter.py` — Per-user Redis token bucket
- `cloud-brain/app/mcp_servers/fitbit_server.py` — 12 MCP tools
- `cloud-brain/app/api/v1/fitbit_routes.py` — OAuth routes (authorize, exchange, status, disconnect)
- `cloud-brain/app/api/v1/fitbit_webhooks.py` — Webhook verification + event handler

**Rate Limiting Strategy:** Per-user token bucket in Redis (unlike Strava's app-level limiter). Tracks remaining from `Fitbit-Rate-Limit-Remaining` headers. Stops at ≤5 remaining. Fails open if Redis unavailable.

**PKCE Key Differences from Strava:**
- Code verifier (43–128 chars) + SHA-256 challenge generated server-side
- State token maps to verifier in Redis (10-min TTL, one-time use)
- Server apps use `Authorization: Basic` header (Base64 of `client_id:client_secret`)
- Refresh tokens are **single-use** — must atomically save new refresh token before using old one
- 10-min refresh buffer (vs 5-min for Strava) because access tokens expire in only 8 hours

**Webhook Flow:**
1. Fitbit sends `POST /api/v1/webhooks/fitbit` (notification array)
2. **Must respond HTTP 204 within 5 seconds** — never fetch data before responding
3. Dispatches `sync_fitbit_collection_task` Celery task per notification item
4. Celery task fetches data and upserts to health tables

## Intraday Data

| App Type | Access |
|----------|--------|
| Personal | Automatic (dev testing) |
| Server | Case-by-case approval via Google Issue Tracker |

**Plan:** Use Personal during development; apply for Server + intraday approval before production launch.

## Environment Variables

```env
FITBIT_CLIENT_ID=
FITBIT_CLIENT_SECRET=
FITBIT_REDIRECT_URI=zuralog://oauth/fitbit
FITBIT_WEBHOOK_VERIFY_CODE=
FITBIT_WEBHOOK_SUBSCRIBER_ID=
```

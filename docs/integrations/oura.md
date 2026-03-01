# Integration: Oura Ring

**Status:** ✅ Production  
**Priority:** P1  
**Type:** Direct API (REST)  
**Auth:** OAuth 2.0 (Authorization Code — no PKCE)

---

## Overview

The Oura Ring API provides the most comprehensive passive biometric data of any wearable — sleep staging, HRV, readiness scores, activity, SpO2, stress, and cardiovascular metrics — all derived from continuous ring-based sensors. The integration covers 16 data types across 16 dedicated MCP tools.

### Why Direct Integration (Not Just HealthKit Indirect)

Oura does write some data to HealthKit (sleep, steps, HR), but the direct API provides critical data that HealthKit cannot relay:

- **Readiness score** — composite metric proprietary to Oura, unavailable via HealthKit
- **Sleep stages** (deep, REM, light, awake) at fine granularity with contributor scores
- **HRV** (RMSSD, nightly average + trend)
- **SpO2** — nightly continuous measurements (HealthKit only gets daily average)
- **Resilience** — chronic vs. acute load balance indicator (Oura proprietary)
- **Cardiovascular age** — biological age estimate (Oura proprietary)
- **Stress index** — daytime stress monitoring from HRV patterns
- **Rest mode** — manual recovery mode state
- **Sleep time recommendations** — Oura's personalized bedtime window
- **Ring configuration** — hardware version and settings
- **Full historical data** — Oura API returns all-time data; HealthKit limited to what was written while app was installed
- **Webhooks** — real-time push on new data; HealthKit is pull-only

---

## API Details

| Property | Value |
|----------|-------|
| Base URL | `https://api.ouraring.com` |
| Sandbox URL | `https://api.ouraring.com` (sandbox uses mock token) |
| Auth URL | `https://cloud.ouraring.com/oauth/authorize` |
| Token URL | `https://api.ouraring.com/oauth/token` |
| Rate Limit | **5,000 requests/hour per app** (shared across all users) |
| Rate Limit Headers | None — Oura does not return rate-limit headers |
| Access Token | Offline (no expiry unless revoked) |
| Refresh Token | Provided but tokens are long-lived; refresh on 401 |
| Webhooks | Yes — per subscription, **90-day expiry**, manual renewal required |
| Read/Write | Read-only |
| Pricing | Free |

### Auth Flow (OAuth 2.0 — No PKCE)

Oura uses standard Authorization Code flow **without** PKCE. Unlike Fitbit, no code verifier is generated.

```
1. Flutter opens browser: GET /oauth/authorize?client_id=...&redirect_uri=zuralog://oauth/oura&scope=...&response_type=code
2. User logs in and grants permissions on cloud.ouraring.com
3. Oura redirects to zuralog://oauth/oura?code=<auth_code>
4. Flutter deep link fires → calls POST /api/v1/oura/exchange with auth_code
5. Backend calls POST https://api.ouraring.com/oauth/token (Basic auth header: Base64(client_id:client_secret))
6. Tokens stored in `integrations` table (server-side, never on device)
```

### Scopes Requested

```
email personal daily heartrate workout tag session spo2 daily_stress
daily_resilience daily_cardiovascular_age daily_sleep_time ring_configuration
```

---

## Sandbox Mode

Set `OURA_USE_SANDBOX=true` in `.env` to enable sandbox mode during development.

In sandbox mode, the backend uses a pre-configured sandbox token (set via `OURA_SANDBOX_TOKEN`) instead of performing OAuth. This allows full end-to-end testing of all 16 MCP tools against Oura's mock dataset without a real ring or OAuth credentials.

```env
OURA_USE_SANDBOX=true
OURA_SANDBOX_TOKEN=<sandbox_token_from_oura_developer_portal>
```

Sandbox mode is detected in `oura_token_service.py` — when active, `get_valid_token()` returns the sandbox token directly without hitting the database.

---

## Rate Limiting Strategy

Oura enforces a **5,000 requests/hour limit at the app level** (shared across all users), unlike Fitbit's per-user limit. The rate limiter is implemented as a Redis sliding-window counter in `oura_rate_limiter.py`:

- Window: 3,600 seconds
- Limit: 5,000 requests
- No response headers to track — the limiter is purely counter-based
- Fails open if Redis is unavailable (logs warning, allows request)
- Raises `RateLimitExceeded` (HTTP 429) when limit is reached

Because Oura has no per-user enforcement, heavy multi-user usage must be monitored at the app level. As user count grows, consider batching or caching frequently accessed data.

---

## Webhook Subscription Management

Oura webhooks are **per-app subscriptions** (not per-user like Fitbit). A single webhook subscription covers all users who have connected Oura.

### Key Webhook Properties

| Property | Detail |
|----------|--------|
| Subscription endpoint | `POST /api/v1/webhooks/oura` |
| Expiry | **90 days** — must be renewed before expiry |
| Renewal | `PUT https://api.ouraring.com/v2/webhook/{subscription_id}/renew` |
| Event types | `create`, `update`, `delete` per data type |
| Data types | `daily_sleep`, `daily_activity`, `daily_readiness`, `daily_spo2`, `sleep` |

### Automatic Renewal

A Celery Beat task (`renew_oura_webhook_task`) runs daily and renews the subscription if it expires within 7 days. The subscription ID and expiry are stored in the `oura_webhook_subscriptions` table.

### Webhook Flow

```
1. Oura fires POST /api/v1/webhooks/oura (event notification)
2. Verify HMAC signature using OURA_WEBHOOK_CLIENT_SECRET
3. Respond HTTP 200 immediately — never fetch data synchronously
4. Dispatch sync_oura_data_task(user_id, data_type, date) Celery task
5. Celery task fetches full record from API and upserts to health tables
```

---

## Implementation Architecture

### Backend Files

| File | Purpose |
|------|---------|
| `cloud-brain/app/services/oura_token_service.py` | OAuth token management, refresh on 401, sandbox mode support |
| `cloud-brain/app/services/oura_rate_limiter.py` | App-level Redis sliding-window rate limiter (5,000/hr) |
| `cloud-brain/app/mcp_servers/oura_server.py` | 16 MCP tools exposing all Oura data types to the LLM |
| `cloud-brain/app/api/v1/oura_routes.py` | OAuth routes: `/authorize`, `/exchange`, `/status`, `/disconnect` |
| `cloud-brain/app/api/v1/oura_webhooks.py` | Webhook receiver, HMAC verification, Celery dispatch |
| `cloud-brain/app/tasks/oura_sync_tasks.py` | Celery tasks: data sync, token refresh, webhook renewal |

### Flutter Files

| File | Purpose |
|------|---------|
| `zuralog/lib/features/integrations/oura_oauth_page.dart` | OAuth initiation screen and deep link callback handler |
| `zuralog/lib/features/integrations/providers/oura_provider.dart` | Riverpod provider for Oura connection state |
| `zuralog/lib/features/integrations/services/oura_integration_service.dart` | API calls: connect, disconnect, status check |
| `zuralog/lib/features/integrations/widgets/oura_tile.dart` | Integration tile in the Integrations Hub |

---

## MCP Tools (16)

| Tool | Endpoint | Description |
|------|----------|-------------|
| `oura_get_sleep` | `GET /v2/usercollection/sleep` | Detailed sleep sessions with stages (deep, REM, light, awake) |
| `oura_get_daily_sleep` | `GET /v2/usercollection/daily_sleep` | Daily sleep summary with score and contributors |
| `oura_get_daily_readiness` | `GET /v2/usercollection/daily_readiness` | Daily readiness score and HRV balance |
| `oura_get_daily_activity` | `GET /v2/usercollection/daily_activity` | Activity score, steps, calories, active time |
| `oura_get_heart_rate` | `GET /v2/usercollection/heartrate` | Continuous heart rate readings (5-min intervals) |
| `oura_get_daily_spo2` | `GET /v2/usercollection/daily_spo2` | Nightly average and variation of blood oxygen |
| `oura_get_daily_stress` | `GET /v2/usercollection/daily_stress` | Daytime stress index and recovery time |
| `oura_get_daily_resilience` | `GET /v2/usercollection/daily_resilience` | Chronic vs. acute load balance (daytime / sleep resilience) |
| `oura_get_daily_cardiovascular_age` | `GET /v2/usercollection/daily_cardiovascular_age` | Estimated biological cardiovascular age |
| `oura_get_vo2_max` | `GET /v2/usercollection/daily_activity` | VO2 max estimate derived from activity data |
| `oura_get_workouts` | `GET /v2/usercollection/workout` | Logged workouts with type, duration, HR |
| `oura_get_sessions` | `GET /v2/usercollection/session` | Guided sessions (meditation, breathing, etc.) |
| `oura_get_tags` | `GET /v2/usercollection/tag` | User-entered text tags and notes |
| `oura_get_rest_mode_periods` | `GET /v2/usercollection/rest_mode_period` | Rest mode activation periods |
| `oura_get_sleep_time` | `GET /v2/usercollection/sleep_time` | Recommended and actual bedtime window |
| `oura_get_ring_configuration` | `GET /v2/usercollection/ring_configuration` | Hardware version, color, firmware |

All tools accept `start_date` and `end_date` parameters (ISO 8601). The LLM can request ranges up to 90 days per call.

---

## Environment Variables

```env
OURA_CLIENT_ID=
OURA_CLIENT_SECRET=
OURA_REDIRECT_URI=zuralog://oauth/oura
OURA_WEBHOOK_CLIENT_SECRET=
OURA_USE_SANDBOX=false
OURA_SANDBOX_TOKEN=
```

---

## Known Limitations

| Limitation | Detail |
|------------|--------|
| **10-user dev limit** | Oura restricts OAuth apps to 10 users until the app is reviewed and approved for production. Submit app review before public launch. |
| **Webhook expiry** | Subscriptions expire every 90 days. The auto-renewal Celery task handles this, but manual renewal via `PUT /v2/webhook/{id}/renew` is the fallback. |
| **No rate-limit headers** | Oura does not return `X-RateLimit-*` headers. The Redis counter is the only mechanism to track usage — it will drift if Redis is unavailable. |
| **App-level rate limit** | The 5,000/hr limit is shared across all users, not per-user. High concurrency during sync windows could exhaust the budget. |
| **Read-only API** | Oura does not support writing data back (e.g., logging activities). |
| **Webhook data types** | Webhooks only cover 5 data types. Metrics like stress, resilience, and cardiovascular age must be fetched via periodic Celery sync rather than webhook-triggered sync. |

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `401 Unauthorized` | Access token expired or revoked | Token service triggers refresh automatically; if refresh also returns 401, the user must reconnect via the Integrations Hub |
| `403 Forbidden` | Webhook subscription expired | Renew subscription via `PUT /v2/webhook/{subscription_id}/renew` or trigger `renew_oura_webhook_task` manually |
| `429 Too Many Requests` | App-level rate limit (5,000/hr) hit | Requests blocked by `oura_rate_limiter.py`; retry after the sliding window resets (up to 60 min) |
| `OURA_USE_SANDBOX=true` but no data | `OURA_SANDBOX_TOKEN` not set | Add sandbox token from the Oura Developer Portal to `.env` |
| Webhook not firing | Subscription expired or wrong endpoint | Check `oura_webhook_subscriptions` table; verify `OURA_WEBHOOK_CLIENT_SECRET` matches |
| 10-user limit hit | Dev app not yet approved | Submit production app request at [cloud.ouraring.com/docs](https://cloud.ouraring.com/docs) |

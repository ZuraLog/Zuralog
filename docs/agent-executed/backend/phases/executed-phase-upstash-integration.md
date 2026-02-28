# Executed Phase: Upstash Redis Integration

**Date:** 2026-03-01
**Branch:** feat/upstash-integration
**Plan:** .opencode/plans/2026-02-28-integration-upstash.md
**Status:** Complete — all 8 tasks executed, spec-reviewed, and pushed

---

## What Was Built

### Cloud Brain (FastAPI)

Distributed caching and rate-limit header infrastructure added to the Python backend.

**New file — `cloud-brain/app/services/cache_service.py`**
A `CacheService` class using the `upstash-redis` HTTP REST Python SDK. Provides `get`, `set`, `delete`, `invalidate_pattern` (SCAN+DELETE loop), and a `make_key` static helper. All methods are async-signature no-ops when credentials are absent, enabling local development without Upstash. Alongside it, a `@cached(prefix, ttl, key_params)` decorator wraps FastAPI route handlers — it reads `request.app.state.cache_service`, attempts a cache hit, falls through to the handler on miss, and serializes Pydantic models via `.model_dump()` before storing.

**New file — `cloud-brain/app/api/v1/deps.py`**
A `get_authenticated_user_id` FastAPI dependency that extracts and validates the user ID from the JWT via `AuthService.get_user()`, returning it as a string in `kwargs` where `@cached`'s `key_params` can pick it up.

**Modified — `cloud-brain/pyproject.toml`**
Added `upstash-redis>=1.4.0` dependency. The existing `redis[hiredis]>=5.0.0` (used by Celery and the rate limiter via TCP) is untouched.

**Modified — `cloud-brain/app/config.py`**
Added five new settings: `upstash_redis_rest_url`, `upstash_redis_rest_token`, `cache_ttl_short` (300s), `cache_ttl_medium` (900s), `cache_ttl_long` (86400s). The existing `redis_url` field is untouched.

**Modified — `cloud-brain/app/main.py`**
`CacheService()` is instantiated in the lifespan startup and stored as `app.state.cache_service`. No shutdown teardown (REST client is stateless).

**Modified — `cloud-brain/app/api/v1/analytics.py`**
`@cached` applied to all 6 GET endpoints: `daily_summary` (300s), `weekly_trends` (300s), `sleep_activity_correlation` (900s), `metric_trend` (300s), `get_goals` (300s), `dashboard_insight` (300s). The POST endpoint is untouched.

**Modified — `cloud-brain/app/api/v1/health_ingest.py`**
After successful upsert, targeted invalidation of 5 analytics cache keys (daily_summary, weekly_trends, correlation, goals, dashboard_insight) scoped to `user_id`.

**Modified — `cloud-brain/app/api/v1/users.py`**
`GET /me/preferences` and `GET /me/profile` refactored to use `Depends(get_authenticated_user_id)` (removing duplicate auth extraction) and decorated with `@cached` (900s each). PATCH handlers retain original auth pattern and have cache invalidation added after `db.commit()` / `db.refresh()`.

**Modified — `cloud-brain/app/api/v1/integrations.py`**
`GET /strava/authorize` decorated with `@cached` (3600s, no user-specific key). `GET /strava/status` refactored with `Depends(get_authenticated_user_id)` and `@cached` (300s). `POST /strava/exchange` and `DELETE /strava/disconnect` both invalidate the strava_status cache after completing.

**Modified — `cloud-brain/app/services/rate_limiter.py`**
Added `RateLimiter.headers(result: RateLimitResult) -> dict[str, str]` static method returning `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` headers. Consumers (e.g. `chat.py`) can call this to add standard headers to responses.

---

### Website (Next.js)

Distributed rate limiting and Redis response caching added to the Next.js marketing site.

**New file — `website/src/lib/redis.ts`**
`Redis.fromEnv()` singleton. Logs a warning at startup if credentials are absent.

**New file — `website/src/lib/cache.ts`**
`getCached<T>`, `setCached<T>`, `deleteCached` helpers. All wrapped in try/catch — fail silently so the route continues without cache.

**Replaced — `website/src/lib/rate-limit.ts`**
The 94-line in-memory `Map`-based sliding window is gone. Replaced with three `Ratelimit` instances (waitlist: 5/60s, contact: 3/60s, general: 30/60s) backed by Upstash atomic Lua scripts. The `rateLimiter` named export is preserved with the identical `{ limit(identifier) }` interface so `waitlist/join/route.ts` requires zero changes.

**New file — `website/src/middleware.ts`**
Next.js Edge Middleware running on all `/api/*` requests. Creates its own `Redis` instance (cannot share the lib/redis singleton across module scopes). Global rate limit: 60 req/60s per IP. Admin routes bypassed. Rate limit headers added to all responses (successful and blocked). TypeScript deviation: removed `?? request.ip` — `NextRequest.ip` does not exist in Next.js 16.x, build verified clean.

**Modified — `website/src/app/api/contact/route.ts`**
Rate limiting added (contact type: 3/60s) after body validation, before email send. Full `X-RateLimit-*` + `Retry-After` headers on 429.

**Modified — `website/src/app/api/waitlist/stats/route.ts`**
Rate limiting (general: 30/60s) + 10s Redis cache. `setCached` called before return; cache is read first on subsequent requests.

**Modified — `website/src/app/api/waitlist/status/route.ts`**
Rate limiting (general: 30/60s) added.

**Modified — `website/src/app/api/waitlist/leaderboard/route.ts`**
Rate limiting (general: 30/60s) + 60s Redis cache.

**Modified — `website/src/app/api/waitlist/join/route.ts`**
After successful insert, `deleteCached` called for both `website:waitlist:stats` and `website:waitlist:leaderboard` before the welcome email fires.

**Modified — `website/src/app/api/support/stats/route.ts`**
Rate limiting (general: 30/60s) + 300s Redis cache. In-memory `lastSyncTimestamp` / `SYNC_INTERVAL_MS` vars removed. BMC sync runs on every cache miss (Redis TTL controls frequency, which is more reliable across serverless instances).

---

## Deviations from Plan

**`request.ip` removed from middleware.ts**
The plan included `?? request.ip` as a fallback in IP extraction. `NextRequest.ip` does not exist in Next.js 16.x and causes a TypeScript error. Removed; `x-forwarded-for` header is the correct and sufficient approach on Vercel.

**`support/stats/route.ts` BMC sync always runs on cache miss**
The plan suggested replacing the in-memory TTL guard with Redis cache. Implemented as: cache hit → return early; cache miss → always run BMC sync then store result. This is functionally equivalent to a 5-minute TTL guard but more correct across multiple serverless instances.

**`GET /me/preferences` and `GET /me/profile` auth refactored**
The plan noted these endpoints extract `user_id` inside the handler body. Solution implemented: `Depends(get_authenticated_user_id)` replaces the inline `auth_service.get_user(credentials.credentials)` pattern so `user_id` is in `kwargs` for `@cached`. PATCH handlers are untouched.

---

## Next Steps

- Set `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN` in Railway (cloud-brain production env)
- Set `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN` in Vercel (website production env)
- Squash-merge `feat/upstash-integration` into `main` when verified
- PostHog integration is next in the execution order (plan 3 of 3)

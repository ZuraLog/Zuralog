# Phase 2.0 — Railway Deployment

**Status:** Complete (core deployment live)
**Date:** 2026-02-28
**Branch:** Multiple fix branches merged to `main`

---

## What Was Built

Successfully deployed the Cloud Brain FastAPI backend to Railway PaaS with full database connectivity to Supabase.

### Infrastructure

- **Railway service** running Docker container with Python 3.12 + uv
- **Supabase PostgreSQL** connected via Session Pooler (IPv4 compatible)
- **Upstash Redis** connected via TLS (rediss://)
- **Custom domain** `api.zuralog.com` configured and DNS propagated
- **Health check** at `/health` verified working
- **Swagger docs** at `/docs` accessible in production
- **All 30 API routes** registered and responding

### Docker & Build Fixes

- Fixed Dockerfile `uv sync` command: changed `--no-editable` to `--no-install-project` to support Docker layer caching (source code is copied after dependency install)
- Added `[build-system]` with hatchling to `pyproject.toml` (required by uv)
- Regenerated `uv.lock` after pyproject.toml change
- Created `.dockerignore` to exclude `.env`, tests, docs, and secrets from Docker image

### Railway Configuration Fix

- Removed `startCommand` from `railway.toml` because Railway's exec-form execution does not expand `$PORT` shell variables. The Dockerfile CMD uses shell form (`CMD uvicorn ... --port ${PORT}`) which correctly expands the variable at container start.

### Database Connectivity

- **Transaction pooler** (`aws-0-us-east-1.pooler.supabase.com:6543`) failed with "Tenant or user not found"
- **Direct connection** (`db.enccjffwpnwkxfkhargr.supabase.co:5432`) failed due to Railway being IPv4-only
- **Session pooler** (`aws-1-us-east-1.pooler.supabase.com:5432`) works correctly — IPv4 proxied, compatible with Alembic migrations

### Alembic Migrations

All 6 migrations applied successfully to production Supabase:
1. `initial_tables`
2. `fix_users_schema`
3. `add_usage_logs_table`
4. `add_user_profile_fields`
5. `add_daily_health_metrics_table`
6. `add_phase6_columns_to_daily_health_metrics`

### Environment Variables

All 26+ environment variables configured in Railway dashboard including:
- Database, Redis, Supabase credentials
- OpenRouter AI/LLM configuration
- Google OAuth client ID/secret
- Strava integration credentials
- Firebase push notification credentials (single-line JSON)
- RevenueCat subscription keys
- Application settings (APP_ENV=production, APP_DEBUG=false)

### Files Created

- `cloud-brain/.dockerignore`

### Files Modified

- `cloud-brain/Dockerfile` — fixed uv sync flags
- `cloud-brain/pyproject.toml` — added build-system
- `cloud-brain/uv.lock` — regenerated
- `cloud-brain/railway.toml` — removed startCommand
- `cloud-brain/RAILWAY_ENV_VARS.md` — updated session pooler host reference
- `cloud-brain/.env` — updated with all current dev credentials

---

## Deviations From Plan

- Originally planned to use Supabase transaction pooler; switched to session pooler after two connection failures. Session pooler is the correct choice for Railway (IPv4 network).
- `startCommand` in railway.toml was expected to work but Railway does not shell-expand variables in exec-form commands. Removed in favor of Dockerfile CMD.

---

## Known Issues

- `POST /api/v1/auth/login` returns 500 Internal Server Error — needs investigation (may be a code bug, not a deployment issue)

---

## Next Steps

- Configure custom domain DNS CNAME in Namecheap (record added, propagation complete)
- Register Strava webhook subscription (curl command ready, needs final URL confirmation)
- Configure RevenueCat webhook URL in RevenueCat dashboard
- Set up Celery Worker service in Railway (deferred)
- Set up Celery Beat service in Railway (deferred)
- Investigate auth login 500 error
- Add Fitbit integration credentials (pending from user)

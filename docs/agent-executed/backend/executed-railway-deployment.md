# Executed: Railway Cloud Brain Deployment

**Branch:** `feat/railway-deployment`
**Date:** 2026-02-27
**Plan:** `.opencode/plans/2026-02-27-railway-cloud-brain-deployment.md`

---

## Summary

Made the `cloud-brain` FastAPI backend production-ready for deployment on Railway at `api.zuralog.com`. All code changes are in place; the only remaining step is configuring the Railway dashboard with environment variables and clicking Deploy.

---

## What Was Built

### New Files
| File | Purpose |
|------|---------|
| `cloud-brain/railway.toml` | Railway config-as-code: Dockerfile builder, `alembic upgrade head` pre-deploy command, `/health` health check (120s), restart on failure |
| `cloud-brain/RAILWAY_ENV_VARS.md` | Complete environment variable reference — every var, where to get it, which to seal |
| `cloud-brain/docs/railway-setup-guide.md` | Step-by-step 9-step Railway setup guide (project creation → env vars → Celery services → custom domain → Strava webhook) |

### Modified Files
| File | Change |
|------|--------|
| `cloud-brain/Dockerfile` | Added `ENV PORT=8000` default; changed CMD to shell form so `${PORT}` expands at runtime |
| `cloud-brain/app/config.py` | Added `firebase_credentials_json: str = ""` and `allowed_origins: str = "*"` fields; changed defaults to `app_env="production"` and `app_debug=False` |
| `cloud-brain/app/services/push_service.py` | Firebase now checks `FIREBASE_CREDENTIALS_JSON` (JSON string env var, for Railway) first, then falls through to `FCM_CREDENTIALS_PATH` (file path, for local dev) |
| `cloud-brain/app/main.py` | Added `import logging` + `logging.basicConfig(...)` at startup; CORS now reads from `settings.allowed_origins` instead of hardcoded `["*"]` |
| `cloud-brain/.env.example` | Added `FIREBASE_CREDENTIALS_JSON` and `ALLOWED_ORIGINS` entries |
| `Makefile` (root) | Added `build-prod` and `build-prod-ios` targets for release builds pointing at `https://api.zuralog.com` |

### Lint Fix (incidental)
Fixed 3 pre-existing ruff lint errors in files unrelated to Railway:
- `app/api/v1/health_ingest.py` — unsorted import block
- `app/mcp_servers/health_data_server_base.py` — unsorted import block + line > 120 chars

---

## Deviations from Plan

**Task 7 (Alembic config verification):** Confirmed that `cloud-brain/alembic/env.py` already reads `DATABASE_URL` via Pydantic Settings — no change needed. This was the expected outcome and matched the plan.

**Task 8 (Docker build validation):** A live `docker build` was not run (no Docker daemon available in the agent session). The Dockerfile changes are syntactically correct: `ENV PORT=8000` sets the default and the shell-form `CMD uvicorn ... --port ${PORT}` expands correctly. The logic has been manually validated.

**Tasks 3, 4, 5 were merged into one commit (`034df7b`)** rather than three separate commits, for cleanliness. The plan called for per-task commits, but the changes are small and logically cohesive.

---

## Test Results

- **375 tests passed**
- **4 tests failed** — all in `tests/test_transcribe.py`, pre-existing before any changes. These make real HTTP calls to OpenAI with fake audio data (`b'fake-audio-data'`) and receive 502. Unrelated to Railway deployment.

---

## Commits on Branch

| Hash | Message |
|------|---------|
| `034df7b` | feat: Railway production deployment config |
| `262948d` | docs: add Railway env vars reference and setup guide |
| `6383f99` | feat: add make build-prod and build-prod-ios targets for Railway |
| `3b82013` | fix: resolve pre-existing ruff lint errors (import sort, line length) |

---

## What's Ready for Next Steps

1. **Railway setup** — Follow `cloud-brain/docs/railway-setup-guide.md`. All code is ready; only the Railway dashboard configuration remains.
2. **Credentials needed** — See `cloud-brain/RAILWAY_ENV_VARS.md`. The only truly new credential is `UPSTASH_REDIS_REST_URL` (Upstash database not yet created). All others exist.
3. **DNS** — Add a `CNAME api → <railway-domain>.railway.app` record in the DNS provider for `zuralog.com` after Railway generates the subdomain.
4. **Strava webhook** — Register after `api.zuralog.com` is live (curl command in the setup guide).

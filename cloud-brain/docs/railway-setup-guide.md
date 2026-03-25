# Railway Setup Guide — Zuralog Cloud Brain

> This guide walks you through deploying `cloud-brain` to Railway at `api.zuralog.com`.
> **Estimated time:** 30 minutes.

---

## Prerequisites

Before starting, ensure you have:

- [ ] Railway account — [railway.com](https://railway.com)
- [ ] GitHub repository connected to Railway
- [ ] Supabase project (already set up — shared with website)
- [ ] Railway Redis service added to project
- [ ] Firebase project with service account JSON downloaded
- [ ] OpenRouter API key
- [ ] Domain `api.zuralog.com` with DNS access (Cloudflare recommended)
- [ ] All values from `RAILWAY_ENV_VARS.md` ready

---

## Step 1: Create the Railway Project

1. Go to [railway.com/new](https://railway.com/new)
2. Click **"Deploy from GitHub Repo"**
3. Authorize Railway and select the **`life-logger`** repository

Railway will create a service. Don't deploy yet.

---

## Step 2: Configure the Web Service (Root Directory)

The `cloud-brain/` backend lives in a subdirectory of the monorepo. Tell Railway where to look:

1. Open the service → **Settings** tab
2. Under **Source → Root Directory**, set: `cloud-brain`
3. Railway will now look for the `Dockerfile` and `railway.toml` inside `cloud-brain/`

Railway automatically reads `railway.toml`, which configures:
- **Builder:** Dockerfile
- **Pre-deploy:** `alembic upgrade head` (runs migrations before traffic cutover)
- **Start:** `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
- **Health check:** `GET /health` with 120s timeout
- **Restart policy:** On failure, up to 5 retries

---

## Step 3: Add Environment Variables

1. Service → **Variables** tab → **RAW Editor**
2. Paste all required variables from `RAILWAY_ENV_VARS.md`
3. **Seal sensitive keys** (click 3-dot menu → Seal):
   - `SUPABASE_SERVICE_KEY`
   - `OPENROUTER_API_KEY`
   - `GOOGLE_WEB_CLIENT_SECRET`
   - `FIREBASE_CREDENTIALS_JSON`
   - `REVENUECAT_API_KEY`
   - `STRAVA_CLIENT_SECRET`

### Minimum required for first deploy:
```
DATABASE_URL=postgresql+asyncpg://...
REDIS_URL=rediss://...
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_KEY=eyJ...
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_MODEL=moonshotai/kimi-k2.5
APP_ENV=production
APP_DEBUG=false
```

---

## Step 4: First Deploy

1. Click **Deploy** (or push a commit to `main`)
2. Watch the **Build Logs**:
   - ✅ `Using detected Dockerfile!`
   - ✅ Builder stage: uv installs dependencies
   - ✅ Runtime stage: copies app code
3. Watch the **Deploy Logs**:
   - ✅ Pre-deploy: `alembic upgrade head` runs all migrations
   - ✅ `Uvicorn running on 0.0.0.0:PORT (Press CTRL+C to quit)`
4. Health check passes → deployment goes live

---

## Step 5: Configure Custom Domain (`api.zuralog.com`)

1. Service → **Settings** → **Networking**
2. Click **"Generate Domain"** — you'll get something like:
   ```
   zuralog-cloud-brain-production.up.railway.app
   ```
3. Click **"+ Custom Domain"** → enter `api.zuralog.com`
4. Railway shows a CNAME record. Add it to your DNS provider:

   | Type  | Name  | Value                                             |
   |-------|-------|---------------------------------------------------|
   | CNAME | `api` | `zuralog-cloud-brain-production.up.railway.app`   |

5. Wait for DNS propagation (seconds with Cloudflare, up to 24h elsewhere)
6. Railway auto-provisions SSL via Let's Encrypt

### Verify:
```bash
curl https://api.zuralog.com/health
# Expected: {"status":"healthy"}

# Check OpenAPI docs:
open https://api.zuralog.com/docs
```

---

## Step 6: Add Celery Worker Service (includes Beat)

The AI background sync, token refresh, and periodic tasks all run in a single Celery service.
Beat is embedded in the worker process via the `--beat` flag, so no separate Beat service is needed.

1. Railway canvas → **"+ New"** → **"GitHub Repo"** → same `life-logger` repo
2. Rename service to **`celery-worker`**
3. Service → **Settings**:
   - **Root Directory:** `cloud-brain`
   - **Start Command:** `celery -A app.worker worker --beat --loglevel=info --concurrency=2`
4. Service → **Variables**: Add the same variables as the web service (use Shared Variables)
5. **No networking** needed (workers don't serve HTTP)

> ⚠️ **Only run ONE instance of the worker.** The embedded Beat scheduler means multiple replicas will cause duplicate periodic task execution.

Check logs for: `celery@hostname ready.` and `beat: Starting...`

---

## Step 7: Register Strava Webhook (Post-Deploy)

After `api.zuralog.com` is live, register the Strava webhook subscription:

```bash
curl -X POST https://www.strava.com/api/v3/push_subscriptions \
  -F client_id=YOUR_STRAVA_CLIENT_ID \
  -F client_secret=YOUR_STRAVA_CLIENT_SECRET \
  -F callback_url=https://api.zuralog.com/api/v1/webhooks/strava \
  -F verify_token=YOUR_STRAVA_WEBHOOK_VERIFY_TOKEN
```

Expected response: `{"id": 12345}` — save this ID.

---

## Step 8: Update Mobile App Production URL

For production builds of the Flutter app:

```bash
# From the repo root:
flutter build appbundle \
  --dart-define=BASE_URL=https://api.zuralog.com \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID
```

Or use `make build-prod` (see root `Makefile`).

---

## Verification Checklist

After full setup:

- [ ] `GET https://api.zuralog.com/health` returns `{"status":"healthy"}`
- [ ] `GET https://api.zuralog.com/docs` loads Swagger UI
- [ ] Alembic migrations ran (check deploy logs for "Running upgrade...")
- [ ] Celery worker logs show `ready` and `beat: Starting...`
- [ ] SSL certificate is valid (green lock in browser)
- [ ] Strava webhook registered (if using Strava)
- [ ] `DELETE https://api.zuralog.com/api/v1/users/me` returns 204 for a valid token (GDPR account deletion)
- [ ] `GET https://api.zuralog.com/api/v1/users/me/export` returns a JSON blob of user data (GDPR data export)

---

## Recent API Changes

### GDPR Endpoints (Art. 17 & 20)

Two user-facing GDPR endpoints were added:

| Method | Path | What it does |
|---|---|---|
| `DELETE` | `/api/v1/users/me` | Deletes **all** user health data and the account itself. Returns `204 No Content`. Also removes the user from Supabase Auth. |
| `GET` | `/api/v1/users/me/export` | Returns all user health data (metrics, activities, sleep, nutrition, weight, goals) as a single JSON download. |

### Health Ingest Validation

`POST /api/v1/health/ingest` now enforces two additional rules:

- **`source` field** must be exactly `"apple_health"` or `"health_connect"`. Any other string returns `422 Unprocessable Entity`.
- **Payload size cap**: a single request may not contain more than 500 total records across all data types. Larger batches should be split client-side. Exceeding the cap returns `422 Unprocessable Entity`.

### Secret Field Handling

`REVENUECAT_API_KEY` and `REVENUECAT_WEBHOOK_SECRET` are now treated as secrets internally (they will no longer appear in logs or error traces). No change is needed to the Railway environment variable values themselves.

---

## Troubleshooting

### Build Fails
- Confirm **Root Directory** is set to `cloud-brain` in Railway settings
- Check that `pyproject.toml` and `uv.lock` are committed (not gitignored)

### Migration Fails (Pre-deploy)
```
FATAL: could not connect to server: Connection refused
```
- Verify `DATABASE_URL` uses `postgresql+asyncpg://` scheme
- Verify Supabase project is active (not paused)
- Confirm the database allows connections from Railway's IP range

### Health Check Fails
```
Error: service unavailable
```
- Check deploy logs for startup errors
- Ensure all required env vars are set (missing vars cause startup crash)
- Increase `healthcheckTimeout` in `railway.toml` if startup is slow

### FCM / Firebase Not Working
```
FCM not configured — push notifications disabled
```
- Verify `FIREBASE_CREDENTIALS_JSON` is set and contains valid JSON
- The JSON must be on a single line (no newlines in the value)
- Check logs for `Failed to initialize FCM from JSON env var`

### CORS Errors in Browser
- Ensure `ALLOWED_ORIGINS` includes the exact origin making the request
- Mobile apps (iOS/Android) don't have CORS restrictions — this only affects web clients

### Celery Workers Not Processing Tasks
- Verify workers and web service have the same `REDIS_URL`
- Check Railway Redis metrics in the Railway dashboard
- Review worker logs for `ConnectionError`

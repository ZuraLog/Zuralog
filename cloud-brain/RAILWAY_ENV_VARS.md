# Railway Environment Variables Reference

> Configure these in the Railway dashboard under **Service → Variables → RAW Editor**.
> Use [**Shared Variables**](https://docs.railway.com/guides/variables#shared-variables) for values that are identical across the `web`, `celery-worker`, and `celery-beat` services.

---

## Required Variables — App Will Not Start Without These

| Variable | Example Value | Where to Get It |
|----------|---------------|-----------------|
| `DATABASE_URL` | `postgresql+asyncpg://user:pass@db.supabase.co:5432/postgres` | Supabase → Settings → Database → URI. **Change scheme from `postgresql://` to `postgresql+asyncpg://`** |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | In Railway, set this to `${{Redis.REDIS_URL}}` to automatically reference the Railway Redis service. Used by Celery broker/backend and rate limiters. |
| `SUPABASE_URL` | `https://xxxxxxxxxxxx.supabase.co` | Supabase → Settings → API → Project URL |
| `SUPABASE_ANON_KEY` | `eyJhbGciOiJIUzI1NiIs...` | Supabase → Settings → API → `anon` / `public` key |
| `SUPABASE_SERVICE_KEY` | `eyJhbGciOiJIUzI1NiIs...` | Supabase → Settings → API → `service_role` key — **⚠️ SEAL THIS** |
| `OPENROUTER_API_KEY` | `sk-or-v1-...` | [openrouter.ai/keys](https://openrouter.ai/keys) — **⚠️ SEAL THIS** |

---

## AI / LLM Settings

| Variable | Recommended Value | Notes |
|----------|-------------------|-------|
| `OPENROUTER_MODEL` | `moonshotai/kimi-k2.5` | LLM model ID on OpenRouter |
| `OPENROUTER_REFERER` | `https://zuralog.app` | Sent as HTTP `Referer` header |
| `OPENROUTER_TITLE` | `Zuralog` | Sent as `X-Title` header |

---

## Google OAuth (Social Sign-In)

| Variable | Example | Where to Get It |
|----------|---------|-----------------|
| `GOOGLE_WEB_CLIENT_ID` | `123456789-abc.apps.googleusercontent.com` | Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Web client |
| `GOOGLE_WEB_CLIENT_SECRET` | `GOCSPX-...` | Same — **⚠️ SEAL THIS** |

---

## Strava Integration

| Variable | Example | Notes |
|----------|---------|-------|
| `STRAVA_CLIENT_ID` | `12345` | Strava → Settings → My API Application |
| `STRAVA_CLIENT_SECRET` | `abc123...` | Same — **⚠️ SEAL THIS** |
| `STRAVA_REDIRECT_URI` | `zuralog://oauth/strava` | Must match your Strava app's callback domain |
| `STRAVA_WEBHOOK_VERIFY_TOKEN` | `randomly-generated-secret` | Generate with: `openssl rand -hex 32` |

---

## Fitbit Integration

The Fitbit app is registered at [dev.fitbit.com](https://dev.fitbit.com) under `developer@zuralog.com` (Server type). Get `FITBIT_CLIENT_ID` and `FITBIT_CLIENT_SECRET` from Bitwarden → **"Fitbit API - Zuralog"**.

| Variable | Example | Notes |
|----------|---------|-------|
| `FITBIT_CLIENT_ID` | `23V3LJ` | From Bitwarden → "Fitbit API - Zuralog" → Username |
| `FITBIT_CLIENT_SECRET` | `7d071f...` | From Bitwarden → "Fitbit API - Zuralog" → Password — **⚠️ SEAL THIS** |
| `FITBIT_REDIRECT_URI` | `zuralog://oauth/fitbit` | Keep this exact value — matches deep link scheme in the Flutter app |
| `FITBIT_WEBHOOK_VERIFY_CODE` | `openssl rand -hex 32` output | Generate once, set here **before** registering the webhook subscription in the Fitbit dashboard |
| `FITBIT_WEBHOOK_SUBSCRIBER_ID` | *(assigned by Fitbit)* | Set after webhook subscription is created in the Fitbit developer portal |

> **Webhook setup order:** Set `FITBIT_WEBHOOK_VERIFY_CODE` first → deploy → then register the subscription in [dev.fitbit.com](https://dev.fitbit.com) → Fitbit will assign a Subscriber ID → set `FITBIT_WEBHOOK_SUBSCRIBER_ID`.

---

## Firebase Push Notifications

| Variable | Value | Notes |
|----------|-------|-------|
| `FIREBASE_CREDENTIALS_JSON` | `{"type":"service_account","project_id":"zuralog",...}` | Firebase Console → Project Settings → Service Accounts → **Generate new private key**. Paste the **entire JSON file content** as a single-line string. — **⚠️ SEAL THIS** |

> **How to flatten JSON to one line (PowerShell):**
> ```powershell
> (Get-Content firebase-service-account.json -Raw) -replace '\s+', ' ' | Set-Clipboard
> ```
> Or use: https://www.freeformatter.com/json-minifier.html

---

## Subscriptions (RevenueCat)

| Variable | Example | Notes |
|----------|---------|-------|
| `REVENUECAT_WEBHOOK_SECRET` | `whsec_...` | RevenueCat Dashboard → Webhooks → Authorization header value |
| `REVENUECAT_API_KEY` | `appl_...` | RevenueCat → API Keys → Secret key — **⚠️ SEAL THIS** |

---

## Application Settings

| Variable | Production Value | Notes |
|----------|-----------------|-------|
| `APP_ENV` | `production` | Enables production-mode behavior |
| `APP_DEBUG` | `false` | **Must be `false`** — prevents SQLAlchemy query logging |
| `ALLOWED_ORIGINS` | `https://zuralog.com,https://www.zuralog.com` | Comma-separated CORS origins for browser clients |
| `PORT` | *(auto-injected by Railway)* | **Do NOT set manually** — Railway injects this |

---

## Optional / Future Variables

| Variable | Purpose | When Needed |
|----------|---------|-------------|
| `PINECONE_API_KEY` | Vector memory for long-term AI context | Phase 2 — deferred |
| `OPENAI_API_KEY` | OpenAI API access for Pinecone embeddings | Required when `PINECONE_API_KEY` is set |
| `FCM_CREDENTIALS_PATH` | Firebase credentials file path | **Not used on Railway** — use `FIREBASE_CREDENTIALS_JSON` instead |

---

## Railway-Specific Tips

### 1. Sealing Sensitive Variables
For all variables marked **⚠️ SEAL THIS**, click the 3-dot menu → **Seal**. Once sealed, the value is never shown in the UI again but is still injected into the container.

### 2. Using Shared Variables
Go to **Project Settings → Shared Variables** and add variables that all three services need (`DATABASE_URL`, `REDIS_URL`, `SUPABASE_*`, `OPENROUTER_*`). Then in each service's Variables tab, click **"+ Shared Variable"** to reference them.

### 3. DATABASE_URL Scheme
Supabase gives you a connection string starting with `postgresql://`. You **must** change this to `postgresql+asyncpg://` for the async SQLAlchemy driver (asyncpg).

```
# Wrong (from Supabase):
postgresql://postgres.xxxx:password@aws-1-us-east-1.pooler.supabase.com:5432/postgres

# Correct (for Railway — use session pooler, not transaction pooler):
postgresql+asyncpg://postgres.xxxx:password@aws-1-us-east-1.pooler.supabase.com:5432/postgres
```

### 4. REDIS_URL — Railway Redis
Railway Redis uses plain `redis://` on the internal network (no TLS required). Set `REDIS_URL` to `${{Redis.REDIS_URL}}` in your service variables — Railway will automatically substitute the correct connection string from the Redis service.

```
# Railway internal (recommended):
redis://default:${{REDISPASSWORD}}@redis.railway.internal:6379

# Or use the reference variable (simplest):
${{Redis.REDIS_URL}}
```

### 5. Firebase JSON — Single Line
Railway env vars don't support multiline values well. You must flatten the Firebase JSON to a single line before pasting:
```bash
# macOS/Linux:
cat firebase-service-account.json | jq -c . | pbcopy

# Windows PowerShell:
(Get-Content firebase-service-account.json -Raw) -replace '\r?\n', '' | Set-Clipboard
```

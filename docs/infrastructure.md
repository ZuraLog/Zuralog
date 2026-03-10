# Zuralog — Infrastructure & Deployment

**Version:** 2.0  
**Last Updated:** 2026-03-01  
**Status:** Living Document

---

## 1. Development Environment

Zuralog uses a **Hybrid Development** approach: application code runs natively on the developer's machine for speed; infrastructure services run in Docker for isolation.

**Why Hybrid?**

| Option | Decision |
|--------|----------|
| **Hybrid (code local + services in Docker)** | ✅ **Chosen** — Fast dev loop, no WSL2 I/O penalty, easy debugging |
| Full Docker (code + services) | ❌ 10–50× slower file I/O on Windows (WSL2 mount penalty), painful hot-reload |
| Nothing (install everything locally) | ❌ "Works on my machine" problems, hard to reproduce |

### Quick Start (Cloud Brain)

```bash
git clone <repo>
docker compose up -d                          # Start Postgres + Redis
uv sync                                       # Create .venv/, install all deps
uv run uvicorn app.main:app --reload          # Start FastAPI dev server
```

### Key Files

| File | Purpose |
|------|---------|
| `cloud-brain/pyproject.toml` | Python version + all dependencies |
| `cloud-brain/uv.lock` | Exact dependency lockfile (deterministic) |
| `cloud-brain/docker-compose.yml` | Local Postgres + Redis containers |
| `cloud-brain/.env.example` | Env var template (never commit `.env`) |
| `cloud-brain/Dockerfile` | Production container build |
| `cloud-brain/Makefile` | Dev commands (`make dev`, `make test`, `make lint`) |
| `cloud-brain/RAILWAY_ENV_VARS.md` | Complete env var reference for Railway deployment |

---

## 2. Production Services

All services used in production, current tier, and purpose:

| Service | Role | Free Tier Limits | Current Cost |
|---------|------|-----------------|--------------|
| **Railway** | Backend hosting (Cloud Brain) | $5 trial credit | ~$5–10/mo |
| **Supabase** | PostgreSQL + Auth + Row Level Security | 500MB DB, 50K MAU | $0 |
| **Railway Redis** | Redis — Celery queue + rate limiting | Flat compute cost | ~$0.50/mo |
| **Pinecone** | Vector DB — AI long-term memory (planned, not active) | 1 index, 100K vectors | $0 |
| **Firebase (FCM)** | Push notifications to mobile | Unlimited | $0 |
| **Sentry** | Error tracking — Cloud Brain + Flutter + Website | 5K events/mo | $0 |
| **PostHog** | Product analytics | 1M events/mo | $0 |
| **RevenueCat** | Subscription billing (App Store + Play Store) | Free until $2.5K MTR | $0 |
| **Codemagic** | Flutter CI/CD (`.ipa` + `.aab` builds) | 500 build-min/mo | $0 |
| **Vercel** | Website hosting | Free | $0 |
| **Vercel Analytics** | Website traffic analytics | Free | $0 |
| **Resend** | Transactional email (waitlist confirmations) | 3K emails/mo | $0 |
| **Cloudflare** | DNS + SSL + CDN + DDoS protection | Unlimited | $0 |

### One-Time / Annual Costs

| Item | Cost | Frequency |
|------|------|-----------|
| Google Play Developer | $25 | One-time |
| Apple Developer Program | $99 | Yearly |
| Domain (zuralog.app) | ~$15 | Yearly |
| **Total Upfront** | ~$140 | |

---

## 3. Deployment Architecture

### 3.1 Cloud Brain → Railway

**Flow:**
1. Push to `main` branch on GitHub
2. Railway auto-detects push, builds `Dockerfile`
3. Blue-green deployment (zero downtime)
4. Health check endpoint validates new instance
5. Old instance retired

**Why Railway:** GitHub auto-deploy, built-in logging, cron support, Docker-native, simple pay-per-compute pricing. Migration path to AWS ECS/Fargate at scale.

### 3.2 Mobile App → App Store / Play Store

**CI/CD:** Codemagic

**Flow:**
1. Push to `main`
2. Codemagic builds `.ipa` (iOS) and `.aab` (Android)
3. Auto-upload to TestFlight + Google Play Internal Testing
4. Manual promotion to production after QA

### 3.3 Website → Vercel

**Flow:**
1. Push to `main`
2. Vercel auto-deploys via Next.js build
3. Preview deployments on PRs
4. Production on `main`

---

## 4. Monitoring & Observability

| Platform | What's Monitored | Config |
|---------|------------------|----|
| **Sentry (Cloud Brain)** | FastAPI exceptions, Celery task failures, slow queries | `sentry-sdk[fastapi,celery,sqlalchemy,httpx]` in pyproject.toml |
| **Sentry (Flutter)** | Dart exceptions, network errors, app crashes | `sentry_flutter` + `sentry_dio` in pubspec.yaml |
| **Sentry (Website)** | Next.js server errors, client errors | `@sentry/nextjs` in package.json |
| **Vercel Analytics** | Website traffic, Core Web Vitals | `@vercel/analytics` |
| **PostHog** | Feature usage, funnel analytics, user journeys | Disabled (env var empty) |

**Sentry Configuration (Cloud Brain):**
- **Zuralog (web):** `sentry_traces_sample_rate: 0.05`, `sentry_profiles_sample_rate: 0` (cost optimization)
- **Celery_Worker:** `sentry_traces_sample_rate: 0.0`, `sentry_profiles_sample_rate: 0.0` (task errors only)
- Integrated with FastAPI middleware, Celery signals, SQLAlchemy

---

## 5. AI & Variable Cost Model

| Service | Model | Cost/User/Month | Notes |
|---------|-------|----------------|-------|
| **Kimi K2.5** | Via OpenRouter (`moonshotai/kimi-k2.5`) | ~$2.16 | Based on ~30 msgs/day/user |
| **OpenAI Embeddings** | `text-embedding-3-small` | ~$0.05 | For Pinecone vector store (planned) |

### Revenue Share (Post-Launch)

| Platform | Commission |
|----------|------------|
| Apple App Store | 15% (Small Business Program, first $1M/yr) |
| Google Play | 15% (first $1M/yr) |
| RevenueCat | Free until $2.5K MTR, then 1% |

### Cost Projections

| Phase | Monthly Infrastructure | LLM Costs | Total |
|-------|----------------------|-----------|----|
| Development (pre-launch) | ~$5 | ~$0 | ~$5 |
| Early Launch (100 users) | ~$10 | ~$216 | ~$226 |
| 100 Paying Users ($9.99/mo) | ~$10 | ~$216 | Revenue: ~$700 net |
| **Net profit at 100 users** | | | **~$474/mo** |

### Cost Risks

1. **LLM costs** — Primary COGS. Scales linearly with message volume. **Mitigation:** Rate limiting per tier, response caching for common queries.
2. **Supabase Pro upgrade** — Required at ~500 active users (> 500MB DB). Cost: $25/mo.
3. **Integration API rate limits** — Not a cost issue, but operational. **Mitigation:** Intelligent caching, webhook-driven sync over polling, per-provider rate limiters in Redis.

---

## 5.5 Infrastructure Optimization (2026-03-10)

**Completed:** Upstash Redis removal, Celery_Beat service consolidation, observability cost reduction.

### Changes

**Redis Migration**
- Removed Upstash Redis entirely. All three services (Zuralog, Celery_Worker, Celery_Beat) now use Railway-native Redis at `redis.railway.internal:6379`.
- New `Redis` service provisioned in the Railway project.
- Cost reduction: Upstash ~$2.50/mo → Railway Redis ~$0.50/mo.

**Celery_Beat Consolidation**
- Deleted the standalone `Celery_Beat` service.
- Beat (periodic task scheduler) merged into `Celery_Worker` via the `--beat` flag.
- Worker now runs: `celery -A app.worker worker --beat --loglevel=info --concurrency=2`
- Cost reduction: 1 fewer service instance.

**Safety Constraint**
- Beat merged into Worker is **only safe with a single Worker replica**. If Worker scales to 2+ replicas, Beat must be split back to a dedicated service to prevent duplicate task execution.
- This constraint is documented in the Worker service configuration.

**Observability Cost Reduction**
- Zuralog (web): `SENTRY_TRACES_SAMPLE_RATE=0.05` (5% sampling), `SENTRY_PROFILES_SAMPLE_RATE=0` (disabled)
- Celery_Worker: `SENTRY_TRACES_SAMPLE_RATE=0.0`, `SENTRY_PROFILES_SAMPLE_RATE=0.0` (task errors only, no tracing)
- PostHog: `POSTHOG_API_KEY=` (disabled)

**Code Changes (commit `eed860f`)**
- Beat schedule: Fixed broken task names, removed stub tasks, extended 4 sync intervals from 15min to 60min (Fitbit, Oura, Withings, Polar), replaced raw float schedules with `crontab()` for weekly/monthly reports, added `celery-redbeat>=2.2.0` with `RedBeatScheduler` for crash-safe schedule persistence.
- Database: NullPool for all Celery worker tasks, reduced FastAPI connection pool from 10+20 to 2+3, all task files use `worker_async_session`.
- Task cleanup: Removed 3 dead Fitbit API calls (HR, SpO2, HRV), lazy Firebase initialization.
- FastAPI startup: All 7 integrations guarded on credential env vars, `CeleryIntegration` removed from Sentry init, `/health` excluded from Sentry middleware.
- Image size: Replaced `numpy` with stdlib `statistics` (−50MB), removed `psycopg2-binary` (−10MB), fixed `_get_release()` to read `RAILWAY_GIT_COMMIT_SHA` env var, pinned uv to `0.10.9`, added `--timeout-keep-alive 15` to uvicorn.

**Cost Impact**
- Before: ~$3.48/mo (Upstash + Sentry + 3 services)
- After: ~$0.95/mo (Railway Redis ~$0.50 + Sentry 5% sample rate + 2 services)
- **Savings: ~$2.53/mo (73% reduction)**

---

## 6. Environment Variables Reference

See `cloud-brain/RAILWAY_ENV_VARS.md` for the complete list of all env vars required for production deployment. Key categories:

| Category | Variables |
|----------|---------|
| Database | `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY` |
| Redis | `REDIS_URL` |
| LLM | `OPENROUTER_API_KEY`, `OPENROUTER_MODEL` (default: `moonshotai/kimi-k2.5`) |
| Auth | `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_WEB_CLIENT_SECRET` |
| Strava | `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`, `STRAVA_WEBHOOK_VERIFY_TOKEN` |
| Fitbit | `FITBIT_CLIENT_ID`, `FITBIT_CLIENT_SECRET`, `FITBIT_WEBHOOK_VERIFY_CODE`, `FITBIT_WEBHOOK_SUBSCRIBER_ID` |
| Notifications | `FCM_CREDENTIALS_PATH` or `FIREBASE_CREDENTIALS_JSON` |
| Subscriptions | `REVENUECAT_WEBHOOK_SECRET`, `REVENUECAT_API_KEY` |
| Monitoring | `SENTRY_DSN` |
| AI (planned) | `PINECONE_API_KEY`, `OPENAI_API_KEY` |

---

## 7. System Architecture Diagram

```mermaid
graph TD
    subgraph "Developer Machine"
        A[Python + uv] --> B[Docker Compose\nPostgres + Redis]
        C[Flutter SDK\nEmulator/Device]
    end

    subgraph "Production: Backend"
        D[Railway\nCloud Brain] --> E[Supabase\nPostgres + Auth]
        D --> F[Railway\nRedis]
        D --> G[Pinecone\nVectors - planned]
        D --> H[OpenRouter\nKimi K2.5]
        D --> I[Firebase\nFCM]
        D --> J[Sentry\nErrors]
        D --> K[Railway\nCelery_Worker + Beat]
    end

    subgraph "Production: Mobile"
        L[Codemagic\nCI/CD] --> M[App Store]
        L --> N[Play Store]
        O[RevenueCat] --> M
        O --> N
    end

    subgraph "Production: Website"
        P[Vercel] --> Q[Supabase\nWaitlist]
        P --> R[Resend\nEmail]
        P --> S[reCAPTCHA v2\nAbuse Protection]
        P --> T[Vercel Analytics]
        P --> U[Sentry]
    end
```

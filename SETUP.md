# Zuralog — Developer Setup Guide

> **Security Notice — Read Before Filling In Any Values**
> This document is a **setup guide with placeholder values only**. Do **not** paste real API keys, secrets, or credentials into this file. All shared production credentials for this project live in **Bitwarden** — search for `"Zuralog"` in the shared team vault. If a credential is not in Bitwarden, ask the project owner to add it there before sharing it any other way. Never share secrets in chat, email, or comments.

Get the Cloud Brain (backend), Edge Agent (mobile), and Website (Next.js) running locally from a fresh clone.

## Prerequisites

Install the following before proceeding:

| Tool | Version | Install | Used By |
|---|---|---|---|
| **Python** | 3.12+ | [python.org/downloads](https://www.python.org/downloads/) | Cloud Brain |
| **uv** | Latest | `pip install uv` or [docs.astral.sh/uv](https://docs.astral.sh/uv/getting-started/installation/) | Cloud Brain |
| **Docker Desktop** | Latest | [docs.docker.com/desktop](https://docs.docker.com/desktop/setup/install/windows-install/) | Cloud Brain |
| **Flutter SDK** | 3.32+ (Dart 3.11+) | [docs.flutter.dev/install/manual](https://docs.flutter.dev/install/manual) | Edge Agent |
| **Android Studio** | Latest | [developer.android.com/studio](https://developer.android.com/studio) (needed for Android SDK, Emulator, and Java) | Edge Agent |
| **Node.js** | 20 LTS+ | [nodejs.org](https://nodejs.org/) | Website |
| **GNU Make** | 4.4+ | Pre-installed on macOS/Linux. Windows: `scoop install make` (recommended) — see [`make` not found](#make-not-found) | Cloud Brain / Edge Agent |

After installing Flutter, run `flutter doctor` to verify your setup and accept any Android SDK licenses.

> **Android minSdk is 28 (Android 9).** This is required by the Health Connect API. Emulators and physical test devices must run Android 9 or later.

---

## 1. Clone the Repository

```bash
git clone https://github.com/hyowonbernabe/Life-Logger.git
cd Life-Logger
```

---

## 2. Cloud Brain (Backend)

> **Terminal to use:**
> - **Windows** — Git Bash (not PowerShell). In AntiGravity, click the **`+`** dropdown next to your terminal tabs → select **"Git Bash"**. `make` must be installed separately first — see [`make` not found](#make-not-found) below.
> - **macOS** — Terminal or iTerm2. `make` is pre-installed.
> - **Linux** — Any shell (bash/zsh). `make` is pre-installed on most distros; if not, run `sudo apt install make` (Debian/Ubuntu) or `sudo dnf install make` (Fedora).

All commands in this section are run from the `cloud-brain/` directory unless noted.

### 2a. Start Docker Services (PostgreSQL + Redis)

Make sure Docker Desktop is running, then:

```bash
cd cloud-brain
docker compose up -d
```

This starts four containers: `zuralog-postgres` (port 5432), `zuralog-redis` (port 6379), `zuralog-celery-worker`, and `zuralog-celery-beat`. For initial development you only need Postgres and Redis healthy.

Verify the containers are running:

```bash
docker compose ps
```

You should see `zuralog-postgres` and `zuralog-redis` with status `healthy`. The two Celery containers will start once both datastores are healthy.

Makefile shortcut (equivalent):

```bash
make docker-up   # start
make docker-down # stop
```

### 2b. Install Python Dependencies

```bash
uv sync --all-extras
```

This installs all production and dev dependencies into a `.venv` virtual environment.

### 2c. Create Your `.env` File

```bash
# Windows
copy .env.example .env

# macOS/Linux
cp .env.example .env
```

Open `.env` and fill in credentials for each service below.

#### Required: Supabase (Auth)

| Variable | Where to find it | Description |
|---|---|---|
| `DATABASE_URL` | **Keep default** | Points to your local Docker Postgres |
| `REDIS_URL` | **Keep default** | Points to your local Docker Redis |
| `SUPABASE_URL` | Supabase → Project Settings → API → Project URL | e.g., `https://xxxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase → Project Settings → API → `anon` `public` | JWT token starting with `eyJ...` |
| `SUPABASE_SERVICE_KEY` | Supabase → Project Settings → API → `service_role` `secret` | Starts with `sb_secret_...` |

> **⚠️ Warning:** The `SUPABASE_SERVICE_KEY` has **full admin access** to your Supabase project. Never commit it to Git, share it in chat, or expose it client-side. The `.gitignore` already excludes `.env` files.

**Team strategy:** The project uses a hybrid database approach — local Docker Postgres for application data, Supabase for auth (GoTrue) only. For team development you have two options:

1. **Shared dev project** (simpler): All developers use the same Supabase project URL and anon key. Distribute keys securely via **Bitwarden**.
2. **Individual free-tier projects** (isolated): Each developer creates their own free Supabase project. Free tier is more than enough for development.

#### Required: Google OAuth (Social Sign-In)

Google Sign-In uses a **Web Application** OAuth 2.0 client from Google Cloud Console. This is distinct from Firebase — Firebase (used for push notifications) does not provide the OAuth credentials needed for Sign-In.

| Variable | Where to find it | Description |
|---|---|---|
| `GOOGLE_WEB_CLIENT_ID` | [console.cloud.google.com](https://console.cloud.google.com) → project `zuralog-8311a` → APIs & Services → Credentials → Web Application client | Ends in `.apps.googleusercontent.com` |
| `GOOGLE_WEB_CLIENT_SECRET` | Same credentials page → Client Secret | Starts with `GOCSPX-` |

> **⚠️ Note:** The client secret lives only in `cloud-brain/.env` (gitignored). Never commit it.

**Supabase setup (one-time, already done):**
- Supabase Dashboard → Authentication → Providers → Google → Enable → paste Web Client ID + Secret.

**Flutter setup:**
- The Flutter app reads `GOOGLE_WEB_CLIENT_ID` at build time via `--dart-define`. Use `make run` (see Section 3e) — it injects this automatically from `cloud-brain/.env`. Do **not** use bare `flutter run` if you need Google Sign-In to work.

#### Required: OpenRouter (AI Brain)

The AI agent uses [OpenRouter](https://openrouter.ai/) to call `moonshotai/kimi-k2.5`.

| Variable | Where to find it |
|---|---|
| `OPENROUTER_API_KEY` | [openrouter.ai/keys](https://openrouter.ai/keys) — create a free account and generate a key |

The other `OPENROUTER_*` variables (`REFERER`, `TITLE`, `MODEL`) have sensible defaults and do not need to be changed.

#### Optional: OpenAI (Embeddings / Fallback LLM)

Used for vector embeddings and as an LLM fallback. You can skip this during initial setup — the backend will start without it and features that require it will return errors until a key is provided.

| Variable | Where to find it |
|---|---|
| `OPENAI_API_KEY` | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |

#### Required: Fitbit Integration

Fitbit OAuth is fully implemented (OAuth 2.0 + PKCE) with 12 MCP tools and webhook support. The Fitbit API application is already registered at [dev.fitbit.com](https://dev.fitbit.com) under the `developer@zuralog.com` Google account as a **Server** app. You do not need to register a new application.

Get the credentials from Bitwarden (search **"Fitbit API - Zuralog"**) and copy them into `.env`:

| Variable | Description |
|---|---|
| `FITBIT_CLIENT_ID` | From Bitwarden → "Fitbit API - Zuralog" → Username |
| `FITBIT_CLIENT_SECRET` | From Bitwarden → "Fitbit API - Zuralog" → Password — **never commit** |
| `FITBIT_REDIRECT_URI` | Keep default: `zuralog://oauth/fitbit` |
| `FITBIT_WEBHOOK_VERIFY_CODE` | Only needed when registering the webhook subscription (production) |
| `FITBIT_WEBHOOK_SUBSCRIBER_ID` | Assigned by Fitbit after webhook registration (production) |

> **Note:** `FITBIT_WEBHOOK_VERIFY_CODE` and `FITBIT_WEBHOOK_SUBSCRIBER_ID` are not required for local development — leave them empty. They are only needed when setting up the live webhook endpoint on Railway.

#### Coming Soon: Oura Ring Integration

> **Blocked — hardware required.** The Oura integration code is fully implemented (OAuth 2.0, 16 MCP tools, webhooks, Celery sync), but registering an Oura OAuth application requires an active Oura account, which requires owning an Oura Ring. The feature appears as **Coming Soon** in the app until credentials are available.

**When the ring arrives, complete these steps:**

1. Set up the ring in the Oura app and create your account.
2. Sign in at [cloud.ouraring.com/oauth/applications](https://cloud.ouraring.com/oauth/applications).
3. Create a new application — name: `Zuralog`, redirect URI: `zuralog://oauth/oura`.
4. Save the Client ID and Client Secret to Bitwarden under **"Oura API - Zuralog"**.
5. Copy the credentials into `cloud-brain/.env`:

| Variable | Description |
|---|---|
| `OURA_CLIENT_ID` | From the Oura developer portal → your application → Client ID |
| `OURA_CLIENT_SECRET` | From the Oura developer portal → Client Secret — **never commit** |
| `OURA_REDIRECT_URI` | Keep default: `zuralog://oauth/oura` |
| `OURA_WEBHOOK_VERIFICATION_TOKEN` | Chosen by you when creating webhook subscriptions (production) |
| `OURA_USE_SANDBOX` | Set to `true` to use Oura sandbox endpoints during development |

> **Note:** `OURA_WEBHOOK_VERIFICATION_TOKEN` is only needed when registering webhook subscriptions in production. Leave it empty for local development. `OURA_USE_SANDBOX=true` routes all data fetches to `/v2/sandbox/usercollection/` — useful for smoke-testing the integration without real ring data.

#### Deferred: Strava Integration

Strava OAuth is implemented. Registration of the Strava API application is not required for core local development. When you are ready to test Strava:

1. Go to [strava.com/settings/api](https://www.strava.com/settings/api) and create an API application.
2. Set the **Authorization Callback Domain** to `localhost` (for development).
3. Copy the **Client ID** and **Client Secret** into `.env`.

> **Note:** You (the developer) register one Strava API application. Users just log in via OAuth using the app's credentials. The `STRAVA_REDIRECT_URI` default (`zuralog://oauth/strava`) is a deep link handled by the Flutter app.

| Variable | Description |
|---|---|
| `STRAVA_CLIENT_ID` | Your Strava API application's numeric Client ID |
| `STRAVA_CLIENT_SECRET` | Your Strava API application's Client Secret |
| `STRAVA_REDIRECT_URI` | Keep default: `zuralog://oauth/strava` |

Firebase is required for the Flutter app to build. `google-services.json` and `GoogleService-Info.plist` are already committed to the repo — you get them automatically from `git clone`. The service account JSON (backend push notifications) is a private key and must be shared securely between developers.

**One-time project setup (already done — for reference only):**

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com/) using a `@zuralog.com` Google account
2. Add an **Android** app (package: `com.zuralog.zuralog`) → download `google-services.json` → place at `zuralog/android/app/google-services.json`
3. Add an **iOS** app (bundle ID: `com.zuralog.zuralog`) → download `GoogleService-Info.plist` → place at `zuralog/ios/Runner/GoogleService-Info.plist`
4. Project Settings → **Service accounts** tab → **Generate new private key** → rename to `firebase-service-account.json` → place at `cloud-brain/firebase-service-account.json`
5. Set `FCM_CREDENTIALS_PATH` in `.env` (see below)

**What each developer needs to do:**

- `google-services.json` and `GoogleService-Info.plist` — already in Git, no action needed
- `firebase-service-account.json` — share securely via **Bitwarden**. Place at `cloud-brain/firebase-service-account.json`. This file is gitignored and must never be committed.
- Set in `cloud-brain/.env`:

```
FCM_CREDENTIALS_PATH=firebase-service-account.json
```

> **⚠️ Note:** `firebase-service-account.json` is a private key with admin access to Firebase. Never commit it to Git or share it publicly. The `.gitignore` already excludes it.

#### Deferred: Pinecone (Vector Memory)

Used for long-term vector memory. Not required for local development.

| Variable | Where to find it |
|---|---|
| `PINECONE_API_KEY` | [app.pinecone.io](https://app.pinecone.io/) → API Keys |

#### Deferred: RevenueCat (Subscriptions)

Used for in-app purchase webhooks. Not required for local development.

| Variable | Where to find it |
|---|---|
| `REVENUECAT_WEBHOOK_SECRET` | RevenueCat Dashboard → Webhooks → Auth Header |
| `REVENUECAT_API_KEY` | RevenueCat Dashboard → API Keys → Secret key (starts with `sk_`) |

#### Optional: PostHog (Analytics)

PostHog captures backend events (API requests, auth, health ingest, chat, integrations, subscriptions). When `POSTHOG_API_KEY` is empty the service starts normally and all analytics calls are silent no-ops — no errors, no crashes.

| Variable | Value |
|---|---|
| `POSTHOG_API_KEY` | `phc_<your-posthog-project-api-key>` (shared project key) |
| `POSTHOG_HOST` | `https://us.i.posthog.com` |

> **Production (Railway):** These are already set on all three services (Zuralog, Celery_Worker, Celery_Beat). No Railway action needed.

#### Required: Sentry (Error Monitoring)

The Cloud Brain sends errors and performance traces to Sentry. The DSN is already filled in `.env.example` — copy it across when you run `cp .env.example .env`. No account setup needed for local dev; events will appear in the `cloud-brain` project at [zuralog.sentry.io](https://zuralog.sentry.io).

| Variable | Value (local dev) |
|---|---|
| `SENTRY_DSN` | Pre-filled in `.env.example` |
| `SENTRY_TRACES_SAMPLE_RATE` | `1.0` (100% locally; set to `0.2` in Railway prod) |
| `SENTRY_PROFILES_SAMPLE_RATE` | `0.25` (25% locally; set to `0.1` in Railway prod) |

### 2d. Run Database Migrations

```bash
uv run alembic upgrade head
```

This creates the `users`, `integrations`, and related tables in your local PostgreSQL.

### 2e. Start the Dev Server

```bash
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
```

Or use the Makefile shortcut:

```bash
make dev
```

> **Why port 8001?** Port 8000 is reserved by the `workspace-mcp` service on developer machines. The Cloud Brain uses 8001 to avoid conflicts.
>
> **`--host 0.0.0.0` is required** so the Android emulator can reach the server via `http://10.0.2.2:8001`. Binding to `127.0.0.1` only (the default) will make the emulator unable to connect.

### 2f. Verify It Works

Open [http://localhost:8001/health](http://localhost:8001/health) in your browser. You should see:

```json
{"status": "healthy"}
```

Full interactive API docs (Swagger UI) are available at [http://localhost:8001/docs](http://localhost:8001/docs).

All API routes are under the `/api/v1` prefix (e.g., `/api/v1/auth/login`, `/api/v1/chat/message`).

### 2g. Run Backend Tests

```bash
uv run pytest tests/ -v
```

Makefile shortcut:

```bash
make test
```

### 2h. Lint and Format

```bash
make lint     # ruff check + format check (read-only)
make format   # auto-fix formatting with ruff
```

---

## 3. Edge Agent (Flutter Mobile App)

> **Terminal to use:** Same as Section 2 — Windows: Git Bash; macOS: Terminal/iTerm2; Linux: any shell.

All commands in this section are run from the **project root** (`Life-Logger/`) unless noted.

> `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are already committed to the repo — you get them from `git clone`. No action needed.

### 3a. Install Flutter Dependencies

```bash
cd zuralog
flutter pub get
```

### 3b. Run Drift Code Generation

The local SQLite database uses Drift, which requires a one-time code generation step:

```bash
dart run build_runner build --delete-conflicting-outputs
```

> **Note:** Re-run this command whenever you modify Drift table definitions or Riverpod annotated providers.

### 3c. Run Flutter Analysis

```bash
flutter analyze
```

This should report **No issues found**. The project enforces a zero-warning policy — all warnings are treated as errors.

### 3d. Run Flutter Tests

```bash
flutter test
```

273 tests pass across unit, widget, and provider layers. 8 pre-existing failures in `test/features/dashboard/presentation/dashboard_screen_test.dart` are known — they relate to pending fake timers in the `RealMetricDataRepository` and do not affect production behavior.

### 3e. Launch on an Emulator

1. Open Android Studio → **Virtual Device Manager** → create and start an Android emulator running **API 28 or higher** (Android 9+)
2. Confirm the emulator is visible:

```bash
flutter devices
```

3. Run the app using `make` from the project root (required for Google Sign-In):

```bash
# From Life-Logger/ (project root)
make run          # Android emulator
make run-ios      # iOS Simulator
make run-device   # Physical device (update IP in Makefile first)
```

> **Why `make run` instead of `flutter run`?** The app requires `GOOGLE_WEB_CLIENT_ID` and `SENTRY_DSN` to be injected at build time via `--dart-define`. `make run` reads both automatically from `cloud-brain/.env` and passes them through. Bare `flutter run` skips this — Google Sign-In will return a null token and Sentry will be disabled.

You should see the **Zuralog Welcome screen** — the animated entry screen with the Zuralog logo.

> **PostHog analytics in debug builds:** Analytics is disabled by default in `kDebugMode` to prevent test events polluting production data. To enable it locally (e.g., when verifying event instrumentation), add `--dart-define=ENABLE_ANALYTICS=true` to your `flutter run` command or `make` target.

From there you can proceed through onboarding and log in. The auth guard will redirect authenticated users directly to the Dashboard on subsequent launches.

**Screen map (post Phase 2.2):**

| Screen | Route | Notes |
|---|---|---|
| Welcome | `/welcome` | Entry point, animated logo |
| Onboarding | `/onboarding` | 2-page PageView for new users |
| Login | `/auth/login` | Email + password |
| Register | `/auth/register` | Email + password |
| Dashboard | `/dashboard` | Home tab — activity rings, metrics, AI insight |
| Coach Chat | `/chat` | AI Coach tab — WebSocket chat |
| Integrations | `/integrations` | Apps tab — connect Strava, Apple Health, etc. |
| Settings | `/settings` | Pushed over shell — theme, subscription, logout |

### 3f. Configuring the API URL

The app connects to `http://10.0.2.2:8001` by default — `10.0.2.2` is the Android emulator's alias for the host machine's `localhost`. The WebSocket URL is derived automatically (`ws://10.0.2.2:8001`).

Override for different environments using `make`:

```bash
make run-ios     # iOS Simulator — uses http://localhost:8001
make run-device  # Physical device — update BASE_URL in Makefile to your LAN IP first
```

Or manually if needed:

```bash
# iOS Simulator
flutter run --dart-define=BASE_URL=http://localhost:8001 \
            --dart-define=GOOGLE_WEB_CLIENT_ID=<your-web-client-id> \
            --dart-define=SENTRY_DSN=<sentry-dsn> \
            --dart-define=APP_ENV=development

# Physical device
flutter run --dart-define=BASE_URL=http://192.168.1.100:8001 \
            --dart-define=GOOGLE_WEB_CLIENT_ID=<your-web-client-id> \
            --dart-define=SENTRY_DSN=<sentry-dsn> \
            --dart-define=APP_ENV=development
```

> Make sure the backend server is bound to `0.0.0.0:8001` (not `127.0.0.1`) so it is reachable from the emulator.

### 3g. VS Code / AntiGravity Launch Configs

A `.vscode/launch.json` is automatically available if you open the project in AntiGravity (or VS Code). It is **gitignored** — each developer has their own local copy with their own credentials.

The file is pre-populated at `.vscode/launch.json` with three configurations:

| Configuration | Use case |
|---|---|
| **Zuralog (Android Emulator)** | Default — hits `http://10.0.2.2:8001` |
| **Zuralog (iOS Simulator)** | Uses `http://localhost:8001` |
| **Zuralog (Physical Device)** | Update `BASE_URL` IP to your machine's LAN address |

All three configurations have `GOOGLE_WEB_CLIENT_ID` and `SENTRY_DSN` pre-filled. Press **F5** to launch.

> If `.vscode/launch.json` is missing (e.g., fresh clone), create it manually or run `make run` from the terminal instead.

---

## 4. Website (Next.js)

> The website is a separate Next.js application at `website/` in the monorepo. It is deployed to Vercel and live at [https://www.zuralog.com](https://www.zuralog.com). You only need this section if you are working on the marketing site / waitlist page.

All commands in this section are run from the `website/` directory unless noted.

### 4a. Install Node.js Dependencies

```bash
cd website
npm install
```

### 4b. Create Your `.env.local` File

```bash
# Windows
copy .env.example .env.local

# macOS/Linux
cp .env.example .env.local
```

Open `.env.local` and fill in the values below.

#### Required: Supabase

The website uses the **same Supabase project** as the backend (`enccjffwpnwkxfkhargr`).

| Variable | Where to find it | Description |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase → Project Settings → API → Project URL | e.g., `https://enccjffwpnwkxfkhargr.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase → Project Settings → API → `anon public` | JWT starting with `eyJ...` |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase → Project Settings → API → `service_role` | Starts with `sb_secret_...` |

> **⚠️ Warning:** `SUPABASE_SERVICE_ROLE_KEY` has full admin access. Never expose it client-side or commit it to Git. It is used only in server-side API routes.

#### Required: Site URL

| Variable | Local value | Production value |
|---|---|---|
| `NEXT_PUBLIC_SITE_URL` | `http://localhost:3000` | `https://www.zuralog.com` |

#### Optional: Analytics (PostHog)

PostHog tracking is wired but gracefully skipped when any key is absent. Three variables are required — two for the client-side SDK (`NEXT_PUBLIC_*`) and one for the server-side Node.js client used in API routes.

| Variable | Value |
|---|---|
| `NEXT_PUBLIC_POSTHOG_KEY` | `phc_<your-posthog-project-api-key>` |
| `NEXT_PUBLIC_POSTHOG_HOST` | `https://us.i.posthog.com` |
| `POSTHOG_API_KEY` | `phc_<your-posthog-project-api-key>` (same key, no prefix — used server-side in API routes) |

> **Vercel (production):** All three variables must be set in the Vercel dashboard → Project Settings → Environment Variables. They are **not** auto-deployed from `.env.local`.

#### Required: Sentry (Error Monitoring)

The website sends client-side errors, server errors, and performance data to Sentry. Values are pre-filled in `.env.local` — no extra steps needed for local dev.

| Variable | Value (local dev) |
|---|---|
| `NEXT_PUBLIC_SENTRY_DSN` | Pre-filled in `.env.local` |
| `SENTRY_DSN` | Pre-filled in `.env.local` |
| `SENTRY_ORG` | `zuralog` |
| `SENTRY_PROJECT` | `website` |
| `SENTRY_AUTH_TOKEN` | Pre-filled in `.env.local` and `website/.env.sentry-build-plugin` |

> **Note:** `SENTRY_AUTH_TOKEN` is an org-level CI token. It is gitignored. Source map uploads only run during `npm run build` when `SENTRY_AUTH_TOKEN` is present.

#### Required: Email & Rate Limiting (Waitlist)

Used for the waitlist signup flow (Resend for transactional emails, Upstash Redis for rate limiting). Both are implemented and required for the waitlist to function locally.

| Variable | Where to find it |
|---|---|
| `RESEND_API_KEY` | [resend.com](https://resend.com) → API Keys (free tier: 100 emails/day) |
| `UPSTASH_REDIS_REST_URL` | [console.upstash.com](https://console.upstash.com) → Redis database → REST URL |
| `UPSTASH_REDIS_REST_TOKEN` | Same page → REST Token |

### 4c. Start the Dev Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). Hot reload is enabled — edits to `src/` apply instantly.

> The website dev server does **not** depend on Docker, the Cloud Brain, or the Flutter emulator. It runs fully independently.

### 4d. Verify It Works

- [http://localhost:3000](http://localhost:3000) — landing page with waitlist, 3D hero, and marketing sections
- No console errors in browser DevTools
- If you see a blank page, check that `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` are set in `.env.local`

### 4e. Lint and Type-Check

```bash
# ESLint
npm run lint

# TypeScript (type-check without emitting output)
npx tsc --noEmit
```

The project enforces a zero-warning policy. All lint warnings should be treated as errors.

### 4f. Build for Production (local verification)

```bash
npm run build
npm run start    # serves the production build at http://localhost:3000
```

Run this before opening a PR that touches `website/` to confirm there are no build errors.

### 4g. Deployment

The website deploys automatically via Vercel on every push to `main`. The Vercel project is configured with:

- **Root Directory:** `website`
- **Build Command:** `npm run build` (Vercel default)
- **Output Directory:** `.next` (Vercel default)
- **Node.js Version:** 20.x

All environment variables are set in the Vercel dashboard → Project Settings → Environment Variables. You do **not** need to push `.env.local`.

| Variable | Notes |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | |
| `SUPABASE_SERVICE_ROLE_KEY` | |
| `NEXT_PUBLIC_SITE_URL` | Set to `https://www.zuralog.com` |
| `NEXT_PUBLIC_POSTHOG_KEY` | PostHog client-side SDK key |
| `NEXT_PUBLIC_POSTHOG_HOST` | `https://us.i.posthog.com` |
| `POSTHOG_API_KEY` | PostHog server-side key (same value as `NEXT_PUBLIC_POSTHOG_KEY`) |
| `NEXT_PUBLIC_SENTRY_DSN` | |
| `SENTRY_DSN` | |
| `SENTRY_ORG` | `zuralog` |
| `SENTRY_PROJECT` | `website` |
| `SENTRY_AUTH_TOKEN` | Source map upload token — gitignored, set only in Vercel |
| `RESEND_API_KEY` | Transactional email for waitlist |
| `UPSTASH_REDIS_REST_URL` | Rate limiting |
| `UPSTASH_REDIS_REST_TOKEN` | Rate limiting |

### 4h. Design System

The website uses the **"Bold Convergence"** design system:

| Token | Value |
|---|---|
| Background (dark) | `#000000` OLED black |
| Background (light) | `#FAFAFA` |
| Surface (dark) | `#1C1C1E` |
| Surface (light) | `#FFFFFF` |
| Primary (Sage Green) | `#CFE1B9` |
| Display font | Satoshi Variable (`public/fonts/Satoshi-Variable.woff2`) |
| Body font | Inter (Google Fonts via `next/font`) |
| Mono font | JetBrains Mono (Google Fonts via `next/font`) |

All tokens are defined as CSS variables in `src/app/globals.css` using Tailwind v4's `@theme inline`. Never hardcode hex values in component files — always reference `var(--color-*)` or Tailwind utility classes.

---

## 5. Production Deployment (Railway)

The Cloud Brain backend deploys to Railway at `api.zuralog.com`. All deployment configuration is in `cloud-brain/`.

### One-time deploy

1. Connect the `life-logger` GitHub repo to Railway
2. Set the service **Root Directory** to `cloud-brain`
3. Railway auto-detects `railway.toml` which configures:
   - Builder: Dockerfile
   - Pre-deploy: `alembic upgrade head` (runs migrations before the new deployment goes live)
   - Start: `uvicorn app.main:app --host 0.0.0.0 --port ${PORT}`
   - Health check: `/health`
4. Add all environment variables (see `cloud-brain/RAILWAY_ENV_VARS.md`)
5. Add separate services for `Celery_Worker` and `Celery_Beat`:
   - Same GitHub repo + root directory (`cloud-brain`) as the web service
   - In each service: **Settings → Source → Config File Path** →
     - Worker: `cloud-brain/railway.celery-worker.toml`
     - Beat: `cloud-brain/railway.celery-beat.toml`
   - The config files set the correct start commands and disable the HTTP healthcheck automatically — no dashboard overrides needed
6. Add CNAME `api → <railway-domain>.railway.app` in your DNS provider

For the full step-by-step guide including domain setup, Celery services, and Strava webhook registration, see:
- **[`cloud-brain/docs/railway-setup-guide.md`](./cloud-brain/docs/railway-setup-guide.md)** — step-by-step Railway setup
- **[`cloud-brain/RAILWAY_ENV_VARS.md`](./cloud-brain/RAILWAY_ENV_VARS.md)** — every env var, where to get it, which to seal

### Production build commands

```bash
# Build Android App Bundle pointing at production API
make build-prod

# Build iOS IPA pointing at production API
make build-prod-ios
```

### Key differences from local dev

| Concern | Local | Production (Railway) |
|---------|-------|----------------------|
| Firebase credentials | `FCM_CREDENTIALS_PATH=firebase-service-account.json` (file) | `FIREBASE_CREDENTIALS_JSON={"type":"service_account",...}` (JSON string) |
| CORS origins | `ALLOWED_ORIGINS=*` | `ALLOWED_ORIGINS=https://zuralog.com,https://www.zuralog.com` |
| Debug mode | `APP_DEBUG=true` | `APP_DEBUG=false` |
| Migrations | `make migrate` (manual) | Auto-run as pre-deploy command |

---

## Quick Reference

### Cloud Brain (`cloud-brain/`)

| Action | Command |
|---|---|
| Start Docker services | `docker compose up -d` — or `make docker-up` |
| Stop Docker services | `docker compose down` — or `make docker-down` |
| Install Python deps | `uv sync --all-extras` |
| Apply migrations | `uv run alembic upgrade head` — or `make migrate` |
| Create new migration | `uv run alembic revision --autogenerate -m "description"` — or `make migration msg="description"` |
| Start backend server | `uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8001` — or `make dev` |
| Run backend tests | `uv run pytest tests/ -v` — or `make test` |
| Lint backend | `uv run ruff check app/ tests/` — or `make lint` |
| Format backend | `uv run ruff format app/ tests/` — or `make format` |
| Health check | `curl http://localhost:8001/health` |
| API docs (browser) | [http://localhost:8001/docs](http://localhost:8001/docs) |

### Edge Agent (`zuralog/`) — run from project root

| Action | Command |
|---|---|
| Install Flutter deps | `cd zuralog && flutter pub get` |
| Drift + Riverpod code gen | `cd zuralog && dart run build_runner build --delete-conflicting-outputs` |
| Flutter static analysis | `cd zuralog && flutter analyze` — or `make analyze` |
| Flutter tests | `cd zuralog && flutter test` — or `make test` |
| List connected devices | `flutter devices` |
| Run on Android emulator | `make run` |
| Run on iOS Simulator | `make run-ios` |
| Run on physical device | `make run-device` |
| Build debug APK | `make build-apk` |
| Build release App Bundle | `make build-appbundle` |

> All `make` targets for Flutter automatically inject `GOOGLE_WEB_CLIENT_ID` from `cloud-brain/.env`. Never use bare `flutter run` if Google Sign-In needs to work.

### Website (`website/`)

| Action | Command |
|---|---|
| Install Node deps | `cd website && npm install` |
| Start dev server | `cd website && npm run dev` → [http://localhost:3000](http://localhost:3000) |
| Lint | `cd website && npm run lint` |
| Type-check | `cd website && npx tsc --noEmit` |
| Production build (local) | `cd website && npm run build && npm run start` |
| Add shadcn/ui component | `cd website && npx shadcn add <component>` |

---

## Troubleshooting

### `flutter` not found after install
Add `C:\flutter\bin` (or wherever you extracted Flutter) to your system PATH, then restart your terminal.

### `make` not found

`make` is not available in PowerShell or Git Bash on Windows by default. It is pre-installed on macOS and most Linux distros.

**Windows — Recommended: Install via Scoop**

[Scoop](https://scoop.sh) is a Windows package manager that automatically manages PATH — no manual PATH editing required. Run this in PowerShell:

```powershell
# Install Scoop if you don't have it yet
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# Then install make
scoop install make
```

If Scoop is already installed, just run `scoop install make`. Open a **new** Git Bash terminal after installing and `make --version` will work immediately.

**Windows — Alternative: GnuWin32 (more steps)**

```powershell
winget install GnuWin32.Make
```

After installing you must do **all three** of these steps or it won't work:

1. Manually add `C:\Program Files (x86)\GnuWin32\bin` to your **system** PATH (Start → "Edit the system environment variables" → Environment Variables → System variables → Path → New)
2. **Fully close your editor/terminal app** (not just a new tab — the entire process must restart to inherit the new PATH)
3. Verify with `make --version` in a fresh Git Bash terminal

> **Why so many steps?** `winget` installs the binary but does not update PATH. And changing PATH in Windows registry does not affect already-running processes — every terminal tab you open inherits the PATH from the parent app at launch time. If you add `GnuWin32\bin` to PATH but don't fully restart AntiGravity (or VS Code, or whatever IDE), Git Bash will still report `command not found`.

> **GnuWin32 caveat:** `winget install GnuWin32.Make` installs `make` 3.81 from 2006. If you encounter issues with Makefile recipes, use the Scoop method instead (installs `make` 4.4+, which this project's Makefile is tested against).

**Linux — `make` missing**
```bash
sudo apt install make     # Debian / Ubuntu
sudo dnf install make     # Fedora / RHEL
sudo pacman -S make       # Arch
```

**Any platform — skip `make` entirely**
Every `make` target has a direct equivalent listed in the Quick Reference table. For example:
```bash
# Instead of: make dev
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8001

# Instead of: make run
cd zuralog && flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=<your_client_id>
```

### `gradlew` fails with "JAVA_HOME is not set"
You do not need to install Java separately — Android Studio bundles a JDK. Run Gradle commands with the bundled JDK:
```bash
# From zuralog/android/
JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" PATH="$JAVA_HOME/bin:$PATH" ./gradlew <task>
```

### Docker Compose fails with "unable to get image"
Make sure Docker Desktop is running before executing `docker compose up -d`.

### `flutter pub get` fails with version errors
Try `flutter pub upgrade --major-versions` to resolve dependency conflicts.

### Android emulator can't reach backend
- Ensure the Cloud Brain server is running on `0.0.0.0:8001` (not `127.0.0.1:8001`). Use `make dev` or add `--host 0.0.0.0` explicitly.
- Use `http://10.0.2.2:8001` as the base URL — this is the emulator's alias for host `localhost`. Do not use `127.0.0.1` or `localhost` from inside the emulator.
- If using a physical device, pass your machine's LAN IP: `--dart-define=BASE_URL=http://192.168.x.x:8001`.

### Chat WebSocket not connecting
The WebSocket URL is automatically derived from `BASE_URL` by swapping `http://` → `ws://`. Ensure the backend is running and the `BASE_URL` override is correct for your environment. WebSocket connections go to `ws://10.0.2.2:8001/api/v1/chat/ws` by default.

### Auth endpoints return 500 / connection errors
Verify your Supabase credentials in `cloud-brain/.env`:
- `SUPABASE_URL` should be `https://xxxxx.supabase.co` (no trailing slash)
- `SUPABASE_ANON_KEY` is the JWT token (starts with `eyJ...`)
- `SUPABASE_SERVICE_KEY` is the secret key (starts with `sb_secret_...`)
- Make sure the Email auth provider is enabled in Supabase → Authentication → Providers

### Google Sign-In returns null token / silently fails
This means `GOOGLE_WEB_CLIENT_ID` was not injected at build time. Use `make run` instead of bare `flutter run`. The `make` target reads `GOOGLE_WEB_CLIENT_ID` and `SENTRY_DSN` automatically from `cloud-brain/.env`.

If you must use `flutter run` directly:
```bash
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=<your-google-web-client-id>
```

### AI features return "LLM unavailable" or model errors
- Ensure `OPENROUTER_API_KEY` is set in `cloud-brain/.env`.
- The correct model ID is `moonshotai/kimi-k2.5` (already set as the default in `.env.example`).

### Flutter app fails to build with Google Services error
`google-services.json` should already be in the repo at `zuralog/android/app/google-services.json`. If it's missing, run `git pull` — or ask the project owner for the file and place it there manually. Do not regenerate it — use the existing file from the shared Zuralog Firebase project.

### Push notifications not working
- Ensure `FCM_CREDENTIALS_PATH` points to a valid Firebase service account JSON in `cloud-brain/.env`.
- The Flutter app registers the device FCM token with the backend automatically on first launch once Firebase is configured.

### `sqlite3` / Drift build errors on Android
The project pins `sqlite3_flutter_libs: ^0.5.0`. Do **not** upgrade this to `0.6.x` — that version is an empty tombstone and Drift 2.28.x is not yet compatible with sqlite3 v3.x. If you see JNI errors, ensure `jniLibs.useLegacyPackaging = true` is set in `zuralog/android/app/build.gradle.kts`.

### Emulator screen looks wrong / minSdk errors
The project requires **minSdk 28** (Android 9) due to the Health Connect dependency. Create your emulator with a system image of API 28 or higher. API 34 (Android 14) is recommended for the best Health Connect support.

### Google Sign-In works in debug but fails after a Play Store release
The Android OAuth client in Google Cloud Console is registered with the **debug keystore SHA-1** (`3F:E9:FF:6A:41:D9:E0:45:94:77:BC:6C:D0:A0:E7:33:A2:DE:A2:55`). Release builds are signed with a completely different keystore, so Google will reject sign-in attempts from a release APK/AAB.

**Before releasing to the Play Store, you must:**

1. Generate your release keystore (or locate it if it already exists).
2. Get its SHA-1 fingerprint:
   ```bash
   # Windows (from zuralog/android/)
   JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" PATH="$JAVA_HOME/bin:$PATH" ./gradlew signingReport
   # Look for the "release" Variant SHA1 line (will be different from the debug one above)
   ```
   Or directly from the keystore file:
   ```bash
   keytool -list -v -keystore your-release-key.jks -alias your-key-alias
   ```
3. Go to [console.cloud.google.com](https://console.cloud.google.com) → project `zuralog-8311a` → **APIs & Services** → **Credentials**.
4. Find the existing Android OAuth client (`Zuralog Android`) → click **Edit** → add the release SHA-1 as a second fingerprint. Do **not** delete the debug SHA-1 — you still need that for local development.
5. Save. No app restart or re-download of config files is needed — the credential update takes effect within a few minutes.

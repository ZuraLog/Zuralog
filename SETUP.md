# Life Logger — Developer Setup Guide

Get the Cloud Brain (backend) and Edge Agent (mobile) running locally from a fresh clone.

## Prerequisites

Install the following before proceeding:

| Tool | Version | Install |
|---|---|---|
| **Python** | 3.12+ | [python.org/downloads](https://www.python.org/downloads/) |
| **uv** | Latest | `pip install uv` or [docs.astral.sh/uv](https://docs.astral.sh/uv/getting-started/installation/) |
| **Docker Desktop** | Latest | [docs.docker.com/desktop](https://docs.docker.com/desktop/setup/install/windows-install/) |
| **Flutter SDK** | 3.32+ | [docs.flutter.dev/install/manual](https://docs.flutter.dev/install/manual) |
| **Android Studio** | Latest | [developer.android.com/studio](https://developer.android.com/studio) (needed for Android SDK + Emulator) |

After installing Flutter, run `flutter doctor` to verify your setup and accept any Android SDK licenses.

---

## 1. Clone the Repository

```bash
git clone https://github.com/hyowonbernabe/Life-Logger.git
cd Life-Logger
```

---

## 2. Cloud Brain (Backend)

### 2a. Start Docker Services (PostgreSQL + Redis)

Make sure Docker Desktop is running, then:

```bash
cd cloud-brain
docker compose up -d
```

Verify both containers are healthy:

```bash
docker compose ps
```

You should see `lifelogger-postgres` and `lifelogger-redis` both running.

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

1. **Shared dev project** (simpler): All developers use the same Supabase project URL and anon key. Distribute keys securely (e.g., via 1Password).
2. **Individual free-tier projects** (isolated): Each developer creates their own free Supabase project. Free tier is more than enough for development.

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

#### Deferred: Strava Integration

Strava OAuth is implemented but registration of the Strava API application is not required for core local development. When you are ready to test Strava:

1. Go to [strava.com/settings/api](https://www.strava.com/settings/api) and create an API application.
2. Set the **Authorization Callback Domain** to `localhost` (for development).
3. Copy the **Client ID** and **Client Secret** into `.env`.

> **Note:** This follows the same model as "Sign in with Google." You (the developer) register one Strava API application. Users never need their own Strava API keys — they just log in via OAuth using the app's credentials. The `STRAVA_REDIRECT_URI` default (`lifelogger://oauth/strava`) is a deep link handled by the Flutter app.

| Variable | Description |
|---|---|
| `STRAVA_CLIENT_ID` | Your Strava API application's numeric Client ID |
| `STRAVA_CLIENT_SECRET` | Your Strava API application's Client Secret |
| `STRAVA_REDIRECT_URI` | Keep default: `lifelogger://oauth/strava` |

#### Deferred: Firebase Cloud Messaging (Push Notifications)

FCM push notifications require a Firebase project and service account. Leave `FCM_CREDENTIALS_PATH` unset for now — the backend starts without it and push notification endpoints will return a no-op response.

When you are ready to enable push notifications:

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Add an Android app (package name: `com.lifelogger.life_logger`).
3. Download `google-services.json` and place it at `life_logger/android/app/google-services.json`.
4. In Firebase Console → Project Settings → Service Accounts, generate a new private key (JSON).
5. Save the downloaded JSON somewhere safe (e.g., `cloud-brain/firebase-service-account.json`) and set `FCM_CREDENTIALS_PATH` to that path in `.env`.

> **⚠️ Note:** The Google Services Gradle plugin is already wired into the Android build. If `google-services.json` is missing, the Flutter app **will not build**. You must either place the file or temporarily comment out the plugin in `life_logger/android/app/build.gradle.kts`.

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

### 2f. Verify It Works

Open [http://localhost:8001/health](http://localhost:8001/health) in your browser. You should see:

```json
{"status": "healthy"}
```

API docs are available at [http://localhost:8001/docs](http://localhost:8001/docs).

### 2g. Run Backend Tests

```bash
uv run pytest tests/ -v
```

---

## 3. Edge Agent (Flutter Mobile App)

### 3a. Install Flutter Dependencies

```bash
cd life_logger
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

This should report **No issues found**.

### 3d. Launch on an Emulator

1. Open Android Studio → **Virtual Device Manager** → Create/start an Android emulator
2. Run the app:

```bash
flutter run
```

You should see the **TEST HARNESS** screen with buttons for Health Check, Secure Storage, Local DB, and more.

### 3e. Configuring the API URL

The app connects to `http://10.0.2.2:8001` by default (Android emulator's alias for host `localhost`). Override for different environments:

```bash
# iOS Simulator
flutter run --dart-define=BASE_URL=http://localhost:8001

# Physical device (use your machine's LAN IP)
flutter run --dart-define=BASE_URL=http://192.168.1.100:8001
```

---

## Quick Reference

| Action | Command |
|---|---|
| Start Docker services | `docker compose up -d` (in `cloud-brain/`) |
| Stop Docker services | `docker compose down` (in `cloud-brain/`) |
| Start backend server | `uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8001` (in `cloud-brain/`) |
| Start backend (shortcut) | `make dev` (in `cloud-brain/`) |
| Run backend tests | `uv run pytest tests/ -v` (in `cloud-brain/`) |
| Lint backend | `uv run ruff check app/ tests/` (in `cloud-brain/`) |
| Run new migration | `uv run alembic revision --autogenerate -m "description"` (in `cloud-brain/`) |
| Apply migrations | `uv run alembic upgrade head` (in `cloud-brain/`) |
| Install Flutter deps | `flutter pub get` (in `life_logger/`) |
| Drift code gen | `dart run build_runner build --delete-conflicting-outputs` (in `life_logger/`) |
| Flutter analysis | `flutter analyze` (in `life_logger/`) |
| Run Flutter app | `flutter run` (in `life_logger/`) |

---

## Troubleshooting

### `flutter` not found after install
Add `C:\flutter\bin` (or wherever you extracted Flutter) to your system PATH, then restart your terminal.

### Docker Compose fails with "unable to get image"
Make sure Docker Desktop is running before executing `docker compose up -d`.

### `flutter pub get` fails with version errors
Try `flutter pub upgrade --major-versions` to resolve dependency conflicts.

### Android emulator can't reach backend
Ensure the Cloud Brain server is running on `0.0.0.0:8001` (not `127.0.0.1:8001`) and use `http://10.0.2.2:8001` as the base URL from the emulator.

### Auth endpoints return 500 / connection errors
Verify your Supabase credentials in `.env`:
- `SUPABASE_URL` should be `https://xxxxx.supabase.co` (no trailing slash)
- `SUPABASE_ANON_KEY` is the JWT token (starts with `eyJ...`)
- `SUPABASE_SERVICE_KEY` is the secret key (starts with `sb_secret_...`)
- Make sure the Email auth provider is enabled in Supabase → Authentication → Providers

### AI features return "LLM unavailable" or model errors
- Ensure `OPENROUTER_API_KEY` is set in `cloud-brain/.env`.
- The correct model ID is `moonshotai/kimi-k2.5` (already set as the default in `.env.example`).

### Flutter app fails to build with Google Services error
The Google Services Gradle plugin is enabled. You must place a valid `google-services.json` at `life_logger/android/app/google-services.json`. Download it from Firebase Console → Project Settings → Your Apps (Android). See the [Deferred: Firebase Cloud Messaging](#deferred-firebase-cloud-messaging-push-notifications) section for full instructions.

### Push notifications not working
- Ensure `FCM_CREDENTIALS_PATH` points to a valid Firebase service account JSON in `cloud-brain/.env`.
- The Flutter app must call "Init FCM" in the harness (or the equivalent production flow) to register the device token with the backend before push notifications can be sent.

### `sqlite3` / Drift build errors on Android
The project pins `sqlite3_flutter_libs: ^0.5.0`. Do **not** upgrade this to `0.6.x` — that version is an empty tombstone and Drift 2.28.x is not yet compatible with sqlite3 v3.x. If you see JNI errors, ensure `jniLibs.useLegacyPackaging = true` is set in `life_logger/android/app/build.gradle.kts`.

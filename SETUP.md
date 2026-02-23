# Zuralog — Developer Setup Guide

Get the Cloud Brain (backend) and Edge Agent (mobile) running locally from a fresh clone.

## Prerequisites

Install the following before proceeding:

| Tool | Version | Install |
|---|---|---|
| **Python** | 3.12+ | [python.org/downloads](https://www.python.org/downloads/) |
| **uv** | Latest | `pip install uv` or [docs.astral.sh/uv](https://docs.astral.sh/uv/getting-started/installation/) |
| **Docker Desktop** | Latest | [docs.docker.com/desktop](https://docs.docker.com/desktop/setup/install/windows-install/) |
| **Flutter SDK** | 3.32+ (Dart 3.11+) | [docs.flutter.dev/install/manual](https://docs.flutter.dev/install/manual) |
| **Android Studio** | Latest | [developer.android.com/studio](https://developer.android.com/studio) (needed for Android SDK, Emulator, and Java) |
| **GNU Make** | Any | Pre-installed on macOS/Linux. Windows: [gnuwin32.sourceforge.net/packages/make.htm](http://gnuwin32.sourceforge.net/packages/make.htm) or use Git Bash |

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
> - **Windows** — Git Bash (not PowerShell). In AntiGravity, click the **`+`** dropdown next to your terminal tabs → select **"Git Bash"**.
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

1. **Shared dev project** (simpler): All developers use the same Supabase project URL and anon key. Distribute keys securely (e.g., via 1Password).
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

#### Deferred: Strava Integration

Strava OAuth is implemented but registration of the Strava API application is not required for core local development. When you are ready to test Strava:

1. Go to [strava.com/settings/api](https://www.strava.com/settings/api) and create an API application.
2. Set the **Authorization Callback Domain** to `localhost` (for development).
3. Copy the **Client ID** and **Client Secret** into `.env`.

> **Note:** This follows the same model as "Sign in with Google." You (the developer) register one Strava API application. Users never need their own Strava API keys — they just log in via OAuth using the app's credentials. The `STRAVA_REDIRECT_URI` default (`zuralog://oauth/strava`) is a deep link handled by the Flutter app.

| Variable | Description |
|---|---|
| `STRAVA_CLIENT_ID` | Your Strava API application's numeric Client ID |
| `STRAVA_CLIENT_SECRET` | Your Strava API application's Client Secret |
| `STRAVA_REDIRECT_URI` | Keep default: `zuralog://oauth/strava` |

#### Required: Firebase (Push Notifications + Flutter Build)

Firebase is required for the Flutter app to build. `google-services.json` and `GoogleService-Info.plist` are already committed to the repo — you get them automatically from `git clone`. The service account JSON (backend push notifications) is a private key and must be shared securely between developers.

**One-time project setup (already done — for reference only):**

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com/) using a `@zuralog.com` Google account
2. Add an **Android** app (package: `com.zuralog.zuralog`) → download `google-services.json` → place at `zuralog/android/app/google-services.json`
3. Add an **iOS** app (bundle ID: `com.zuralog.zuralog`) → download `GoogleService-Info.plist` → place at `zuralog/ios/Runner/GoogleService-Info.plist`
4. Project Settings → **Service accounts** tab → **Generate new private key** → rename to `firebase-service-account.json` → place at `cloud-brain/firebase-service-account.json`
5. Set `FCM_CREDENTIALS_PATH` in `.env` (see below)

**What each developer needs to do:**

- `google-services.json` and `GoogleService-Info.plist` — already in Git, no action needed
- `firebase-service-account.json` — share securely (1Password, direct message). Place at `cloud-brain/firebase-service-account.json`. This file is gitignored and must never be committed.
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

All tests should pass. The test suite currently covers 201 tests across unit, widget, and provider layers.

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

> **Why `make run` instead of `flutter run`?** The app requires `GOOGLE_WEB_CLIENT_ID` to be injected at build time via `--dart-define`. `make run` reads this automatically from `cloud-brain/.env` and passes it through. Bare `flutter run` skips this and Google Sign-In will return a null token at runtime.

You should see the **Zuralog Welcome screen** — the animated entry screen with the Zuralog logo. From there you can proceed through onboarding and log in. The auth guard will redirect authenticated users directly to the Dashboard on subsequent launches.

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
            --dart-define=GOOGLE_WEB_CLIENT_ID=<your-web-client-id>

# Physical device
flutter run --dart-define=BASE_URL=http://192.168.1.100:8001 \
            --dart-define=GOOGLE_WEB_CLIENT_ID=<your-web-client-id>
```

> Make sure the backend server is bound to `0.0.0.0:8001` (not `127.0.0.1`) so it is reachable from the emulator.

### 3g. AntiGravity / VS Code Launch Configs

A `.vscode/launch.json` is automatically available if you open the project in AntiGravity (or VS Code). It is **gitignored** — each developer has their own local copy with their own credentials.

The file is pre-populated at `.vscode/launch.json` with three configurations:

| Configuration | Use case |
|---|---|
| **Zuralog (Android Emulator)** | Default — hits `http://10.0.2.2:8001` |
| **Zuralog (iOS Simulator)** | Uses `http://localhost:8001` |
| **Zuralog (Physical Device)** | Update `BASE_URL` IP to your machine's LAN address |

All three configurations have `GOOGLE_WEB_CLIENT_ID` pre-filled. Press **F5** to launch.

> If `.vscode/launch.json` is missing (e.g., fresh clone), create it manually or run `make run` from the terminal instead.

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

---

## Troubleshooting

### `flutter` not found after install
Add `C:\flutter\bin` (or wherever you extracted Flutter) to your system PATH, then restart your terminal.

### `make` not found
`make` is not available in PowerShell on Windows. It is pre-installed on macOS and most Linux distros.

**Windows — Option A: Git Bash (recommended, no install required)**
Git Bash ships with Git for Windows and includes `make`. Open it in one of two ways:
- **From AntiGravity / VS Code:** Click the **`+`** dropdown next to the terminal tabs → select **"Git Bash"**.
- **From Windows:** Press **Win** → search **"Git Bash"** → open it.

**Windows — Option B: Install `make` permanently**
```powershell
choco install make        # Chocolatey
winget install GnuWin32.Make  # Winget
```
Restart PowerShell after installing.

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
cd zuralog && flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=616346397607-se60r20r85d24teksi3oco8ss77kol0d.apps.googleusercontent.com
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
This means `GOOGLE_WEB_CLIENT_ID` was not injected at build time. Use `make run` instead of bare `flutter run`. The `make` target reads the client ID from `cloud-brain/.env` automatically.

If you must use `flutter run` directly:
```bash
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=616346397607-se60r20r85d24teksi3oco8ss77kol0d.apps.googleusercontent.com
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

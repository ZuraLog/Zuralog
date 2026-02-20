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

Open `.env` and fill in the Supabase credentials:

| Variable | Where to find it | Description |
|---|---|---|
| `DATABASE_URL` | **Keep default** | Points to your local Docker Postgres |
| `REDIS_URL` | **Keep default** | Points to your local Docker Redis |
| `SUPABASE_URL` | Supabase → Project Settings → API → Project URL | e.g., `https://xxxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase → Project Settings → API → `anon` `public` | JWT token starting with `eyJ...` |
| `SUPABASE_SERVICE_KEY` | Supabase → Project Settings → API → `service_role` `secret` | Starts with `sb_secret_...` |

> **⚠️ Warning:** The `SUPABASE_SERVICE_KEY` has **full admin access** to your Supabase project. Never commit it to Git, share it in chat, or expose it client-side. The `.gitignore` already excludes `.env` files.

#### Supabase for Auth Only (Team Strategy)

The project uses a **hybrid database strategy:**

- **Local Docker Postgres** → Your application data (users, integrations, health records). Fast, isolated per developer.
- **Supabase** → Authentication (GoTrue) only. The Cloud Brain proxies auth requests to Supabase's REST API.

For team development, you have two options for Supabase auth:

1. **Shared dev project** (simpler): All developers use the same Supabase project URL and anon key. The team lead distributes keys securely (e.g., via 1Password).
2. **Individual free-tier projects** (isolated): Each developer creates their own free Supabase project for auth testing. Free tier is more than enough for development.

### 2d. Run Database Migrations

```bash
uv run alembic upgrade head
```

This creates the `users` and `integrations` tables in your local PostgreSQL.

### 2e. Start the Dev Server

```bash
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Or use the Makefile shortcut:

```bash
make dev
```

### 2f. Verify It Works

Open [http://localhost:8000/health](http://localhost:8000/health) in your browser. You should see:

```json
{"status": "healthy"}
```

API docs are available at [http://localhost:8000/docs](http://localhost:8000/docs).

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

You should see the **TEST HARNESS** screen with buttons for Health Check, Secure Storage, and Local DB.

### 3e. Configuring the API URL

The app connects to `http://10.0.2.2:8000` by default (Android emulator's alias for host `localhost`). Override for different environments:

```bash
# iOS Simulator
flutter run --dart-define=BASE_URL=http://localhost:8000

# Physical device (use your machine's LAN IP)
flutter run --dart-define=BASE_URL=http://192.168.1.100:8000
```

---

## Quick Reference

| Action | Command |
|---|---|
| Start Docker services | `docker compose up -d` (in `cloud-brain/`) |
| Stop Docker services | `docker compose down` (in `cloud-brain/`) |
| Start backend server | `uv run uvicorn app.main:app --reload` (in `cloud-brain/`) |
| Run backend tests | `uv run pytest tests/ -v` (in `cloud-brain/`) |
| Lint backend | `uv run ruff check app/ tests/` (in `cloud-brain/`) |
| Run new migration | `uv run alembic revision --autogenerate -m "description"` |
| Apply migrations | `uv run alembic upgrade head` |
| Install Flutter deps | `flutter pub get` (in `life_logger/`) |
| Drift code gen | `dart run build_runner build --delete-conflicting-outputs` |
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
Ensure the Cloud Brain server is running on `0.0.0.0:8000` (not `127.0.0.1:8000`) and use `http://10.0.2.2:8000` as the base URL from the emulator.

### Auth endpoints return 500 / connection errors
Verify your Supabase credentials in `.env`:
- `SUPABASE_URL` should be `https://xxxxx.supabase.co` (no trailing slash)
- `SUPABASE_ANON_KEY` is the JWT token (starts with `eyJ...`)
- `SUPABASE_SERVICE_KEY` is the secret key (starts with `sb_secret_...`)
- Make sure the Email auth provider is enabled in Supabase → Authentication → Providers

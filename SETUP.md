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

The defaults in `.env.example` are configured for local Docker services — no changes needed for local development.

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

# Executed Phase 1.2: Authentication & User Management

> **Status:** ✅ Completed
> **Branch:** `feat/phase-1.2`
> **Date:** 2026-02-20

## What Was Built

### Cloud Brain (Python/FastAPI)

| Component | File | Description |
|---|---|---|
| Auth Service | `cloud-brain/app/services/auth_service.py` | httpx-based Supabase GoTrue REST client (signup, signin, signout, refresh) |
| User Service | `cloud-brain/app/services/user_service.py` | Upsert via `INSERT ... ON CONFLICT DO UPDATE` |
| Auth Router | `cloud-brain/app/api/v1/auth.py` | 4 endpoints: `/register`, `/login`, `/logout`, `/refresh` |
| Schemas | `cloud-brain/app/api/v1/schemas.py` | `LoginRequest`, `RegisterRequest`, `RefreshRequest`, `AuthResponse`, `MessageResponse` |
| Main | `cloud-brain/app/main.py` | httpx lifecycle + router mounted at `/api/v1` |
| Tests | `cloud-brain/tests/test_auth.py` | 7 auth tests + 2 health regression tests (all mocked, no live Supabase needed) |
| Dependencies | `cloud-brain/pyproject.toml` | Added `email-validator>=2.0.0` |

### Edge Agent (Flutter/Dart)

| Component | File | Description |
|---|---|---|
| Auth State | `zuralog/lib/features/auth/domain/auth_state.dart` | Sealed `AuthResult` class + `AuthState` enum |
| Auth Repository | `zuralog/lib/features/auth/data/auth_repository.dart` | Typed `AuthResult` returns, token management |
| Auth Providers | `zuralog/lib/features/auth/domain/auth_providers.dart` | Riverpod 3.x `Notifier`/`NotifierProvider` |
| Harness Screen | `zuralog/lib/features/harness/harness_screen.dart` | Auth UI with email/password fields, login/register/logout buttons, live auth status indicator |
| API Client | `zuralog/lib/core/network/api_client.dart` | Silent token refresh interceptor (401 → refresh → retry) |

## Deviations from Original Plan

1. **httpx instead of supabase-py:** Only 4 REST endpoints needed; avoids 5+ transitive dependencies from the full SDK.
2. **DI via `app.state` + `Depends`:** Original used module-level Supabase client which fails at import time and is untestable.
3. **`AuthResult` sealed class:** Original plan returned bare `bool` from `AuthRepository`; sealed class provides error context to UI.
4. **Logout uses user's token:** Original called `supabase.auth.sign_out()` which signs out the *service client*, not the user.
5. **Upsert for user sync:** Original used SELECT-then-INSERT which has a TOCTOU race condition. Replaced with `INSERT ... ON CONFLICT DO UPDATE`.
6. **Riverpod 3.x `Notifier`:** Original used `StateNotifier` which was removed in `flutter_riverpod` 3.2.1.
7. **API versioning:** All auth routes mounted at `/api/v1/auth/*` instead of bare `/auth/*`.
8. **Pydantic response models:** Original returned raw dicts leaking Supabase internals. `AuthResponse` + `MessageResponse` control the API surface.

## Verification Results

| Check | Result |
|---|---|
| `uv run pytest tests/ -v` | ✅ 9 passed |
| `uv run ruff check app/ tests/` | ✅ All checks passed |
| `flutter analyze` | ✅ No issues found |

## Next Steps

- Phase 1.3 can build on the auth endpoints and repository pattern established here.
- E2E manual verification requires live Supabase credentials in `.env`.
- Token refresh interceptor is ready for any future authenticated API calls.

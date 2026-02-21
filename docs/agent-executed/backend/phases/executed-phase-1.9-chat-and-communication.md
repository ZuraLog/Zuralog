# Executed Phase 1.9: Chat & Communication Layer

## Summary
Implemented the full Chat & Communication Layer spanning both the Cloud Brain (Python/FastAPI) and the Edge Agent (Flutter/Dart). This phase establishes real-time WebSocket chat with authenticated connections, message persistence models, push notification scaffolding, and a test harness for end-to-end validation.

## What Was Built

### Cloud Brain (Backend)
- **WebSocket endpoint** (`/api/v1/chat/ws`) with Supabase Auth token validation via query parameter
- **Chat history REST endpoint** (`GET /api/v1/chat/history`) with Bearer token auth
- **Conversation & Message models** (SQLAlchemy 2.0 `Mapped`/`mapped_column` pattern, composite index on `(conversation_id, created_at)`)
- **Push notification service** (`PushService`) — config-gated behind `fcm_credentials_path`, graceful degradation when not configured
- **7 new tests** — WS rejection (no token, invalid token), WS connect + echo, empty message error, no-auth history, empty history, health regression

### Edge Agent (Flutter)
- **Enhanced `WsClient`** — auto-reconnect with exponential backoff (1s→30s), broadcast `StreamController`, `ConnectionStatus` enum, `dispose()` lifecycle
- **`ChatMessage`** domain model with JSON serialization
- **`ChatRepository`** mediating WsClient ↔ ApiClient ↔ UI, providing typed `Stream<ChatMessage>` and `Stream<ConnectionStatus>`
- **`FCMService`** scaffold — permission request, token retrieval, foreground/background handlers
- **Harness chat section** — Connect WS, Send Message, Disconnect WS buttons with chat input field

## Deviations from Plan
1. **SQLAlchemy model style**: Used modern `Mapped`/`mapped_column` instead of legacy `Column()` — matches existing `User` and `Integration` models.
2. **Real WS auth**: Implemented token validation via `AuthService.get_user()` instead of the plan's commented-out placeholder.
3. **Orchestrator wired**: Connected the WS endpoint to the existing `Orchestrator.process_message()` scaffold for end-to-end echo.
4. **FCM config-gated**: Both backend (`PushService`) and Flutter (`FCMService`) are scaffolded but gated — no Firebase project setup required during dev.
5. **Alembic migration deferred**: Models are registered and ready for `alembic revision --autogenerate`, but the actual migration was not generated (requires running DB).

## Test Results
- **93 tests pass** (full suite including all pre-existing tests)
- **Zero lint errors** (ruff check passes)
- **Branch**: `feat/phase-1.9`

## Next Steps
- Run `alembic revision --autogenerate -m "add_chat_models"` + `alembic upgrade head` when DB is available
- Add Firebase project config files (GoogleService-Info.plist, google-services.json) to enable FCM
- Phase 1.8 (AI Brain) integration will replace the Orchestrator scaffold with real LLM function-calling
- Run `flutter pub get` to install `firebase_messaging` and `firebase_core` packages

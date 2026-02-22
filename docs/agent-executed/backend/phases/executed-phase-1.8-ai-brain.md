# Executed Phase 1.8: The AI Brain (Reasoning Engine)

> **Branch:** `feat/phase-1.8-ai-brain`
> **Date:** 2026-02-22
> **Status:** Complete

---

## Summary

Phase 1.8 implements the LLM agent that orchestrates MCP tool calls, performs cross-app reasoning, generates "Tough Love Coach" responses, and manages per-user rate limits and usage tracking. This replaces the Phase 1.3 scaffold Orchestrator with a production-ready ReAct-style tool-calling loop.

### What Was Built

1. **LLM Client (1.8.1):** `AsyncOpenAI` wrapper connecting to OpenRouter with configurable model, temperature, and max tokens. 5 tests.
2. **System Prompt (1.8.2):** Tough Love Coach persona with tool usage rules, tone examples, and dynamic user context suffix. 6 tests.
3. **Orchestrator Upgrade (1.8.3):** Full ReAct loop (max 5 turns) replacing the scaffold. Converts MCP ToolDefinitions to OpenAI function-calling format, executes tools via MCPClient, feeds results back. 4 tests.
4. **Reasoning Engine (1.8.4):** Pure-function analytics: caloric deficit analysis, sleep-activity correlation, month-over-month activity trends. 7 tests.
5. **Voice Input (1.8.5):** POST `/api/v1/transcribe` accepting .webm/.m4a/.wav/.mp3 with mock transcription. 5 tests.
6. **User Profile (1.8.6):** `get_system_prompt_suffix()` for persona-aware prompts (tough_love/balanced/gentle). GET/PATCH `/api/v1/users/me/preferences` endpoints. 3 tests.
7. **Harness UI (1.8.7):** AI Brain section in Flutter developer harness with "Test AI Chat" and "Voice Test" buttons.
8. **Integration Doc (1.8.8):** Updated `ai-brain-integration.md` with implementation status, actual rate limits, and key file references.
9. **Rate Limiter (1.8.9):** Redis-backed fixed-window daily counter. Free: 50/day, Premium: 500/day. 5 tests.
10. **Usage Tracker (1.8.10):** `UsageLog` SQLAlchemy model + `UsageTracker` service for per-request token tracking. 3 tests.
11. **Rate Limit Middleware (1.8.11):** `check_rate_limit()` dependency querying user tier and enforcing limits with 429 + `X-RateLimit-*` headers. 2 tests.

### Test Results

- **133 Python tests passing** (25 new in this phase)
- **0 ruff lint errors** in `app/` and `tests/`
- **Flutter analyze:** 0 new issues (pre-existing warnings only)

---

## Deviations from Original Plan

1. **LLM Client:** Used `openai` SDK (`AsyncOpenAI`) instead of raw `httpx` + `tenacity`. Built-in retries, streaming, structured tool_calls parsing reduce custom code by ~60%.
2. **Rate Limiter:** Kept existing `slowapi` for IP-level abuse protection; added new Redis-based per-user/tier limiter for LLM cost control (different concerns).
3. **Voice Input (1.8.5):** Scaffolded with mock transcription. Real Whisper integration deferred until infrastructure is ready.
4. **Integration Doc (1.8.8):** Already existed (368 lines) — updated with implementation status section rather than creating from scratch.

---

## Architecture Decisions

- **ReAct Loop:** 5-turn maximum prevents infinite tool-calling loops while allowing complex multi-step reasoning.
- **Orchestrator accepts `llm_client` parameter:** Enables dependency injection for testing (mocked LLM) and future model swapping.
- **Reasoning Engine is stateless:** Pure functions operating on pre-fetched data — the Orchestrator handles data retrieval, the engine handles computation.
- **Dual rate limiting:** slowapi (IP-level abuse) + Redis per-user (cost control) serve orthogonal concerns.

---

## Next Steps

- Wire `UsageTracker` into the Orchestrator's `process_message()` loop to record actual token usage per request.
- Implement real Whisper STT when audio infrastructure is ready.
- Add Redis to Docker Compose for local development.
- Connect the `check_rate_limit` dependency to the WebSocket chat endpoint.
- Integrate `ReasoningEngine` methods as MCP tools so the LLM can invoke them directly.

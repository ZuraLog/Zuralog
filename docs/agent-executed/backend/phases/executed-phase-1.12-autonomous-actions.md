# Executed Phase 1.12: Autonomous Actions & Deep Linking

> **Branch:** `feat/phase-1.12`
> **Date:** 2026-02-22
> **Status:** Complete (pending merge to main)

---

## Summary

Implemented the "Autonomous Task Execution" feature for Phase 1.12, enabling the AI Agent to trigger actions in external apps (Strava, CalAI) via deep links. This spans both Cloud Brain (Python/FastAPI) and Edge Agent (Flutter/Dart), with a new MCP server, a structured response format, and platform-level deep link configuration.

## What Was Built

### Cloud Brain (Backend)

- **Deep Link Registry** (`app/mcp_servers/deep_link_registry.py`) -- Data-driven registry mapping (app_name, action) pairs to deep link URLs. Static class with lookup, fallback URL, and supported app/action enumeration methods. Uses module-level dicts with callable entries for parameterized URLs (e.g., CalAI search with query interpolation).

- **Deep Link MCP Server** (`app/mcp_servers/deep_link_server.py`) -- New `BaseMCPServer` subclass exposing one tool: `open_external_app`. Resolves app+action via the registry and returns a `ToolResult` with `client_action` payload (`open_url`, URL, fallback URL, user message). Registered in application startup alongside existing servers.

- **Agent Response Model** (`app/agent/response.py`) -- Pydantic `AgentResponse(message, client_action)` model replacing the Orchestrator's previous plain `str` return type. Enables structured responses that carry optional client-side action payloads.

- **Orchestrator Refactor** (`app/agent/orchestrator.py`) -- `process_message()` now returns `AgentResponse` instead of `str`. Tracks `last_client_action` during the ReAct loop: when a tool result contains a `client_action` key in its `data` dict, the Orchestrator extracts and surfaces it in the response.

- **WebSocket Handler Update** (`app/api/v1/chat.py`) -- Unpacks `AgentResponse.message` into the existing `content` field and conditionally includes `client_action` in the WebSocket JSON payload when present.

- **32 new backend tests** across 4 test files (registry: 13, server: 13, model: 4, orchestrator: 2 new + 6 updated).

### Edge Agent (Flutter)

- **DeepLinkLauncher Extension** (`core/deeplink/deeplink_launcher.dart`) -- Added generic `executeDeepLink(String url, {String? fallbackUrl})` method with try/canLaunch/fallback pattern. Reusable for any deep link, not just CalAI.

- **ChatMessage Model Update** (`features/chat/domain/message.dart`) -- Added `clientAction` field (`Map<String, dynamic>?`) with `fromJson`/`toJson` support for the `client_action` key.

- **Harness Auto-Execution** (`features/harness/harness_screen.dart`) -- WebSocket listener detects `client_action == 'open_url'` in AI responses and automatically calls `DeepLinkLauncher.executeDeepLink()`.

- **Deep Link Test Section** -- 3 test buttons in the developer harness: Strava Record, CalAI Camera, CalAI Search.

- **Platform Configuration** -- iOS `Info.plist`: `LSApplicationQueriesSchemes` for `strava` and `calai`. Android `AndroidManifest.xml`: `<queries>` intents for `strava://`, `calai://`, and `https://` schemes.

- **5 new Flutter tests** for `executeDeepLink()`.

---

## Deviations from Original Plan

| # | Original Plan | What We Did | Reason |
|---|---|---|---|
| 1 | Import from `cloudbrain.app.mcp.base` | Import from `app.mcp_servers.base_server` / `app.mcp_servers.models` | Match actual codebase paths |
| 2 | `ToolResult(content=..., meta={"client_action": ...})` | `ToolResult(success=True, data={"client_action": "open_url", "url": "...", ...})` | Actual `ToolResult` has `success/data/error` fields, not `content/meta` |
| 3 | Only backend Orchestrator changes | Full-stack: Orchestrator + WebSocket handler + Flutter ChatMessage + Harness auto-execute | Breaking change requires coordinated update across all layers |
| 4 | Create new `DeepLinkHandler` class | Extended existing `DeepLinkLauncher` with `executeDeepLink()` | `DeeplinkHandler` already exists for inbound links; avoids duplication |
| 5 | Platform configs as documentation only | Actual `Info.plist` + `AndroidManifest.xml` changes | Required for `canLaunchUrl()` to work at runtime on iOS 9+ / Android 11+ |
| 6 | Zero backend tests | TDD with 32 new backend tests + 5 Flutter tests | Engineering standards mandate test coverage |
| 7 | `myfitnesspal` in app enum | Removed from supported apps | Not in PRD MVP integrations (YAGNI) |
| 8 | Hardcoded deep links in server | Extracted `DeepLinkRegistry` with data-driven lookup | Adding a new app is a dict entry, not control flow changes |

---

## Verification Results

| Check | Result |
|-------|--------|
| Backend tests (all) | 251/251 passed |
| Backend tests (new) | 32 new tests |
| Ruff lint | All checks passed |
| Flutter analyze | 10 issues (all pre-existing in unrelated files) |
| Flutter tests (deep link) | 8/8 passed (3 existing + 5 new) |
| Branch | `feat/phase-1.12` -- 7 atomic commits |

---

## Files Created (8)

| File | Purpose |
|------|---------|
| `cloud-brain/app/mcp_servers/deep_link_registry.py` | Data-driven deep link URL registry |
| `cloud-brain/app/mcp_servers/deep_link_server.py` | MCP server with `open_external_app` tool |
| `cloud-brain/app/agent/response.py` | `AgentResponse` Pydantic model |
| `cloud-brain/tests/test_deep_link_registry.py` | 13 registry unit tests |
| `cloud-brain/tests/mcp/test_deep_link_server.py` | 13 server unit tests |
| `cloud-brain/tests/test_agent_response.py` | 4 model tests |
| `docs/plans/backend/integrations/deep-links-integration.md` | Integration reference document |
| `docs/agent-executed/backend/phases/executed-phase-1.12-autonomous-actions.md` | This file |

## Files Modified (10)

| File | Change |
|------|--------|
| `cloud-brain/app/mcp_servers/__init__.py` | Added `DeepLinkServer` export |
| `cloud-brain/app/main.py` | Registered `DeepLinkServer` in startup |
| `cloud-brain/app/agent/orchestrator.py` | Returns `AgentResponse`, extracts `client_action` from tool results |
| `cloud-brain/app/api/v1/chat.py` | Propagates `client_action` in WebSocket payload |
| `cloud-brain/tests/test_orchestrator.py` | 6 tests updated + 2 new tests for client_action |
| `zuralog/lib/core/deeplink/deeplink_launcher.dart` | Added generic `executeDeepLink()` method |
| `zuralog/lib/features/chat/domain/message.dart` | Added `clientAction` field |
| `zuralog/lib/features/harness/harness_screen.dart` | Deep link auto-execution + 3 test buttons |
| `zuralog/ios/Runner/Info.plist` | `LSApplicationQueriesSchemes` for strava/calai |
| `zuralog/android/app/src/main/AndroidManifest.xml` | `<queries>` for strava/calai/https schemes |
| `zuralog/test/core/deeplink/deeplink_launcher_test.dart` | 5 new `executeDeepLink` tests |

---

## Next Steps

- **More Apps:** Add Fitbit, Oura, WHOOP deep links to the registry as those integrations come online (Phases 1.4-1.5 provided the data; deep links are separate from data access).
- **Confirmation UI:** Add user confirmation dialog before auto-launching external apps (security/UX consideration for Phase 2).
- **Navigation Actions:** Extend `client_action` types beyond `open_url` to support internal navigation (`navigate_to`) and UI effects (`confetti`).
- **Production Chat UI:** Wire `client_action` handling into the Phase 2 chat screen (currently only in the test harness).
- **Universal Links:** Consider adding HTTPS-verified deep links (Apple Universal Links / Android App Links) for a smoother UX without scheme detection.

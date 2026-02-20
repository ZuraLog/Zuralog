# Executed Phase 1.3: MCP Base Framework

> **Status:** ✅ Completed
> **Branch:** `feat/phase-1.3`
> **Date:** 2026-02-20

## What Was Built

### MCP Server Abstractions

| Component | File | Description |
|---|---|---|
| Base Class | `cloud-brain/app/mcp_servers/base_server.py` | Abstract `BaseMCPServer` with typed `ToolDefinition`/`ToolResult`/`Resource` returns |
| Models | `cloud-brain/app/mcp_servers/models.py` | Pydantic v2 models: `ToolDefinition`, `ToolResult`, `Resource` |
| Registry | `cloud-brain/app/mcp_servers/registry.py` | `MCPServerRegistry` with duplicate detection, `get_by_tool()` routing, dynamic tool aggregation |
| Package Init | `cloud-brain/app/mcp_servers/__init__.py` | Re-exports public API |

### Agent Layer

| Component | File | Description |
|---|---|---|
| MCP Client | `cloud-brain/app/agent/mcp_client.py` | Routes tool calls via registry lookup; exception wrapping |
| Orchestrator | `cloud-brain/app/agent/orchestrator.py` | Scaffold for Phase 1.8 LLM integration |
| Memory Store | `cloud-brain/app/agent/context_manager/memory_store.py` | `MemoryStore` protocol + `InMemoryStore` dev stub |
| User Profile | `cloud-brain/app/agent/context_manager/user_profile_service.py` | Queries existing `users` table via SQLAlchemy |

### Tests (28 new)

| File | Tests | Covers |
|---|---|---|
| `tests/mcp/test_base_server.py` | 8 | ABC contract, typed returns, enforcement |
| `tests/mcp/test_registry.py` | 8 | Registration, duplicate detection, tool routing |
| `tests/mcp/test_client.py` | 5 | Routing, not-found, exception wrapping |
| `tests/mcp/test_memory_store.py` | 7 | Protocol compliance, user isolation, metadata |

## Deviations from Original Plan

1. **No Pinecone dependency**: Built abstract `MemoryStore` protocol + `InMemoryStore` stub. Pinecone adapter deferred to Phase 1.8 when real embeddings exist — follows Phase 1.1's "premature deps deferred" principle.
2. **No module-level singleton**: `MCPServerRegistry` instantiated in `main.py` lifespan and stored on `app.state` — consistent with Phase 1.2's DI pattern for `AuthService`.
3. **Typed returns, not raw dicts**: `execute_tool()` returns `ToolResult`, `get_tools()` returns `list[ToolDefinition]` — the plan defined these models but never enforced their use.
4. **Dynamic tool schemas (1.3.3)**: No static `TOOLS_SCHEMA` string. Tools are aggregated dynamically via `registry.get_all_tools()` at runtime.
5. **MCPClient consumes registry, not duplicates it**: Single source of truth for servers (registry), client delegates lookup.
6. **Fixed import paths**: Used `from app.xxx` consistently (not `from cloudbrain.app`).
7. **UserProfileService queries real DB**: Reads existing `users` table instead of returning hardcoded stub dicts.
8. **Pydantic v2 conventions**: Used `model_config` dict, not deprecated `class Config`.

## Verification Results

| Check | Result |
|---|---|
| `uv run pytest tests/mcp/ -v` | ✅ 28 passed |
| `uv run pytest tests/ -v` | ✅ 37 passed (28 new + 9 regression) |
| `uv run ruff check app/ tests/` | ✅ All checks passed |
| Import smoke test | ✅ All imports OK |

## Next Steps

- Phase 1.4+ can register concrete servers (Strava, HealthKit, etc.) via `registry.register(...)` in `main.py` lifespan.
- Phase 1.8 (AI Brain) will add the Pinecone `MemoryStore` adapter and LLM function-calling to the Orchestrator.
- The `UserProfileService` will need schema expansion when coach persona / goals columns are added.

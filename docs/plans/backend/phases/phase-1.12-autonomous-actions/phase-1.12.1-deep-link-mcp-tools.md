# Phase 1.12.1: Deep Link MCP Tools

**Parent Goal:** Phase 1.12 Autonomous Actions & Deep Linking
**Checklist:**
- [x] 1.12.1 Deep Link MCP Tools
- [ ] 1.12.2 Edge Agent Deep Link Executor
- [ ] 1.12.3 Autonomous Action Response Format
- [ ] 1.12.4 Harness: Deep Link Test
- [ ] 1.12.5 Integration Document

---

## What
Create an MCP Server that exposes tools for opening specific screens in external apps (e.g., "Start Strava Recording", "Open CalAI Camera").

## Why
The AI knows *what* needs to happen ("User should go for a run"). It needs a tool to *make* it happen, bridging the gap between text advice and app action.

## How
Define `DeepLinkServer` with tools that return a specific `client_action` payload, which the Orchestrator passes to the frontend.

## Features
- **Validation:** Ensures the requested app matches a supported integration.
- **Paramyzation:** "Log Coffee" -> `calai://search?q=coffee`.

## Files
- Create: `cloud-brain/app/mcp/servers/deep_link_server.py`

## Steps

1. **Create Deep Link server (`cloud-brain/app/mcp/servers/deep_link_server.py`)**

```python
from cloudbrain.app.mcp.base import BaseMCPServer, ToolResult

class DeepLinkServer(BaseMCPServer):
    """MCP server for deep linking to external apps."""
    
    def get_tools(self) -> list[dict]:
        return [
            {
                "name": "open_external_app",
                "description": "Open a specific screen in an external app.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "app_name": {"type": "string", "enum": ["strava", "calai", "myfitnesspal"]},
                        "action": {"type": "string", "enum": ["record", "camera", "home", "search"]},
                        "query": {"type": "string", "description": "Search term if action is search"}
                    },
                    "required": ["app_name", "action"]
                }
            }
        ]
    
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> ToolResult:
        app = params.get("app_name")
        action = params.get("action")
        query = params.get("query", "")
        
        deep_link = ""
        
        if app == "strava":
             if action == "record": deep_link = "strava://record"
             else: deep_link = "strava://home"
        elif app == "calai":
             if action == "camera": deep_link = "calai://camera"
             elif action == "search": deep_link = f"calai://search?q={query}"
             
        # We don't "open" it here. We return the link so the Client can open it.
        return ToolResult(
            content=f"Opening {app}...",
            meta={"client_action": "open_url", "url": deep_link}
        )
```

## Exit Criteria
- Tools exposed to agent.
- `execute_tool` returns metadata for client execution.

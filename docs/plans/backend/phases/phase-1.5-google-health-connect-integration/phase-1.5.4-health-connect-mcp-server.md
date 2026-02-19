# Phase 1.5.4: Health Connect MCP Server

**Parent Goal:** Phase 1.5 Google Health Connect Integration
**Checklist:**
- [x] 1.5.1 Health Connect Permissions (Android)
- [x] 1.5.2 Kotlin Health Connect Bridge
- [x] 1.5.3 Flutter Platform Channel (Android)
- [ ] 1.5.4 Health Connect MCP Server
- [ ] 1.5.5 Background Sync (Android WorkManager)
- [ ] 1.5.6 Unified Health Store Abstraction
- [ ] 1.5.7 Health Connect Integration Document

---

## What
Create the `HealthConnectServer` class on the backend (Cloud Brain) that exposes Health Connect capabilities to the LLM agent.

## Why
This allows the AI to "see" and "act upon" Android health data, mirroring the capabilities we built for iOS.

## How
Inherit from `BaseMCPServer` and define the `get_tools()` schema for `health_connect_read_metrics` and `health_connect_write_entry`.

## Features
- **Symmetry:** Provides almost identical capabilities to `AppleHealthServer`, simplifying the Agent's reasoning logic.
- **Dynamic Tool Dispatch:** The system will know which tool to use based on the user's primary device (or both).

## Files
- Create: `cloud-brain/app/mcp_servers/health_connect_server.py`
- Modify: `cloud-brain/app/main.py`

## Steps

1. **Create Health Connect MCP server (`cloud-brain/app/mcp_servers/health_connect_server.py`)**

```python
from cloudbrain.app.mcp_servers.base_server import BaseMCPServer
# from cloudbrain.app.config import settings

class HealthConnectServer(BaseMCPServer):
    """MCP server for Google Health Connect via Edge Agent."""
    
    @property
    def name(self) -> str:
        return "health_connect"
    
    @property
    def description(self) -> str:
        return "Read and write health data on Android via Google Health Connect"
    
    def get_tools(self) -> list[dict]:
        return [
            {
                "name": "health_connect_read_metrics",
                "description": "Read health metrics from Google Health Connect",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "data_type": {"type": "string", "enum": ["steps", "calories", "workouts", "sleep", "weight"]},
                        "start_date": {"type": "string", "description": "ISO 8601"},
                        "end_date": {"type": "string", "description": "ISO 8601"},
                    },
                    "required": ["data_type", "start_date", "end_date"]
                }
            },
            {
                "name": "health_connect_write_entry",
                "description": "Write health data to Google Health Connect",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "data_type": {"type": "string", "enum": ["nutrition", "weight"]},
                        "value": {"type": "number"},
                        "date": {"type": "string", "description": "ISO 8601"},
                    },
                    "required": ["data_type", "value", "date"]
                }
            }
        ]
    
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
        # Implementation concept:
        # 1. Check if user has an active Android device connected via WebSocket/FCM.
        # 2. Send payload to device.
        # 3. Device executes HealthConnectBridge -> returns result.
        
        # For MVP/Sim:
        if tool_name == "health_connect_read_metrics":
             return {
                "success": True, 
                "data": {"status": "pending_device_sync", "message": "Request queued for Android device"}
            }
            
        return {"success": False, "error": f"Unknown tool: {tool_name}"}
    
    async def get_resources(self, user_id: str) -> list[dict]:
        return [
            {"type": "recent_workouts", "description": "Last 7 days of workouts from Health Connect"},
            {"type": "today_summary", "description": "Today's steps and calories"}
        ]
```

2. **Register in registry (`cloud-brain/app/main.py`)**

```python
from cloudbrain.app.mcp_servers.health_connect_server import HealthConnectServer
from cloudbrain.app.mcp_servers.registry import registry

registry.register(HealthConnectServer())
```

## Exit Criteria
- Server registered.
- Tools exposed to MCP client.

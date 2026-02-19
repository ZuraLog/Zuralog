# Phase 1.4.4: HealthKit MCP Server (Cloud Brain)

**Parent Goal:** Phase 1.4 Apple HealthKit Integration
**Checklist:**
- [x] 1.4.1 HealthKit Entitlements & Permissions (iOS)
- [x] 1.4.2 Swift HealthKit Bridge
- [x] 1.4.3 Flutter Platform Channel
- [ ] 1.4.4 HealthKit MCP Server (Cloud Brain)
- [ ] 1.4.5 Edge Agent Health Repository
- [ ] 1.4.6 Background Observation
- [ ] 1.4.7 Harness Test: HealthKit Integration
- [ ] 1.4.8 Apple Health Integration Document

---

## What
Create the `AppleHealthServer` class on the backend (Cloud Brain) that exposes specific HealthKit capabilities as "Tools" to the LLM agent.

## Why
This maps the low-level API calls (which happen on the user's phone) to semantic actions the AI can understand (e.g., "apple_health_read_metrics"). It acts as the definition of what the AI *can* do with Apple Health.

## How
Inherit from `BaseMCPServer` and define the `get_tools()` schema.
*Note: In the MVP, the `execute_tool` method will essentially construct a message to send to the Edge Agent (conceptually), but for now, it serves as the schema definition point.*

## Features
- **Read Metrics:** Steps, calories, workouts.
- **Write Metrics:** Log a workout, add nutrition entry.

## Files
- Create: `cloud-brain/app/mcp_servers/apple_health_server.py`
- Modify: `cloud-brain/app/main.py`

## Steps

1. **Create HealthKit MCP server (`cloud-brain/app/mcp_servers/apple_health_server.py`)**

```python
from cloudbrain.app.mcp_servers.base_server import BaseMCPServer
from cloudbrain.app.config import settings

class AppleHealthServer(BaseMCPServer):
    """MCP server for Apple HealthKit via Edge Agent."""
    
    @property
    def name(self) -> str:
        return "apple_health"
    
    @property
    def description(self) -> str:
        return "Read and write Apple HealthKit data on the user's iOS device"
    
    def get_tools(self) -> list[dict]:
        return [
            # Check phase-1.3.3-tool-schema-definitions.md for exact prompts to match
            {
                "name": "apple_health_read_metrics",
                "description": "Read health metrics from Apple HealthKit (steps, calories, workouts, sleep)",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "data_type": {"type": "string", "enum": ["steps", "calories", "workouts", "sleep", "weight"]},
                        "start_date": {"type": "string", "description": "ISO 8601 date"},
                        "end_date": {"type": "string", "description": "ISO 8601 date"},
                    },
                    "required": ["data_type", "start_date", "end_date"]
                }
            },
            {
                "name": "apple_health_write_entry",
                "description": "Write health data to Apple HealthKit (nutrition, workout, weight)",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "data_type": {"type": "string", "enum": ["nutrition", "workout", "weight"]},
                        "value": {"type": "number"},
                        "date": {"type": "string", "description": "ISO 8601 date"},
                        "metadata": {"type": "object", "description": "Additional data (e.g., activity type for workouts)"}
                    },
                    "required": ["data_type", "value", "date"]
                }
            }
        ]
    
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
        """Execute tool by sending command to Edge Agent via FCM or REST."""
        if tool_name == "apple_health_read_metrics":
            # In later phases, this triggers a push notification to Edge Agent
            return {
                "success": True, 
                "data": {"status": "pending_device_sync", "message": "Request queued for device"}
            }
        # ... handle write tool ...
        return {"success": False, "error": f"Unknown tool: {tool_name}"}
    
    async def get_resources(self, user_id: str) -> list[dict]:
        return []
```

2. **Register server in registry (`cloud-brain/app/main.py`)**

```python
from cloudbrain.app.mcp_servers.apple_health_server import AppleHealthServer
from cloudbrain.app.mcp_servers.registry import registry

registry.register(AppleHealthServer())
```

## Exit Criteria
- Server defined with correct tools.
- Registered in the global registry.

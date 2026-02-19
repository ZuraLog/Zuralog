# Phase 1.6.3: Strava MCP Server

**Parent Goal:** Phase 1.6 Strava Integration
**Checklist:**
- [x] 1.6.1 Strava API Setup
- [x] 1.6.2 Strava OAuth Flow (Cloud Brain)
- [ ] 1.6.3 Strava MCP Server
- [ ] 1.6.4 Edge Agent OAuth Flow
- [ ] 1.6.5 Deep Link Handling
- [ ] 1.6.6 Strava WebView Button
- [ ] 1.6.7 Strava Integration Document

---

## What
Create an MCP server that wraps the Strava API. This allows the Agent to say "Get my last run" and have the system fetch it from Strava.

## Why
Integrations are the core value proposition. The Agent needs standard Tools to interact with third-party APIs.

## How
The `StravaServer` will use `httpx` to call Strava's REST API using the stored Access Token.

## Features
- **Read Activities:** Get recent runs/rides.
- **Write Activity:** Create a manual entry (e.g., "I did 50 pushups").
- **Athlete Stats:** Get total distance, etc.

## Files
- Create: `cloud-brain/app/mcp_servers/strava_server.py`
- Modify: `cloud-brain/app/main.py`

## Steps

1. **Create Strava MCP server (`cloud-brain/app/mcp_servers/strava_server.py`)**

```python
import httpx
from cloudbrain.app.mcp_servers.base_server import BaseMCPServer
# from cloudbrain.app.config import settings

class StravaServer(BaseMCPServer):
    """MCP server for Strava API."""
    
    @property
    def name(self) -> str:
        return "strava"
    
    @property
    def description(self) -> str:
        return "Read and write Strava activities (Runs, Rides, Swims)"
    
    def get_tools(self) -> list[dict]:
        return [
            {
                "name": "strava_get_activities",
                "description": "Get recent activities from Strava",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "limit": {"type": "integer", "default": 10},
                    }
                }
            },
            {
                "name": "strava_create_activity",
                "description": "Create a manual activity in Strava",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "type": {"type": "string", "enum": ["Run", "Ride", "Swim", "Workout", "WeightTraining"]},
                        "elapsed_time": {"type": "integer", "description": "in seconds"},
                        "start_date_local": {"type": "string", "description": "ISO 8601"},
                        "distance": {"type": "number", "description": "meters (optional)"},
                    },
                    "required": ["name", "type", "elapsed_time", "start_date_local"]
                }
            }
        ]
    
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
        # In a real impl, we'd fetch the user's access token from DB
        # token = await get_user_token(user_id)
        # For now, we mock or assume env var for single user dev
        
        token = "MOCK_TOKEN_OR_ENV" 
        
        async with httpx.AsyncClient() as client:
            headers = {"Authorization": f"Bearer {token}"}
            
            if tool_name == "strava_get_activities":
                # Real call:
                # resp = await client.get("https://www.strava.com/api/v3/athlete/activities", headers=headers)
                # return {"success": True, "data": resp.json()}
                
                # Mock Data
                return {
                    "success": True, 
                    "data": [
                        {"name": "Morning Run", "distance": 5000, "type": "Run", "id": 12345},
                        {"name": "Lunch Walk", "distance": 1500, "type": "Walk", "id": 67890}
                    ]
                }
                
            elif tool_name == "strava_create_activity":
                return {"success": True, "data": {"id": 99999, "name": params["name"]}}
                
        return {"success": False, "error": f"Unknown tool: {tool_name}"}
    
    async def get_resources(self, user_id: str) -> list[dict]:
        return [{"type": "recent_activities", "description": "List of recent Strava activities"}]
```

2. **Register in registry (`cloud-brain/app/main.py`)**

```python
from cloudbrain.app.mcp_servers.strava_server import StravaServer
from cloudbrain.app.mcp_servers.registry import registry
registry.register(StravaServer())
```

## Exit Criteria
- Strava MCP server registered.
- Can fetch mock activities via tool call.

# Phase 1.7.2: Nutrition Data Flow via Health Store

**Parent Goal:** Phase 1.7 CalAI Integration
**Checklist:**
- [x] 1.7.1 CalAI Deep Link Strategy
- [ ] 1.7.2 Nutrition Data Flow via Health Store
- [ ] 1.7.3 CalAI Integration Document

---

## What
Configure our existing MCP Servers (`apple_health` and `health_connect`) to explicitly read Nutrition data written by CalAI.

## Why
CalAI writes calories and macros to Apple Health/Health Connect. By reading from there, we get the data without needing a direct API integration with CalAI. This is the "Zero-Friction" approach.

## How
Ensure `HKQuantityType.dietaryEnergyConsumed` and equivalent Android records are included in our `read_metrics` tool.

## Features
- **Privacy First:** User controls data sharing via OS settings.
- **No API Key Needed:** We don't need to authenticate with CalAI servers.

## Files
- Modify: `cloud-brain/app/mcp_servers/apple_health_server.py`
- Modify: `cloud-brain/app/mcp_servers/health_connect_server.py`

## Steps

1. **Add nutrition reading to HealthKit MCP server (`cloud-brain/app/mcp_servers/apple_health_server.py`)**

```python
# In apple_health_server.py -> execute_tool

async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
    if tool_name == "apple_health_read_metrics":
        data_type = params.get("data_type")
        
        if data_type == "nutrition":
            # This triggers the Edge Agent to query HKQuantityType.dietaryEnergyConsumed
            return {
                "success": True,
                "data": {
                    "action": "read_healthkit",
                    "type": "nutrition",
                    "date": params.get("date", "today")
                }
            }
```

2. **Add to Health Connect server (`cloud-brain/app/mcp_servers/health_connect_server.py`)**

```python
# In health_connect_server.py -> execute_tool
# Ensure 'nutrition' is handled similarly
```

## Exit Criteria
- MCP server tools include nutrition data type support.
- Agent prompt updated to know it can "check nutrition" via Health tools.

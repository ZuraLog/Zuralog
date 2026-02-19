# Phase 1.3.3: Tool Schema Definitions

**Parent Goal:** Phase 1.3 MCP Base Framework
**Checklist:**
- [x] 1.3.1 MCP Server Base Class
- [x] 1.3.2 MCP Client (Orchestrator)
- [ ] 1.3.3 Tool Schema Definitions
- [ ] 1.3.4 Context Manager (Pinecone Integration)
- [ ] 1.3.5 MCP Server Registry
- [ ] 1.3.6 MCP Integration Tests

---

## What
Define a centralized "manifest" or docstring-based schema of all tools the AI can access. This serves as the "System Tool Definition" passed to the LLM (OpenAI/Kimi) during conversation setup.

## Why
LLMs need precise instructions on *what* functions are available and *how* to call them (parameters, types). Centralizing this makes it easier to manage the agent's capabilities and ensures the documentation matches the code.

## How
We will create a python file containing the JSON-schema definitions or a string representation that maps to our implementations. (Note: In dynamic systems, this is generated from code, but for planning/documentation, we define the contract here).

## Features
- **Capability Map:** Clear view of what the AI can do (Read Strava, Write HealthKit, Open App).
- **Prompt Engineering:** Optimized descriptions to ensure the LLM picks the right tool.

## Files
- Create: `cloud-brain/app/agent/prompts/tools_schema.py`

## Steps

1. **Create consolidated tools schema**

```python
# This file consolidates all MCP tool definitions for the LLM

TOOLS_SCHEMA = """
# Available Tools

## Strava
- get_activities: Get recent activities from Strava
  params: user_id, limit (optional), start_date (optional)
- create_activity: Create a manual activity in Strava
  params: user_id, name, sport_type, distance, elapsed_time, start_date_local
- get_athlete_stats: Get athlete statistics from Strava
  params: user_id

## Apple Health
- read_health_metrics: Read health data from Apple HealthKit
  params: user_id, data_type (steps|calories|heart_rate|sleep|workouts), start_date, end_date
- write_health_entry: Write health data to Apple HealthKit
  params: user_id, data_type, value, date

## Google Health Connect
- read_health_connect: Read health data from Google Health Connect
  params: user_id, data_type, start_date, end_date
- write_health_connect: Write health data to Google Health Connect
  params: user_id, data_type, value, date

## Deep Links
- open_app: Open an external app via deep link
  params: app (strava|calai|myfitnesspal), action (record|camera)
"""
```

*(Note: In the actual implementation, these schemas will likely be generated dynamically by calling `get_tools()` on registered servers, but this file serves as the design contract.)*

## Exit Criteria
- Tools schema defined in a centralized file.

# Phase 1.12.3: Autonomous Action Response Format

**Parent Goal:** Phase 1.12 Autonomous Actions & Deep Linking
**Checklist:**
- [x] 1.12.1 Deep Link MCP Tools
- [x] 1.12.2 Edge Agent Deep Link Executor
- [x] 1.12.3 Autonomous Action Response Format
- [ ] 1.12.4 Harness: Deep Link Test
- [ ] 1.12.5 Integration Document

---

## What
Standardize the API response structure so the Edge Agent knows when to display a message vs. when to execute a command.

## Why
We can't just mix text and commands. Start-up of external apps should be explicit and client-controlled.

## How
Modify the `Orchestrator` to return a structured JSON object, not just a string.

## Features
- **Action Type:** `deep_link`, `navigation` (internal), `confetti` (UI effect).
- **Fallback Text:** Message to show if action fails.

## Files
- Modify: `cloud-brain/app/agent/orchestrator.py`

## Steps

1. **Update Orchestrator Response (`cloud-brain/app/agent/orchestrator.py`)**

```python
from pydantic import BaseModel
from typing import Optional, Dict, Any

class AgentResponse(BaseModel):
    message: str
    client_action: Optional[Dict[str, Any]] = None

# In Orchestrator.process_message
async def process_message(...) -> AgentResponse:
    # ... logic ...
    
    # If tool returned a client_action metadata
    if tool_result.meta and "client_action" in tool_result.meta:
        return AgentResponse(
            message="Opening app...",
            client_action=tool_result.meta
        )
        
    return AgentResponse(message=llm_text)
```

## Exit Criteria
- API returns JSON with optional `client_action` field.

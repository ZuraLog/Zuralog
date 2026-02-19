# Phase 1.3.1: MCP Server Base Class

**Parent Goal:** Phase 1.3 MCP Base Framework
**Checklist:**
- [ ] 1.3.1 MCP Server Base Class
- [ ] 1.3.2 MCP Client (Orchestrator)
- [ ] 1.3.3 Tool Schema Definitions
- [ ] 1.3.4 Context Manager (Pinecone Integration)
- [ ] 1.3.5 MCP Server Registry
- [ ] 1.3.6 MCP Integration Tests

---

## What
Define an abstract base class (`BaseMCPServer`) that adheres to the Model Context Protocol. All future integrations (Strava, Apple Health, etc.) will inherit from this class.

## Why
Consistency is key when managing multiple diverse integrations. By enforcing a strict interface (get_tools, execute_tool, get_resources), we ensure the orchestration layer doesn't need custom logic for each new integration we add.

## How
We will use Python's `abc` (Abstract Base Classes) module to enforce the implementation of required methods. We will also define Pydantic models for standardized return types.

## Features
- **Standardized Interface:** Any service can easily plug into the Cloud Brain.
- **Type Safety:** Ensures all tools return data in a predictable format (`ToolResult`).
- **Discovery:** Allows the orchestration layer to dynamically inspect available tools.

## Files
- Create: `cloud-brain/app/mcp_servers/base_server.py`
- Create: `cloud-brain/app/mcp_servers/__init__.py`
- Create: `cloud-brain/app/mcp_servers/models.py`

## Steps

1. **Create base MCP server class**

```python
from abc import ABC, abstractmethod
from typing import Any

class BaseMCPServer(ABC):
    """Abstract MCP server interface."""
    
    @property
    @abstractmethod
    def name(self) -> str:
        """Server name for identification."""
        pass
    
    @property
    @abstractmethod
    def description(self) -> str:
        """Server description for tool schema."""
        pass
    
    @abstractmethod
    def get_tools(self) -> list[dict]:
        """
        Return tool schemas the LLM can call.
        Format: [
            {
                "name": "tool_name",
                "description": "What this tool does",
                "input_schema": {
                    "type": "object",
                    "properties": {...},
                    "required": [...]
                }
            }
        ]
        """
        pass
    
    @abstractmethod
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
        """
        Execute a tool call and return structured results.
        
        Args:
            tool_name: Name of the tool to execute
            params: Parameters for the tool
            user_id: The user making the request
            
        Returns:
            dict with 'success', 'data', and optionally 'error' keys
        """
        pass
    
    @abstractmethod
    async def get_resources(self, user_id: str) -> list[dict]:
        """
        Return available data resources (e.g., recent activities).
        """
        pass
```

2. **Create tool result model**

```python
# cloud-brain/app/mcp_servers/models.py
from pydantic import BaseModel
from typing import Any

class ToolResult(BaseModel):
    success: bool
    data: Any = None
    error: str | None = None
    
    class Config:
        arbitrary_types_allowed = True
```

## Exit Criteria
- Base class defined along with ToolResult model.

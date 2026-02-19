# Phase 1.3.2: MCP Client (Orchestrator)

**Parent Goal:** Phase 1.3 MCP Base Framework
**Checklist:**
- [x] 1.3.1 MCP Server Base Class
- [ ] 1.3.2 MCP Client (Orchestrator)
- [ ] 1.3.3 Tool Schema Definitions
- [ ] 1.3.4 Context Manager (Pinecone Integration)
- [ ] 1.3.5 MCP Server Registry
- [ ] 1.3.6 MCP Integration Tests

---

## What
Implement the `MCPClient` which acts as the router/dispatcher. It holds references to all registered MCP servers and routes an incoming tool execution request (e.g., "get_activities") to the correct server (e.g., "strava_server"). We also scaffold the `Orchestrator` which will eventually hold the LLM logic.

## Why
The LLM doesn't know *how* to call Strava or Apple Health. It just outputs a function name like `get_activities`. The `MCPClient` bridges the gap between the LLM's intent and the actual code execution, centralizing error handling and routing.

## How
We will use a Registry pattern where servers register themselves with the Client. The Client maintains a mapping of `tool_name` -> `server_instance` (or iterates servers to find the tool).

## Features
- **Dynamic Routing:** Decouples the request from the handler.
- **Tool Aggregation:** Can produce a consolidated list of *all* tools available across all connected apps for the system prompt.
- **Unified Execution:** Single entry point for executing any action in the system.

## Files
- Create: `cloud-brain/app/agent/mcp_client.py`
- Create: `cloud-brain/app/agent/orchestrator.py`

## Steps

1. **Create MCP client**

```python
from typing import Any
from cloudbrain.app.mcp_servers.base_server import BaseMCPServer

class MCPClient:
    """Routes tool calls to the appropriate MCP server."""
    
    def __init__(self):
        self._servers: dict[str, BaseMCPServer] = {}
    
    def register_server(self, server: BaseMCPServer):
        """Register an MCP server."""
        self._servers[server.name] = server
    
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
        """Execute a tool across all registered servers."""
        # Find which server has this tool
        for server in self._servers.values():
            tools = server.get_tools()
            tool_names = [t['name'] for t in tools]
            
            if tool_name in tool_names:
                return await server.execute_tool(tool_name, params, user_id)
        
        return {"success": False, "error": f"Tool {tool_name} not found"}
    
    def get_all_tools(self) -> list[dict]:
        """Get consolidated tool list from all servers."""
        tools = []
        for server in self._servers.values():
            tools.extend(server.get_tools())
        return tools
```

2. **Create orchestrator**

```python
# cloud-brain/app/agent/orchestrator.py
from cloudbrain.app.agent.mcp_client import MCPClient
from cloudbrain.app.agent.context_manager.memory_manager import MemoryManager # Updated import

class Orchestrator:
    """LLM Agent that orchestrates MCP tool calls."""
    
    def __init__(self, mcp_client: MCPClient, memory_manager: MemoryManager):
        self.mcp_client = mcp_client
        self.memory_manager = memory_manager
    
    async def process_message(self, user_id: str, message: str) -> str:
        """
        Process user message and return AI response.
        This is a simplified version - full version uses OpenAI function calling.
        """
        # 1. Get user context from Pinecone
        context = await self.memory_manager.get_context(user_id)
        
        # 2. Get available tools
        tools = self.mcp_client.get_all_tools()
        
        # 3. In MVP, we use a simple prompt to determine if tools are needed
        # Full version: OpenAI function calling to select tools
        response = f"Processing: {message}"
        
        return response
```

## Exit Criteria
- MCP Client compiles and can route messages.
- Orchestrator skeleton compiles.

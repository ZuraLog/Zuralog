# Phase 1.3.6: MCP Integration Tests

**Parent Goal:** Phase 1.3 MCP Base Framework
**Checklist:**
- [x] 1.3.1 MCP Server Base Class
- [x] 1.3.2 MCP Client (Orchestrator)
- [x] 1.3.3 Tool Schema Definitions
- [x] 1.3.4 Context Manager (Pinecone Integration)
- [x] 1.3.5 MCP Server Registry
- [ ] 1.3.6 MCP Integration Tests

---

## What
Create a suite of tests to verify the core MCP architecture. We will implement valid "Mock" servers and tools to ensure the `MCPClient`, `Registry`, and `BaseServer` logic works correctly before building real integrations.

## Why
The MCP Framework is the backbone of the entire reasoning engine. If routing logic or tool execution contract is broken, the AI will fail to use Strava/HealthKit. Testing with mocks isolates framework bugs from integration bugs.

## How
We will use `pytest` and `asyncio`. We will define a `MockServer` that implements `BaseMCPServer`, register it, and then use the `MCPClient` to call a method on it, asserting the result.

## Features
- **Regression Testing:** Ensure core logic remains stable as we add features.
- **Contract Verification:** Proves that our `BaseMCPServer` interface is implementable.

## Files
- Create: `cloud-brain/tests/mcp/test_base_server.py`
- Create: `cloud-brain/tests/mcp/test_client.py`

## Steps

1. **Write base server test**

```python
import pytest
from cloudbrain.app.mcp_servers.base_server import BaseMCPServer

class MockServer(BaseMCPServer):
    @property
    def name(self) -> str:
        return "mock_server"
    
    @property
    def description(self) -> str:
        return "Mock server for testing"
    
    def get_tools(self) -> list[dict]:
        return [
            {
                "name": "mock_tool",
                "description": "A mock tool",
                "input_schema": {
                    "type": "object",
                    "properties": {"input": {"type": "string"}},
                    "required": ["input"]
                }
            }
        ]
    
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
        return {"success": True, "data": f"Mock executed: {params}"}
    
    async def get_resources(self, user_id: str) -> list[dict]:
        return [{"type": "mock_resource", "data": "test"}]

@pytest.mark.asyncio
async def test_mock_server_inherits_base():
    server = MockServer()
    assert server.name == "mock_server"
    assert len(server.get_tools()) == 1
    
    result = await server.execute_tool("mock_tool", {"input": "test"}, "user_1")
    assert result["success"] is True
    assert "Mock executed" in result["data"]
```

2. **Run tests**

```bash
cd cloud-brain
poetry run pytest tests/mcp/ -v
```

## Exit Criteria
- Tests run and pass.

# Phase 1.3.5: MCP Server Registry

**Parent Goal:** Phase 1.3 MCP Base Framework
**Checklist:**
- [x] 1.3.1 MCP Server Base Class
- [x] 1.3.2 MCP Client (Orchestrator)
- [x] 1.3.3 Tool Schema Definitions
- [x] 1.3.4 Context Manager (Pinecone Integration)
- [ ] 1.3.5 MCP Server Registry
- [ ] 1.3.6 MCP Integration Tests

---

## What
Implement a Singleton Registry pattern to manage the lifecycle and access of all MCP servers. This is the "Phonebook" of the application, knowing where `strava`, `healthkit`, and `reasoning` servers live.

## Why
We need a central place to instantiate servers once and reuse them. It also provides a clean injection point for the `MCPClient` to discover what servers are available at runtime.

## How
Simple Python class holding a dictionary of `name` -> `instance`, instantiated as a global singleton.

## Features
- **Hot Pluggability:** (Future) Could allow registering new plugins dynamically.
- **Central Access:** Single source of truth for all integrations.

## Files
- Create: `cloud-brain/app/mcp_servers/registry.py`

## Steps

1. **Create server registry**

```python
from cloudbrain.app.mcp_servers.base_server import BaseMCPServer

class MCPServerRegistry:
    """Central registry for all MCP servers."""
    
    def __init__(self):
        self._servers: dict[str, BaseMCPServer] = {}
    
    def register(self, server: BaseMCPServer):
        self._servers[server.name] = server
    
    def get(self, name: str) -> BaseMCPServer | None:
        return self._servers.get(name)
    
    def list_all(self) -> list[BaseMCPServer]:
        return list(self._servers.values())

# Global registry instance
registry = MCPServerRegistry()
```

## Exit Criteria
- Registry class implemented and global instance available.

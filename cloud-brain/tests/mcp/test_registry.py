"""
Zuralog Cloud Brain — MCP Server Registry Tests.

Verifies registration, duplicate detection, tool routing, and
aggregated tool discovery across multiple mock servers.
"""

import pytest

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult
from app.mcp_servers.registry import MCPServerRegistry

# ---------------------------------------------------------------------------
# Mock Servers
# ---------------------------------------------------------------------------


class ServerA(BaseMCPServer):
    """Mock server exposing tool_a_1 and tool_a_2."""

    @property
    def name(self) -> str:
        return "server_a"

    @property
    def description(self) -> str:
        return "Test server A."

    def get_tools(self) -> list[ToolDefinition]:
        return [
            ToolDefinition(name="tool_a_1", description="Tool A1"),
            ToolDefinition(name="tool_a_2", description="Tool A2"),
        ]

    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> ToolResult:
        return ToolResult(success=True, data=f"A:{tool_name}")

    async def get_resources(self, user_id: str) -> list[Resource]:
        return []


class ServerB(BaseMCPServer):
    """Mock server exposing tool_b_1."""

    @property
    def name(self) -> str:
        return "server_b"

    @property
    def description(self) -> str:
        return "Test server B."

    def get_tools(self) -> list[ToolDefinition]:
        return [
            ToolDefinition(name="tool_b_1", description="Tool B1"),
        ]

    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> ToolResult:
        return ToolResult(success=True, data=f"B:{tool_name}")

    async def get_resources(self, user_id: str) -> list[Resource]:
        return []


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestMCPServerRegistry:
    """Tests for MCPServerRegistry."""

    def test_register_and_get(self) -> None:
        """Registered servers are retrievable by name."""
        registry = MCPServerRegistry()
        server = ServerA()
        registry.register(server)
        assert registry.get("server_a") is server

    def test_get_unknown_returns_none(self) -> None:
        """Getting an unregistered server returns None."""
        registry = MCPServerRegistry()
        assert registry.get("nonexistent") is None

    def test_duplicate_registration_raises_value_error(self) -> None:
        """Registering the same server name twice raises ValueError."""
        registry = MCPServerRegistry()
        registry.register(ServerA())
        with pytest.raises(ValueError, match="already registered"):
            registry.register(ServerA())

    def test_list_all(self) -> None:
        """list_all returns all registered servers."""
        registry = MCPServerRegistry()
        a, b = ServerA(), ServerB()
        registry.register(a)
        registry.register(b)
        assert registry.list_all() == [a, b]

    def test_get_by_tool_found(self) -> None:
        """get_by_tool returns the correct owning server."""
        registry = MCPServerRegistry()
        a, b = ServerA(), ServerB()
        registry.register(a)
        registry.register(b)
        assert registry.get_by_tool("tool_a_1") is a
        assert registry.get_by_tool("tool_b_1") is b

    def test_get_by_tool_not_found(self) -> None:
        """get_by_tool returns None for unknown tools."""
        registry = MCPServerRegistry()
        registry.register(ServerA())
        assert registry.get_by_tool("nonexistent") is None

    def test_get_all_tools_aggregation(self) -> None:
        """get_all_tools aggregates tools from all servers."""
        registry = MCPServerRegistry()
        registry.register(ServerA())
        registry.register(ServerB())
        tools = registry.get_all_tools()
        names = [t.name for t in tools]
        assert names == ["tool_a_1", "tool_a_2", "tool_b_1"]

    def test_get_all_tools_empty_registry(self) -> None:
        """get_all_tools returns empty list on empty registry."""
        registry = MCPServerRegistry()
        assert registry.get_all_tools() == []

    def test_get_tools_for_servers_filters_correctly(self) -> None:
        """Only returns tools from the specified server names."""
        registry = MCPServerRegistry()
        registry.register(ServerA())
        registry.register(ServerB())
        tools = registry.get_tools_for_servers({"server_a"})
        tool_names = [t.name for t in tools]
        assert "tool_a_1" in tool_names
        assert "tool_a_2" in tool_names
        assert "tool_b_1" not in tool_names

    def test_get_tools_for_servers_empty_set_returns_empty(self) -> None:
        """An empty server set returns no tools."""
        registry = MCPServerRegistry()
        registry.register(ServerA())
        registry.register(ServerB())
        tools = registry.get_tools_for_servers(set())
        assert tools == []

    def test_get_tools_for_servers_unknown_name_ignored(self) -> None:
        """Unknown server names are silently skipped."""
        registry = MCPServerRegistry()
        registry.register(ServerA())
        tools = registry.get_tools_for_servers({"nonexistent_server"})
        assert tools == []

    def test_get_tools_for_servers_all_names_returns_all(self) -> None:
        """Passing all registered names returns the same as get_all_tools()."""
        registry = MCPServerRegistry()
        registry.register(ServerA())
        registry.register(ServerB())
        all_names = {s.name for s in registry.list_all()}
        filtered = registry.get_tools_for_servers(all_names)
        all_tools = registry.get_all_tools()
        assert sorted(t.name for t in filtered) == sorted(t.name for t in all_tools)

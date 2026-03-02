"""
Zuralog Cloud Brain — MCP Client Tests.

Verifies tool routing through the registry, error handling for
unknown tools, exception wrapping, and tool aggregation delegation.
"""

import pytest
from unittest.mock import AsyncMock, MagicMock

from app.agent.mcp_client import MCPClient
from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult
from app.mcp_servers.registry import MCPServerRegistry

# ---------------------------------------------------------------------------
# Mock Servers
# ---------------------------------------------------------------------------


class HealthServer(BaseMCPServer):
    """Mock server simulating a health data integration."""

    @property
    def name(self) -> str:
        return "health_server"

    @property
    def description(self) -> str:
        return "Mock health integration."

    def get_tools(self) -> list[ToolDefinition]:
        return [
            ToolDefinition(
                name="read_steps",
                description="Read step count.",
                input_schema={
                    "type": "object",
                    "properties": {"date": {"type": "string"}},
                    "required": ["date"],
                },
            ),
        ]

    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> ToolResult:
        if tool_name == "read_steps":
            return ToolResult(success=True, data={"steps": 8500, "date": params.get("date")})
        return ToolResult(success=False, error=f"Unknown tool: {tool_name}")

    async def get_resources(self, user_id: str) -> list[Resource]:
        return []


class FailingServer(BaseMCPServer):
    """Mock server that raises exceptions during tool execution."""

    @property
    def name(self) -> str:
        return "failing_server"

    @property
    def description(self) -> str:
        return "Server that always fails."

    def get_tools(self) -> list[ToolDefinition]:
        return [ToolDefinition(name="will_fail", description="Always raises.")]

    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> ToolResult:
        raise RuntimeError("Simulated external API failure")

    async def get_resources(self, user_id: str) -> list[Resource]:
        return []


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class WeatherServer(BaseMCPServer):
    """Mock server simulating a weather integration."""

    @property
    def name(self) -> str:
        return "weather_server"

    @property
    def description(self) -> str:
        return "Mock weather integration."

    def get_tools(self) -> list[ToolDefinition]:
        return [
            ToolDefinition(
                name="get_forecast",
                description="Get weather forecast.",
                input_schema={"type": "object", "properties": {}},
            ),
        ]

    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> ToolResult:
        return ToolResult(success=True, data={"forecast": "sunny"})

    async def get_resources(self, user_id: str) -> list[Resource]:
        return []


class TestMCPClient:
    """Tests for MCPClient tool routing and error handling."""

    @pytest.fixture
    def client_with_health(self) -> MCPClient:
        """Create an MCPClient with one mock health server."""
        registry = MCPServerRegistry()
        registry.register(HealthServer())
        return MCPClient(registry=registry)

    @pytest.mark.asyncio
    async def test_execute_tool_routes_correctly(self, client_with_health: MCPClient) -> None:
        """Tool call is routed to the correct server and returns data."""
        result = await client_with_health.execute_tool(
            "read_steps",
            {"date": "2026-02-20"},
            "user_1",
        )
        assert result.success is True
        assert result.data["steps"] == 8500
        assert result.data["date"] == "2026-02-20"

    @pytest.mark.asyncio
    async def test_execute_tool_not_found(self, client_with_health: MCPClient) -> None:
        """Unknown tool returns error ToolResult (not exception)."""
        result = await client_with_health.execute_tool(
            "nonexistent_tool",
            {},
            "user_1",
        )
        assert result.success is False
        assert result.error is not None
        assert "not found" in result.error

    @pytest.mark.asyncio
    async def test_execute_tool_wraps_exceptions(self) -> None:
        """Server exceptions are caught and wrapped in ToolResult."""
        registry = MCPServerRegistry()
        registry.register(FailingServer())
        client = MCPClient(registry=registry)

        result = await client.execute_tool("will_fail", {}, "user_1")
        assert result.success is False
        assert result.error is not None
        assert "Simulated external API failure" in result.error

    def test_get_all_tools_delegates_to_registry(self, client_with_health: MCPClient) -> None:
        """get_all_tools returns tools from the underlying registry."""
        tools = client_with_health.get_all_tools()
        assert len(tools) == 1
        assert tools[0].name == "read_steps"

    def test_get_all_tools_empty(self) -> None:
        """Empty registry yields empty tool list."""
        client = MCPClient(registry=MCPServerRegistry())
        assert client.get_all_tools() == []

    @pytest.mark.asyncio
    async def test_get_tools_for_user_delegates_to_resolver(self) -> None:
        """get_tools_for_user() delegates to the UserToolResolver."""
        mock_tool = ToolDefinition(
            name="strava_get_activities",
            description="Get Strava activities",
            input_schema={"type": "object", "properties": {}},
        )
        mock_resolver = MagicMock()
        mock_resolver.resolve_tools = AsyncMock(return_value=[mock_tool])
        mock_db = AsyncMock()

        registry = MCPServerRegistry()
        client = MCPClient(registry=registry, tool_resolver=mock_resolver)

        tools = await client.get_tools_for_user(mock_db, "user-123")
        assert len(tools) == 1
        assert tools[0].name == "strava_get_activities"
        mock_resolver.resolve_tools.assert_called_once_with(mock_db, "user-123")

    @pytest.mark.asyncio
    async def test_get_tools_for_user_without_resolver_returns_all(self) -> None:
        """If no resolver is provided, falls back to get_all_tools() (all tools)."""
        registry = MCPServerRegistry()
        registry.register(HealthServer())
        registry.register(WeatherServer())

        client = MCPClient(registry=registry)  # No resolver
        mock_db = AsyncMock()

        tools = await client.get_tools_for_user(mock_db, "user-123")
        # Concrete assertion: 2 servers registered → 2 tools returned
        assert len(tools) == 2
        assert {t.name for t in tools} == {"read_steps", "get_forecast"}

"""Tests for HealthConnectServer MCP server.

Verifies tool definitions, execute_tool routing, typed returns,
and edge cases (unknown tools, missing params). Mirrors the
test structure from test_apple_health_server.py.
"""

import pytest

from app.mcp_servers.health_connect_server import HealthConnectServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult


@pytest.fixture
def server() -> HealthConnectServer:
    """Create a fresh HealthConnectServer instance."""
    return HealthConnectServer()


class TestHealthConnectServerProperties:
    """Tests for server identity properties."""

    def test_name_is_health_connect(self, server: HealthConnectServer) -> None:
        assert server.name == "health_connect"

    def test_description_is_nonempty(self, server: HealthConnectServer) -> None:
        assert len(server.description) > 0
        assert "Health Connect" in server.description


class TestHealthConnectServerTools:
    """Tests for tool definitions."""

    def test_get_tools_returns_tool_definitions(self, server: HealthConnectServer) -> None:
        tools = server.get_tools()
        assert isinstance(tools, list)
        assert all(isinstance(t, ToolDefinition) for t in tools)

    def test_has_read_metrics_tool(self, server: HealthConnectServer) -> None:
        tools = server.get_tools()
        names = [t.name for t in tools]
        assert "health_connect_read_metrics" in names

    def test_has_write_entry_tool(self, server: HealthConnectServer) -> None:
        tools = server.get_tools()
        names = [t.name for t in tools]
        assert "health_connect_write_entry" in names

    def test_read_metrics_has_required_fields(self, server: HealthConnectServer) -> None:
        tools = server.get_tools()
        read_tool = next(t for t in tools if t.name == "health_connect_read_metrics")
        required = read_tool.input_schema.get("required", [])
        assert "data_type" in required
        assert "start_date" in required
        assert "end_date" in required

    def test_read_metrics_includes_nutrition_data_type(self, server: HealthConnectServer) -> None:
        """Nutrition data type must be in the read_metrics enum (Phase 1.7)."""
        tools = server.get_tools()
        read_tool = next(t for t in tools if t.name == "health_connect_read_metrics")
        enum_values = read_tool.input_schema["properties"]["data_type"]["enum"]
        assert "nutrition" in enum_values


class TestHealthConnectServerExecution:
    """Tests for tool execution."""

    @pytest.mark.asyncio
    async def test_read_metrics_returns_tool_result(self, server: HealthConnectServer) -> None:
        result = await server.execute_tool(
            tool_name="health_connect_read_metrics",
            params={
                "data_type": "steps",
                "start_date": "2026-02-20",
                "end_date": "2026-02-20",
            },
            user_id="test-user-123",
        )
        assert isinstance(result, ToolResult)
        assert result.success is True
        assert "pending_device_sync" in str(result.data)

    @pytest.mark.asyncio
    async def test_read_metrics_nutrition_returns_success(self, server: HealthConnectServer) -> None:
        """Read tool accepts nutrition data type (Phase 1.7)."""
        result = await server.execute_tool(
            tool_name="health_connect_read_metrics",
            params={
                "data_type": "nutrition",
                "start_date": "2026-02-20",
                "end_date": "2026-02-21",
            },
            user_id="test-user-123",
        )
        assert isinstance(result, ToolResult)
        assert result.success is True
        assert "pending_device_sync" in str(result.data)

    @pytest.mark.asyncio
    async def test_write_entry_returns_tool_result(self, server: HealthConnectServer) -> None:
        result = await server.execute_tool(
            tool_name="health_connect_write_entry",
            params={
                "data_type": "nutrition",
                "value": 420.0,
                "date": "2026-02-20T12:00:00Z",
            },
            user_id="test-user-123",
        )
        assert isinstance(result, ToolResult)
        assert result.success is True

    @pytest.mark.asyncio
    async def test_unknown_tool_returns_error(self, server: HealthConnectServer) -> None:
        result = await server.execute_tool(
            tool_name="nonexistent_tool",
            params={},
            user_id="test-user-123",
        )
        assert isinstance(result, ToolResult)
        assert result.success is False
        assert result.error is not None

    @pytest.mark.asyncio
    async def test_read_metrics_missing_params_returns_error(self, server: HealthConnectServer) -> None:
        """Read tool rejects calls with missing required parameters."""
        result = await server.execute_tool(
            tool_name="health_connect_read_metrics",
            params={"data_type": "steps"},
            user_id="test-user-123",
        )
        assert isinstance(result, ToolResult)
        assert result.success is False
        assert result.error is not None
        assert "start_date" in result.error
        assert "end_date" in result.error

    @pytest.mark.asyncio
    async def test_write_entry_missing_params_returns_error(self, server: HealthConnectServer) -> None:
        """Write tool rejects calls with missing required parameters."""
        result = await server.execute_tool(
            tool_name="health_connect_write_entry",
            params={"data_type": "nutrition"},
            user_id="test-user-123",
        )
        assert isinstance(result, ToolResult)
        assert result.success is False
        assert result.error is not None
        assert "value" in result.error
        assert "date" in result.error


class TestHealthConnectServerResources:
    """Tests for resource listing."""

    @pytest.mark.asyncio
    async def test_get_resources_returns_list(self, server: HealthConnectServer) -> None:
        resources = await server.get_resources(user_id="test-user-123")
        assert isinstance(resources, list)
        assert all(isinstance(r, Resource) for r in resources)

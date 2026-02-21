"""Tests for AppleHealthServer MCP server.

Verifies tool definitions, execute_tool routing, typed returns,
and edge cases (unknown tools, missing params).
"""

import pytest

from app.mcp_servers.apple_health_server import AppleHealthServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult


@pytest.fixture
def server() -> AppleHealthServer:
    """Create a fresh AppleHealthServer instance."""
    return AppleHealthServer()


class TestAppleHealthServerProperties:
    """Tests for server identity properties."""

    def test_name_is_apple_health(self, server: AppleHealthServer) -> None:
        assert server.name == "apple_health"

    def test_description_is_nonempty(self, server: AppleHealthServer) -> None:
        assert len(server.description) > 0
        assert "HealthKit" in server.description


class TestAppleHealthServerTools:
    """Tests for tool definitions."""

    def test_get_tools_returns_tool_definitions(self, server: AppleHealthServer) -> None:
        tools = server.get_tools()
        assert isinstance(tools, list)
        assert all(isinstance(t, ToolDefinition) for t in tools)

    def test_has_read_metrics_tool(self, server: AppleHealthServer) -> None:
        tools = server.get_tools()
        names = [t.name for t in tools]
        assert "apple_health_read_metrics" in names

    def test_has_write_entry_tool(self, server: AppleHealthServer) -> None:
        tools = server.get_tools()
        names = [t.name for t in tools]
        assert "apple_health_write_entry" in names

    def test_read_metrics_has_required_fields(self, server: AppleHealthServer) -> None:
        tools = server.get_tools()
        read_tool = next(t for t in tools if t.name == "apple_health_read_metrics")
        required = read_tool.input_schema.get("required", [])
        assert "data_type" in required
        assert "start_date" in required
        assert "end_date" in required

    def test_read_metrics_includes_nutrition_data_type(self, server: AppleHealthServer) -> None:
        """Nutrition data type must be in the read_metrics enum (Phase 1.7)."""
        tools = server.get_tools()
        read_tool = next(t for t in tools if t.name == "apple_health_read_metrics")
        enum_values = read_tool.input_schema["properties"]["data_type"]["enum"]
        assert "nutrition" in enum_values


class TestAppleHealthServerExecution:
    """Tests for tool execution."""

    @pytest.mark.asyncio
    async def test_read_metrics_returns_tool_result(self, server: AppleHealthServer) -> None:
        result = await server.execute_tool(
            tool_name="apple_health_read_metrics",
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
    async def test_read_metrics_nutrition_returns_success(self, server: AppleHealthServer) -> None:
        """Read tool accepts nutrition data type (Phase 1.7)."""
        result = await server.execute_tool(
            tool_name="apple_health_read_metrics",
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
    async def test_write_entry_returns_tool_result(self, server: AppleHealthServer) -> None:
        result = await server.execute_tool(
            tool_name="apple_health_write_entry",
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
    async def test_unknown_tool_returns_error(self, server: AppleHealthServer) -> None:
        result = await server.execute_tool(
            tool_name="nonexistent_tool",
            params={},
            user_id="test-user-123",
        )
        assert isinstance(result, ToolResult)
        assert result.success is False
        assert result.error is not None

    @pytest.mark.asyncio
    async def test_read_metrics_missing_params_returns_error(self, server: AppleHealthServer) -> None:
        """Read tool rejects calls with missing required parameters."""
        result = await server.execute_tool(
            tool_name="apple_health_read_metrics",
            params={"data_type": "steps"},
            user_id="test-user-123",
        )
        assert isinstance(result, ToolResult)
        assert result.success is False
        assert result.error is not None
        assert "start_date" in result.error
        assert "end_date" in result.error

    @pytest.mark.asyncio
    async def test_write_entry_missing_params_returns_error(self, server: AppleHealthServer) -> None:
        """Write tool rejects calls with missing required parameters."""
        result = await server.execute_tool(
            tool_name="apple_health_write_entry",
            params={"data_type": "nutrition"},
            user_id="test-user-123",
        )
        assert isinstance(result, ToolResult)
        assert result.success is False
        assert result.error is not None
        assert "value" in result.error
        assert "date" in result.error


class TestAppleHealthServerResources:
    """Tests for resource listing."""

    @pytest.mark.asyncio
    async def test_get_resources_returns_list(self, server: AppleHealthServer) -> None:
        resources = await server.get_resources(user_id="test-user-123")
        assert isinstance(resources, list)
        assert all(isinstance(r, Resource) for r in resources)

"""Tests for AppleHealthServer MCP server.

Verifies tool definitions, execute_tool routing, typed returns,
and edge cases (unknown tools, missing params, missing db_factory).
"""

from __future__ import annotations

from contextlib import asynccontextmanager
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.mcp_servers.apple_health_server import AppleHealthServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult


@pytest.fixture
def server() -> AppleHealthServer:
    """Create a fresh AppleHealthServer with no dependencies (stub mode)."""
    return AppleHealthServer()


@pytest.fixture
def server_with_db() -> AppleHealthServer:
    """Create an AppleHealthServer with a mock db_factory that returns empty results."""

    mock_db = AsyncMock()
    # make execute() return a result whose scalars().all() returns []
    mock_result = MagicMock()
    mock_result.scalars.return_value.all.return_value = []
    mock_db.execute = AsyncMock(return_value=mock_result)

    @asynccontextmanager
    async def _factory():
        yield mock_db

    return AppleHealthServer(db_factory=_factory)


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
        """Nutrition data type must be in the read_metrics enum."""
        tools = server.get_tools()
        read_tool = next(t for t in tools if t.name == "apple_health_read_metrics")
        enum_values = read_tool.input_schema["properties"]["data_type"]["enum"]
        assert "nutrition" in enum_values

    def test_read_metrics_includes_daily_summary_data_type(self, server: AppleHealthServer) -> None:
        """daily_summary must be in the read_metrics enum for AI general health queries."""
        tools = server.get_tools()
        read_tool = next(t for t in tools if t.name == "apple_health_read_metrics")
        enum_values = read_tool.input_schema["properties"]["data_type"]["enum"]
        assert "daily_summary" in enum_values

    def test_read_metrics_includes_hrv_and_vo2(self, server: AppleHealthServer) -> None:
        """HRV and VO2 max must be in the enum for advanced health queries."""
        tools = server.get_tools()
        read_tool = next(t for t in tools if t.name == "apple_health_read_metrics")
        enum_values = read_tool.input_schema["properties"]["data_type"]["enum"]
        assert "hrv" in enum_values
        assert "vo2_max" in enum_values
        assert "resting_heart_rate" in enum_values


class TestAppleHealthServerExecutionNoDb:
    """Tests for tool execution without db_factory (graceful degradation)."""

    @pytest.mark.asyncio
    async def test_read_metrics_without_db_returns_error(self, server: AppleHealthServer) -> None:
        """Without db_factory, reads should fail gracefully with an error."""
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
        assert result.success is False
        assert result.error is not None

    @pytest.mark.asyncio
    async def test_write_entry_without_service_returns_error(self, server: AppleHealthServer) -> None:
        """Write entry without device_write_service returns a graceful error."""
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
        assert result.success is False
        assert result.error is not None

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


class TestAppleHealthServerExecutionWithDb:
    """Tests for tool execution with a mock db_factory (DB queries)."""

    @pytest.mark.asyncio
    async def test_read_steps_returns_success(self, server_with_db: AppleHealthServer) -> None:
        result = await server_with_db.execute_tool(
            tool_name="apple_health_read_metrics",
            params={
                "data_type": "steps",
                "start_date": "2026-02-20",
                "end_date": "2026-02-26",
            },
            user_id="test-user-123",
        )
        assert isinstance(result, ToolResult)
        assert result.success is True
        assert result.data is not None
        assert result.data["data_type"] == "steps"
        assert "records" in result.data

    @pytest.mark.asyncio
    async def test_read_daily_summary_returns_success(self, server_with_db: AppleHealthServer) -> None:
        result = await server_with_db.execute_tool(
            tool_name="apple_health_read_metrics",
            params={
                "data_type": "daily_summary",
                "start_date": "2026-02-20",
                "end_date": "2026-02-26",
            },
            user_id="test-user-123",
        )
        assert result.success is True
        assert result.data["data_type"] == "daily_summary"
        assert "records" in result.data

    @pytest.mark.asyncio
    async def test_read_workouts_returns_success(self, server_with_db: AppleHealthServer) -> None:
        result = await server_with_db.execute_tool(
            tool_name="apple_health_read_metrics",
            params={
                "data_type": "workouts",
                "start_date": "2026-02-20",
                "end_date": "2026-02-26",
            },
            user_id="test-user-123",
        )
        assert result.success is True
        assert result.data["data_type"] == "workouts"

    @pytest.mark.asyncio
    async def test_read_sleep_returns_success(self, server_with_db: AppleHealthServer) -> None:
        result = await server_with_db.execute_tool(
            tool_name="apple_health_read_metrics",
            params={
                "data_type": "sleep",
                "start_date": "2026-02-20",
                "end_date": "2026-02-26",
            },
            user_id="test-user-123",
        )
        assert result.success is True
        assert result.data["data_type"] == "sleep"

    @pytest.mark.asyncio
    async def test_unsupported_data_type_returns_error(self, server_with_db: AppleHealthServer) -> None:
        result = await server_with_db.execute_tool(
            tool_name="apple_health_read_metrics",
            params={
                "data_type": "invalid_type",
                "start_date": "2026-02-20",
                "end_date": "2026-02-26",
            },
            user_id="test-user-123",
        )
        assert result.success is False
        assert "invalid_type" in (result.error or "")


class TestAppleHealthServerResources:
    """Tests for resource listing."""

    @pytest.mark.asyncio
    async def test_get_resources_returns_list(self, server: AppleHealthServer) -> None:
        resources = await server.get_resources(user_id="test-user-123")
        assert isinstance(resources, list)
        assert all(isinstance(r, Resource) for r in resources)

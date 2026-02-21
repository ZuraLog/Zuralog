"""Tests for StravaServer MCP server.

Verifies tool definitions, execute_tool routing, mock and live
responses for reading and writing Strava activities.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import httpx
import pytest

from app.mcp_servers.models import Resource, ToolDefinition, ToolResult
from app.mcp_servers.strava_server import StravaServer


@pytest.fixture
def server() -> StravaServer:
    """Create a fresh StravaServer instance."""
    return StravaServer()


class TestStravaServerProperties:
    """Tests for server identity properties."""

    def test_name_is_strava(self, server: StravaServer) -> None:
        assert server.name == "strava"

    def test_description_is_nonempty(self, server: StravaServer) -> None:
        assert len(server.description) > 0
        assert "Strava" in server.description


class TestStravaServerTools:
    """Tests for tool definitions."""

    def test_get_tools_returns_tool_definitions(self, server: StravaServer) -> None:
        tools = server.get_tools()
        assert isinstance(tools, list)
        assert all(isinstance(t, ToolDefinition) for t in tools)

    def test_has_get_activities_tool(self, server: StravaServer) -> None:
        tools = server.get_tools()
        names = [t.name for t in tools]
        assert "strava_get_activities" in names

    def test_has_create_activity_tool(self, server: StravaServer) -> None:
        tools = server.get_tools()
        names = [t.name for t in tools]
        assert "strava_create_activity" in names

    def test_create_activity_has_required_fields(self, server: StravaServer) -> None:
        tools = server.get_tools()
        create_tool = next(t for t in tools if t.name == "strava_create_activity")
        required = create_tool.input_schema.get("required", [])
        assert "name" in required
        assert "type" in required
        assert "elapsed_time" in required
        assert "start_date_local" in required


class TestStravaServerExecutionMock:
    """Tests for tool execution (no token provided - mock responses)."""

    @pytest.mark.asyncio
    async def test_get_activities_returns_mock_result(self, server: StravaServer) -> None:
        # Without token, it returns mock data
        result = await server.execute_tool(
            tool_name="strava_get_activities",
            params={"limit": 2},
            user_id="test-user-123",
        )
        assert isinstance(result, ToolResult)
        assert result.success is True
        assert isinstance(result.data, list)
        assert len(result.data) == 2
        assert result.data[0]["name"] == "Morning Run"

    @pytest.mark.asyncio
    async def test_create_activity_returns_mock_result(self, server: StravaServer) -> None:
        result = await server.execute_tool(
            tool_name="strava_create_activity",
            params={
                "name": "Evening Run",
                "type": "Run",
                "elapsed_time": 1800,
                "start_date_local": "2026-02-21T18:00:00Z",
            },
            user_id="test-user-123",
        )
        assert isinstance(result, ToolResult)
        assert result.success is True
        assert result.data["mock"] is True
        assert result.data["name"] == "Evening Run"

    @pytest.mark.asyncio
    async def test_unknown_tool_returns_error(self, server: StravaServer) -> None:
        result = await server.execute_tool(
            tool_name="nonexistent_tool",
            params={},
            user_id="test-user-123",
        )
        assert isinstance(result, ToolResult)
        assert result.success is False
        assert result.error is not None


class TestStravaServerExecutionLive:
    """Tests for tool execution (token provided - mocked httpx live responses)."""

    @pytest.fixture
    def authenticated_server(self, server: StravaServer) -> StravaServer:
        server.store_token("test-user-123", "fake-token")
        return server

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get")
    async def test_get_activities_live_success(self, mock_get: AsyncMock, authenticated_server: StravaServer) -> None:
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = [{"id": 1, "name": "Live Run"}]
        mock_get.return_value = mock_response

        result = await authenticated_server.execute_tool(
            tool_name="strava_get_activities",
            params={"limit": 5},
            user_id="test-user-123",
        )

        assert result.success is True
        assert result.data == [{"id": 1, "name": "Live Run"}]
        mock_get.assert_called_once()
        args, kwargs = mock_get.call_args
        assert args[0] == "https://www.strava.com/api/v3/athlete/activities"
        assert kwargs["params"] == {"per_page": 5}
        assert kwargs["headers"]["Authorization"] == "Bearer fake-token"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get")
    async def test_get_activities_live_failure(self, mock_get: AsyncMock, authenticated_server: StravaServer) -> None:
        mock_response = MagicMock()
        mock_response.status_code = 401
        mock_response.text = "Unauthorized"
        mock_get.return_value = mock_response

        result = await authenticated_server.execute_tool(
            tool_name="strava_get_activities",
            params={"limit": 5},
            user_id="test-user-123",
        )

        assert result.success is False
        assert result.error is not None
        assert "401" in result.error

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_create_activity_live_success(self, mock_post: AsyncMock, authenticated_server: StravaServer) -> None:
        mock_response = MagicMock()
        mock_response.status_code = 201
        mock_response.json.return_value = {"id": 100, "name": "Live Ride"}
        mock_post.return_value = mock_response

        result = await authenticated_server.execute_tool(
            tool_name="strava_create_activity",
            params={
                "name": "Live Ride",
                "type": "Ride",
                "elapsed_time": 3600,
                "start_date_local": "2026-02-21T08:00:00Z",
                "distance": 25000,
            },
            user_id="test-user-123",
        )

        assert result.success is True
        assert result.data == {"id": 100, "name": "Live Ride"}
        mock_post.assert_called_once()
        args, kwargs = mock_post.call_args
        assert args[0] == "https://www.strava.com/api/v3/activities"
        assert kwargs["json"]["distance"] == 25000

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_create_activity_live_network_error(
        self, mock_post: AsyncMock, authenticated_server: StravaServer
    ) -> None:
        mock_post.side_effect = httpx.RequestError("Network Down")

        result = await authenticated_server.execute_tool(
            tool_name="strava_create_activity",
            params={
                "name": "Failed Ride",
                "type": "Ride",
                "elapsed_time": 3600,
                "start_date_local": "2026-02-21T08:00:00Z",
            },
            user_id="test-user-123",
        )

        assert result.success is False
        assert result.error is not None
        assert "Network error" in result.error


class TestStravaServerResources:
    """Tests for resource listing."""

    @pytest.mark.asyncio
    async def test_get_resources_returns_list(self, server: StravaServer) -> None:
        resources = await server.get_resources(user_id="test-user-123")
        assert isinstance(resources, list)
        assert all(isinstance(r, Resource) for r in resources)


class TestStravaServerHealthCheck:
    """Tests for health check endpoints."""

    @pytest.mark.asyncio
    async def test_health_check_returns_true_without_tokens(self, server: StravaServer) -> None:
        assert await server.health_check() is True

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get")
    async def test_health_check_returns_true_when_tokens_valid(self, mock_get: AsyncMock, server: StravaServer) -> None:
        server.store_token("test-user-123", "fake-token")

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_get.return_value = mock_response

        assert await server.health_check() is True

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get")
    async def test_health_check_returns_false_when_tokens_invalid(
        self, mock_get: AsyncMock, server: StravaServer
    ) -> None:
        server.store_token("test-user-123", "fake-token")

        mock_response = MagicMock()
        mock_response.status_code = 401
        mock_get.return_value = mock_response

        assert await server.health_check() is False

"""Tests for the DeepLinkServer MCP server.

Verifies server identity properties, tool schema, successful execution
for every supported app/action, error paths for unsupported entries and
unknown tools, and that response payloads include the expected fields.
"""

import pytest

from app.mcp_servers.deep_link_server import DeepLinkServer
from app.mcp_servers.models import ToolDefinition, ToolResult


@pytest.fixture
def server() -> DeepLinkServer:
    """Create a fresh DeepLinkServer instance."""
    return DeepLinkServer()


class TestDeepLinkServerProperties:
    """Tests for server identity properties."""

    def test_name_is_deep_link(self, server: DeepLinkServer) -> None:
        assert server.name == "deep_link"

    def test_description_is_nonempty(self, server: DeepLinkServer) -> None:
        assert len(server.description) > 0


class TestDeepLinkServerTools:
    """Tests for tool definitions."""

    def test_get_tools_returns_tool_definitions(self, server: DeepLinkServer) -> None:
        tools = server.get_tools()
        assert isinstance(tools, list)
        assert len(tools) == 1
        assert all(isinstance(t, ToolDefinition) for t in tools)

    def test_open_external_app_tool_schema(self, server: DeepLinkServer) -> None:
        tools = server.get_tools()
        tool = tools[0]
        assert tool.name == "open_external_app"
        schema = tool.input_schema
        assert "app_name" in schema["properties"]
        assert "action" in schema["properties"]
        assert "query" in schema["properties"]
        assert "app_name" in schema["required"]
        assert "action" in schema["required"]

    def test_app_name_enum_includes_supported_apps(self, server: DeepLinkServer) -> None:
        tools = server.get_tools()
        tool = tools[0]
        enum_values = tool.input_schema["properties"]["app_name"]["enum"]
        assert "strava" in enum_values
        assert "calai" in enum_values


class TestDeepLinkServerExecution:
    """Tests for tool execution across all supported apps."""

    @pytest.mark.asyncio
    async def test_strava_record_execution(self, server: DeepLinkServer) -> None:
        result = await server.execute_tool(
            tool_name="open_external_app",
            params={"app_name": "strava", "action": "record"},
            user_id="test-user",
        )
        assert isinstance(result, ToolResult)
        assert result.success is True
        assert result.data["url"] == "strava://record"
        assert result.data["client_action"] == "open_url"
        assert result.data["fallback_url"] == "https://www.strava.com"

    @pytest.mark.asyncio
    async def test_calai_camera_execution(self, server: DeepLinkServer) -> None:
        result = await server.execute_tool(
            tool_name="open_external_app",
            params={"app_name": "calai", "action": "camera"},
            user_id="test-user",
        )
        assert result.success is True
        assert result.data["url"] == "calai://camera"
        assert result.data["fallback_url"] == "https://www.calai.app"

    @pytest.mark.asyncio
    async def test_calai_search_with_query_execution(self, server: DeepLinkServer) -> None:
        result = await server.execute_tool(
            tool_name="open_external_app",
            params={"app_name": "calai", "action": "search", "query": "pizza"},
            user_id="test-user",
        )
        assert result.success is True
        assert result.data["url"] == "calai://search?q=pizza"

    @pytest.mark.asyncio
    async def test_unsupported_app_returns_error(self, server: DeepLinkServer) -> None:
        result = await server.execute_tool(
            tool_name="open_external_app",
            params={"app_name": "unknown_app", "action": "home"},
            user_id="test-user",
        )
        assert result.success is False
        assert result.error is not None
        assert "Unsupported deep link" in result.error

    @pytest.mark.asyncio
    async def test_unsupported_action_returns_error(self, server: DeepLinkServer) -> None:
        result = await server.execute_tool(
            tool_name="open_external_app",
            params={"app_name": "strava", "action": "nonexistent"},
            user_id="test-user",
        )
        assert result.success is False
        assert "Unsupported deep link" in result.error

    @pytest.mark.asyncio
    async def test_unknown_tool_name_returns_error(self, server: DeepLinkServer) -> None:
        result = await server.execute_tool(
            tool_name="nonexistent_tool",
            params={},
            user_id="test-user",
        )
        assert result.success is False
        assert result.error is not None

    @pytest.mark.asyncio
    async def test_result_data_contains_message(self, server: DeepLinkServer) -> None:
        result = await server.execute_tool(
            tool_name="open_external_app",
            params={"app_name": "strava", "action": "home"},
            user_id="test-user",
        )
        assert result.success is True
        assert "message" in result.data
        assert "strava" in result.data["message"].lower() or "Opening" in result.data["message"]


class TestDeepLinkServerResources:
    """Tests for resource listing."""

    @pytest.mark.asyncio
    async def test_get_resources_returns_empty_list(self, server: DeepLinkServer) -> None:
        resources = await server.get_resources(user_id="test-user")
        assert isinstance(resources, list)
        assert len(resources) == 0

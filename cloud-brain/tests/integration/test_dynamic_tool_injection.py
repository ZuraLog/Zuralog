"""Integration test: dynamic tool injection end-to-end.

Verifies that the Orchestrator only sends tools for connected
integrations to the LLM, using real MCPServerRegistry, MCPClient,
and UserToolResolver instances (only DB and LLM are mocked).
"""

import pytest
from unittest.mock import AsyncMock, MagicMock

from app.agent.mcp_client import MCPClient
from app.agent.orchestrator import Orchestrator
from app.agent.context_manager.memory_store import InMemoryStore
from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import ToolDefinition, ToolResult
from app.mcp_servers.registry import MCPServerRegistry
from app.services.user_tool_resolver import UserToolResolver


# ---------------------------------------------------------------------------
# Minimal concrete MCP servers for testing
# ---------------------------------------------------------------------------

class StubStravaServer(BaseMCPServer):
    @property
    def name(self) -> str:
        return "strava"

    @property
    def description(self) -> str:
        return "Strava integration"

    def get_tools(self) -> list[ToolDefinition]:
        return [
            ToolDefinition(
                name="get_activities",
                description="Get Strava activities",
                input_schema={"type": "object", "properties": {"limit": {"type": "integer"}}},
            ),
        ]

    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> ToolResult:
        return ToolResult(success=True, data={"activities": []})

    async def get_resources(self, user_id: str) -> list:
        return []


class StubFitbitServer(BaseMCPServer):
    @property
    def name(self) -> str:
        return "fitbit"

    @property
    def description(self) -> str:
        return "Fitbit integration"

    def get_tools(self) -> list[ToolDefinition]:
        return [
            ToolDefinition(
                name="fitbit_get_activity",
                description="Get Fitbit activity data",
                input_schema={"type": "object", "properties": {}},
            ),
        ]

    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> ToolResult:
        return ToolResult(success=True, data={"activity": {}})

    async def get_resources(self, user_id: str) -> list:
        return []


class StubAppleHealthServer(BaseMCPServer):
    @property
    def name(self) -> str:
        return "apple_health"

    @property
    def description(self) -> str:
        return "Apple Health"

    def get_tools(self) -> list[ToolDefinition]:
        return [
            ToolDefinition(
                name="apple_health_read_metrics",
                description="Read Apple Health metrics",
                input_schema={"type": "object", "properties": {}},
            ),
        ]

    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> ToolResult:
        return ToolResult(success=True, data={"metrics": []})

    async def get_resources(self, user_id: str) -> list:
        return []


class StubDeepLinkServer(BaseMCPServer):
    @property
    def name(self) -> str:
        return "deep_link"

    @property
    def description(self) -> str:
        return "Deep link launcher"

    def get_tools(self) -> list[ToolDefinition]:
        return [
            ToolDefinition(
                name="open_external_app",
                description="Open external app",
                input_schema={"type": "object", "properties": {}},
            ),
        ]

    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> ToolResult:
        return ToolResult(success=True, data={})

    async def get_resources(self, user_id: str) -> list:
        return []


class StubIntegrationsServer(BaseMCPServer):
    @property
    def name(self) -> str:
        return "integrations"

    @property
    def description(self) -> str:
        return "Integrations catalog"

    def get_tools(self) -> list[ToolDefinition]:
        return [
            ToolDefinition(
                name="get_integrations",
                description="List all available integrations and connection status",
                input_schema={"type": "object", "properties": {}},
            ),
        ]

    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> ToolResult:
        return ToolResult(success=True, data={"integrations": []})

    async def get_resources(self, user_id: str) -> list:
        return []


class StubHealthConnectServer(BaseMCPServer):
    @property
    def name(self) -> str:
        return "health_connect"

    @property
    def description(self) -> str:
        return "Health Connect"

    def get_tools(self) -> list[ToolDefinition]:
        return [
            ToolDefinition(
                name="health_connect_read_metrics",
                description="Read Health Connect metrics",
                input_schema={"type": "object", "properties": {}},
            ),
        ]

    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> ToolResult:
        return ToolResult(success=True, data={"metrics": []})

    async def get_resources(self, user_id: str) -> list:
        return []


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

def _mock_db(providers: list[str]):
    """Create an AsyncMock DB session returning a list of provider name strings.

    The production query uses ``select(Integration.provider)`` so
    ``scalars().all()`` returns plain strings, not ORM objects.
    """
    db = AsyncMock()
    mock_result = MagicMock()
    mock_scalars = MagicMock()
    mock_scalars.all.return_value = providers
    mock_result.scalars.return_value = mock_scalars
    db.execute.return_value = mock_result
    return db


@pytest.fixture
def full_stack():
    """Build a real registry + resolver + client + orchestrator."""
    registry = MCPServerRegistry()
    registry.register(StubAppleHealthServer())
    registry.register(StubHealthConnectServer())
    registry.register(StubStravaServer())
    registry.register(StubFitbitServer())
    registry.register(StubDeepLinkServer())
    registry.register(StubIntegrationsServer())

    resolver = UserToolResolver(registry=registry)
    client = MCPClient(registry=registry, tool_resolver=resolver)
    memory_store = InMemoryStore()

    mock_llm = MagicMock()
    mock_llm.chat = AsyncMock()

    orchestrator = Orchestrator(
        mcp_client=client,
        memory_store=memory_store,
        llm_client=mock_llm,
    )

    return {
        "orchestrator": orchestrator,
        "llm": mock_llm,
    }


def _make_llm_response(content: str):
    """Create a mock LLM response with no tool calls."""
    resp = MagicMock()
    resp.choices = [MagicMock()]
    resp.choices[0].message.content = content
    resp.choices[0].message.tool_calls = None
    resp.usage.prompt_tokens = 100
    resp.usage.completion_tokens = 20
    return resp


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestDynamicToolInjectionE2E:

    @pytest.mark.asyncio
    async def test_strava_only_user_sees_strava_plus_always_on(self, full_stack):
        """User with only Strava connected sees strava + 4 always-on tools."""
        db = _mock_db(["strava"])
        full_stack["llm"].chat.return_value = _make_llm_response("Your activities look great!")

        result = await full_stack["orchestrator"].process_message(
            "user-strava", "Show my runs", db=db,
        )

        call_args = full_stack["llm"].chat.call_args
        tools = call_args.kwargs.get("tools")
        tool_names = {t["function"]["name"] for t in tools}
        assert tool_names == {
            "get_activities",
            "apple_health_read_metrics",
            "health_connect_read_metrics",
            "open_external_app",
            "get_integrations",
        }
        assert "fitbit_get_activity" not in tool_names
        assert result.message == "Your activities look great!"

    @pytest.mark.asyncio
    async def test_no_integrations_user_sees_only_always_on(self, full_stack):
        """User with zero integrations sees only 4 always-on tools."""
        db = _mock_db([])
        full_stack["llm"].chat.return_value = _make_llm_response("Connect an integration first!")

        await full_stack["orchestrator"].process_message(
            "user-new", "How am I doing?", db=db,
        )

        call_args = full_stack["llm"].chat.call_args
        tools = call_args.kwargs.get("tools")
        tool_names = {t["function"]["name"] for t in tools}
        assert tool_names == {
            "apple_health_read_metrics",
            "health_connect_read_metrics",
            "open_external_app",
            "get_integrations",
        }

    @pytest.mark.asyncio
    async def test_strava_and_fitbit_user_sees_all_registered_tools(self, full_stack):
        """User with Strava and Fitbit connected sees all 6 registered tools (both providers + 4 always-on)."""
        db = _mock_db(["strava", "fitbit"])
        full_stack["llm"].chat.return_value = _make_llm_response("Here's everything!")

        await full_stack["orchestrator"].process_message(
            "user-all", "Give me a summary", db=db,
        )

        call_args = full_stack["llm"].chat.call_args
        tools = call_args.kwargs.get("tools")
        tool_names = {t["function"]["name"] for t in tools}
        assert tool_names == {
            "get_activities",
            "fitbit_get_activity",
            "apple_health_read_metrics",
            "health_connect_read_metrics",
            "open_external_app",
            "get_integrations",
        }

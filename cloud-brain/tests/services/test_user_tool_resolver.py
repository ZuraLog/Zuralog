"""Tests for UserToolResolver — dynamic MCP tool filtering per user."""

import pytest
from unittest.mock import AsyncMock, MagicMock

from app.mcp_servers.models import ToolDefinition
from app.services.user_tool_resolver import UserToolResolver


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

def _make_tool(name: str) -> ToolDefinition:
    """Helper to create a minimal ToolDefinition."""
    return ToolDefinition(
        name=name,
        description=f"Tool: {name}",
        input_schema={"type": "object", "properties": {}},
    )


@pytest.fixture
def mock_registry():
    """MCPServerRegistry mock with get_tools_for_servers + get_all_tools."""
    registry = MagicMock()

    def _get_tools_for_servers(server_names: set[str]) -> list[ToolDefinition]:
        tools = []
        mapping = {
            "apple_health": [_make_tool("apple_health_read_metrics")],
            "health_connect": [_make_tool("health_connect_read_metrics")],
            "deep_link": [_make_tool("open_external_app")],
            "integrations": [_make_tool("get_integrations")],
            "strava": [_make_tool("get_activities"), _make_tool("get_athlete_stats")],
            "fitbit": [_make_tool("fitbit_get_activity")],
            "oura": [_make_tool("oura_get_sleep")],
            "withings": [_make_tool("withings_get_measurements")],
            "polar": [_make_tool("polar_get_exercises")],
        }
        for name in server_names:
            tools.extend(mapping.get(name, []))
        return tools

    registry.get_tools_for_servers.side_effect = _get_tools_for_servers
    return registry


@pytest.fixture
def resolver(mock_registry):
    return UserToolResolver(registry=mock_registry)


# ---------------------------------------------------------------------------
# Helpers for mocking DB results
# ---------------------------------------------------------------------------

def _mock_db_session(providers: list[str]):
    """Create an AsyncMock DB session returning a list of provider name strings.

    The production query uses ``select(Integration.provider)`` so
    ``scalars().all()`` returns plain strings, not ORM objects.
    The caller is responsible for only passing active providers
    (mirroring the SQL ``WHERE is_active IS TRUE`` filter).
    """
    db = AsyncMock()
    mock_result = MagicMock()
    mock_scalars = MagicMock()
    mock_scalars.all.return_value = providers
    mock_result.scalars.return_value = mock_scalars
    db.execute.return_value = mock_result
    return db


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestUserToolResolver:

    @pytest.mark.asyncio
    async def test_always_on_servers_included_even_with_no_integrations(self, resolver):
        """A user with zero integrations still gets apple_health, health_connect, deep_link, integrations."""
        db = _mock_db_session([])
        tools = await resolver.resolve_tools(db, "user-123")
        tool_names = [t.name for t in tools]
        assert "apple_health_read_metrics" in tool_names
        assert "health_connect_read_metrics" in tool_names
        assert "open_external_app" in tool_names
        assert "get_integrations" in tool_names
        # OAuth-dependent tools must NOT be present
        assert "get_activities" not in tool_names
        assert "fitbit_get_activity" not in tool_names

    @pytest.mark.asyncio
    async def test_connected_strava_adds_strava_tools(self, resolver):
        """A user with active Strava integration gets Strava tools + always-on."""
        db = _mock_db_session(["strava"])
        tools = await resolver.resolve_tools(db, "user-123")
        tool_names = [t.name for t in tools]
        assert "get_activities" in tool_names
        assert "get_athlete_stats" in tool_names
        # Always-on still present
        assert "apple_health_read_metrics" in tool_names

    @pytest.mark.asyncio
    async def test_inactive_integration_excluded(self, resolver):
        """SQL WHERE is_active IS TRUE means inactive rows never reach the resolver.

        The mock returns an empty list (as the real DB would), confirming
        the resolver produces only always-on tools.
        """
        # No active providers — inactive rows filtered out by SQL before we see them
        db = _mock_db_session([])
        tools = await resolver.resolve_tools(db, "user-123")
        tool_names = [t.name for t in tools]
        assert "get_activities" not in tool_names

    @pytest.mark.asyncio
    async def test_multiple_integrations(self, resolver):
        """A user with Strava + Fitbit gets tools from both."""
        db = _mock_db_session(["strava", "fitbit"])
        tools = await resolver.resolve_tools(db, "user-123")
        tool_names = [t.name for t in tools]
        assert "get_activities" in tool_names
        assert "fitbit_get_activity" in tool_names
        assert "oura_get_sleep" not in tool_names

    @pytest.mark.asyncio
    async def test_all_integrations_connected(self, resolver):
        """A user with every integration gets every tool."""
        db = _mock_db_session(["strava", "fitbit", "oura", "withings", "polar"])
        tools = await resolver.resolve_tools(db, "user-123")
        tool_names = [t.name for t in tools]
        assert "get_activities" in tool_names
        assert "fitbit_get_activity" in tool_names
        assert "oura_get_sleep" in tool_names
        assert "withings_get_measurements" in tool_names
        assert "polar_get_exercises" in tool_names
        assert "apple_health_read_metrics" in tool_names
        assert "open_external_app" in tool_names

    @pytest.mark.asyncio
    async def test_unknown_provider_in_db_is_skipped(self, resolver):
        """A provider name in DB with no matching server is silently ignored."""
        db = _mock_db_session(["unknown_provider"])
        tools = await resolver.resolve_tools(db, "user-123")
        tool_names = [t.name for t in tools]
        # Only always-on tools (apple_health, health_connect, deep_link, integrations)
        assert "apple_health_read_metrics" in tool_names
        assert "health_connect_read_metrics" in tool_names
        assert "open_external_app" in tool_names
        assert "get_integrations" in tool_names
        assert "get_activities" not in tool_names

    @pytest.mark.asyncio
    async def test_registry_called_with_correct_server_names(self, resolver, mock_registry):
        """Verify the registry receives the right set of server names."""
        db = _mock_db_session(["strava", "polar"])
        await resolver.resolve_tools(db, "user-123")

        call_args = mock_registry.get_tools_for_servers.call_args
        server_names = call_args[0][0]  # first positional arg
        assert "strava" in server_names
        assert "polar" in server_names
        assert "apple_health" in server_names
        assert "health_connect" in server_names
        assert "deep_link" in server_names
        assert "integrations" in server_names
        # NOT connected
        assert "fitbit" not in server_names

    @pytest.mark.asyncio
    async def test_db_failure_falls_back_to_all_tools(self, resolver, mock_registry):
        """If the DB query fails, fall back to returning ALL tools (fail-open)."""
        db = AsyncMock()
        db.execute.side_effect = Exception("DB connection lost")
        mock_registry.get_all_tools.return_value = [_make_tool("fallback_tool")]

        tools = await resolver.resolve_tools(db, "user-123")
        tool_names = [t.name for t in tools]
        assert "fallback_tool" in tool_names
        mock_registry.get_all_tools.assert_called_once()

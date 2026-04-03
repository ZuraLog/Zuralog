"""
ZuraLog Cloud Brain — IntegrationsMCPServer Tests.

Verifies catalog contents, get_integrations tool behavior, connection status
merging, and error handling.
"""

from contextlib import asynccontextmanager
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.mcp_servers.integrations_server import (
    IntegrationsMCPServer,
    _CATALOG,
    _CATALOG_BY_PROVIDER,
    get_display_name,
)
from app.mcp_servers.models import ToolResult


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_db_row(provider: str, sync_status: str = "idle", last_synced_at=None, sync_error=None):
    """Build a mock DB result row."""
    row = MagicMock()
    row.provider = provider
    row.sync_status = sync_status
    row.last_synced_at = last_synced_at
    row.sync_error = sync_error
    return row


def _make_server(rows: list) -> IntegrationsMCPServer:
    """Build a server whose DB returns the given rows."""
    mock_result = MagicMock()
    mock_result.all.return_value = rows

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(return_value=mock_result)

    @asynccontextmanager
    async def db_factory():
        yield mock_db

    return IntegrationsMCPServer(db_factory=db_factory)


# ---------------------------------------------------------------------------
# Catalog
# ---------------------------------------------------------------------------


class TestCatalog:
    def test_catalog_is_non_empty(self):
        assert len(_CATALOG) > 0

    def test_catalog_by_provider_matches_catalog(self):
        assert len(_CATALOG_BY_PROVIDER) == len(_CATALOG)
        for entry in _CATALOG:
            assert entry.provider in _CATALOG_BY_PROVIDER
            assert _CATALOG_BY_PROVIDER[entry.provider] is entry

    def test_all_entries_have_non_empty_tools(self):
        for entry in _CATALOG:
            assert len(entry.tools) > 0, f"{entry.provider} has no tools"

    def test_all_tool_names_have_provider_prefix(self):
        """Tool names should start with the provider key to avoid collisions."""
        for entry in _CATALOG:
            for tool in entry.tools:
                assert tool.startswith(entry.provider), (
                    f"Tool '{tool}' does not start with provider '{entry.provider}'"
                )

    def test_no_duplicate_tool_names_across_catalog(self):
        seen = set()
        for entry in _CATALOG:
            for tool in entry.tools:
                assert tool not in seen, f"Duplicate tool name: {tool}"
                seen.add(tool)


# ---------------------------------------------------------------------------
# get_display_name utility
# ---------------------------------------------------------------------------


class TestGetDisplayName:
    def test_known_provider_returns_catalog_name(self):
        for entry in _CATALOG:
            assert get_display_name(entry.provider) == entry.display_name

    def test_unknown_provider_returns_title_case(self):
        assert get_display_name("garmin") == "Garmin"
        assert get_display_name("whoop") == "Whoop"

    def test_empty_string_returns_empty(self):
        assert get_display_name("") == ""


# ---------------------------------------------------------------------------
# Server properties
# ---------------------------------------------------------------------------


class TestServerProperties:
    def test_name(self):
        server = _make_server([])
        assert server.name == "integrations"

    def test_description_non_empty(self):
        server = _make_server([])
        assert len(server.description) > 0

    def test_get_tools_returns_one_tool(self):
        server = _make_server([])
        tools = server.get_tools()
        assert len(tools) == 1
        assert tools[0].name == "get_integrations"

    def test_get_integrations_takes_no_required_params(self):
        server = _make_server([])
        tool = server.get_tools()[0]
        assert tool.input_schema.get("required", []) == []


# ---------------------------------------------------------------------------
# get_integrations — no connections
# ---------------------------------------------------------------------------


class TestGetIntegrationsNoConnections:
    @pytest.mark.asyncio
    async def test_returns_success(self):
        server = _make_server([])
        result = await server.execute_tool("get_integrations", {}, "user-1")
        assert result.success is True

    @pytest.mark.asyncio
    async def test_returns_all_catalog_entries(self):
        server = _make_server([])
        result = await server.execute_tool("get_integrations", {}, "user-1")
        integrations = result.data["integrations"]
        assert len(integrations) == len(_CATALOG)

    @pytest.mark.asyncio
    async def test_all_entries_not_connected(self):
        server = _make_server([])
        result = await server.execute_tool("get_integrations", {}, "user-1")
        for item in result.data["integrations"]:
            assert item["connected"] is False

    @pytest.mark.asyncio
    async def test_disconnected_entries_have_no_sync_fields(self):
        server = _make_server([])
        result = await server.execute_tool("get_integrations", {}, "user-1")
        for item in result.data["integrations"]:
            assert "sync_status" not in item
            assert "last_synced_at" not in item

    @pytest.mark.asyncio
    async def test_all_entries_have_tools_list(self):
        server = _make_server([])
        result = await server.execute_tool("get_integrations", {}, "user-1")
        for item in result.data["integrations"]:
            assert isinstance(item["tools"], list)
            assert len(item["tools"]) > 0


# ---------------------------------------------------------------------------
# get_integrations — with connections
# ---------------------------------------------------------------------------


class TestGetIntegrationsWithConnections:
    @pytest.mark.asyncio
    async def test_connected_provider_marked_true(self):
        server = _make_server([_make_db_row("strava")])
        result = await server.execute_tool("get_integrations", {}, "user-1")
        strava = next(i for i in result.data["integrations"] if i["provider"] == "strava")
        assert strava["connected"] is True

    @pytest.mark.asyncio
    async def test_other_providers_remain_disconnected(self):
        server = _make_server([_make_db_row("strava")])
        result = await server.execute_tool("get_integrations", {}, "user-1")
        others = [i for i in result.data["integrations"] if i["provider"] != "strava"]
        for item in others:
            assert item["connected"] is False

    @pytest.mark.asyncio
    async def test_connected_entry_includes_sync_status(self):
        server = _make_server([_make_db_row("fitbit", sync_status="idle")])
        result = await server.execute_tool("get_integrations", {}, "user-1")
        fitbit = next(i for i in result.data["integrations"] if i["provider"] == "fitbit")
        assert fitbit["sync_status"] == "idle"

    @pytest.mark.asyncio
    async def test_sync_error_included_when_present(self):
        server = _make_server([_make_db_row("oura", sync_status="error", sync_error="token expired")])
        result = await server.execute_tool("get_integrations", {}, "user-1")
        oura = next(i for i in result.data["integrations"] if i["provider"] == "oura")
        assert oura["sync_error"] == "token expired"

    @pytest.mark.asyncio
    async def test_sync_error_absent_when_none(self):
        server = _make_server([_make_db_row("strava", sync_error=None)])
        result = await server.execute_tool("get_integrations", {}, "user-1")
        strava = next(i for i in result.data["integrations"] if i["provider"] == "strava")
        assert "sync_error" not in strava

    @pytest.mark.asyncio
    async def test_multiple_connected_providers(self):
        server = _make_server([_make_db_row("strava"), _make_db_row("oura")])
        result = await server.execute_tool("get_integrations", {}, "user-1")
        connected = [i for i in result.data["integrations"] if i["connected"]]
        providers = {i["provider"] for i in connected}
        assert providers == {"strava", "oura"}


# ---------------------------------------------------------------------------
# Unknown tool
# ---------------------------------------------------------------------------


class TestUnknownTool:
    @pytest.mark.asyncio
    async def test_returns_error_for_unknown_tool(self):
        server = _make_server([])
        result = await server.execute_tool("does_not_exist", {}, "user-1")
        assert result.success is False
        assert "Unknown tool" in result.error


# ---------------------------------------------------------------------------
# DB error handling
# ---------------------------------------------------------------------------


class TestDBError:
    @pytest.mark.asyncio
    async def test_db_exception_returns_error_result(self):
        @asynccontextmanager
        async def broken_db_factory():
            raise RuntimeError("connection refused")
            yield  # noqa: unreachable

        server = IntegrationsMCPServer(db_factory=broken_db_factory)
        result = await server.execute_tool("get_integrations", {}, "user-1")
        assert result.success is False
        assert result.error is not None


# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------


class TestResources:
    @pytest.mark.asyncio
    async def test_get_resources_returns_empty_list(self):
        server = _make_server([])
        resources = await server.get_resources("user-1")
        assert resources == []

"""
Life Logger Cloud Brain — MCP + AI Flow Integration Tests.

Validates the MCP framework components in isolation: the server
registry, tool discovery, client routing, and the in-memory
conversation store. These tests exercise real classes (not mocked)
to confirm the wiring between MCP components works correctly.
"""

import pytest

from app.agent.context_manager.memory_store import InMemoryStore
from app.agent.mcp_client import MCPClient
from app.mcp_servers.apple_health_server import AppleHealthServer
from app.mcp_servers.deep_link_server import DeepLinkServer
from app.mcp_servers.health_connect_server import HealthConnectServer
from app.mcp_servers.registry import MCPServerRegistry
from app.mcp_servers.strava_server import StravaServer


class TestMCPIntegration:
    """Integration tests for MCP registry, client, and memory store.

    Uses real instances (no mocks) to verify component wiring.
    """

    # ------------------------------------------------------------------
    # Registry
    # ------------------------------------------------------------------

    def test_registry_discovers_all_servers(self):
        """Register 4 servers; list_all returns >= 4 entries.

        Confirms all four server types (AppleHealth, HealthConnect,
        Strava, DeepLink) can be registered and discovered.
        """
        registry = MCPServerRegistry()
        registry.register(AppleHealthServer())
        registry.register(HealthConnectServer())
        registry.register(StravaServer())
        registry.register(DeepLinkServer())

        servers = registry.list_all()
        assert len(servers) >= 4

        # Verify server names are correct.
        names = {s.name for s in servers}
        assert "apple_health" in names
        assert "health_connect" in names
        assert "strava" in names
        assert "deep_link" in names

    def test_registry_lists_all_tools(self):
        """Register AppleHealth + Strava; get_all_tools returns > 0.

        Each server exposes at least one tool. The aggregated list
        must contain tools from both servers.
        """
        registry = MCPServerRegistry()
        registry.register(AppleHealthServer())
        registry.register(StravaServer())

        tools = registry.get_all_tools()
        assert len(tools) > 0

        tool_names = {t.name for t in tools}
        # AppleHealth exposes read + write; Strava exposes get + create.
        assert "apple_health_read_metrics" in tool_names
        assert "strava_get_activities" in tool_names

    # ------------------------------------------------------------------
    # MCP Client
    # ------------------------------------------------------------------

    def test_mcp_client_routes_to_correct_server(self):
        """Construct MCPClient with registry and verify tool listing.

        The client delegates tool discovery to the registry. Confirm
        that get_all_tools() returns tools from all registered servers.
        """
        registry = MCPServerRegistry()
        registry.register(AppleHealthServer())
        registry.register(StravaServer())

        client = MCPClient(registry=registry)
        tools = client.get_all_tools()

        assert len(tools) > 0

        tool_names = {t.name for t in tools}
        assert "apple_health_read_metrics" in tool_names
        assert "strava_get_activities" in tool_names

    @pytest.mark.asyncio
    async def test_mcp_client_unknown_tool_returns_error(self):
        """Calling execute_tool with an unknown tool returns error ToolResult.

        Verifies the client's error handling for unregistered tools.
        """
        registry = MCPServerRegistry()
        registry.register(AppleHealthServer())

        client = MCPClient(registry=registry)
        result = await client.execute_tool(
            tool_name="nonexistent_tool",
            params={},
            user_id="test-user",
        )

        assert result.success is False
        assert "not found" in result.error.lower()

    # ------------------------------------------------------------------
    # Memory Store
    # ------------------------------------------------------------------

    @pytest.mark.asyncio
    async def test_memory_store_conversation_lifecycle(self):
        """add() + query() round-trip works correctly.

        Stores two entries and verifies they are returned by query().
        """
        store = InMemoryStore()

        await store.add("user-A", "Ran 5K this morning")
        await store.add("user-A", "Ate 2000 kcal today")

        history = await store.query("user-A")
        assert len(history) == 2
        assert history[0]["text"] == "Ran 5K this morning"
        assert history[1]["text"] == "Ate 2000 kcal today"

    @pytest.mark.asyncio
    async def test_memory_store_isolates_users(self):
        """Different users have separate conversation histories.

        Entries for user-A must not leak into user-B's query results.
        """
        store = InMemoryStore()

        await store.add("user-A", "User A entry")
        await store.add("user-B", "User B entry")

        history_a = await store.query("user-A")
        history_b = await store.query("user-B")

        assert len(history_a) == 1
        assert history_a[0]["text"] == "User A entry"

        assert len(history_b) == 1
        assert history_b[0]["text"] == "User B entry"

    @pytest.mark.asyncio
    async def test_memory_store_respects_limit(self):
        """query() with limit parameter caps returned entries.

        Add 5 entries and query with limit=2; only last 2 returned.
        """
        store = InMemoryStore()

        for i in range(5):
            await store.add("user-C", f"Entry {i}")

        history = await store.query("user-C", limit=2)
        assert len(history) == 2
        assert history[0]["text"] == "Entry 3"
        assert history[1]["text"] == "Entry 4"

    @pytest.mark.asyncio
    async def test_memory_store_empty_user_returns_empty(self):
        """query() for a user with no entries returns empty list."""
        store = InMemoryStore()
        history = await store.query("nonexistent-user")
        assert history == []

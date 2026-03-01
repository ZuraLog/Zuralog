"""
Zuralog Cloud Brain — Oura Ring MCP Server Tests.

Tests for OuraServer: tool registration, routing, sandbox mode,
pagination, 401 retry logic, and rate limit handling.
"""

from contextlib import asynccontextmanager
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.mcp_servers.oura_server import OuraServer
from app.mcp_servers.models import ToolResult
from app.services.oura_token_service import OuraTokenService


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_server(sandbox: bool = False) -> OuraServer:
    """Build an OuraServer with mocked dependencies."""
    token_service = AsyncMock(spec=OuraTokenService)

    @asynccontextmanager
    async def db_factory():
        yield AsyncMock()

    server = OuraServer(
        token_service=token_service,
        db_factory=db_factory,
    )
    return server


def _make_server_with_token(access_token: str = "test-token", sandbox: bool = False):
    """Build a server where get_access_token returns a specific token."""
    token_service = AsyncMock(spec=OuraTokenService)
    token_service.get_access_token.return_value = access_token

    @asynccontextmanager
    async def db_factory():
        yield AsyncMock()

    server = OuraServer(
        token_service=token_service,
        db_factory=db_factory,
    )
    return server, token_service


# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------


class TestOuraServerProperties:
    def test_name(self):
        """Server name must be 'oura'."""
        server = _make_server()
        assert server.name == "oura"

    def test_description_non_empty(self):
        """Description must be a non-empty string."""
        server = _make_server()
        assert isinstance(server.description, str)
        assert len(server.description) > 10

    def test_description_mentions_oura(self):
        """Description should reference Oura capabilities."""
        server = _make_server()
        desc_lower = server.description.lower()
        assert "sleep" in desc_lower
        assert "readiness" in desc_lower


# ---------------------------------------------------------------------------
# Tool registration
# ---------------------------------------------------------------------------


class TestOuraServerTools:
    _EXPECTED_TOOLS = [
        "oura_get_daily_sleep",
        "oura_get_sleep",
        "oura_get_daily_activity",
        "oura_get_daily_readiness",
        "oura_get_heart_rate",
        "oura_get_daily_spo2",
        "oura_get_daily_stress",
        "oura_get_workouts",
        "oura_get_sessions",
        "oura_get_daily_resilience",
        "oura_get_daily_cardiovascular_age",
        "oura_get_vo2_max",
        "oura_get_sleep_time",
        "oura_get_tags",
        "oura_get_rest_mode",
        "oura_get_ring_configuration",
    ]

    def test_returns_16_tools(self):
        """get_tools() must return exactly 16 tools."""
        server = _make_server()
        tools = server.get_tools()
        assert len(tools) == 16

    def test_all_tool_names_match(self):
        """Every expected tool name must be present."""
        server = _make_server()
        tool_names = {t.name for t in server.get_tools()}
        for expected in self._EXPECTED_TOOLS:
            assert expected in tool_names, f"Missing tool: {expected}"

    def test_all_tools_have_descriptions(self):
        """Every tool must have a non-empty description."""
        server = _make_server()
        for tool in server.get_tools():
            assert isinstance(tool.description, str)
            assert len(tool.description) > 5, f"Tool {tool.name} has too-short description"

    def test_ring_configuration_has_empty_schema(self):
        """oura_get_ring_configuration should have no required params."""
        server = _make_server()
        tools = {t.name: t for t in server.get_tools()}
        ring_tool = tools["oura_get_ring_configuration"]
        assert ring_tool.input_schema.get("required", []) == []

    def test_date_based_tools_require_date(self):
        """All tools except ring_configuration must require 'date'."""
        server = _make_server()
        tools = {t.name: t for t in server.get_tools()}
        for name, tool in tools.items():
            if name == "oura_get_ring_configuration":
                continue
            assert "date" in tool.input_schema.get("required", []), f"Tool {name} should require 'date'"

    def test_heart_rate_tool_schema(self):
        """oura_get_heart_rate must have date and end_date in schema."""
        server = _make_server()
        tools = {t.name: t for t in server.get_tools()}
        hr_tool = tools["oura_get_heart_rate"]
        props = hr_tool.input_schema.get("properties", {})
        assert "date" in props
        assert "end_date" in props


# ---------------------------------------------------------------------------
# Path building
# ---------------------------------------------------------------------------


class TestOuraServerPathBuilding:
    def test_daily_sleep_path(self):
        server = _make_server()
        path, params = server._build_path_and_params("oura_get_daily_sleep", {"date": "2026-02-01"})
        assert path == "/v2/usercollection/daily_sleep"
        assert params["start_date"] == "2026-02-01"

    def test_daily_sleep_path_with_end_date(self):
        server = _make_server()
        path, params = server._build_path_and_params(
            "oura_get_daily_sleep", {"date": "2026-02-01", "end_date": "2026-02-07"}
        )
        assert path == "/v2/usercollection/daily_sleep"
        assert params["start_date"] == "2026-02-01"
        assert params["end_date"] == "2026-02-07"

    def test_heart_rate_uses_datetime_params(self):
        """Heart rate tool converts date → ISO datetime params."""
        server = _make_server()
        path, params = server._build_path_and_params(
            "oura_get_heart_rate", {"date": "2026-02-01", "end_date": "2026-02-02"}
        )
        assert path == "/v2/usercollection/heartrate"
        assert params["start_datetime"] == "2026-02-01T00:00:00+00:00"
        assert params["end_datetime"] == "2026-02-02T23:59:59+00:00"

    def test_ring_configuration_no_params(self):
        """Ring configuration tool builds path with empty params."""
        server = _make_server()
        path, params = server._build_path_and_params("oura_get_ring_configuration", {})
        assert path == "/v2/usercollection/ring_configuration"
        assert params == {}

    def test_workout_path(self):
        server = _make_server()
        path, params = server._build_path_and_params("oura_get_workouts", {"date": "2026-01-15"})
        assert path == "/v2/usercollection/workout"
        assert params["start_date"] == "2026-01-15"

    def test_vo2_max_path(self):
        server = _make_server()
        path, params = server._build_path_and_params("oura_get_vo2_max", {"date": "2026-01-10"})
        assert path == "/v2/usercollection/vO2_max"

    def test_enhanced_tag_path(self):
        server = _make_server()
        path, params = server._build_path_and_params("oura_get_tags", {"date": "2026-01-01"})
        assert path == "/v2/usercollection/enhanced_tag"

    def test_unknown_tool_returns_none(self):
        """Unknown tool names return (None, {})."""
        server = _make_server()
        path, params = server._build_path_and_params("oura_get_nonexistent", {})
        assert path is None
        assert params == {}

    def test_end_date_defaults_to_start_date(self):
        """end_date defaults to date when not provided."""
        server = _make_server()
        path, params = server._build_path_and_params("oura_get_daily_sleep", {"date": "2026-02-15"})
        assert params.get("end_date") == "2026-02-15"


# ---------------------------------------------------------------------------
# Sandbox mode
# ---------------------------------------------------------------------------


class TestOuraServerSandbox:
    def test_sandbox_substitutes_path(self):
        """When sandbox=True, paths use /v2/sandbox/usercollection/."""
        server = _make_server()

        with patch("app.mcp_servers.oura_server.settings") as mock_settings:
            mock_settings.oura_use_sandbox = True
            path, _ = server._build_path_and_params("oura_get_daily_sleep", {"date": "2026-02-01"})

        assert "/sandbox/usercollection/" in path
        assert "/v2/sandbox/usercollection/daily_sleep" == path

    def test_no_sandbox_uses_normal_path(self):
        """When sandbox=False, paths use /v2/usercollection/."""
        server = _make_server()

        with patch("app.mcp_servers.oura_server.settings") as mock_settings:
            mock_settings.oura_use_sandbox = False
            path, _ = server._build_path_and_params("oura_get_daily_sleep", {"date": "2026-02-01"})

        assert "/v2/usercollection/daily_sleep" == path
        assert "sandbox" not in path

    def test_sandbox_also_applies_to_heart_rate(self):
        """Sandbox substitution works for heartrate endpoint too."""
        server = _make_server()

        with patch("app.mcp_servers.oura_server.settings") as mock_settings:
            mock_settings.oura_use_sandbox = True
            path, _ = server._build_path_and_params("oura_get_heart_rate", {"date": "2026-02-01"})

        assert "sandbox" in path
        assert "heartrate" in path


# ---------------------------------------------------------------------------
# execute_tool: no token
# ---------------------------------------------------------------------------


class TestOuraExecuteToolNoToken:
    @pytest.mark.asyncio
    async def test_no_token_returns_error(self):
        """execute_tool returns error when no token available."""
        server, token_service = _make_server_with_token(access_token=None)
        token_service.get_access_token.return_value = None

        result = await server.execute_tool("oura_get_daily_sleep", {"date": "2026-02-01"}, user_id="user-123")

        assert result.success is False
        assert "connect" in result.error.lower() or "token" in result.error.lower()

    @pytest.mark.asyncio
    async def test_unknown_tool_returns_error(self):
        """execute_tool returns error for unknown tool names."""
        server, _ = _make_server_with_token("valid-token")

        result = await server.execute_tool("oura_get_nonexistent", {}, user_id="user-123")

        assert result.success is False
        assert "Unknown tool" in result.error


# ---------------------------------------------------------------------------
# execute_tool: happy path (mocked _call_oura)
# ---------------------------------------------------------------------------


class TestOuraExecuteToolHappyPath:
    @pytest.mark.asyncio
    async def test_daily_sleep_dispatches_correct_path(self):
        """execute_tool routes to the correct Oura API path."""
        server, _ = _make_server_with_token("access-token-123")

        mock_data = {"data": [{"id": "sleep-1", "score": 85}]}
        with patch.object(
            server,
            "_call_oura",
            new=AsyncMock(return_value=ToolResult(success=True, data=mock_data)),
        ) as mock_call:
            result = await server.execute_tool(
                "oura_get_daily_sleep",
                {"date": "2026-02-01"},
                user_id="user-123",
            )

        assert result.success is True
        assert result.data == mock_data

        # Verify correct path passed to _call_oura
        call_args = mock_call.call_args
        assert "daily_sleep" in call_args.args[0]

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "tool_name,expected_collection",
        [
            ("oura_get_sleep", "sleep"),
            ("oura_get_daily_activity", "daily_activity"),
            ("oura_get_daily_readiness", "daily_readiness"),
            ("oura_get_daily_spo2", "daily_spo2"),
            ("oura_get_daily_stress", "daily_stress"),
            ("oura_get_workouts", "workout"),
            ("oura_get_sessions", "session"),
            ("oura_get_daily_resilience", "daily_resilience"),
            ("oura_get_daily_cardiovascular_age", "daily_cardiovascular_age"),
            ("oura_get_vo2_max", "vO2_max"),
            ("oura_get_sleep_time", "sleep_time"),
            ("oura_get_tags", "enhanced_tag"),
            ("oura_get_rest_mode", "rest_mode_period"),
        ],
    )
    async def test_tool_routing(self, tool_name, expected_collection):
        """Each tool routes to its expected Oura API collection."""
        server, _ = _make_server_with_token("access-token")

        with patch.object(
            server,
            "_call_oura",
            new=AsyncMock(return_value=ToolResult(success=True, data={"data": []})),
        ) as mock_call:
            await server.execute_tool(tool_name, {"date": "2026-02-01"}, user_id="user-123")

        call_args = mock_call.call_args
        assert expected_collection in call_args.args[0], (
            f"Tool {tool_name}: expected '{expected_collection}' in path, got: {call_args.args[0]}"
        )

    @pytest.mark.asyncio
    async def test_heart_rate_routing(self):
        """Heart rate tool routes to heartrate collection."""
        server, _ = _make_server_with_token("access-token")

        with patch.object(
            server,
            "_call_oura",
            new=AsyncMock(return_value=ToolResult(success=True, data={"data": []})),
        ) as mock_call:
            await server.execute_tool(
                "oura_get_heart_rate",
                {"date": "2026-02-01"},
                user_id="user-123",
            )

        call_args = mock_call.call_args
        assert "heartrate" in call_args.args[0]

    @pytest.mark.asyncio
    async def test_ring_configuration_routing(self):
        """Ring configuration tool routes with no params."""
        server, _ = _make_server_with_token("access-token")

        with patch.object(
            server,
            "_call_oura",
            new=AsyncMock(return_value=ToolResult(success=True, data={"data": []})),
        ) as mock_call:
            await server.execute_tool("oura_get_ring_configuration", {}, user_id="user-123")

        call_args = mock_call.call_args
        assert "ring_configuration" in call_args.args[0]
        # No date params for ring configuration
        assert call_args.args[1] == {}


# ---------------------------------------------------------------------------
# _call_oura: 401 retry
# ---------------------------------------------------------------------------


class TestOuraCallOura401Retry:
    @pytest.mark.asyncio
    async def test_401_triggers_token_refresh_and_retry(self):
        """On 401, token is refreshed and the request is retried once."""
        server, token_service = _make_server_with_token("stale-token")

        # Set up integration mock for refresh
        mock_integration = MagicMock()
        token_service.get_integration.return_value = mock_integration
        token_service.refresh_access_token.return_value = "new-token"

        call_count = 0

        async def fake_call_oura(path, query_params, token, user_id, *, _retry=True):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                # Simulate 401 on first call
                mock_resp = MagicMock()
                mock_resp.status_code = 401

                import httpx

                async with httpx.AsyncClient(timeout=15.0) as client:
                    pass

                return ToolResult(success=False, data=None, error="401")
            # Second call succeeds
            return ToolResult(success=True, data={"data": []})

        # We test the actual 401 handling via mocking httpx
        mock_resp_401 = MagicMock()
        mock_resp_401.status_code = 401

        mock_resp_200 = MagicMock()
        mock_resp_200.status_code = 200
        mock_resp_200.json.return_value = {"data": [{"id": "1"}], "next_token": None}

        call_count = 0

        async def mock_get(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                return mock_resp_401
            return mock_resp_200

        with patch("app.mcp_servers.oura_server.httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = mock_get
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_cls.return_value = mock_client

            result = await server._call_oura(
                "/v2/usercollection/daily_sleep",
                {"start_date": "2026-02-01"},
                "stale-token",
                "user-123",
            )

        assert result.success is True
        token_service.refresh_access_token.assert_called_once()

    @pytest.mark.asyncio
    async def test_401_with_no_integration_returns_error(self):
        """401 with no integration found returns an error without retry."""
        server, token_service = _make_server_with_token("stale-token")
        token_service.get_integration.return_value = None

        mock_resp = MagicMock()
        mock_resp.status_code = 401

        with patch("app.mcp_servers.oura_server.httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_cls.return_value = mock_client

            result = await server._call_oura(
                "/v2/usercollection/daily_sleep",
                {},
                "stale-token",
                "user-123",
            )

        assert result.success is False
        assert "reconnect" in result.error.lower() or "integration" in result.error.lower()

    @pytest.mark.asyncio
    async def test_401_with_failed_refresh_returns_error(self):
        """401 + failed refresh returns user-facing error."""
        server, token_service = _make_server_with_token("stale-token")
        mock_integration = MagicMock()
        token_service.get_integration.return_value = mock_integration
        token_service.refresh_access_token.return_value = None  # refresh failed

        mock_resp = MagicMock()
        mock_resp.status_code = 401

        with patch("app.mcp_servers.oura_server.httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_cls.return_value = mock_client

            result = await server._call_oura(
                "/v2/usercollection/daily_sleep",
                {},
                "stale-token",
                "user-123",
            )

        assert result.success is False
        assert "refresh failed" in result.error or "reconnect" in result.error.lower()

    @pytest.mark.asyncio
    async def test_no_retry_on_second_401(self):
        """When _retry=False, 401 does not trigger another token refresh."""
        server, token_service = _make_server_with_token("token")

        mock_resp = MagicMock()
        mock_resp.status_code = 401

        with patch("app.mcp_servers.oura_server.httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_cls.return_value = mock_client

            result = await server._call_oura(
                "/v2/usercollection/daily_sleep",
                {},
                "token",
                "user-123",
                _retry=False,
            )

        assert result.success is False
        token_service.refresh_access_token.assert_not_called()


# ---------------------------------------------------------------------------
# _call_oura: rate limit handling
# ---------------------------------------------------------------------------


class TestOuraCallOuraRateLimit:
    @pytest.mark.asyncio
    async def test_429_returns_rate_limit_error(self):
        """429 response returns a rate limit error with retry info."""
        server, _ = _make_server_with_token("token")

        mock_resp = MagicMock()
        mock_resp.status_code = 429
        mock_resp.headers = {"Retry-After": "60"}

        with patch("app.mcp_servers.oura_server.httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_cls.return_value = mock_client

            result = await server._call_oura(
                "/v2/usercollection/daily_sleep",
                {},
                "token",
                "user-123",
            )

        assert result.success is False
        assert "rate limit" in result.error.lower() or "Rate limited" in result.error

    @pytest.mark.asyncio
    async def test_429_without_retry_after_header(self):
        """429 without Retry-After header returns 'unknown' retry time."""
        server, _ = _make_server_with_token("token")

        mock_resp = MagicMock()
        mock_resp.status_code = 429
        mock_resp.headers = {}

        with patch("app.mcp_servers.oura_server.httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_cls.return_value = mock_client

            result = await server._call_oura(
                "/v2/usercollection/daily_sleep",
                {},
                "token",
                "user-123",
            )

        assert result.success is False
        assert "unknown" in result.error.lower() or "rate" in result.error.lower()


# ---------------------------------------------------------------------------
# _call_oura: network errors
# ---------------------------------------------------------------------------


class TestOuraCallOuraNetworkErrors:
    @pytest.mark.asyncio
    async def test_network_error_returns_error_result(self):
        """Network error during API call returns failure ToolResult."""
        import httpx

        server, _ = _make_server_with_token("token")

        with patch("app.mcp_servers.oura_server.httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(side_effect=httpx.RequestError("Connection refused"))
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_cls.return_value = mock_client

            result = await server._call_oura(
                "/v2/usercollection/daily_sleep",
                {},
                "token",
                "user-123",
            )

        assert result.success is False
        assert "Network error" in result.error

    @pytest.mark.asyncio
    async def test_non_200_non_401_non_429_returns_error(self):
        """5xx errors return a generic API error result."""
        server, _ = _make_server_with_token("token")

        mock_resp = MagicMock()
        mock_resp.status_code = 500
        mock_resp.text = "Internal Server Error"

        with patch("app.mcp_servers.oura_server.httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_cls.return_value = mock_client

            result = await server._call_oura(
                "/v2/usercollection/daily_sleep",
                {},
                "token",
                "user-123",
            )

        assert result.success is False
        assert "500" in result.error


# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------


class TestOuraServerResources:
    @pytest.mark.asyncio
    async def test_get_resources_returns_list(self):
        """get_resources returns a non-empty list."""
        server = _make_server()
        resources = await server.get_resources("user-123")
        assert isinstance(resources, list)
        assert len(resources) >= 1

    @pytest.mark.asyncio
    async def test_resource_has_correct_uri(self):
        """The primary resource URI should reference oura."""
        server = _make_server()
        resources = await server.get_resources("user-123")
        uris = [r.uri for r in resources]
        assert any("oura" in uri for uri in uris)

"""
Zuralog Cloud Brain — Polar AccessLink MCP Server Tests.

Tests for PolarServer: tool registration, routing, rate limiting,
token handling, path substitution, status code handling, and
health checks. ~25 tests following the OuraServer test pattern.
"""

from contextlib import asynccontextmanager
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.mcp_servers.polar_server import PolarServer
from app.mcp_servers.models import ToolResult
from app.services.polar_token_service import PolarTokenService


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_server(rate_limiter=None) -> PolarServer:
    """Build a PolarServer with mocked dependencies."""
    token_service = AsyncMock(spec=PolarTokenService)

    @asynccontextmanager
    async def db_factory():
        yield AsyncMock()

    return PolarServer(
        token_service=token_service,
        db_factory=db_factory,
        rate_limiter=rate_limiter,
    )


def _make_server_with_token(
    access_token: str = "test-token",
    polar_user_id: str = "12345678",
    rate_limiter=None,
):
    """Build a server where get_access_token returns a specific token."""
    token_service = AsyncMock(spec=PolarTokenService)
    token_service.get_access_token.return_value = access_token

    # get_integration returns a mock with provider_metadata
    mock_integration = MagicMock()
    mock_integration.provider_metadata = {"polar_user_id": polar_user_id}
    token_service.get_integration.return_value = mock_integration

    @asynccontextmanager
    async def db_factory():
        yield AsyncMock()

    server = PolarServer(
        token_service=token_service,
        db_factory=db_factory,
        rate_limiter=rate_limiter,
    )
    return server, token_service


def _make_mock_response(status_code: int, json_data=None, text="", headers=None):
    """Build a MagicMock httpx response."""
    mock_resp = MagicMock()
    mock_resp.status_code = status_code
    mock_resp.text = text
    mock_resp.headers = headers or {}
    if json_data is not None:
        mock_resp.json.return_value = json_data
    return mock_resp


# ---------------------------------------------------------------------------
# TestGetTools
# ---------------------------------------------------------------------------


class TestGetTools:
    def test_returns_14_tools(self):
        """get_tools() must return exactly 14 tools."""
        server = _make_server()
        tools = server.get_tools()
        assert len(tools) == 14

    def test_all_tools_have_descriptions(self):
        """Every tool must have a non-empty description string."""
        server = _make_server()
        for tool in server.get_tools():
            assert isinstance(tool.description, str)
            assert len(tool.description) > 5, f"Tool {tool.name} has too-short description"

    def test_tool_names_start_with_polar(self):
        """All tool names must start with 'polar_'."""
        server = _make_server()
        for tool in server.get_tools():
            assert tool.name.startswith("polar_"), f"Tool {tool.name} doesn't start with 'polar_'"

    def test_expected_tool_names_present(self):
        """All 14 expected tool names must be present."""
        expected = {
            "polar_get_exercises",
            "polar_get_exercise",
            "polar_get_daily_activity",
            "polar_get_activity_range",
            "polar_get_continuous_hr",
            "polar_get_continuous_hr_range",
            "polar_get_sleep",
            "polar_get_nightly_recharge",
            "polar_get_cardio_load",
            "polar_get_cardio_load_range",
            "polar_get_sleepwise_alertness",
            "polar_get_sleepwise_bedtime",
            "polar_get_body_temperature",
            "polar_get_physical_info",
        }
        server = _make_server()
        actual = {t.name for t in server.get_tools()}
        assert actual == expected

    def test_physical_info_has_no_required_params(self):
        """polar_get_physical_info should have no required parameters."""
        server = _make_server()
        tools = {t.name: t for t in server.get_tools()}
        tool = tools["polar_get_physical_info"]
        assert tool.input_schema.get("required", []) == []

    def test_date_based_tools_require_date(self):
        """Tools with _DATE_SCHEMA should require 'date'."""
        date_required_tools = {
            "polar_get_daily_activity",
            "polar_get_continuous_hr",
            "polar_get_sleep",
            "polar_get_nightly_recharge",
            "polar_get_cardio_load",
        }
        server = _make_server()
        tools = {t.name: t for t in server.get_tools()}
        for name in date_required_tools:
            required = tools[name].input_schema.get("required", [])
            assert "date" in required, f"Tool {name} should require 'date'"


# ---------------------------------------------------------------------------
# TestExecuteTool
# ---------------------------------------------------------------------------


class TestExecuteTool:
    @pytest.mark.asyncio
    async def test_unknown_tool_returns_error(self):
        """execute_tool returns an error for unknown tool names."""
        server, _ = _make_server_with_token("valid-token")
        result = await server.execute_tool("polar_nonexistent", {}, user_id="user-123")
        assert result.success is False
        assert result.error is not None

    @pytest.mark.asyncio
    async def test_rate_limit_blocks_request(self):
        """When rate_limiter.check_and_increment returns False, execute_tool returns rate limit error."""
        rate_limiter = AsyncMock()
        rate_limiter.check_and_increment.return_value = False

        server, _ = _make_server_with_token("valid-token", rate_limiter=rate_limiter)

        result = await server.execute_tool("polar_get_exercises", {}, user_id="user-123")

        assert result.success is False
        assert "rate" in result.error.lower()

    @pytest.mark.asyncio
    async def test_rate_limit_allowed_calls_polar(self):
        """When rate_limiter.check_and_increment returns True, the API call proceeds."""
        rate_limiter = AsyncMock()
        rate_limiter.check_and_increment.return_value = True

        server, _ = _make_server_with_token("valid-token", rate_limiter=rate_limiter)

        mock_data = {"data": [{"id": "ex-1"}]}
        with patch.object(
            server,
            "_call_polar",
            new=AsyncMock(return_value=ToolResult(success=True, data=mock_data)),
        ):
            result = await server.execute_tool("polar_get_exercises", {}, user_id="user-123")

        assert result.success is True
        assert result.data == mock_data

    @pytest.mark.asyncio
    async def test_no_rate_limiter_calls_polar_directly(self):
        """Without a rate_limiter, execute_tool calls _call_polar directly."""
        server, _ = _make_server_with_token("valid-token")

        mock_data = {"data": []}
        with patch.object(
            server,
            "_call_polar",
            new=AsyncMock(return_value=ToolResult(success=True, data=mock_data)),
        ) as mock_call:
            result = await server.execute_tool("polar_get_exercises", {}, user_id="user-123")

        assert result.success is True
        mock_call.assert_called_once()


# ---------------------------------------------------------------------------
# TestCallPolar
# ---------------------------------------------------------------------------


class TestCallPolar:
    @pytest.mark.asyncio
    async def test_no_token_returns_error(self):
        """_call_polar returns error when token_service returns None."""
        server, token_service = _make_server_with_token("some-token")
        token_service.get_access_token.return_value = None

        result = await server._call_polar("polar_get_exercises", {}, user_id="user-123")

        assert result.success is False
        assert "token" in result.error.lower() or "connect" in result.error.lower()

    @pytest.mark.asyncio
    async def test_expired_token_401_returns_error(self):
        """A 401 from Polar returns the re-auth error message."""
        server, _ = _make_server_with_token("expired-token")

        mock_resp = _make_mock_response(401)

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server._call_polar("polar_get_exercises", {}, user_id="user-123")

        assert result.success is False
        assert "reconnect" in result.error.lower() or "expired" in result.error.lower()

    @pytest.mark.asyncio
    async def test_rate_limited_429_returns_error(self):
        """A 429 from Polar returns a rate limit error message."""
        server, _ = _make_server_with_token("token")

        mock_resp = _make_mock_response(429)

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server._call_polar("polar_get_exercises", {}, user_id="user-123")

        assert result.success is False
        assert "rate" in result.error.lower()

    @pytest.mark.asyncio
    async def test_204_returns_no_data_message(self):
        """A 204 No Content response returns a success with a no-data message."""
        server, _ = _make_server_with_token("token")

        mock_resp = _make_mock_response(204)

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server._call_polar("polar_get_daily_activity", {"date": "2026-02-01"}, user_id="user-123")

        assert result.success is True
        assert "no data" in str(result.data).lower()

    @pytest.mark.asyncio
    async def test_404_returns_not_found_message(self):
        """A 404 response returns a success with a not-found message."""
        server, _ = _make_server_with_token("token")

        mock_resp = _make_mock_response(404)

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server._call_polar("polar_get_daily_activity", {"date": "2026-02-01"}, user_id="user-123")

        assert result.success is True
        assert "no data" in str(result.data).lower() or "not found" in str(result.data).lower()

    @pytest.mark.asyncio
    async def test_200_returns_success_with_data(self):
        """A 200 response returns success with the parsed JSON body."""
        server, _ = _make_server_with_token("token")

        payload = {"steps": 12000, "calories": 450}
        mock_resp = _make_mock_response(200, json_data=payload)

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server._call_polar("polar_get_daily_activity", {"date": "2026-02-01"}, user_id="user-123")

        assert result.success is True
        assert result.data == payload

    @pytest.mark.asyncio
    async def test_timeout_returns_error(self):
        """A timeout exception returns an error ToolResult."""
        import httpx as httpx_module

        server, _ = _make_server_with_token("token")

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(side_effect=httpx_module.TimeoutException("timed out"))
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server._call_polar("polar_get_exercises", {}, user_id="user-123")

        assert result.success is False
        assert "timeout" in result.error.lower() or "timed out" in result.error.lower()

    @pytest.mark.asyncio
    async def test_exercise_id_substituted_in_url(self):
        """polar_get_exercise substitutes {exercise_id} into the URL path."""
        server, _ = _make_server_with_token("token")

        payload = {"id": "abc123", "sport": "running"}
        mock_resp = _make_mock_response(200, json_data=payload)

        captured_urls = []

        async def mock_get(url, **kwargs):
            captured_urls.append(url)
            return mock_resp

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.get = mock_get
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server._call_polar(
                "polar_get_exercise",
                {"exercise_id": "abc123"},
                user_id="user-123",
            )

        assert result.success is True
        assert any("abc123" in url for url in captured_urls), f"URL did not contain exercise_id: {captured_urls}"

    @pytest.mark.asyncio
    async def test_date_substituted_in_url(self):
        """polar_get_daily_activity substitutes {date} into the URL path."""
        server, _ = _make_server_with_token("token")

        payload = {"steps": 8000}
        mock_resp = _make_mock_response(200, json_data=payload)

        captured_urls = []

        async def mock_get(url, **kwargs):
            captured_urls.append(url)
            return mock_resp

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.get = mock_get
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server._call_polar(
                "polar_get_daily_activity",
                {"date": "2026-02-15"},
                user_id="user-123",
            )

        assert result.success is True
        assert any("2026-02-15" in url for url in captured_urls), f"URL did not contain date: {captured_urls}"

    @pytest.mark.asyncio
    async def test_polar_user_id_substituted_for_physical_info(self):
        """polar_get_physical_info substitutes {polar_user_id} from integration metadata."""
        server, _ = _make_server_with_token("token", polar_user_id="99887766")

        payload = {"weight": 75.0, "height": 180}
        mock_resp = _make_mock_response(200, json_data=payload)

        captured_urls = []

        async def mock_get(url, **kwargs):
            captured_urls.append(url)
            return mock_resp

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.get = mock_get
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server._call_polar("polar_get_physical_info", {}, user_id="user-123")

        assert result.success is True
        assert any("99887766" in url for url in captured_urls), f"URL did not contain polar_user_id: {captured_urls}"

    @pytest.mark.asyncio
    async def test_range_endpoint_uses_from_to_params(self):
        """Range endpoints pass 'from' and 'to' as query params instead of path segments."""
        server, _ = _make_server_with_token("token")

        payload = [{"date": "2026-02-01", "steps": 9000}]
        mock_resp = _make_mock_response(200, json_data=payload)

        captured_params = []

        async def mock_get(url, params=None, **kwargs):
            captured_params.append(params or {})
            return mock_resp

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.get = mock_get
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server._call_polar(
                "polar_get_activity_range",
                {"date": "2026-02-01", "end_date": "2026-02-07"},
                user_id="user-123",
            )

        assert result.success is True
        assert any("from" in p for p in captured_params), f"'from' not in query params: {captured_params}"
        assert any("to" in p for p in captured_params), f"'to' not in query params: {captured_params}"

    @pytest.mark.asyncio
    async def test_rate_limiter_updated_from_headers(self):
        """After a successful response, update_from_headers is called with response headers."""
        rate_limiter = AsyncMock()
        rate_limiter.check_and_increment.return_value = True
        rate_limiter.update_from_headers = AsyncMock()

        server, _ = _make_server_with_token("token", rate_limiter=rate_limiter)

        headers = {"RateLimit-Usage": "10, 50", "RateLimit-Limit": "500, 5000"}
        payload = {"data": "ok"}
        mock_resp = _make_mock_response(200, json_data=payload, headers=headers)

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server._call_polar("polar_get_exercises", {}, user_id="user-123")

        assert result.success is True
        rate_limiter.update_from_headers.assert_called_once()

    @pytest.mark.asyncio
    async def test_generic_error_returns_status_and_text(self):
        """A non-2xx, non-401, non-429, non-404 response returns status code in error."""
        server, _ = _make_server_with_token("token")

        mock_resp = _make_mock_response(500, text="Internal Server Error")

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server._call_polar("polar_get_exercises", {}, user_id="user-123")

        assert result.success is False
        assert "500" in result.error

    @pytest.mark.asyncio
    async def test_include_samples_adds_query_param(self):
        """include_samples=True adds samples=true to the query parameters."""
        server, _ = _make_server_with_token("token")

        payload = {"exercises": []}
        mock_resp = _make_mock_response(200, json_data=payload)

        captured_params = []

        async def mock_get(url, params=None, **kwargs):
            captured_params.append(params or {})
            return mock_resp

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.get = mock_get
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server._call_polar(
                "polar_get_exercises",
                {"include_samples": True},
                user_id="user-123",
            )

        assert result.success is True
        assert any(p.get("samples") == "true" for p in captured_params), (
            f"'samples=true' not in query params: {captured_params}"
        )


# ---------------------------------------------------------------------------
# TestGetResources
# ---------------------------------------------------------------------------


class TestGetResources:
    @pytest.mark.asyncio
    async def test_returns_one_resource(self):
        """get_resources must return exactly one resource."""
        server = _make_server()
        resources = await server.get_resources("user-123")
        assert isinstance(resources, list)
        assert len(resources) == 1

    @pytest.mark.asyncio
    async def test_resource_uri_is_polar_scheme(self):
        """The resource URI must use the 'polar://' scheme."""
        server = _make_server()
        resources = await server.get_resources("user-123")
        assert resources[0].uri.startswith("polar://")

    @pytest.mark.asyncio
    async def test_resource_has_name_and_description(self):
        """Resource must have a non-empty name and description."""
        server = _make_server()
        resources = await server.get_resources("user-123")
        resource = resources[0]
        assert resource.name
        assert resource.description


# ---------------------------------------------------------------------------
# TestHealthCheck
# ---------------------------------------------------------------------------


class TestHealthCheck:
    @pytest.mark.asyncio
    async def test_health_check_returns_true_on_success(self):
        """health_check returns True when Polar API responds with 2xx."""
        server = _make_server()

        mock_resp = _make_mock_response(200)

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.head = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server.health_check()

        assert result is True

    @pytest.mark.asyncio
    async def test_health_check_returns_false_on_exception(self):
        """health_check returns False when a network exception occurs."""
        import httpx as httpx_module

        server = _make_server()

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.head = AsyncMock(side_effect=httpx_module.RequestError("Connection refused"))
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server.health_check()

        assert result is False

    @pytest.mark.asyncio
    async def test_health_check_returns_false_on_5xx(self):
        """health_check returns False for 5xx responses (not in 200-399 range)."""
        server = _make_server()

        mock_resp = _make_mock_response(503)

        with patch("app.mcp_servers.polar_server.httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.head = AsyncMock(return_value=mock_resp)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_cls.return_value = mock_client

            result = await server.health_check()

        assert result is False


# ---------------------------------------------------------------------------
# TestServerProperties
# ---------------------------------------------------------------------------


class TestServerProperties:
    def test_name_is_polar(self):
        """Server name must be 'polar'."""
        server = _make_server()
        assert server.name == "polar"

    def test_description_non_empty(self):
        """Description must be a meaningful string."""
        server = _make_server()
        assert isinstance(server.description, str)
        assert len(server.description) > 20

    def test_description_mentions_polar_data_types(self):
        """Description should mention key Polar data types."""
        server = _make_server()
        desc_lower = server.description.lower()
        assert "sleep" in desc_lower
        assert "heart rate" in desc_lower or "exercise" in desc_lower

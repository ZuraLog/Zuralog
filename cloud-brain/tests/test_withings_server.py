"""Tests for WithingsServer MCP server."""

from contextlib import asynccontextmanager
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.mcp_servers.withings_server import WithingsServer
from app.mcp_servers.models import ToolResult


@pytest.fixture
def mock_token_service():
    svc = AsyncMock()
    svc.get_access_token = AsyncMock(return_value="test_access_token")
    svc.get_integration = AsyncMock(return_value=MagicMock())
    svc.refresh_access_token = AsyncMock(return_value="new_token")
    return svc


@pytest.fixture
def mock_signature_service():
    svc = AsyncMock()
    svc.prepare_signed_params = AsyncMock(
        return_value={
            "action": "getmeas",
            "client_id": "test_client_id",
            "nonce": "test_nonce",
            "signature": "a" * 64,
        }
    )
    return svc


@pytest.fixture
def mock_rate_limiter():
    limiter = AsyncMock()
    limiter.check_and_increment = AsyncMock(return_value=True)
    return limiter


@asynccontextmanager
async def _mock_db_factory():
    yield AsyncMock()


@pytest.fixture
def server(mock_token_service, mock_signature_service, mock_rate_limiter):
    return WithingsServer(
        token_service=mock_token_service,
        signature_service=mock_signature_service,
        db_factory=_mock_db_factory,
        rate_limiter=mock_rate_limiter,
    )


class TestWithingsServerProperties:
    def test_name(self, server):
        assert server.name == "withings"

    def test_description_contains_key_terms(self, server):
        desc = server.description.lower()
        assert "body composition" in desc
        assert "blood pressure" in desc
        assert "sleep" in desc
        assert "ecg" in desc

    def test_get_tools_returns_10(self, server):
        tools = server.get_tools()
        assert len(tools) == 10

    def test_all_tool_names_are_unique(self, server):
        names = [t.name for t in server.get_tools()]
        assert len(names) == len(set(names))

    def test_all_tools_have_withings_prefix(self, server):
        for tool in server.get_tools():
            assert tool.name.startswith("withings_"), f"{tool.name} missing prefix"


class TestExecuteTool:
    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_successful_getmeas(self, mock_post, server):
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "status": 0,
            "body": {"measuregrps": [{"measures": [{"value": 75, "type": 1, "unit": 0}]}]},
        }
        mock_post.return_value = mock_response

        result = await server.execute_tool(
            "withings_get_measurements",
            {"start_date": "2024-01-01", "end_date": "2024-01-07"},
            "user-abc",
        )

        assert result.success is True
        assert "measuregrps" in result.data

    @pytest.mark.asyncio
    async def test_unknown_tool_returns_error(self, server):
        result = await server.execute_tool("unknown_tool", {}, "user-abc")
        assert result.success is False
        assert "Unknown tool" in result.error

    @pytest.mark.asyncio
    async def test_no_token_returns_error(self, server, mock_token_service):
        mock_token_service.get_access_token = AsyncMock(return_value=None)

        result = await server.execute_tool("withings_get_measurements", {"start_date": "2024-01-01"}, "user-abc")

        assert result.success is False
        assert "connect" in result.error.lower()

    @pytest.mark.asyncio
    async def test_rate_limit_exceeded_returns_error(self, server, mock_rate_limiter):
        mock_rate_limiter.check_and_increment = AsyncMock(return_value=False)

        result = await server.execute_tool("withings_get_measurements", {"start_date": "2024-01-01"}, "user-abc")

        assert result.success is False
        assert "rate limit" in result.error.lower()

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_withings_api_error_returns_failure(self, mock_post, server):
        mock_response = MagicMock()
        mock_response.json.return_value = {"status": 500, "error": "Internal error"}
        mock_post.return_value = mock_response

        result = await server.execute_tool("withings_get_measurements", {"start_date": "2024-01-01"}, "user-abc")

        assert result.success is False
        assert "500" in result.error

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_auth_error_triggers_refresh_and_retry(self, mock_post, server):
        """401 from Withings triggers token refresh and one retry.

        Each API call involves 2 POSTs: one for getnonce, one for the API.
        Refresh is mocked on token_service so it doesn't make HTTP calls.
        """
        nonce_ok = MagicMock()
        nonce_ok.json.return_value = {"status": 0, "body": {"nonce": "test_nonce"}}
        nonce_ok.raise_for_status = MagicMock()

        api_401 = MagicMock()
        api_401.json.return_value = {"status": 401, "error": "Unauthorized"}

        api_ok = MagicMock()
        api_ok.json.return_value = {"status": 0, "body": {"measuregrps": []}}

        # Call 1: nonce → 401; Call 2 (retry after refresh): nonce → success
        mock_post.side_effect = [nonce_ok, api_401, nonce_ok, api_ok]

        result = await server.execute_tool("withings_get_measurements", {"start_date": "2024-01-01"}, "user-abc")

        assert result.success is True

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_network_error_returns_failure(self, mock_post, server):
        import httpx as _httpx

        mock_post.side_effect = _httpx.RequestError("Connection refused")

        result = await server.execute_tool("withings_get_measurements", {"start_date": "2024-01-01"}, "user-abc")

        assert result.success is False
        assert "Network error" in result.error

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_all_tool_names_resolve(self, mock_post, server):
        """All 10 tools resolve to a valid Withings endpoint."""
        mock_response = MagicMock()
        mock_response.json.return_value = {"status": 0, "body": {}}
        mock_post.return_value = mock_response

        tools = server.get_tools()
        for tool in tools:
            result = await server.execute_tool(tool.name, {"start_date": "2024-01-01"}, "user-abc")
            # Should not get "Unknown tool" error
            assert "Unknown tool" not in (result.error or ""), f"{tool.name} failed routing"


class TestGetResources:
    @pytest.mark.asyncio
    async def test_returns_one_resource(self, server):
        resources = await server.get_resources("user-abc")
        assert len(resources) == 1
        assert resources[0].uri == "withings://health/data"


class TestHealthCheck:
    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.head")
    async def test_returns_true_on_200(self, mock_head, server):
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_head.return_value = mock_resp

        result = await server.health_check()
        assert result is True

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.head")
    async def test_returns_false_on_network_error(self, mock_head, server):
        import httpx as _httpx

        mock_head.side_effect = _httpx.RequestError("Connection refused")

        result = await server.health_check()
        assert result is False

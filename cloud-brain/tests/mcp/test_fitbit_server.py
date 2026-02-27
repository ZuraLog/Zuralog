"""Tests for FitbitServer MCP server.

Covers:
- All 12 tool definitions (name, description, input_schema, required fields)
- execute_tool routing dispatches to correct Fitbit API path for each tool
- Rate limit exhaustion returns error ToolResult (no HTTP call made)
- 401 → token refresh → retry flow (one refresh, then success)
- 401 → token refresh fails → error ToolResult
- 429 → rate limit error ToolResult from Fitbit server
- Generic non-200 → error ToolResult
- Network error → error ToolResult
- Successful response → ToolResult(success=True, data=...)
- Rate limiter update_from_headers called after 200 response
- Missing token → error ToolResult
- Unknown tool → error ToolResult
- _build_path for every tool including optional end_date / time variants
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import httpx
import pytest

from app.mcp_servers.fitbit_server import FitbitServer, _FITBIT_API_BASE
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_EXPECTED_TOOL_NAMES = [
    "fitbit_get_daily_activity",
    "fitbit_get_activity_timeseries",
    "fitbit_get_heart_rate",
    "fitbit_get_heart_rate_intraday",
    "fitbit_get_hrv",
    "fitbit_get_sleep",
    "fitbit_get_spo2",
    "fitbit_get_breathing_rate",
    "fitbit_get_temperature",
    "fitbit_get_vo2max",
    "fitbit_get_weight",
    "fitbit_get_nutrition",
]


def _make_server(
    token: str | None = "fake-token",
    rate_limiter: object | None = None,
) -> FitbitServer:
    """Build a FitbitServer with mocked token_service and db_factory.

    Args:
        token: Value returned by get_access_token. ``None`` simulates no
            integration.
        rate_limiter: Optional mock rate limiter to inject.

    Returns:
        A ``FitbitServer`` ready for testing without a real DB or Redis.
    """
    mock_token_service = AsyncMock()
    mock_token_service.get_access_token.return_value = token

    mock_db = AsyncMock()
    mock_db_ctx = AsyncMock()
    mock_db_ctx.__aenter__ = AsyncMock(return_value=mock_db)
    mock_db_ctx.__aexit__ = AsyncMock(return_value=False)

    return FitbitServer(
        token_service=mock_token_service,
        db_factory=lambda: mock_db_ctx,
        rate_limiter=rate_limiter,
    )


def _mock_http_response(status_code: int = 200, json_data: object = None, headers: dict | None = None) -> MagicMock:
    """Build a fake httpx response object.

    Args:
        status_code: HTTP status code.
        json_data: Value returned by ``.json()``.
        headers: Optional response headers dict.

    Returns:
        A ``MagicMock`` mimicking an ``httpx.Response``.
    """
    resp = MagicMock()
    resp.status_code = status_code
    resp.json.return_value = json_data or {}
    resp.text = str(json_data or {})
    resp.headers = headers or {}
    return resp


# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

class TestFitbitServerProperties:
    """Tests for server identity properties."""

    def test_name_is_fitbit(self) -> None:
        server = _make_server()
        assert server.name == "fitbit"

    def test_description_is_nonempty(self) -> None:
        server = _make_server()
        assert len(server.description) > 0
        assert "Fitbit" in server.description or "fitbit" in server.description.lower()

    def test_description_mentions_key_data_types(self) -> None:
        server = _make_server()
        desc = server.description.lower()
        for keyword in ("activity", "heart rate", "sleep", "spo2"):
            assert keyword in desc, f"Expected '{keyword}' in description"


# ---------------------------------------------------------------------------
# Tool definitions
# ---------------------------------------------------------------------------

class TestFitbitServerTools:
    """Verify all 12 tool definitions are registered correctly."""

    def test_get_tools_returns_tool_definitions(self) -> None:
        tools = _make_server().get_tools()
        assert isinstance(tools, list)
        assert all(isinstance(t, ToolDefinition) for t in tools)

    def test_exactly_12_tools(self) -> None:
        tools = _make_server().get_tools()
        assert len(tools) == 12

    @pytest.mark.parametrize("name", _EXPECTED_TOOL_NAMES)
    def test_tool_name_present(self, name: str) -> None:
        names = [t.name for t in _make_server().get_tools()]
        assert name in names

    @pytest.mark.parametrize("name", _EXPECTED_TOOL_NAMES)
    def test_tool_has_nonempty_description(self, name: str) -> None:
        tool = next(t for t in _make_server().get_tools() if t.name == name)
        assert len(tool.description) > 0

    @pytest.mark.parametrize("name", _EXPECTED_TOOL_NAMES)
    def test_tool_has_input_schema(self, name: str) -> None:
        tool = next(t for t in _make_server().get_tools() if t.name == name)
        assert isinstance(tool.input_schema, dict)
        assert tool.input_schema.get("type") == "object"

    # Required field checks

    def test_daily_activity_requires_date(self) -> None:
        tool = next(t for t in _make_server().get_tools() if t.name == "fitbit_get_daily_activity")
        assert "date" in tool.input_schema.get("required", [])

    def test_activity_timeseries_requires_resource_start_end(self) -> None:
        tool = next(t for t in _make_server().get_tools() if t.name == "fitbit_get_activity_timeseries")
        required = tool.input_schema.get("required", [])
        assert "resource" in required
        assert "start_date" in required
        assert "end_date" in required

    def test_activity_timeseries_resource_enum(self) -> None:
        tool = next(t for t in _make_server().get_tools() if t.name == "fitbit_get_activity_timeseries")
        enum = tool.input_schema["properties"]["resource"]["enum"]
        assert "steps" in enum
        assert "calories" in enum
        assert "floors" in enum

    def test_heart_rate_requires_date(self) -> None:
        tool = next(t for t in _make_server().get_tools() if t.name == "fitbit_get_heart_rate")
        assert "date" in tool.input_schema.get("required", [])

    def test_heart_rate_period_enum(self) -> None:
        tool = next(t for t in _make_server().get_tools() if t.name == "fitbit_get_heart_rate")
        period_prop = tool.input_schema["properties"].get("period", {})
        assert "1d" in period_prop.get("enum", [])
        assert "7d" in period_prop.get("enum", [])

    def test_intraday_hr_requires_date(self) -> None:
        tool = next(t for t in _make_server().get_tools() if t.name == "fitbit_get_heart_rate_intraday")
        assert "date" in tool.input_schema.get("required", [])

    def test_intraday_hr_detail_level_enum(self) -> None:
        tool = next(t for t in _make_server().get_tools() if t.name == "fitbit_get_heart_rate_intraday")
        enum = tool.input_schema["properties"]["detail_level"]["enum"]
        assert "1sec" in enum
        assert "1min" in enum
        assert "15min" in enum

    @pytest.mark.parametrize("name", [
        "fitbit_get_hrv", "fitbit_get_sleep", "fitbit_get_spo2",
        "fitbit_get_breathing_rate", "fitbit_get_temperature",
        "fitbit_get_vo2max", "fitbit_get_weight",
    ])
    def test_range_tools_have_optional_end_date(self, name: str) -> None:
        tool = next(t for t in _make_server().get_tools() if t.name == name)
        # end_date must be in properties but NOT in required
        assert "end_date" in tool.input_schema["properties"]
        assert "end_date" not in tool.input_schema.get("required", [])

    def test_nutrition_requires_date_only(self) -> None:
        tool = next(t for t in _make_server().get_tools() if t.name == "fitbit_get_nutrition")
        assert tool.input_schema.get("required") == ["date"]
        # end_date should NOT be in nutrition schema
        assert "end_date" not in tool.input_schema.get("properties", {})


# ---------------------------------------------------------------------------
# _build_path — path construction
# ---------------------------------------------------------------------------

class TestBuildPath:
    """Tests for the internal ``_build_path`` helper."""

    def _server(self) -> FitbitServer:
        return _make_server()

    def test_daily_activity_path(self) -> None:
        path = self._server()._build_path("fitbit_get_daily_activity", {"date": "2026-02-28"})
        assert path == "/1/user/-/activities/date/2026-02-28.json"

    def test_activity_timeseries_path(self) -> None:
        path = self._server()._build_path(
            "fitbit_get_activity_timeseries",
            {"resource": "steps", "start_date": "2026-02-01", "end_date": "2026-02-28"},
        )
        assert path == "/1/user/-/activities/steps/date/2026-02-01/2026-02-28.json"

    def test_heart_rate_default_period(self) -> None:
        path = self._server()._build_path("fitbit_get_heart_rate", {"date": "2026-02-28"})
        assert path == "/1/user/-/activities/heart/date/2026-02-28/1d.json"

    def test_heart_rate_custom_period(self) -> None:
        path = self._server()._build_path("fitbit_get_heart_rate", {"date": "2026-02-28", "period": "7d"})
        assert path == "/1/user/-/activities/heart/date/2026-02-28/7d.json"

    def test_intraday_hr_no_time_range(self) -> None:
        path = self._server()._build_path("fitbit_get_heart_rate_intraday", {"date": "2026-02-28"})
        assert path == "/1/user/-/activities/heart/date/2026-02-28/1d/1min.json"

    def test_intraday_hr_with_time_range(self) -> None:
        path = self._server()._build_path(
            "fitbit_get_heart_rate_intraday",
            {"date": "2026-02-28", "detail_level": "1sec", "start_time": "08:00", "end_time": "09:00"},
        )
        assert path == "/1/user/-/activities/heart/date/2026-02-28/1d/1sec/time/08:00/09:00.json"

    def test_hrv_single_date(self) -> None:
        path = self._server()._build_path("fitbit_get_hrv", {"date": "2026-02-28"})
        assert path == "/1/user/-/hrv/date/2026-02-28.json"

    def test_hrv_date_range(self) -> None:
        path = self._server()._build_path("fitbit_get_hrv", {"date": "2026-02-01", "end_date": "2026-02-28"})
        assert path == "/1/user/-/hrv/date/2026-02-01/2026-02-28.json"

    def test_sleep_single_date(self) -> None:
        path = self._server()._build_path("fitbit_get_sleep", {"date": "2026-02-28"})
        assert path == "/1.2/user/-/sleep/date/2026-02-28.json"

    def test_sleep_date_range(self) -> None:
        path = self._server()._build_path("fitbit_get_sleep", {"date": "2026-02-01", "end_date": "2026-02-28"})
        assert path == "/1.2/user/-/sleep/date/2026-02-01/2026-02-28.json"

    def test_spo2_single_date(self) -> None:
        path = self._server()._build_path("fitbit_get_spo2", {"date": "2026-02-28"})
        assert path == "/1/user/-/spo2/date/2026-02-28.json"

    def test_spo2_date_range(self) -> None:
        path = self._server()._build_path("fitbit_get_spo2", {"date": "2026-02-01", "end_date": "2026-02-07"})
        assert path == "/1/user/-/spo2/date/2026-02-01/2026-02-07.json"

    def test_breathing_rate_single_date(self) -> None:
        path = self._server()._build_path("fitbit_get_breathing_rate", {"date": "2026-02-28"})
        assert path == "/1/user/-/br/date/2026-02-28.json"

    def test_breathing_rate_date_range(self) -> None:
        path = self._server()._build_path("fitbit_get_breathing_rate", {"date": "2026-02-01", "end_date": "2026-02-28"})
        assert path == "/1/user/-/br/date/2026-02-01/2026-02-28.json"

    def test_temperature_single_date(self) -> None:
        path = self._server()._build_path("fitbit_get_temperature", {"date": "2026-02-28"})
        assert path == "/1/user/-/temp/skin/date/2026-02-28.json"

    def test_temperature_date_range(self) -> None:
        path = self._server()._build_path("fitbit_get_temperature", {"date": "2026-02-01", "end_date": "2026-02-28"})
        assert path == "/1/user/-/temp/skin/date/2026-02-01/2026-02-28.json"

    def test_vo2max_single_date(self) -> None:
        path = self._server()._build_path("fitbit_get_vo2max", {"date": "2026-02-28"})
        assert path == "/1/user/-/cardioscore/date/2026-02-28.json"

    def test_vo2max_date_range(self) -> None:
        path = self._server()._build_path("fitbit_get_vo2max", {"date": "2026-02-01", "end_date": "2026-02-28"})
        assert path == "/1/user/-/cardioscore/date/2026-02-01/2026-02-28.json"

    def test_weight_single_date(self) -> None:
        path = self._server()._build_path("fitbit_get_weight", {"date": "2026-02-28"})
        assert path == "/1/user/-/body/log/weight/date/2026-02-28.json"

    def test_weight_date_range(self) -> None:
        path = self._server()._build_path("fitbit_get_weight", {"date": "2026-02-01", "end_date": "2026-02-28"})
        assert path == "/1/user/-/body/log/weight/date/2026-02-01/2026-02-28.json"

    def test_nutrition_path(self) -> None:
        path = self._server()._build_path("fitbit_get_nutrition", {"date": "2026-02-28"})
        assert path == "/1/user/-/foods/log/date/2026-02-28.json"

    def test_unknown_tool_returns_none(self) -> None:
        path = self._server()._build_path("nonexistent_tool", {"date": "2026-02-28"})
        assert path is None


# ---------------------------------------------------------------------------
# execute_tool — rate limit exhaustion
# ---------------------------------------------------------------------------

class TestRateLimitExhaustion:
    """execute_tool returns error ToolResult without making HTTP calls."""

    @pytest.mark.asyncio
    async def test_rate_limit_exhausted_returns_error(self) -> None:
        mock_limiter = AsyncMock()
        mock_limiter.check_and_increment.return_value = False
        mock_limiter.get_reset_seconds.return_value = 42

        server = _make_server(rate_limiter=mock_limiter)

        with patch("httpx.AsyncClient.get") as mock_get:
            result = await server.execute_tool(
                "fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123"
            )
            mock_get.assert_not_called()

        assert isinstance(result, ToolResult)
        assert result.success is False
        assert "42" in result.error
        assert "rate limit" in result.error.lower()

    @pytest.mark.asyncio
    async def test_rate_limit_allowed_proceeds(self) -> None:
        mock_limiter = AsyncMock()
        mock_limiter.check_and_increment.return_value = True
        mock_limiter.update_from_headers = AsyncMock()

        server = _make_server(rate_limiter=mock_limiter)

        with patch("httpx.AsyncClient.get") as mock_get:
            mock_get.return_value = _mock_http_response(200, {"summary": {}})
            result = await server.execute_tool(
                "fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123"
            )

        assert result.success is True
        mock_limiter.check_and_increment.assert_called_once_with("user-123")


# ---------------------------------------------------------------------------
# execute_tool — missing token
# ---------------------------------------------------------------------------

class TestMissingToken:
    """execute_tool returns an error when no Fitbit token exists."""

    @pytest.mark.asyncio
    async def test_no_token_returns_error(self) -> None:
        server = _make_server(token=None)

        with patch("httpx.AsyncClient.get") as mock_get:
            result = await server.execute_tool(
                "fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123"
            )
            mock_get.assert_not_called()

        assert result.success is False
        assert "token" in result.error.lower() or "connect" in result.error.lower()


# ---------------------------------------------------------------------------
# execute_tool — unknown tool
# ---------------------------------------------------------------------------

class TestUnknownTool:
    """execute_tool returns an error for unrecognised tool names."""

    @pytest.mark.asyncio
    async def test_unknown_tool_returns_error(self) -> None:
        server = _make_server()

        with patch("httpx.AsyncClient.get"):
            result = await server.execute_tool("bogus_tool", {"date": "2026-02-28"}, "user-123")

        assert result.success is False
        assert "bogus_tool" in result.error or "Unknown" in result.error


# ---------------------------------------------------------------------------
# execute_tool — successful responses
# ---------------------------------------------------------------------------

class TestSuccessfulResponses:
    """execute_tool returns ToolResult(success=True) on 200 responses."""

    @pytest.mark.asyncio
    @pytest.mark.parametrize("tool_name,params", [
        ("fitbit_get_daily_activity", {"date": "2026-02-28"}),
        ("fitbit_get_activity_timeseries", {"resource": "steps", "start_date": "2026-02-01", "end_date": "2026-02-28"}),
        ("fitbit_get_heart_rate", {"date": "2026-02-28"}),
        ("fitbit_get_heart_rate_intraday", {"date": "2026-02-28"}),
        ("fitbit_get_hrv", {"date": "2026-02-28"}),
        ("fitbit_get_sleep", {"date": "2026-02-28"}),
        ("fitbit_get_spo2", {"date": "2026-02-28"}),
        ("fitbit_get_breathing_rate", {"date": "2026-02-28"}),
        ("fitbit_get_temperature", {"date": "2026-02-28"}),
        ("fitbit_get_vo2max", {"date": "2026-02-28"}),
        ("fitbit_get_weight", {"date": "2026-02-28"}),
        ("fitbit_get_nutrition", {"date": "2026-02-28"}),
    ])
    async def test_success_response_for_each_tool(self, tool_name: str, params: dict) -> None:
        server = _make_server()
        mock_data = {"tool": tool_name, "date": "2026-02-28"}

        with patch("httpx.AsyncClient.get") as mock_get:
            mock_get.return_value = _mock_http_response(200, mock_data)
            result = await server.execute_tool(tool_name, params, "user-123")

        assert isinstance(result, ToolResult)
        assert result.success is True
        assert result.data == mock_data
        assert result.error is None

    @pytest.mark.asyncio
    async def test_correct_url_built_for_daily_activity(self) -> None:
        server = _make_server()

        with patch("httpx.AsyncClient.get") as mock_get:
            mock_get.return_value = _mock_http_response(200, {"summary": {}})
            await server.execute_tool("fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123")

        args, kwargs = mock_get.call_args
        assert args[0] == f"{_FITBIT_API_BASE}/1/user/-/activities/date/2026-02-28.json"
        assert kwargs["headers"]["Authorization"] == "Bearer fake-token"

    @pytest.mark.asyncio
    async def test_correct_url_built_for_sleep(self) -> None:
        server = _make_server()

        with patch("httpx.AsyncClient.get") as mock_get:
            mock_get.return_value = _mock_http_response(200, {"sleep": []})
            await server.execute_tool("fitbit_get_sleep", {"date": "2026-02-28"}, "user-123")

        args, _ = mock_get.call_args
        assert args[0] == f"{_FITBIT_API_BASE}/1.2/user/-/sleep/date/2026-02-28.json"

    @pytest.mark.asyncio
    async def test_correct_url_built_for_sleep_range(self) -> None:
        server = _make_server()

        with patch("httpx.AsyncClient.get") as mock_get:
            mock_get.return_value = _mock_http_response(200, {"sleep": []})
            await server.execute_tool(
                "fitbit_get_sleep",
                {"date": "2026-02-01", "end_date": "2026-02-28"},
                "user-123",
            )

        args, _ = mock_get.call_args
        assert args[0] == f"{_FITBIT_API_BASE}/1.2/user/-/sleep/date/2026-02-01/2026-02-28.json"


# ---------------------------------------------------------------------------
# execute_tool — 401 refresh flow
# ---------------------------------------------------------------------------

class TestTokenRefreshFlow:
    """401 responses trigger one token refresh, then retry the request."""

    @pytest.mark.asyncio
    async def test_401_triggers_refresh_and_retry_succeeds(self) -> None:
        mock_token_service = AsyncMock()
        mock_token_service.get_access_token.return_value = "stale-token"

        mock_integration = MagicMock()
        mock_token_service.get_integration.return_value = mock_integration
        mock_token_service.refresh_access_token.return_value = "fresh-token"

        mock_db = AsyncMock()
        mock_db_ctx = AsyncMock()
        mock_db_ctx.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db_ctx.__aexit__ = AsyncMock(return_value=False)

        server = FitbitServer(
            token_service=mock_token_service,
            db_factory=lambda: mock_db_ctx,
            rate_limiter=None,
        )

        call_count = 0

        def side_effect(url, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                # First call → 401
                return _mock_http_response(401)
            # Second call (retry with fresh token) → 200
            return _mock_http_response(200, {"summary": {}})

        with patch("httpx.AsyncClient.get", side_effect=side_effect):
            result = await server.execute_tool(
                "fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123"
            )

        assert result.success is True
        assert call_count == 2
        mock_token_service.refresh_access_token.assert_called_once_with(mock_db, mock_integration)

    @pytest.mark.asyncio
    async def test_401_no_integration_returns_error(self) -> None:
        mock_token_service = AsyncMock()
        mock_token_service.get_access_token.return_value = "stale-token"
        mock_token_service.get_integration.return_value = None

        mock_db = AsyncMock()
        mock_db_ctx = AsyncMock()
        mock_db_ctx.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db_ctx.__aexit__ = AsyncMock(return_value=False)

        server = FitbitServer(
            token_service=mock_token_service,
            db_factory=lambda: mock_db_ctx,
            rate_limiter=None,
        )

        with patch("httpx.AsyncClient.get") as mock_get:
            mock_get.return_value = _mock_http_response(401)
            result = await server.execute_tool(
                "fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123"
            )

        assert result.success is False
        assert result.error is not None

    @pytest.mark.asyncio
    async def test_401_refresh_fails_returns_error(self) -> None:
        mock_token_service = AsyncMock()
        mock_token_service.get_access_token.return_value = "stale-token"
        mock_token_service.get_integration.return_value = MagicMock()
        mock_token_service.refresh_access_token.return_value = None  # refresh failed

        mock_db = AsyncMock()
        mock_db_ctx = AsyncMock()
        mock_db_ctx.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db_ctx.__aexit__ = AsyncMock(return_value=False)

        server = FitbitServer(
            token_service=mock_token_service,
            db_factory=lambda: mock_db_ctx,
            rate_limiter=None,
        )

        with patch("httpx.AsyncClient.get") as mock_get:
            mock_get.return_value = _mock_http_response(401)
            result = await server.execute_tool(
                "fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123"
            )

        assert result.success is False
        assert "refresh" in result.error.lower() or "expired" in result.error.lower()

    @pytest.mark.asyncio
    async def test_401_no_infinite_loop_on_retry(self) -> None:
        """Second 401 (after refresh) does NOT trigger another refresh."""
        mock_token_service = AsyncMock()
        mock_token_service.get_access_token.return_value = "stale-token"
        mock_token_service.get_integration.return_value = MagicMock()
        mock_token_service.refresh_access_token.return_value = "fresh-token"

        mock_db = AsyncMock()
        mock_db_ctx = AsyncMock()
        mock_db_ctx.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db_ctx.__aexit__ = AsyncMock(return_value=False)

        server = FitbitServer(
            token_service=mock_token_service,
            db_factory=lambda: mock_db_ctx,
            rate_limiter=None,
        )

        call_count = 0

        def always_401(url, **kwargs):
            nonlocal call_count
            call_count += 1
            return _mock_http_response(401)

        with patch("httpx.AsyncClient.get", side_effect=always_401):
            result = await server.execute_tool(
                "fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123"
            )

        # Should make exactly 2 calls (original + one retry), not loop forever
        assert call_count == 2
        assert result.success is False


# ---------------------------------------------------------------------------
# execute_tool — 429 rate limit from Fitbit server
# ---------------------------------------------------------------------------

class TestFitbitServerRateLimitResponse:
    """429 from Fitbit API returns error ToolResult."""

    @pytest.mark.asyncio
    async def test_429_returns_rate_limit_error(self) -> None:
        server = _make_server()

        with patch("httpx.AsyncClient.get") as mock_get:
            mock_get.return_value = _mock_http_response(
                429,
                headers={"Retry-After": "60"},
            )
            result = await server.execute_tool(
                "fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123"
            )

        assert result.success is False
        assert "rate limit" in result.error.lower() or "429" in result.error or "60" in result.error

    @pytest.mark.asyncio
    async def test_429_without_retry_after_header(self) -> None:
        server = _make_server()

        with patch("httpx.AsyncClient.get") as mock_get:
            mock_get.return_value = _mock_http_response(429)
            result = await server.execute_tool(
                "fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123"
            )

        assert result.success is False
        assert result.error is not None


# ---------------------------------------------------------------------------
# execute_tool — generic non-200 errors
# ---------------------------------------------------------------------------

class TestGenericErrorResponses:
    """Non-200/401/429 status codes return error ToolResult."""

    @pytest.mark.asyncio
    @pytest.mark.parametrize("status_code", [400, 403, 404, 500, 503])
    async def test_non_200_returns_error(self, status_code: int) -> None:
        server = _make_server()

        with patch("httpx.AsyncClient.get") as mock_get:
            mock_get.return_value = _mock_http_response(status_code)
            result = await server.execute_tool(
                "fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123"
            )

        assert result.success is False
        assert str(status_code) in result.error


# ---------------------------------------------------------------------------
# execute_tool — network errors
# ---------------------------------------------------------------------------

class TestNetworkErrors:
    """Network-level failures return error ToolResult without raising."""

    @pytest.mark.asyncio
    async def test_request_error_returns_error(self) -> None:
        server = _make_server()

        with patch("httpx.AsyncClient.get", side_effect=httpx.RequestError("Connection refused")):
            result = await server.execute_tool(
                "fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123"
            )

        assert result.success is False
        assert "Network error" in result.error


# ---------------------------------------------------------------------------
# execute_tool — rate limiter header update
# ---------------------------------------------------------------------------

class TestRateLimiterHeaderUpdate:
    """Rate limiter is updated from response headers after a 200."""

    @pytest.mark.asyncio
    async def test_update_from_headers_called_on_success(self) -> None:
        mock_limiter = AsyncMock()
        mock_limiter.check_and_increment.return_value = True
        mock_limiter.update_from_headers = AsyncMock()

        server = _make_server(rate_limiter=mock_limiter)

        with patch("httpx.AsyncClient.get") as mock_get:
            mock_get.return_value = _mock_http_response(
                200,
                {"summary": {}},
                headers={
                    "Fitbit-Rate-Limit-Remaining": "148",
                    "Fitbit-Rate-Limit-Reset": "3500",
                },
            )
            await server.execute_tool("fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123")

        mock_limiter.update_from_headers.assert_called_once_with("user-123", 148, 3500)

    @pytest.mark.asyncio
    async def test_update_from_headers_not_called_on_error(self) -> None:
        mock_limiter = AsyncMock()
        mock_limiter.check_and_increment.return_value = True
        mock_limiter.update_from_headers = AsyncMock()

        server = _make_server(rate_limiter=mock_limiter)

        with patch("httpx.AsyncClient.get") as mock_get:
            mock_get.return_value = _mock_http_response(500)
            await server.execute_tool("fitbit_get_daily_activity", {"date": "2026-02-28"}, "user-123")

        mock_limiter.update_from_headers.assert_not_called()


# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------

class TestFitbitServerResources:
    """Tests for resource listing."""

    @pytest.mark.asyncio
    async def test_get_resources_returns_list(self) -> None:
        resources = await _make_server().get_resources("user-123")
        assert isinstance(resources, list)
        assert all(isinstance(r, Resource) for r in resources)

    @pytest.mark.asyncio
    async def test_resource_uri_contains_fitbit(self) -> None:
        resources = await _make_server().get_resources("user-123")
        assert len(resources) >= 1
        assert any("fitbit" in r.uri for r in resources)


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

class TestFitbitServerHealthCheck:
    """Tests for health_check."""

    @pytest.mark.asyncio
    async def test_health_check_true_on_reachable_api(self) -> None:
        server = _make_server()

        with patch("httpx.AsyncClient.head") as mock_head:
            mock_head.return_value = _mock_http_response(200)
            result = await server.health_check()

        assert result is True

    @pytest.mark.asyncio
    async def test_health_check_false_on_network_error(self) -> None:
        server = _make_server()

        with patch("httpx.AsyncClient.head", side_effect=httpx.RequestError("Timeout")):
            result = await server.health_check()

        assert result is False

    @pytest.mark.asyncio
    async def test_health_check_false_on_5xx(self) -> None:
        server = _make_server()

        with patch("httpx.AsyncClient.head") as mock_head:
            mock_head.return_value = _mock_http_response(500)
            result = await server.health_check()

        assert result is False

    @pytest.mark.asyncio
    async def test_health_check_false_on_4xx(self) -> None:
        # 4xx should now return False since we only accept 2xx/3xx
        server = _make_server()

        with patch("httpx.AsyncClient.head") as mock_head:
            mock_head.return_value = _mock_http_response(401)
            result = await server.health_check()

        assert result is False

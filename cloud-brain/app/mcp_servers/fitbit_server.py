"""
Zuralog Cloud Brain — Fitbit MCP Server (Phase 5.1).

Wraps 12 Fitbit API endpoints so the LLM agent can query health metrics:
activity summaries, heart rate (daily + intraday), HRV, sleep stages, SpO2,
breathing rate, skin temperature, VO2 max, weight logs, and nutrition.

Token storage is backed by the database via ``FitbitTokenService``.
Per-user rate limiting is enforced via ``FitbitRateLimiter`` (150 req/hr).
On 401 responses, the token is refreshed once and the request is retried.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from typing import Any

import httpx

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult
from app.services.fitbit_rate_limiter import FitbitRateLimiter
from app.services.fitbit_token_service import FitbitTokenService

logger = logging.getLogger(__name__)

_FITBIT_API_BASE = "https://api.fitbit.com"


class FitbitServer(BaseMCPServer):
    """MCP server for Fitbit health data queries.

    Exposes 12 tools covering activity, heart rate, sleep, and biometric
    data.  All requests require a valid Fitbit access token retrieved from
    the database via ``FitbitTokenService``.

    Per-user API rate limiting (150 req/hr) is enforced by
    ``FitbitRateLimiter`` before each HTTP call.  On a 401 response the
    token is refreshed once and the request is retried automatically.

    Args:
        token_service: DB-backed ``FitbitTokenService`` for token retrieval
            and refresh.
        db_factory: Callable that returns an async context manager yielding
            an ``AsyncSession`` (e.g. ``async_session`` from
            ``app.database``).
        rate_limiter: Redis-backed ``FitbitRateLimiter`` instance.  Pass
            ``None`` to disable rate limiting (e.g. in unit tests).
    """

    def __init__(
        self,
        token_service: FitbitTokenService,
        db_factory: Callable[[], Any],
        rate_limiter: FitbitRateLimiter | None = None,
    ) -> None:
        """Initialise the Fitbit MCP server.

        Args:
            token_service: Fitbit token lifecycle manager.
            db_factory: Async database session factory.
            rate_limiter: Optional per-user rate limiter.
        """
        self._token_service = token_service
        self._db_factory = db_factory
        self._rate_limiter = rate_limiter

    # ------------------------------------------------------------------
    # BaseMCPServer properties
    # ------------------------------------------------------------------

    @property
    def name(self) -> str:
        """Unique identifier used by the MCP registry.

        Returns:
            The string ``"fitbit"``.
        """
        return "fitbit"

    @property
    def description(self) -> str:
        """Human-readable capability summary surfaced to the LLM.

        Returns:
            A description of Fitbit health-data capabilities.
        """
        return (
            "Query Fitbit health data including: daily activity summaries "
            "(steps, calories, active minutes, floors), activity time-series, "
            "heart rate (daily zones + intraday), HRV (RMSSD), detailed sleep "
            "stages (light/deep/REM/wake) with efficiency scores, SpO2 (blood "
            "oxygen), breathing rate, skin temperature, VO2 max (cardio fitness "
            "score), weight & body composition logs, and food/water nutrition logs."
        )

    # ------------------------------------------------------------------
    # Tool definitions
    # ------------------------------------------------------------------

    def get_tools(self) -> list[ToolDefinition]:
        """Return the 12 Fitbit tools the LLM may invoke.

        Returns:
            A list of 12 ``ToolDefinition`` models covering all major
            Fitbit API data types.
        """
        return [
            ToolDefinition(
                name="fitbit_get_daily_activity",
                description=(
                    "Get a Fitbit user's daily activity summary including steps, "
                    "distance, calories burned, active minutes, floors climbed, "
                    "and elevation for a specific date."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "date": {
                            "type": "string",
                            "description": "Date in YYYY-MM-DD format. Use 'today' for current date.",
                            "pattern": r"^(\d{4}-\d{2}-\d{2}|today)$",
                        },
                    },
                    "required": ["date"],
                },
            ),
            ToolDefinition(
                name="fitbit_get_activity_timeseries",
                description="Get time series data for a specific activity metric over a date range.",
                input_schema={
                    "type": "object",
                    "properties": {
                        "resource": {
                            "type": "string",
                            "enum": [
                                "steps",
                                "distance",
                                "calories",
                                "minutesSedentary",
                                "minutesLightlyActive",
                                "minutesFairlyActive",
                                "minutesVeryActive",
                                "elevation",
                                "floors",
                            ],
                            "description": "The activity metric to retrieve",
                        },
                        "start_date": {
                            "type": "string",
                            "description": "Start date in YYYY-MM-DD format",
                        },
                        "end_date": {
                            "type": "string",
                            "description": "End date in YYYY-MM-DD format. Max 1095 days from start.",
                        },
                    },
                    "required": ["resource", "start_date", "end_date"],
                },
            ),
            ToolDefinition(
                name="fitbit_get_heart_rate",
                description=(
                    "Get heart rate data including resting heart rate, HR zones "
                    "(Out of Range, Fat Burn, Cardio, Peak) with time-in-zone and "
                    "calories burned per zone."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "date": {
                            "type": "string",
                            "description": "Date in YYYY-MM-DD format",
                        },
                        "period": {
                            "type": "string",
                            "enum": ["1d", "7d", "30d", "1w", "1m"],
                            "description": "Time period. Default: 1d",
                        },
                    },
                    "required": ["date"],
                },
            ),
            ToolDefinition(
                name="fitbit_get_heart_rate_intraday",
                description="Get intraday (second or minute level) heart rate data.",
                input_schema={
                    "type": "object",
                    "properties": {
                        "date": {
                            "type": "string",
                            "description": "Date in YYYY-MM-DD format",
                        },
                        "detail_level": {
                            "type": "string",
                            "enum": ["1sec", "1min", "5min", "15min"],
                            "description": "Granularity. Default: 1min",
                        },
                        "start_time": {
                            "type": "string",
                            "description": "Optional start time HH:mm",
                        },
                        "end_time": {
                            "type": "string",
                            "description": "Optional end time HH:mm",
                        },
                    },
                    "required": ["date"],
                },
            ),
            ToolDefinition(
                name="fitbit_get_hrv",
                description="Get Heart Rate Variability (HRV) data as RMSSD during sleep.",
                input_schema={
                    "type": "object",
                    "properties": {
                        "date": {
                            "type": "string",
                            "description": "Date in YYYY-MM-DD format",
                        },
                        "end_date": {
                            "type": "string",
                            "description": "Optional end date for range query",
                        },
                    },
                    "required": ["date"],
                },
            ),
            ToolDefinition(
                name="fitbit_get_sleep",
                description=(
                    "Get detailed sleep log including sleep stages (light, deep, REM, wake), "
                    "duration, efficiency score, and 30-day rolling averages."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "date": {
                            "type": "string",
                            "description": "Date in YYYY-MM-DD format",
                        },
                        "end_date": {
                            "type": "string",
                            "description": "Optional end date for range (max 100 days)",
                        },
                    },
                    "required": ["date"],
                },
            ),
            ToolDefinition(
                name="fitbit_get_spo2",
                description=(
                    "Get blood oxygen saturation (SpO2) readings measured during sleep. "
                    "Returns average, minimum, and maximum SpO2 percentage."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "date": {
                            "type": "string",
                            "description": "Date in YYYY-MM-DD format",
                        },
                        "end_date": {
                            "type": "string",
                            "description": "Optional end date for range query",
                        },
                    },
                    "required": ["date"],
                },
            ),
            ToolDefinition(
                name="fitbit_get_breathing_rate",
                description="Get average breathing rate (breaths per minute) measured during sleep.",
                input_schema={
                    "type": "object",
                    "properties": {
                        "date": {
                            "type": "string",
                            "description": "Date in YYYY-MM-DD format",
                        },
                        "end_date": {
                            "type": "string",
                            "description": "Optional end date for range query",
                        },
                    },
                    "required": ["date"],
                },
            ),
            ToolDefinition(
                name="fitbit_get_temperature",
                description=(
                    "Get skin temperature data measured during sleep. "
                    "Reported as deviation from personal baseline."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "date": {
                            "type": "string",
                            "description": "Date in YYYY-MM-DD format",
                        },
                        "end_date": {
                            "type": "string",
                            "description": "Optional end date for range query",
                        },
                    },
                    "required": ["date"],
                },
            ),
            ToolDefinition(
                name="fitbit_get_vo2max",
                description="Get estimated VO2 Max (cardio fitness score).",
                input_schema={
                    "type": "object",
                    "properties": {
                        "date": {
                            "type": "string",
                            "description": "Date in YYYY-MM-DD format",
                        },
                        "end_date": {
                            "type": "string",
                            "description": "Optional end date for range query",
                        },
                    },
                    "required": ["date"],
                },
            ),
            ToolDefinition(
                name="fitbit_get_weight",
                description="Get weight logs including weight, body fat percentage, and BMI.",
                input_schema={
                    "type": "object",
                    "properties": {
                        "date": {
                            "type": "string",
                            "description": "Date in YYYY-MM-DD format",
                        },
                        "end_date": {
                            "type": "string",
                            "description": "Optional end date for range (max 31 days)",
                        },
                    },
                    "required": ["date"],
                },
            ),
            ToolDefinition(
                name="fitbit_get_nutrition",
                description=(
                    "Get food and water logs including calories consumed, "
                    "macronutrients, and water intake."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "date": {
                            "type": "string",
                            "description": "Date in YYYY-MM-DD format",
                        },
                    },
                    "required": ["date"],
                },
            ),
        ]

    # ------------------------------------------------------------------
    # Tool execution
    # ------------------------------------------------------------------

    async def execute_tool(
        self,
        tool_name: str,
        params: dict,
        user_id: str,
    ) -> ToolResult:
        """Execute a Fitbit tool on behalf of the given user.

        Execution flow:
        1. Check per-user rate limit; return error if exhausted.
        2. Resolve token from DB via ``FitbitTokenService``.
        3. Dispatch to the appropriate private handler.
        4. On 401, refresh token once and retry.
        5. Update rate limiter from response headers.

        Args:
            tool_name: One of the 12 fitbit_* tool names.
            params: Parameter dict matching the tool's ``input_schema``.
            user_id: Authenticated user whose Fitbit token to use.

        Returns:
            A ``ToolResult`` with Fitbit data on success, or an error
            result when rate-limited, unauthorised, or the API fails.
        """
        # 1. Rate limit check
        if self._rate_limiter is not None:
            allowed = await self._rate_limiter.check_and_increment(user_id)
            if not allowed:
                reset_secs = await self._rate_limiter.get_reset_seconds(user_id)
                return ToolResult(
                    success=False,
                    data=None,
                    error=f"Fitbit rate limit reached. Try again in {reset_secs}s.",
                )

        # 2. Resolve token from DB
        async with self._db_factory() as db:
            token = await self._token_service.get_access_token(db, user_id)

        if not token:
            return ToolResult(
                success=False,
                data=None,
                error="No Fitbit access token available. Please connect your Fitbit account first.",
            )

        # 3. Build path and dispatch
        path = self._build_path(tool_name, params)
        if path is None:
            return ToolResult(success=False, data=None, error=f"Unknown tool: {tool_name}")

        return await self._call_fitbit(path, token, user_id)

    # ------------------------------------------------------------------
    # Path building
    # ------------------------------------------------------------------

    def _build_path(self, tool_name: str, params: dict) -> str | None:
        """Construct the Fitbit API path for the given tool and params.

        Args:
            tool_name: Name of the tool to dispatch.
            params: Tool parameters from the LLM.

        Returns:
            The URL path string (without base URL), or ``None`` if the
            tool name is unknown.
        """
        date = params.get("date", "today")
        end_date = params.get("end_date")

        if tool_name == "fitbit_get_daily_activity":
            return f"/1/user/-/activities/date/{date}.json"

        if tool_name == "fitbit_get_activity_timeseries":
            resource = params["resource"]
            start = params["start_date"]
            end = params["end_date"]
            return f"/1/user/-/activities/{resource}/date/{start}/{end}.json"

        if tool_name == "fitbit_get_heart_rate":
            period = params.get("period", "1d")
            return f"/1/user/-/activities/heart/date/{date}/{period}.json"

        if tool_name == "fitbit_get_heart_rate_intraday":
            detail = params.get("detail_level", "1min")
            start_time = params.get("start_time")
            end_time = params.get("end_time")
            base = f"/1/user/-/activities/heart/date/{date}/1d/{detail}"
            if start_time and end_time:
                return f"{base}/time/{start_time}/{end_time}.json"
            return f"{base}.json"

        if tool_name == "fitbit_get_hrv":
            if end_date:
                return f"/1/user/-/hrv/date/{date}/{end_date}.json"
            return f"/1/user/-/hrv/date/{date}.json"

        if tool_name == "fitbit_get_sleep":
            if end_date:
                return f"/1.2/user/-/sleep/date/{date}/{end_date}.json"
            return f"/1.2/user/-/sleep/date/{date}.json"

        if tool_name == "fitbit_get_spo2":
            if end_date:
                return f"/1/user/-/spo2/date/{date}/{end_date}.json"
            return f"/1/user/-/spo2/date/{date}.json"

        if tool_name == "fitbit_get_breathing_rate":
            if end_date:
                return f"/1/user/-/br/date/{date}/{end_date}.json"
            return f"/1/user/-/br/date/{date}.json"

        if tool_name == "fitbit_get_temperature":
            if end_date:
                return f"/1/user/-/temp/skin/date/{date}/{end_date}.json"
            return f"/1/user/-/temp/skin/date/{date}.json"

        if tool_name == "fitbit_get_vo2max":
            if end_date:
                return f"/1/user/-/cardioscore/date/{date}/{end_date}.json"
            return f"/1/user/-/cardioscore/date/{date}.json"

        if tool_name == "fitbit_get_weight":
            if end_date:
                return f"/1/user/-/body/log/weight/date/{date}/{end_date}.json"
            return f"/1/user/-/body/log/weight/date/{date}.json"

        if tool_name == "fitbit_get_nutrition":
            return f"/1/user/-/foods/log/date/{date}.json"

        return None

    # ------------------------------------------------------------------
    # HTTP helper
    # ------------------------------------------------------------------

    async def _call_fitbit(
        self,
        path: str,
        token: str,
        user_id: str,
        *,
        _retry: bool = True,
    ) -> ToolResult:
        """Make a GET request to the Fitbit API.

        Handles 401 (one token refresh + retry), 429 (rate limit error),
        and updates the rate limiter from response headers on success.

        Args:
            path: API path (e.g. ``/1/user/-/activities/date/today.json``).
            token: Current Fitbit Bearer access token.
            user_id: Zuralog user ID (for rate limiter updates and token refresh).
            _retry: Internal flag — set to ``False`` on the retry to prevent
                infinite refresh loops.

        Returns:
            ``ToolResult(success=True, data=<response JSON>)`` on success,
            or a failed ``ToolResult`` on error.
        """
        url = f"{_FITBIT_API_BASE}{path}"
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.get(
                    url,
                    headers={"Authorization": f"Bearer {token}"},
                )
        except httpx.RequestError as exc:
            return ToolResult(success=False, data=None, error=f"Network error: {exc}")

        # 401 → refresh token once and retry
        if resp.status_code == 401 and _retry:
            logger.info(
                "Fitbit 401 for user '%s' — attempting token refresh", user_id
            )
            async with self._db_factory() as db:
                integration = await self._token_service.get_integration(db, user_id)
                if integration is None:
                    return ToolResult(
                        success=False,
                        data=None,
                        error="Fitbit token expired and no integration found. Please reconnect.",
                    )
                new_token = await self._token_service.refresh_access_token(db, integration)

            if not new_token:
                return ToolResult(
                    success=False,
                    data=None,
                    error="Fitbit access token expired and refresh failed. Please reconnect your Fitbit account.",
                )
            return await self._call_fitbit(path, new_token, user_id, _retry=False)

        # 429 → rate limited by Fitbit server
        if resp.status_code == 429:
            retry_after = resp.headers.get("Retry-After", "unknown")
            return ToolResult(
                success=False,
                data=None,
                error=f"Rate limited by Fitbit. Try again in {retry_after}s.",
            )

        # Non-200 generic error
        if resp.status_code != 200:
            return ToolResult(
                success=False,
                data=None,
                error=f"Fitbit API error {resp.status_code}: {resp.text}",
            )

        # Update rate limiter from authoritative headers (best-effort)
        if self._rate_limiter is not None:
            try:
                remaining = int(resp.headers.get("Fitbit-Rate-Limit-Remaining", 0))
                reset_secs = int(resp.headers.get("Fitbit-Rate-Limit-Reset", 3600))
                await self._rate_limiter.update_from_headers(user_id, remaining, reset_secs)
            except (ValueError, TypeError):
                pass  # headers absent or malformed — silently skip

        return ToolResult(success=True, data=resp.json())

    # ------------------------------------------------------------------
    # Resources
    # ------------------------------------------------------------------

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return a description of resources available for the LLM's context.

        Args:
            user_id: The authenticated user (unused — same resource set for all).

        Returns:
            A list with one ``Resource`` describing Fitbit health data.
        """
        return [
            Resource(
                uri="fitbit://health/data",
                name="Fitbit Health Data",
                description=(
                    "Daily activity, heart rate, sleep stages, SpO2, HRV, "
                    "breathing rate, temperature, VO2 max, weight, and nutrition "
                    "data from the user's Fitbit account."
                ),
            )
        ]

    # ------------------------------------------------------------------
    # Health check
    # ------------------------------------------------------------------

    async def health_check(self) -> bool:
        """Verify Fitbit API base connectivity with a lightweight probe.

        Sends a HEAD request to the Fitbit API base URL. Returns ``True``
        on any HTTP response (the service is reachable), ``False`` on
        network errors.

        Returns:
            ``True`` if the Fitbit API is reachable, ``False`` otherwise.
        """
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.head(_FITBIT_API_BASE)
            return resp.status_code in range(200, 400)
        except httpx.RequestError:
            return False

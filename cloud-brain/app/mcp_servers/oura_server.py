"""
Zuralog Cloud Brain — Oura Ring MCP Server.

Wraps 16 Oura API v2 endpoints so the LLM agent can query health metrics:
daily sleep scores, detailed sleep stages, daily activity, readiness scores,
continuous heart rate, SpO2, stress, workouts, sessions, resilience,
cardiovascular age, VO2 max, sleep timing, tags, rest mode periods, and
ring configuration.

Token storage is backed by the database via ``OuraTokenService``.
On 401 responses, the token is refreshed once and the request is retried.
Supports Oura sandbox mode for development/testing.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from typing import Any

import httpx

from app.config import settings
from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult
from app.services.oura_token_service import OuraTokenService

logger = logging.getLogger(__name__)

_OURA_API_BASE = "https://api.ouraring.com"
_MAX_PAGES = 5  # Maximum pages to fetch during auto-pagination


class OuraServer(BaseMCPServer):
    """MCP server for Oura Ring health data queries.

    Exposes 16 tools covering sleep, activity, readiness, heart rate,
    SpO2, stress, workouts, sessions, and more. All requests require a
    valid Oura access token retrieved from the database via
    ``OuraTokenService``.

    Supports Oura sandbox mode when ``settings.oura_use_sandbox`` is True,
    which substitutes ``/v2/usercollection/`` with
    ``/v2/sandbox/usercollection/`` in all endpoint paths.

    On a 401 response the token is refreshed once and the request is
    retried automatically (Oura issues single-use refresh tokens).

    Auto-pagination: if ``next_token`` is present in the response,
    follow-up requests are made (up to ``_MAX_PAGES``) and all ``data``
    arrays are aggregated into a single result.

    Args:
        token_service: DB-backed ``OuraTokenService`` for token retrieval
            and refresh.
        db_factory: Callable that returns an async context manager yielding
            an ``AsyncSession`` (e.g. ``async_session`` from
            ``app.database``).
    """

    def __init__(
        self,
        token_service: OuraTokenService,
        db_factory: Callable[[], Any],
    ) -> None:
        self._token_service = token_service
        self._db_factory = db_factory

    # ------------------------------------------------------------------
    # BaseMCPServer properties
    # ------------------------------------------------------------------

    @property
    def name(self) -> str:
        """Unique identifier used by the MCP registry.

        Returns:
            The string ``"oura"``.
        """
        return "oura"

    @property
    def description(self) -> str:
        """Human-readable capability summary surfaced to the LLM.

        Returns:
            A description of Oura Ring health-data capabilities.
        """
        return (
            "Query Oura Ring health data including: daily sleep scores "
            "(readiness contribution, efficiency, latency, timing), detailed "
            "sleep stage breakdowns (REM/deep/light/awake with timing and "
            "heart rate/HRV data), daily activity summaries (steps, calories, "
            "active/rest calories, equivalent walking distance, inactivity alerts), "
            "daily readiness scores (contributors: sleep balance, resting heart "
            "rate, recovery index, body temperature deviation), continuous heart "
            "rate (minute-level time series with start/end datetime range), daily "
            "SpO2 averages measured during sleep, daily stress levels and recovery "
            "state, workout sessions with distance/duration/intensity, guided "
            "session logs (meditation, breathing, yoga), daily resilience scores "
            "(daytime/sleep recovery breakdown), cardiovascular age estimates, "
            "VO2 max estimates, optimal sleep timing windows, personal tags and "
            "custom notes, rest mode period logs, and ring configuration details "
            "(color, design, hardware/firmware version, set-up state)."
        )

    # ------------------------------------------------------------------
    # Tool definitions
    # ------------------------------------------------------------------

    def get_tools(self) -> list[ToolDefinition]:
        """Return the 16 Oura tools the LLM may invoke.

        Returns:
            A list of 16 ``ToolDefinition`` models covering all major
            Oura API v2 data types.
        """
        _date_schema = {
            "type": "object",
            "properties": {
                "date": {
                    "type": "string",
                    "description": "Start date in YYYY-MM-DD format.",
                    "pattern": r"^\d{4}-\d{2}-\d{2}$",
                },
                "end_date": {
                    "type": "string",
                    "description": "End date in YYYY-MM-DD format (optional, defaults to date).",
                    "pattern": r"^\d{4}-\d{2}-\d{2}$",
                },
            },
            "required": ["date"],
        }

        return [
            ToolDefinition(
                name="oura_get_daily_sleep",
                description=(
                    "Get Oura daily sleep scores including overall score, "
                    "efficiency, latency, restfulness, REM sleep, deep sleep, "
                    "and timing contributors. One record per night."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_sleep",
                description=(
                    "Get detailed Oura sleep session data with full stage "
                    "breakdown (light, deep, REM, awake), heart rate, HRV, "
                    "movement frequency, and per-epoch sleep stage data."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_daily_activity",
                description=(
                    "Get Oura daily activity summary including steps, calories "
                    "(active + resting), equivalent walking distance, inactivity "
                    "alerts, and meet-daily-targets score."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_daily_readiness",
                description=(
                    "Get Oura daily readiness score with contributor breakdown: "
                    "activity balance, body temperature, HRV balance, previous "
                    "day activity, previous night sleep, recovery index, resting "
                    "heart rate, and sleep balance."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_heart_rate",
                description=(
                    "Get continuous heart rate data at 1-minute granularity from "
                    "the Oura Ring. Specify a date range; timestamps are in UTC. "
                    "Useful for resting HR trends, recovery, and stress detection."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "date": {
                            "type": "string",
                            "description": "Start date in YYYY-MM-DD format.",
                            "pattern": r"^\d{4}-\d{2}-\d{2}$",
                        },
                        "end_date": {
                            "type": "string",
                            "description": "End date in YYYY-MM-DD format (optional, defaults to date).",
                            "pattern": r"^\d{4}-\d{2}-\d{2}$",
                        },
                    },
                    "required": ["date"],
                },
            ),
            ToolDefinition(
                name="oura_get_daily_spo2",
                description=(
                    "Get Oura daily SpO2 (blood oxygen saturation) averages "
                    "measured during sleep. Includes breathing disturbance index."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_daily_stress",
                description=(
                    "Get Oura daily stress level and recovery state. Includes "
                    "daytime stress, recovery, and stress high/low classification."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_workouts",
                description=(
                    "Get Oura workout session logs including activity type, "
                    "duration, intensity, calories, distance, and heart rate data."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_sessions",
                description=(
                    "Get Oura guided session logs (meditation, breathing, yoga, "
                    "nap, etc.) with duration, heart rate, and HRV data."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_daily_resilience",
                description=(
                    "Get Oura daily resilience scores showing recovery capacity "
                    "from daytime activity and sleep, with level classification."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_daily_cardiovascular_age",
                description=(
                    "Get Oura estimated cardiovascular age for each day, comparing vascular age to chronological age."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_vo2_max",
                description=(
                    "Get Oura estimated VO2 max (maximal oxygen uptake) values, "
                    "an indicator of aerobic fitness capacity."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_sleep_time",
                description=(
                    "Get Oura optimal sleep timing windows showing recommended "
                    "bedtime and wake time based on circadian rhythm analysis."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_tags",
                description=(
                    "Get Oura enhanced personal tags and custom notes logged by "
                    "the user, including text content and associated timestamps."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_rest_mode",
                description=(
                    "Get Oura rest mode period logs showing when the user "
                    "activated rest mode and associated end conditions."
                ),
                input_schema=_date_schema,
            ),
            ToolDefinition(
                name="oura_get_ring_configuration",
                description=(
                    "Get Oura Ring hardware configuration including color, design, "
                    "hardware version, firmware version, and set-up completion state."
                ),
                input_schema={
                    "type": "object",
                    "properties": {},
                    "required": [],
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
        """Execute an Oura tool on behalf of the given user.

        Execution flow:
        1. Resolve token from DB via ``OuraTokenService``.
        2. Build the endpoint path and query params.
        3. Call Oura API with auto-pagination (up to 5 pages).
        4. On 401, refresh token once and retry.
        5. Return aggregated data.

        Args:
            tool_name: One of the 16 oura_* tool names.
            params: Parameter dict matching the tool's ``input_schema``.
            user_id: Authenticated user whose Oura token to use.

        Returns:
            A ``ToolResult`` with Oura data on success, or an error
            result when unauthorised or the API fails.
        """
        # Resolve token from DB
        async with self._db_factory() as db:
            token = await self._token_service.get_access_token(db, user_id)

        if not token:
            return ToolResult(
                success=False,
                data=None,
                error="No Oura access token available. Please connect your Oura account first.",
            )

        # Build path and query params
        path, query_params = self._build_path_and_params(tool_name, params)
        if path is None:
            return ToolResult(success=False, data=None, error=f"Unknown tool: {tool_name}")

        return await self._call_oura(path, query_params, token, user_id)

    # ------------------------------------------------------------------
    # Path building
    # ------------------------------------------------------------------

    def _collection_path(self, collection: str) -> str:
        """Return the Oura API path for a collection, applying sandbox substitution.

        Args:
            collection: The collection segment (e.g. ``daily_sleep``).

        Returns:
            The full path with sandbox substitution applied if enabled.
        """
        if settings.oura_use_sandbox:
            return f"/v2/sandbox/usercollection/{collection}"
        return f"/v2/usercollection/{collection}"

    def _build_path_and_params(
        self,
        tool_name: str,
        params: dict,
    ) -> tuple[str | None, dict]:
        """Construct the Oura API path and query parameters for the given tool.

        Args:
            tool_name: Name of the tool to dispatch.
            params: Tool parameters from the LLM.

        Returns:
            A (path, query_params) tuple, or (None, {}) if tool is unknown.
        """
        date = params.get("date")
        end_date = params.get("end_date", date)  # default end_date to start date

        _TOOL_COLLECTIONS: dict[str, str] = {
            "oura_get_daily_sleep": "daily_sleep",
            "oura_get_sleep": "sleep",
            "oura_get_daily_activity": "daily_activity",
            "oura_get_daily_readiness": "daily_readiness",
            "oura_get_daily_spo2": "daily_spo2",
            "oura_get_daily_stress": "daily_stress",
            "oura_get_workouts": "workout",
            "oura_get_sessions": "session",
            "oura_get_daily_resilience": "daily_resilience",
            "oura_get_daily_cardiovascular_age": "daily_cardiovascular_age",
            "oura_get_vo2_max": "vO2_max",
            "oura_get_sleep_time": "sleep_time",
            "oura_get_tags": "enhanced_tag",
            "oura_get_rest_mode": "rest_mode_period",
        }

        if tool_name == "oura_get_ring_configuration":
            return self._collection_path("ring_configuration"), {}

        if tool_name == "oura_get_heart_rate":
            # Heart rate endpoint uses start_datetime / end_datetime (ISO 8601)
            start_datetime = f"{date}T00:00:00+00:00" if date else None
            end_datetime = f"{end_date}T23:59:59+00:00" if end_date else None
            query: dict = {}
            if start_datetime:
                query["start_datetime"] = start_datetime
            if end_datetime:
                query["end_datetime"] = end_datetime
            return self._collection_path("heartrate"), query

        if tool_name in _TOOL_COLLECTIONS:
            collection = _TOOL_COLLECTIONS[tool_name]
            query = {}
            if date:
                query["start_date"] = date
            if end_date:
                query["end_date"] = end_date
            return self._collection_path(collection), query

        return None, {}

    # ------------------------------------------------------------------
    # HTTP helper
    # ------------------------------------------------------------------

    async def _call_oura(
        self,
        path: str,
        query_params: dict,
        token: str,
        user_id: str,
        *,
        _retry: bool = True,
    ) -> ToolResult:
        """Make a GET request to the Oura API with auto-pagination.

        Handles 401 (one token refresh + retry), 429 (rate limit error),
        and auto-paginates via ``next_token`` (up to ``_MAX_PAGES``).

        Args:
            path: API path (e.g. ``/v2/usercollection/daily_sleep``).
            query_params: Query string parameters for the request.
            token: Current Oura Bearer access token.
            user_id: Zuralog user ID (for token refresh).
            _retry: Internal flag — set to ``False`` on the retry to
                prevent infinite refresh loops.

        Returns:
            ``ToolResult(success=True, data=<aggregated response>)`` on
            success, or a failed ``ToolResult`` on error.
        """
        url = f"{_OURA_API_BASE}{path}"
        all_data: list = []
        current_params = dict(query_params)

        for _page in range(_MAX_PAGES):
            try:
                async with httpx.AsyncClient(timeout=15.0) as client:
                    resp = await client.get(
                        url,
                        params=current_params,
                        headers={"Authorization": f"Bearer {token}"},
                    )
            except httpx.RequestError as exc:
                return ToolResult(success=False, data=None, error=f"Network error: {exc}")

            # 401 → refresh token once and retry the whole call
            if resp.status_code == 401 and _retry:
                logger.info("Oura 401 for user '%s' — attempting token refresh", user_id)
                async with self._db_factory() as db:
                    integration = await self._token_service.get_integration(db, user_id)
                    if integration is None:
                        return ToolResult(
                            success=False,
                            data=None,
                            error="Oura token expired and no integration found. Please reconnect.",
                        )
                    new_token = await self._token_service.refresh_access_token(db, integration)

                if not new_token:
                    return ToolResult(
                        success=False,
                        data=None,
                        error=("Oura access token expired and refresh failed. Please reconnect your Oura account."),
                    )
                return await self._call_oura(path, query_params, new_token, user_id, _retry=False)

            # 429 → rate limited by Oura
            if resp.status_code == 429:
                retry_after = resp.headers.get("Retry-After", "unknown")
                return ToolResult(
                    success=False,
                    data=None,
                    error=f"Rate limited by Oura. Try again in {retry_after}s.",
                )

            # Non-200 generic error
            if resp.status_code != 200:
                return ToolResult(
                    success=False,
                    data=None,
                    error=f"Oura API error {resp.status_code}: {resp.text}",
                )

            body = resp.json()

            # Accumulate data pages
            page_data = body.get("data", [])
            if isinstance(page_data, list):
                all_data.extend(page_data)
            else:
                # Non-list response (e.g. ring_configuration returns object list)
                all_data.append(page_data)

            # Auto-pagination via next_token
            next_token = body.get("next_token")
            if not next_token:
                break

            current_params = {**query_params, "next_token": next_token}

        # If the original response didn't have a "data" key, return raw body
        # (ring_configuration and single-object endpoints)
        if not all_data and _page == 0:  # type: ignore[possibly-undefined]
            try:
                async with httpx.AsyncClient(timeout=15.0) as client:
                    raw_resp = await client.get(
                        url,
                        params=query_params,
                        headers={"Authorization": f"Bearer {token}"},
                    )
                if raw_resp.status_code == 200:
                    return ToolResult(success=True, data=raw_resp.json())
            except httpx.RequestError:
                pass

        return ToolResult(success=True, data={"data": all_data})

    # ------------------------------------------------------------------
    # Resources
    # ------------------------------------------------------------------

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return a description of resources available for the LLM's context.

        Args:
            user_id: The authenticated user (unused — same resource set for all).

        Returns:
            A list with one ``Resource`` describing Oura Ring health data.
        """
        return [
            Resource(
                uri="oura://health/data",
                name="Oura Ring Health Data",
                description=(
                    "Daily sleep scores and stages, activity summaries, readiness "
                    "scores, continuous heart rate, SpO2, stress levels, workouts, "
                    "guided sessions, resilience, cardiovascular age, VO2 max, "
                    "sleep timing, tags, rest mode periods, and ring configuration "
                    "data from the user's Oura Ring."
                ),
            )
        ]

    # ------------------------------------------------------------------
    # Health check
    # ------------------------------------------------------------------

    async def health_check(self) -> bool:
        """Verify Oura API base connectivity with a lightweight probe.

        Sends a HEAD request to the Oura API base URL. Returns ``True``
        on any HTTP response (the service is reachable), ``False`` on
        network errors.

        Returns:
            ``True`` if the Oura API is reachable, ``False`` otherwise.
        """
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.head(_OURA_API_BASE)
            return resp.status_code in range(200, 400)
        except httpx.RequestError:
            return False

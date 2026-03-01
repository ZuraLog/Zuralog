"""
Zuralog Cloud Brain — Polar AccessLink MCP Server.

Provides AI agent access to Polar health and fitness data via 14 tools
covering exercises, daily activity, continuous heart rate, sleep, nightly
recharge, cardio load, SleepWise alertness/bedtime, body temperature, and
physical information from Polar watches and sensors.

Architecture:
- Subclasses BaseMCPServer (same pattern as OuraServer, WithingsServer)
- All endpoints use GET with Bearer token
- Rate limiting via PolarRateLimiter (optional)
- No refresh tokens — expired tokens return a re-auth error
- 204/404 responses treated as "no data" (not errors)
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from typing import Any

import httpx

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult

logger = logging.getLogger(__name__)

POLAR_API_BASE = "https://www.polaraccesslink.com"

# ---------------------------------------------------------------------------
# Input schemas
# ---------------------------------------------------------------------------

_DATE_SCHEMA = {
    "type": "object",
    "properties": {
        "date": {"type": "string", "description": "Date in YYYY-MM-DD format"},
    },
    "required": ["date"],
}

_DATE_RANGE_SCHEMA = {
    "type": "object",
    "properties": {
        "date": {"type": "string", "description": "Start date in YYYY-MM-DD format"},
        "end_date": {"type": "string", "description": "End date in YYYY-MM-DD format (optional)"},
    },
    "required": ["date"],
}

_EXERCISE_ID_SCHEMA = {
    "type": "object",
    "properties": {
        "exercise_id": {"type": "string", "description": "Hashed exercise ID from Polar"},
        "include_samples": {"type": "boolean", "description": "Include heart rate/GPS samples (default: false)"},
        "include_zones": {"type": "boolean", "description": "Include HR zone data (default: false)"},
    },
    "required": ["exercise_id"],
}

_EXERCISES_LIST_SCHEMA = {
    "type": "object",
    "properties": {
        "include_samples": {"type": "boolean", "description": "Include heart rate/GPS samples (default: false)"},
        "include_zones": {"type": "boolean", "description": "Include HR zone data (default: false)"},
    },
    "required": [],
}

_NO_PARAMS_SCHEMA = {"type": "object", "properties": {}, "required": []}

# ---------------------------------------------------------------------------
# Tool descriptions
# ---------------------------------------------------------------------------

_TOOL_DESCRIPTIONS = {
    "polar_get_exercises": (
        "List all Polar exercises from the last 30 days. Returns sport type, duration, calories, "
        "distance, heart rate (avg/max), training load, and optional HR samples/zones/route."
    ),
    "polar_get_exercise": (
        "Get a single Polar exercise by ID with full details including HR zones, samples, route, "
        "and Training Load Pro data."
    ),
    "polar_get_daily_activity": (
        "Get daily activity summary for a date: steps, calories (total + active), duration, active steps."
    ),
    "polar_get_activity_range": "Get daily activity summaries for a date range.",
    "polar_get_continuous_hr": (
        "Get continuous heart rate samples for a specific date (time-series with sample_time and heart_rate values)."
    ),
    "polar_get_continuous_hr_range": "Get continuous heart rate data for a date range.",
    "polar_get_sleep": (
        "Get detailed sleep data: stages (light/deep/REM), sleep score, continuity, interruptions, "
        "hypnogram, HR samples during sleep."
    ),
    "polar_get_nightly_recharge": (
        "Get Nightly Recharge recovery data: ANS charge, HRV average, breathing rate, heart rate "
        "during sleep, plus HRV/breathing time-series samples."
    ),
    "polar_get_cardio_load": (
        "Get cardio load (TRIMP training load) for a date, including load status and tolerance levels."
    ),
    "polar_get_cardio_load_range": "Get cardio load data for a date range.",
    "polar_get_sleepwise_alertness": (
        "Get SleepWise alertness periods — predicted alertness levels throughout the day based on sleep quality."
    ),
    "polar_get_sleepwise_bedtime": (
        "Get SleepWise circadian bedtime recommendations — optimal sleep/wake times based on circadian rhythm."
    ),
    "polar_get_body_temperature": "Get Elixir body temperature measurements.",
    "polar_get_physical_info": (
        "Get user physical information: weight, height, max heart rate, VO2 max, resting HR, gender, birthdate."
    ),
}

# ---------------------------------------------------------------------------
# Tool map
# tool_name -> (path_template, input_schema, uses_polar_user_id)
# ---------------------------------------------------------------------------

_TOOL_MAP: dict[str, tuple[str, dict, bool]] = {
    "polar_get_exercises": ("/v3/exercises", _EXERCISES_LIST_SCHEMA, False),
    "polar_get_exercise": ("/v3/exercises/{exercise_id}", _EXERCISE_ID_SCHEMA, False),
    "polar_get_daily_activity": ("/v3/users/activity-summary/{date}", _DATE_SCHEMA, False),
    "polar_get_activity_range": ("/v3/users/activity-summary", _DATE_RANGE_SCHEMA, False),
    "polar_get_continuous_hr": ("/v3/users/continuous-heart-rate/{date}", _DATE_SCHEMA, False),
    "polar_get_continuous_hr_range": ("/v3/users/continuous-heart-rate", _DATE_RANGE_SCHEMA, False),
    "polar_get_sleep": ("/v3/users/sleep-data/{date}", _DATE_SCHEMA, False),
    "polar_get_nightly_recharge": ("/v3/users/nightly-recharge/{date}", _DATE_SCHEMA, False),
    "polar_get_cardio_load": ("/v3/users/cardio-load/{date}", _DATE_SCHEMA, False),
    "polar_get_cardio_load_range": ("/v3/users/cardio-load", _DATE_RANGE_SCHEMA, False),
    "polar_get_sleepwise_alertness": ("/v3/users/sleepwise-alertness", _DATE_RANGE_SCHEMA, False),
    "polar_get_sleepwise_bedtime": ("/v3/users/sleepwise-circadian-bedtime", _DATE_RANGE_SCHEMA, False),
    "polar_get_body_temperature": ("/v3/users/body-temperature", _DATE_RANGE_SCHEMA, False),
    "polar_get_physical_info": ("/v3/users/{polar_user_id}/physical-informations", _NO_PARAMS_SCHEMA, True),
}


class PolarServer(BaseMCPServer):
    """MCP server for Polar AccessLink health and fitness data.

    Exposes 14 tools covering exercises, daily activity, continuous heart
    rate, sleep stages, Nightly Recharge (ANS/HRV), cardio load, SleepWise
    alertness and bedtime, Elixir body temperature, and physical info.

    All requests use Bearer token auth. Polar has no refresh tokens —
    expired tokens return a re-auth error requiring the user to reconnect.
    204 and 404 responses are treated as "no data" rather than errors.

    Args:
        token_service: DB-backed ``PolarTokenService`` for token retrieval.
        db_factory: Callable returning an async context manager yielding
            an ``AsyncSession``.
        rate_limiter: Optional ``PolarRateLimiter`` for app-level rate
            limit enforcement. When provided, checked before every API call
            and updated from response headers after.
    """

    def __init__(
        self,
        token_service: Any,
        db_factory: Callable[[], Any],
        rate_limiter: Any | None = None,
    ) -> None:
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
            The string ``"polar"``.
        """
        return "polar"

    @property
    def description(self) -> str:
        """Human-readable capability summary surfaced to the LLM.

        Returns:
            A description of Polar AccessLink health-data capabilities.
        """
        return (
            "Polar AccessLink integration providing access to exercise data, "
            "daily activity, continuous heart rate, sleep stages, Nightly Recharge "
            "(ANS/HRV recovery), cardio load, SleepWise alertness and circadian "
            "bedtime, Elixir biosensing (body/skin temperature), and "
            "physical information from Polar watches and sensors."
        )

    # ------------------------------------------------------------------
    # Tool definitions
    # ------------------------------------------------------------------

    def get_tools(self) -> list[ToolDefinition]:
        """Return the 14 Polar tools the LLM may invoke.

        Returns:
            A list of 14 ``ToolDefinition`` models covering all major
            Polar AccessLink data types.
        """
        return [
            ToolDefinition(
                name=tool_name,
                description=_TOOL_DESCRIPTIONS[tool_name],
                input_schema=schema,
            )
            for tool_name, (_, schema, _uses_uid) in _TOOL_MAP.items()
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
        """Execute a Polar tool on behalf of the given user.

        Execution flow:
        1. Validate tool_name is in _TOOL_MAP.
        2. Check rate_limiter (if configured) and block if needed.
        3. Call _call_polar to make the API request.

        Args:
            tool_name: One of the 14 polar_* tool names.
            params: Parameter dict matching the tool's ``input_schema``.
            user_id: Authenticated user whose Polar token to use.

        Returns:
            A ``ToolResult`` with Polar data on success, or an error
            result when the tool is unknown, rate-limited, or the API fails.
        """
        if tool_name not in _TOOL_MAP:
            return ToolResult(
                success=False,
                data=None,
                error=f"Unknown tool: {tool_name}",
            )

        if self._rate_limiter is not None:
            allowed = await self._rate_limiter.check_and_increment()
            if not allowed:
                return ToolResult(
                    success=False,
                    data=None,
                    error="Polar app-level rate limit reached. Please try again later.",
                )

        return await self._call_polar(tool_name, params, user_id)

    # ------------------------------------------------------------------
    # HTTP helper
    # ------------------------------------------------------------------

    async def _call_polar(
        self,
        tool_name: str,
        params: dict,
        user_id: str,
    ) -> ToolResult:
        """Make a GET request to the Polar AccessLink API.

        Steps:
        1. Resolve access token from DB.
        2. Build URL from path template, substituting path params.
        3. Build query params (from/to for range endpoints, samples, zones).
        4. GET with Bearer token, timeout=30s.
        5. Update rate limiter from response headers (if configured).
        6. Handle 401/429/204/404/>=400/2xx status codes.

        Args:
            tool_name: The Polar tool name (key in ``_TOOL_MAP``).
            params: Tool input parameters.
            user_id: Zuralog user ID for token lookup.

        Returns:
            A ``ToolResult`` with data on success or error on failure.
        """
        # 1. Resolve token
        async with self._db_factory() as db:
            token = await self._token_service.get_access_token(db, user_id)

        if not token:
            return ToolResult(
                success=False,
                data=None,
                error=("No Polar access token available. Please connect your Polar account first."),
            )

        path_template, _schema, uses_polar_user_id = _TOOL_MAP[tool_name]

        # 2. Substitute path params
        url_path = path_template

        if "{date}" in url_path:
            url_path = url_path.replace("{date}", params.get("date", ""))

        if "{exercise_id}" in url_path:
            url_path = url_path.replace("{exercise_id}", params.get("exercise_id", ""))

        if uses_polar_user_id and "{polar_user_id}" in url_path:
            # Fetch polar_user_id from integration metadata
            async with self._db_factory() as db:
                integration = await self._token_service.get_integration(db, user_id)
            polar_user_id = ""
            if integration and integration.provider_metadata:
                polar_user_id = str(integration.provider_metadata.get("polar_user_id", ""))
            url_path = url_path.replace("{polar_user_id}", polar_user_id)

        url = f"{POLAR_API_BASE}{url_path}"

        # 3. Build query params
        query: dict[str, str] = {}

        # Range endpoints: path has no {date} segment but accepts from/to
        is_range = "{date}" not in path_template and "{exercise_id}" not in path_template and not uses_polar_user_id
        if is_range and "date" in params:
            query["from"] = params["date"]
            if "end_date" in params:
                query["to"] = params["end_date"]

        if params.get("include_samples"):
            query["samples"] = "true"
        if params.get("include_zones"):
            query["zones"] = "true"

        # 4. Make the GET request
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    url,
                    params=query if query else None,
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=30.0,
                )
        except httpx.TimeoutException:
            return ToolResult(
                success=False,
                data=None,
                error="Polar API request timed out.",
            )
        except Exception as exc:  # noqa: BLE001
            return ToolResult(
                success=False,
                data=None,
                error=str(exc),
            )

        # 5. Update rate limiter from response headers
        if self._rate_limiter is not None:
            await self._rate_limiter.update_from_headers(dict(resp.headers))

        # 6. Handle status codes
        if resp.status_code == 401:
            return ToolResult(
                success=False,
                data=None,
                error="Polar token expired or revoked. Please reconnect your Polar account.",
            )

        if resp.status_code == 429:
            return ToolResult(
                success=False,
                data=None,
                error="Polar API rate limited. Please try again later.",
            )

        if resp.status_code == 204:
            return ToolResult(
                success=True,
                data={"message": "No data available for this date/range."},
            )

        if resp.status_code == 404:
            return ToolResult(
                success=True,
                data={"message": "No data found for this date/range."},
            )

        if resp.status_code >= 400:
            return ToolResult(
                success=False,
                data=None,
                error=f"Polar API error {resp.status_code}: {resp.text}",
            )

        # 2xx success
        return ToolResult(success=True, data=resp.json())

    # ------------------------------------------------------------------
    # Resources
    # ------------------------------------------------------------------

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return data resources available for the given user.

        Args:
            user_id: The authenticated user (unused — same resources for all).

        Returns:
            A list with one ``Resource`` describing Polar health data.
        """
        return [
            Resource(
                uri="polar://health/data",
                name="Polar Health Data",
                description=(
                    "Exercises, activity, heart rate, sleep, nightly recharge, cardio load, "
                    "SleepWise, biosensing, and physical info from Polar"
                ),
            )
        ]

    # ------------------------------------------------------------------
    # Health check
    # ------------------------------------------------------------------

    async def health_check(self) -> bool:
        """Verify Polar API base connectivity with a lightweight probe.

        Sends a HEAD request to the Polar API base URL. Returns ``True``
        on any 2xx/3xx HTTP response, ``False`` on network errors or 4xx/5xx.

        Returns:
            ``True`` if the Polar API is reachable and returns a healthy
            status code, ``False`` otherwise.
        """
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.head(POLAR_API_BASE, timeout=5.0)
            return 200 <= resp.status_code < 400
        except Exception:  # noqa: BLE001
            return False

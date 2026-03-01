"""
Zuralog Cloud Brain — Withings MCP Server.

Wraps 10 Withings API endpoints so the LLM agent can query health metrics:
body composition, blood pressure, temperature, SpO2, HRV, daily activity,
workouts, sleep, sleep summary, and ECG recordings.

Key differences from Oura/Fitbit/Strava:
- All Withings API calls use POST (not GET)
- Every request must be signed: signed params come from WithingsSignatureService
- Access tokens expire in 3 hours (most aggressive) — auto-refresh on 401
- App-level rate limit: 120 req/min enforced via WithingsRateLimiter
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from typing import Any

import httpx

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult

logger = logging.getLogger(__name__)

_WITHINGS_API_BASE = "https://wbsapi.withings.net"

# Tool → (endpoint_path, action, optional meastypes filter)
_TOOL_MAP: dict[str, tuple[str, str, str | None]] = {
    "withings_get_measurements": ("/measure", "getmeas", "1,5,6,8,76,77,88,91"),
    "withings_get_blood_pressure": ("/measure", "getmeas", "9,10,11"),
    "withings_get_temperature": ("/measure", "getmeas", "12,71,73"),
    "withings_get_spo2": ("/measure", "getmeas", "54"),
    "withings_get_hrv": ("/measure", "getmeas", "135"),
    "withings_get_activity": ("/v2/measure", "getactivity", None),
    "withings_get_workouts": ("/v2/measure", "getworkouts", None),
    "withings_get_sleep": ("/v2/sleep", "get", None),
    "withings_get_sleep_summary": ("/v2/sleep", "getsummary", None),
    "withings_get_heart_list": ("/v2/heart", "list", None),
}


class WithingsServer(BaseMCPServer):
    """MCP server for Withings health data queries.

    Exposes 10 tools covering body composition, blood pressure, temperature,
    SpO2, HRV, activity, workouts, sleep, and ECG. All requests use POST with
    HMAC SHA-256 signed parameters.

    Args:
        token_service: DB-backed WithingsTokenService.
        signature_service: WithingsSignatureService for nonce+HMAC signing.
        db_factory: Callable returning an async context manager yielding AsyncSession.
        rate_limiter: Optional WithingsRateLimiter (120 req/min app-level).
    """

    def __init__(
        self,
        token_service: Any,
        signature_service: Any,
        db_factory: Callable[[], Any],
        rate_limiter: Any | None = None,
    ) -> None:
        self._token_service = token_service
        self._signature_service = signature_service
        self._db_factory = db_factory
        self._rate_limiter = rate_limiter

    @property
    def name(self) -> str:
        return "withings"

    @property
    def description(self) -> str:
        return (
            "Query Withings health data including: body composition (weight, fat ratio, "
            "fat-free mass, muscle mass, bone mass, hydration, pulse wave velocity), "
            "blood pressure (systolic, diastolic, heart rate), body temperature (oral, "
            "skin, body), SpO2 (blood oxygen saturation), HRV (heart rate variability), "
            "daily activity (steps, distance, active calories, soft/moderate/intense "
            "activity durations), workout sessions, detailed sleep data with heart rate "
            "curves, sleep summary (score, stages, efficiency, duration), and ECG "
            "recordings with AFib detection from Withings smart scales, blood pressure "
            "monitors, sleep mats, and thermometers."
        )

    def get_tools(self) -> list[ToolDefinition]:
        """Return the 10 Withings tools the LLM may invoke."""
        _date_range_schema = {
            "type": "object",
            "properties": {
                "start_date": {
                    "type": "string",
                    "description": "Start date in YYYY-MM-DD format or Unix timestamp.",
                },
                "end_date": {
                    "type": "string",
                    "description": "End date in YYYY-MM-DD format or Unix timestamp (optional).",
                },
            },
            "required": ["start_date"],
        }

        return [
            ToolDefinition(
                name="withings_get_measurements",
                description=(
                    "Get Withings body composition measurements: weight, fat ratio, "
                    "fat-free mass, fat mass, muscle mass, bone mass, hydration, and "
                    "pulse wave velocity. From smart scales."
                ),
                input_schema=_date_range_schema,
            ),
            ToolDefinition(
                name="withings_get_blood_pressure",
                description=(
                    "Get Withings blood pressure readings: systolic mmHg, diastolic mmHg, "
                    "and heart rate BPM. From blood pressure monitors."
                ),
                input_schema=_date_range_schema,
            ),
            ToolDefinition(
                name="withings_get_temperature",
                description=(
                    "Get Withings temperature measurements: oral/body temperature and "
                    "skin temperature in Celsius. From thermometers and sleep mats."
                ),
                input_schema=_date_range_schema,
            ),
            ToolDefinition(
                name="withings_get_spo2",
                description=("Get Withings SpO2 (blood oxygen saturation percentage) measurements."),
                input_schema=_date_range_schema,
            ),
            ToolDefinition(
                name="withings_get_hrv",
                description=("Get Withings HRV (heart rate variability in milliseconds) measurements."),
                input_schema=_date_range_schema,
            ),
            ToolDefinition(
                name="withings_get_activity",
                description=(
                    "Get Withings daily activity summary: steps, distance, active calories, "
                    "total calories, soft/moderate/intense activity durations, elevation."
                ),
                input_schema=_date_range_schema,
            ),
            ToolDefinition(
                name="withings_get_workouts",
                description=("Get Withings workout sessions with type, duration, calories, and heart rate data."),
                input_schema=_date_range_schema,
            ),
            ToolDefinition(
                name="withings_get_sleep",
                description=(
                    "Get detailed Withings sleep data with heart rate curves, "
                    "respiratory rate, and per-epoch sleep stage data."
                ),
                input_schema=_date_range_schema,
            ),
            ToolDefinition(
                name="withings_get_sleep_summary",
                description=(
                    "Get Withings sleep summary: score, duration, wake/light/deep/REM "
                    "stage durations, sleep efficiency, start/end times."
                ),
                input_schema=_date_range_schema,
            ),
            ToolDefinition(
                name="withings_get_heart_list",
                description=("Get Withings ECG recordings with AFib detection results from the ScanWatch."),
                input_schema=_date_range_schema,
            ),
        ]

    async def execute_tool(
        self,
        tool_name: str,
        params: dict,
        user_id: str,
    ) -> ToolResult:
        """Execute a Withings tool for the given user."""
        if tool_name not in _TOOL_MAP:
            return ToolResult(success=False, data=None, error=f"Unknown tool: {tool_name}")

        # Rate limit check
        if self._rate_limiter is not None:
            allowed = await self._rate_limiter.check_and_increment()
            if not allowed:
                return ToolResult(
                    success=False,
                    data=None,
                    error="Withings app-level rate limit reached (120 req/min). Try again shortly.",
                )

        # Resolve token
        async with self._db_factory() as db:
            token = await self._token_service.get_access_token(db, user_id)

        if not token:
            return ToolResult(
                success=False,
                data=None,
                error="No Withings access token. Please connect your Withings account first.",
            )

        endpoint_path, action, meastypes = _TOOL_MAP[tool_name]
        return await self._call_withings(
            endpoint_path=endpoint_path,
            action=action,
            meastypes=meastypes,
            params=params,
            token=token,
            user_id=user_id,
        )

    async def _call_withings(
        self,
        endpoint_path: str,
        action: str,
        meastypes: str | None,
        params: dict,
        token: str,
        user_id: str,
        *,
        _retry: bool = True,
    ) -> ToolResult:
        """Make a signed POST request to the Withings API.

        1. Build date range extra_params from start_date/end_date.
        2. Get signed params via signature_service.prepare_signed_params.
        3. POST to Withings with Bearer token header.
        4. On Withings status != 0 with auth hint: refresh once and retry.
        """
        import calendar
        from datetime import date

        def _to_unix(d: str | None) -> int | None:
            if not d:
                return None
            if d.isdigit():
                return int(d)
            try:
                parsed = date.fromisoformat(d)
                return int(calendar.timegm(parsed.timetuple()))
            except ValueError:
                return None

        start_date = params.get("start_date")
        end_date = params.get("end_date", start_date)

        extra_params: dict[str, Any] = {}

        # Activity and sleep endpoints use startdateymd/enddateymd
        if action in ("getactivity", "getworkouts", "getsummary"):
            if start_date and not str(start_date).isdigit():
                extra_params["startdateymd"] = start_date
                if end_date:
                    extra_params["enddateymd"] = end_date
            else:
                ts = _to_unix(start_date)
                if ts:
                    extra_params["startdate"] = ts
                ts_end = _to_unix(end_date)
                if ts_end:
                    extra_params["enddate"] = ts_end
        elif action in ("get", "list"):
            ts = _to_unix(start_date)
            if ts:
                extra_params["startdate"] = ts
            ts_end = _to_unix(end_date)
            if ts_end:
                extra_params["enddate"] = ts_end
        else:
            # getmeas uses startdate/enddate as unix timestamps
            ts = _to_unix(start_date)
            if ts:
                extra_params["startdate"] = ts
            ts_end = _to_unix(end_date)
            if ts_end:
                extra_params["enddate"] = ts_end
            if meastypes:
                extra_params["meastypes"] = meastypes

        try:
            signed_params = await self._signature_service.prepare_signed_params(
                action=action,
                extra_params=extra_params,
            )
        except Exception as exc:
            return ToolResult(success=False, data=None, error=f"Failed to sign request: {exc}")

        url = f"{_WITHINGS_API_BASE}{endpoint_path}"

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(
                    url,
                    data=signed_params,
                    headers={"Authorization": f"Bearer {token}"},
                )
        except httpx.RequestError as exc:
            return ToolResult(success=False, data=None, error=f"Network error: {exc}")

        try:
            body = resp.json()
        except Exception:
            return ToolResult(
                success=False,
                data=None,
                error=f"Withings returned non-JSON response (HTTP {resp.status_code})",
            )

        status = body.get("status", -1)

        # Auth error → refresh token once and retry
        if status in (401, 293) and _retry:
            logger.info("Withings auth error %d for user '%s' — refreshing token", status, user_id)
            async with self._db_factory() as db:
                integration = await self._token_service.get_integration(db, user_id)
                if integration is None:
                    return ToolResult(
                        success=False,
                        data=None,
                        error="Withings token expired and no integration found. Please reconnect.",
                    )
                new_token = await self._token_service.refresh_access_token(db, integration)

            if not new_token:
                return ToolResult(
                    success=False,
                    data=None,
                    error="Withings token expired and refresh failed. Please reconnect your Withings account.",
                )
            return await self._call_withings(
                endpoint_path=endpoint_path,
                action=action,
                meastypes=meastypes,
                params=params,
                token=new_token,
                user_id=user_id,
                _retry=False,
            )

        if status != 0:
            return ToolResult(
                success=False,
                data=None,
                error=f"Withings API error: status={status}, error={body.get('error', 'unknown')}",
            )

        return ToolResult(success=True, data=body.get("body", body))

    async def get_resources(self, user_id: str) -> list[Resource]:
        return [
            Resource(
                uri="withings://health/data",
                name="Withings Health Data",
                description=(
                    "Body composition, blood pressure, temperature, SpO2, HRV, "
                    "daily activity, workouts, sleep, and ECG data from Withings "
                    "smart scales, blood pressure monitors, sleep mats, and ScanWatch."
                ),
            )
        ]

    async def health_check(self) -> bool:
        """Verify Withings API base connectivity."""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.head(_WITHINGS_API_BASE)
            return resp.status_code in range(200, 400)
        except httpx.RequestError:
            return False

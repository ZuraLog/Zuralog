"""
ZuraLog Cloud Brain — Integrations MCP Server.

Exposes the ``get_integrations`` tool so the LLM agent can discover which
integrations ZuraLog supports and which ones the current user has connected.

The catalog lives here in code — adding a new integration always requires
a new MCP server anyway, so this is the right place to register its metadata.
The system prompt never mentions integration names directly; the AI learns
what is available and connected by calling this tool.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from sqlalchemy import select

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult
from app.models.integration import Integration

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Integration catalog
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class _IntegrationEntry:
    """Static metadata for one ZuraLog integration.

    Attributes:
        provider: Key stored in ``Integration.provider`` (e.g. ``"strava"``).
        display_name: Human-readable name shown to users (e.g. ``"Strava"``).
        description: What data this integration provides.
        tools: Tool names available when the user has this integration connected.
    """

    provider: str
    display_name: str
    description: str
    tools: tuple[str, ...]


# Single source of truth for every integration ZuraLog supports.
# Add a new entry here when a new integration MCP server is shipped.
_CATALOG: tuple[_IntegrationEntry, ...] = (
    _IntegrationEntry(
        provider="strava",
        display_name="Strava",
        description="Sports activities including running, cycling, and swimming via live API.",
        tools=("strava_get_activities", "strava_create_activity"),
    ),
    _IntegrationEntry(
        provider="fitbit",
        display_name="Fitbit",
        description=(
            "Steps, sleep, heart rate, HRV, SpO2, breathing rate, "
            "skin temperature, VO2 max, weight, and nutrition via live API."
        ),
        tools=(
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
        ),
    ),
    _IntegrationEntry(
        provider="oura",
        display_name="Oura Ring",
        description=(
            "Sleep, readiness, daily activity, resilience, stress, "
            "heart rate, SpO2, VO2 max, and workouts via live API."
        ),
        tools=(
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
        ),
    ),
    _IntegrationEntry(
        provider="withings",
        display_name="Withings",
        description=(
            "Body measurements, blood pressure, temperature, SpO2, "
            "HRV, activity, workouts, and sleep via live API."
        ),
        tools=(
            "withings_get_measurements",
            "withings_get_blood_pressure",
            "withings_get_temperature",
            "withings_get_spo2",
            "withings_get_hrv",
            "withings_get_activity",
            "withings_get_workouts",
            "withings_get_sleep",
            "withings_get_sleep_summary",
        ),
    ),
    _IntegrationEntry(
        provider="polar",
        display_name="Polar",
        description=(
            "Exercise sessions, daily activity, continuous heart rate, "
            "sleep, nightly recharge, cardio load, and body temperature via live API."
        ),
        tools=(
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
        ),
    ),
)

# Quick lookup: provider key → catalog entry
_CATALOG_BY_PROVIDER: dict[str, _IntegrationEntry] = {
    entry.provider: entry for entry in _CATALOG
}


def get_display_name(provider: str) -> str:
    """Return the display name for a provider key.

    Used by the orchestrator to build the system prompt's Connected Apps
    section using the same names as ``get_integrations`` returns.

    Args:
        provider: The ``Integration.provider`` value (e.g. ``"strava"``).

    Returns:
        The catalog display name, or a title-cased fallback for unknown providers.
    """
    entry = _CATALOG_BY_PROVIDER.get(provider)
    return entry.display_name if entry is not None else provider.title()


# ---------------------------------------------------------------------------
# MCP Server
# ---------------------------------------------------------------------------


class IntegrationsMCPServer(BaseMCPServer):
    """MCP server exposing the ``get_integrations`` tool.

    Lets the LLM agent discover what integrations ZuraLog supports,
    which ones the current user has connected, and what tools to call
    for each. Read-only — connecting and disconnecting integrations is
    done through the ZuraLog app, not through the AI.

    Args:
        db_factory: A callable returning an async context manager
            that yields an ``AsyncSession``.
    """

    def __init__(self, db_factory: Callable[[], Any]) -> None:
        """Initialise with a database session factory.

        Args:
            db_factory: Callable returning an async context manager
                that yields an ``AsyncSession``.
        """
        self._db_factory = db_factory

    # ------------------------------------------------------------------
    # BaseMCPServer properties
    # ------------------------------------------------------------------

    @property
    def name(self) -> str:
        """Unique identifier used by the MCP registry.

        Returns:
            The string ``"integrations"``.
        """
        return "integrations"

    @property
    def description(self) -> str:
        """Human-readable capability summary surfaced to the LLM.

        Returns:
            A description of the integrations discovery capability.
        """
        return (
            "Discover which integrations ZuraLog supports and which ones "
            "this user has connected. Use get_integrations to find what "
            "tools are available before calling any integration-specific tool."
        )

    # ------------------------------------------------------------------
    # Tool definitions
    # ------------------------------------------------------------------

    def get_tools(self) -> list[ToolDefinition]:
        """Return the get_integrations tool definition.

        Returns:
            A single-element list containing the tool definition.
        """
        return [
            ToolDefinition(
                name="get_integrations",
                description=(
                    "Return all integrations ZuraLog supports, with connection "
                    "status and available tool names for each. Call this before "
                    "using any integration-specific tool to confirm the user has "
                    "that service connected. Also use this when the user asks what "
                    "apps they can connect, or to check the status of a service."
                ),
                input_schema={"type": "object", "properties": {}, "required": []},
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
        """Dispatch tool calls to the appropriate handler.

        Args:
            tool_name: Must be ``"get_integrations"``.
            params: Unused (the tool takes no parameters).
            user_id: The authenticated user whose connections to query.

        Returns:
            A ``ToolResult`` with the integrations list, or an error result.
        """
        if tool_name == "get_integrations":
            return await self._get_integrations(user_id)
        return ToolResult(success=False, error=f"Unknown tool: {tool_name}")

    async def _get_integrations(self, user_id: str) -> ToolResult:
        """Merge the static catalog with the user's live connection status.

        Args:
            user_id: The authenticated user whose ``integrations`` rows to read.

        Returns:
            Success result with an ``integrations`` list. Each item contains:
            ``provider``, ``display_name``, ``description``, ``connected`` (bool),
            ``tools`` (list of tool names), and optionally ``sync_status``,
            ``last_synced_at``, and ``sync_error`` when connected.
        """
        try:
            async with self._db_factory() as db:
                result = await db.execute(
                    select(
                        Integration.provider,
                        Integration.sync_status,
                        Integration.last_synced_at,
                        Integration.sync_error,
                    ).where(
                        Integration.user_id == user_id,
                        Integration.is_active.is_(True),
                    )
                )
                rows = result.all()
        except Exception as exc:
            logger.exception(
                "get_integrations DB query failed for user '%s'", user_id[:8]
            )
            return ToolResult(success=False, error=str(exc))

        # Build a lookup from provider key → connection details
        connected: dict[str, dict] = {}
        for row in rows:
            connected[row.provider] = {
                "sync_status": row.sync_status,
                "last_synced_at": (
                    row.last_synced_at.isoformat() if row.last_synced_at else None
                ),
                "sync_error": row.sync_error,
            }

        integrations = []
        for entry in _CATALOG:
            conn = connected.get(entry.provider)
            record: dict = {
                "provider": entry.provider,
                "display_name": entry.display_name,
                "description": entry.description,
                "connected": conn is not None,
                "tools": list(entry.tools),
            }
            if conn is not None:
                record["sync_status"] = conn["sync_status"]
                record["last_synced_at"] = conn["last_synced_at"]
                if conn["sync_error"]:
                    record["sync_error"] = conn["sync_error"]
            integrations.append(record)

        return ToolResult(success=True, data={"integrations": integrations})

    # ------------------------------------------------------------------
    # Resources
    # ------------------------------------------------------------------

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return data resources available for the given user.

        The integrations server has no readable resources — the catalog
        and connection status are accessed exclusively through the
        ``get_integrations`` tool.

        Args:
            user_id: The authenticated user (unused).

        Returns:
            An empty list.
        """
        return []

"""Apple HealthKit MCP Server.

Exposes Apple Health capabilities as semantic tools for the LLM agent.
Read tools query the Cloud Brain's PostgreSQL database (populated by
the /health/ingest endpoint). Write tools delegate to DeviceWriteService
which pushes the request to the user's iOS device via FCM.

Registered in main.py lifespan via app.state.mcp_registry.

This module is intentionally thin: all shared DB-query and write-dispatch
logic lives in ``HealthDataServerBase``.
"""

from __future__ import annotations

from app.mcp_servers.health_data_server_base import HealthDataServerBase


class AppleHealthServer(HealthDataServerBase):
    """MCP server for Apple HealthKit data.

    Read tools query PostgreSQL data ingested by the /health/ingest
    endpoint (populated by the iOS Edge Agent).

    Write tools delegate to DeviceWriteService, which sends an FCM
    push to the user's device to perform the HealthKit write natively.

    Parameters
    ----------
    db_factory : AsyncContextManager factory, optional
        Called as `async with db_factory() as db` to get an AsyncSession.
        When None, read tools return an appropriate error.
    device_write_service : DeviceWriteService, optional
        Used to dispatch FCM write commands to the user's iOS device.
        When None, write tools return an appropriate error.
    """

    @property
    def name(self) -> str:
        """Unique server identifier used for registry lookup."""
        return "apple_health"

    @property
    def description(self) -> str:
        """Human-readable description for LLM system prompts."""
        return (
            "Read Apple HealthKit data stored in the Cloud Brain database. "
            "Supports steps, active calories, resting heart rate, HRV, VO2 max, "
            "workouts, sleep, body weight, and nutrition. "
            "Use 'daily_summary' to get all scalar metrics for a date range. "
            "Data is populated by the iOS Edge Agent after Apple Health authorization."
        )

    @property
    def source_name(self) -> str:
        """DB source column value for Apple Health records."""
        return "apple_health"

    @property
    def platform(self) -> str:
        """Device platform for FCM token lookup."""
        return "ios"

    @property
    def _read_tool_name(self) -> str:
        """MCP tool name for read operations."""
        return "apple_health_read_metrics"

    @property
    def _write_tool_name(self) -> str:
        """MCP tool name for write operations."""
        return "apple_health_write_entry"

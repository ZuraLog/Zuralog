"""Google Health Connect MCP Server.

Exposes Health Connect capabilities as semantic tools for the LLM agent.
Read tools query the Cloud Brain's PostgreSQL database (populated by
the /health/ingest endpoint via the Android Edge Agent + WorkManager sync).
Write tools delegate to DeviceWriteService which pushes the request to
the user's Android device via FCM.

Registered in main.py lifespan via app.state.mcp_registry.

This module is intentionally thin: all shared DB-query and write-dispatch
logic lives in ``HealthDataServerBase``.
"""

from __future__ import annotations

from app.mcp_servers.health_data_server_base import HealthDataServerBase


class HealthConnectServer(HealthDataServerBase):
    """MCP server for Google Health Connect data.

    Read tools query PostgreSQL data ingested by the /health/ingest
    endpoint (populated by the Android Edge Agent via WorkManager sync).

    Write tools delegate to DeviceWriteService, which sends an FCM
    push to the user's Android device to perform the Health Connect
    write natively.

    Parameters
    ----------
    db_factory : AsyncContextManager factory, optional
        Called as `async with db_factory() as db` to get an AsyncSession.
        When None, read tools return an appropriate error.
    device_write_service : DeviceWriteService, optional
        Used to dispatch FCM write commands to the user's Android device.
        When None, write tools return an appropriate error.
    """

    @property
    def name(self) -> str:
        """Unique server identifier used for registry lookup."""
        return "health_connect"

    @property
    def description(self) -> str:
        """Human-readable description for LLM system prompts."""
        return (
            "Read Google Health Connect data stored in the Cloud Brain database. "
            "Supports steps, active calories, resting heart rate, HRV, VO2 max, "
            "workouts, sleep, body weight, nutrition, body fat, respiratory rate, "
            "SpO2, heart rate, distance, and floors climbed. "
            "Use 'daily_summary' to get all scalar metrics for a date range. "
            "Data is populated by the Android Edge Agent after Health Connect authorization."
        )

    @property
    def source_name(self) -> str:
        """DB source column value for Health Connect records."""
        return "health_connect"

    @property
    def platform(self) -> str:
        """Device platform for FCM token lookup."""
        return "android"

    @property
    def _read_tool_name(self) -> str:
        """MCP tool name for read operations."""
        return "health_connect_read_metrics"

    @property
    def _write_tool_name(self) -> str:
        """MCP tool name for write operations."""
        return "health_connect_write_entry"

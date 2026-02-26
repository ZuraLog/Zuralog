"""Apple HealthKit MCP Server.

Exposes Apple Health capabilities as semantic tools for the LLM agent.
Read tools query the Cloud Brain's PostgreSQL database (populated by
the /health/ingest endpoint). Write tools delegate to DeviceWriteService
which pushes the request to the user's iOS device via FCM.

Registered in main.py lifespan via app.state.mcp_registry.
"""

from __future__ import annotations

import logging
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult
from app.models.daily_metrics import DailyHealthMetrics
from app.models.health_data import (
    NutritionEntry as NutritionModel,
    SleepRecord,
    UnifiedActivity,
    WeightMeasurement,
)

logger = logging.getLogger(__name__)


class AppleHealthServer(BaseMCPServer):
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

    def __init__(
        self,
        db_factory=None,
        device_write_service=None,
    ) -> None:
        """Initialise the server with optional database and write dependencies."""
        self._db_factory = db_factory
        self._device_write_service = device_write_service

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

    def get_tools(self) -> list[ToolDefinition]:
        """Return tool schemas the LLM agent can call.

        Returns two tools:
        - apple_health_read_metrics: Read health data from the database.
        - apple_health_write_entry: Write health data via FCM to the device.
        """
        return [
            ToolDefinition(
                name="apple_health_read_metrics",
                description=(
                    "Read health metrics from the Cloud Brain database (populated from Apple HealthKit). "
                    "Use 'daily_summary' for general health questions. "
                    "Use specific types (steps, workouts, sleep) for targeted questions. "
                    "Always use today's date as end_date and an appropriate lookback for start_date."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "data_type": {
                            "type": "string",
                            "enum": [
                                "steps",
                                "calories",
                                "workouts",
                                "sleep",
                                "weight",
                                "nutrition",
                                "resting_heart_rate",
                                "hrv",
                                "vo2_max",
                                "daily_summary",
                            ],
                            "description": (
                                "The health metric type to query. "
                                "'daily_summary' returns all scalar metrics (steps, calories, HR, HRV, VO2 max) "
                                "for the date range in one call."
                            ),
                        },
                        "start_date": {
                            "type": "string",
                            "description": "Start date in ISO 8601 format (e.g., 2026-02-20).",
                        },
                        "end_date": {
                            "type": "string",
                            "description": "End date in ISO 8601 format (e.g., 2026-02-26).",
                        },
                    },
                    "required": ["data_type", "start_date", "end_date"],
                },
            ),
            ToolDefinition(
                name="apple_health_write_entry",
                description=(
                    "Write health data to Apple HealthKit on the user's iOS device "
                    "via an FCM push notification. Supports: nutrition (calories), workout, weight."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "data_type": {
                            "type": "string",
                            "enum": ["nutrition", "workout", "weight"],
                            "description": "The type of health entry to write.",
                        },
                        "value": {
                            "type": "number",
                            "description": (
                                "The value to write. "
                                "For nutrition: calories (kcal). "
                                "For weight: kilograms. "
                                "For workout: energy burned (kcal)."
                            ),
                        },
                        "date": {
                            "type": "string",
                            "description": "Date/time in ISO 8601 format.",
                        },
                        "metadata": {
                            "type": "object",
                            "description": (
                                'Additional data. For workouts: {"activity_type": "running", "duration_seconds": 1800}'
                            ),
                        },
                    },
                    "required": ["data_type", "value", "date"],
                },
            ),
        ]

    async def execute_tool(
        self,
        tool_name: str,
        params: dict,
        user_id: str,
    ) -> ToolResult:
        """Execute a health tool.

        Routes read tools to the PostgreSQL database and write tools to
        the DeviceWriteService (FCM).

        Parameters
        ----------
        tool_name : str
            Must be 'apple_health_read_metrics' or 'apple_health_write_entry'.
        params : dict
            Tool-specific parameters matching the input_schema.
        user_id : str
            The authenticated user's ID.

        Returns
        -------
        ToolResult
            Success with queried data, or failure with an error message.
        """
        if tool_name == "apple_health_read_metrics":
            return await self._read_metrics(params, user_id)
        if tool_name == "apple_health_write_entry":
            return await self._write_entry(params, user_id)
        return ToolResult(success=False, error=f"Unknown tool: {tool_name}")

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return available data resources.

        Currently empty — resources are surfaced through tool calls.
        """
        return []

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    async def _read_metrics(self, params: dict, user_id: str) -> ToolResult:
        """Query the Cloud Brain database for health metrics.

        Parameters
        ----------
        params : dict
            Must contain 'data_type', 'start_date', 'end_date'.
        user_id : str
            The authenticated user's ID.

        Returns
        -------
        ToolResult
            Data dict with 'data_type' and 'records' list, or error.
        """
        required = ("data_type", "start_date", "end_date")
        missing = [k for k in required if k not in params]
        if missing:
            return ToolResult(
                success=False,
                error=f"Missing required parameters: {', '.join(missing)}",
            )

        if not self._db_factory:
            return ToolResult(
                success=False,
                error="Database not configured. The server is not fully initialised.",
            )

        data_type = params["data_type"]
        start_date = params["start_date"]
        end_date = params["end_date"]

        try:
            async with self._db_factory() as db:
                return await self._dispatch_read(db, data_type, start_date, end_date, user_id)
        except Exception as exc:
            logger.exception("apple_health read_metrics failed for user %s: %s", user_id, exc)
            return ToolResult(success=False, error=str(exc))

    async def _dispatch_read(
        self,
        db: AsyncSession,
        data_type: str,
        start_date: str,
        end_date: str,
        user_id: str,
    ) -> ToolResult:
        """Route a read request to the appropriate DB query.

        Parameters
        ----------
        db : AsyncSession
            Active database session.
        data_type : str
            One of the supported metric types.
        start_date, end_date : str
            ISO date strings (YYYY-MM-DD).
        user_id : str
            The authenticated user's ID.

        Returns
        -------
        ToolResult
            Query result or error.
        """
        # --- Daily scalar metrics ---
        if data_type in ("steps", "calories", "resting_heart_rate", "hrv", "vo2_max", "daily_summary"):
            result = await db.execute(
                select(DailyHealthMetrics)
                .where(
                    DailyHealthMetrics.user_id == user_id,
                    DailyHealthMetrics.date >= start_date,
                    DailyHealthMetrics.date <= end_date,
                )
                .order_by(DailyHealthMetrics.date)
            )
            rows = result.scalars().all()

            if data_type == "steps":
                records = [{"date": r.date, "steps": r.steps} for r in rows if r.steps is not None]
                return ToolResult(
                    success=True,
                    data={
                        "data_type": "steps",
                        "records": records,
                        "total_steps": sum(r.steps or 0 for r in rows),
                    },
                )
            if data_type == "calories":
                records = [
                    {"date": r.date, "active_calories": r.active_calories}
                    for r in rows
                    if r.active_calories is not None
                ]
                return ToolResult(
                    success=True,
                    data={
                        "data_type": "calories",
                        "records": records,
                        "total_active_calories": sum(r.active_calories or 0 for r in rows),
                    },
                )
            if data_type == "resting_heart_rate":
                records = [
                    {"date": r.date, "resting_heart_rate_bpm": r.resting_heart_rate}
                    for r in rows
                    if r.resting_heart_rate is not None
                ]
                return ToolResult(success=True, data={"data_type": "resting_heart_rate", "records": records})
            if data_type == "hrv":
                records = [{"date": r.date, "hrv_ms": r.hrv_ms} for r in rows if r.hrv_ms is not None]
                return ToolResult(success=True, data={"data_type": "hrv", "records": records})
            if data_type == "vo2_max":
                records = [{"date": r.date, "vo2_max_ml_kg_min": r.vo2_max} for r in rows if r.vo2_max is not None]
                return ToolResult(success=True, data={"data_type": "vo2_max", "records": records})
            if data_type == "daily_summary":
                records = [
                    {
                        "date": r.date,
                        "steps": r.steps,
                        "active_calories": r.active_calories,
                        "resting_heart_rate_bpm": r.resting_heart_rate,
                        "hrv_ms": r.hrv_ms,
                        "vo2_max_ml_kg_min": r.vo2_max,
                        "distance_meters": r.distance_meters,
                        "flights_climbed": r.flights_climbed,
                    }
                    for r in rows
                ]
                return ToolResult(
                    success=True,
                    data={
                        "data_type": "daily_summary",
                        "records": records,
                        "record_count": len(records),
                    },
                )

        # --- Workouts ---
        if data_type == "workouts":
            result = await db.execute(
                select(UnifiedActivity)
                .where(
                    UnifiedActivity.user_id == user_id,
                    UnifiedActivity.source == "apple_health",
                )
                .order_by(UnifiedActivity.start_time)
            )
            rows = result.scalars().all()
            records = [
                {
                    "activity_type": r.activity_type,
                    "duration_seconds": r.duration_seconds,
                    "distance_meters": r.distance_meters,
                    "calories": r.calories,
                    "start_time": r.start_time.isoformat() if r.start_time else None,
                }
                for r in rows
            ]
            return ToolResult(
                success=True,
                data={
                    "data_type": "workouts",
                    "records": records,
                    "count": len(records),
                },
            )

        # --- Sleep ---
        if data_type == "sleep":
            result = await db.execute(
                select(SleepRecord)
                .where(
                    SleepRecord.user_id == user_id,
                    SleepRecord.source == "apple_health",
                    SleepRecord.date >= start_date,
                    SleepRecord.date <= end_date,
                )
                .order_by(SleepRecord.date)
            )
            rows = result.scalars().all()
            records = [{"date": r.date, "hours": r.hours, "quality_score": r.quality_score} for r in rows]
            return ToolResult(
                success=True,
                data={
                    "data_type": "sleep",
                    "records": records,
                    "avg_hours": (round(sum(r.hours for r in rows) / len(rows), 2) if rows else 0),
                },
            )

        # --- Weight ---
        if data_type == "weight":
            result = await db.execute(
                select(WeightMeasurement)
                .where(
                    WeightMeasurement.user_id == user_id,
                    WeightMeasurement.source == "apple_health",
                    WeightMeasurement.date >= start_date,
                    WeightMeasurement.date <= end_date,
                )
                .order_by(WeightMeasurement.date)
            )
            rows = result.scalars().all()
            records = [{"date": r.date, "weight_kg": r.weight_kg} for r in rows]
            return ToolResult(
                success=True,
                data={"data_type": "weight", "records": records},
            )

        # --- Nutrition ---
        if data_type == "nutrition":
            result = await db.execute(
                select(NutritionModel)
                .where(
                    NutritionModel.user_id == user_id,
                    NutritionModel.source == "apple_health",
                    NutritionModel.date >= start_date,
                    NutritionModel.date <= end_date,
                )
                .order_by(NutritionModel.date)
            )
            rows = result.scalars().all()
            records = [
                {
                    "date": r.date,
                    "calories": r.calories,
                    "protein_grams": r.protein_grams,
                    "carbs_grams": r.carbs_grams,
                    "fat_grams": r.fat_grams,
                }
                for r in rows
            ]
            return ToolResult(
                success=True,
                data={"data_type": "nutrition", "records": records},
            )

        return ToolResult(
            success=False,
            error=f"Unsupported data_type: '{data_type}'",
        )

    async def _write_entry(self, params: dict, user_id: str) -> ToolResult:
        """Delegate a write request to the DeviceWriteService.

        Parameters
        ----------
        params : dict
            Must contain 'data_type', 'value', 'date'.
        user_id : str
            The authenticated user's ID.

        Returns
        -------
        ToolResult
            Dispatched confirmation or error if service unavailable.
        """
        required = ("data_type", "value", "date")
        missing = [k for k in required if k not in params]
        if missing:
            return ToolResult(
                success=False,
                error=f"Missing required parameters: {', '.join(missing)}",
            )

        if not self._device_write_service:
            return ToolResult(
                success=False,
                error=("Write service not configured. Device write operations are not available in this environment."),
            )

        data_type = params["data_type"]
        value = params["value"]
        date = params["date"]
        metadata = params.get("metadata", {})

        # TODO(dev): Look up user's device FCM token from the user_devices table
        # and call device_write_service.send_write_request(device_token, ...).
        # For now we return a pending status — full wiring is in Task 5.3.
        logger.info(
            "apple_health write_entry: queued %s for user %s (FCM token lookup pending)",
            data_type,
            user_id,
        )
        return ToolResult(
            success=True,
            data={
                "status": "pending_device_sync",
                "message": (
                    f"Write request for '{data_type}' queued. Full FCM dispatch will be wired in the next phase."
                ),
                "data_type": data_type,
                "value": value,
                "date": date,
            },
        )
